import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/photo_capture.dart';

/// Tareas agrupadas por módulo (M1..M8 / General). El técnico aprueba
/// cada tarea, el módulo completo o todas a la vez: se ven aprobadas al
/// instante y se envían juntas en segundo plano. Una tarea puede omitirse
/// o marcarse como "No aplica" con observación, y llevar su propia foto.
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key, required this.workOrderId, required this.elevatorId});
  final String workOrderId;
  final String elevatorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(workOrderProvider(workOrderId));
    final ctrl = ref.read(workOrderProvider(workOrderId).notifier);

    void approveModule(Elevator e, String module, List<MaintenanceTask> tasks) {
      final approve = tasks.any((t) => !t.isResolved);
      ctrl.setTasks(e, tasks, approve: approve);
      showResult(context,
          ActionResult(true, approve ? '$module aprobado' : '$module marcado como pendiente'));
    }

    Future<void> other(Elevator e, MaintenanceTask t) async {
      final obs = TextEditingController(text: t.observations);
      final choice = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (c) => Padding(
          padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(c).viewInsets.bottom + MediaQuery.viewPaddingOf(c).bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(t.description, style: Theme.of(c).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: obs,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Observaciones'),
            ),
            const SizedBox(height: 16),
            // Acción principal a todo el ancho; las demás, en una fila pareja.
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () => Navigator.pop(c, TaskStatus.completed),
              icon: const Icon(Icons.check, size: 20),
              label: const Text('Aprobar'),
            ),
            const SizedBox(height: 8),
            Row(children: [
              for (final (i, (label, status)) in const [
                ('Omitir', TaskStatus.skipped),
                ('No aplica', TaskStatus.notApplicable),
                ('Pendiente', TaskStatus.pending),
              ].indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    onPressed: () => Navigator.pop(c, status),
                    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ]),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.add_a_photo_outlined),
              title: const Text('Agregar foto a esta tarea'),
              onTap: () => Navigator.pop(c, 'PHOTO'),
            ),
          ]),
        ),
      );
      if (choice == null) return;
      if (choice == 'PHOTO') {
        if (!context.mounted) return;
        final shot = await capturePhoto(context, initialTag: PhotoTag.point);
        if (shot == null) return;
        final photo = await ctrl.addPhoto(e, shot.file, shot.tag,
            description: shot.description ?? t.description, taskId: t.id);
        final audio = shot.audio;
        if (audio != null) await ctrl.addAudio(e, audio.file, audio.durationMs, photoId: photo.id);
        return;
      }
      ctrl.setTask(e, t, choice, observations: obs.text.trim());
    }

    final current = value.value?.elevators.where((x) => x.id == elevatorId).firstOrNull;
    final canApproveAll =
        current != null && !current.isCompleted && current.tasks.any((t) => !t.isResolved);

    return Scaffold(
      appBar: AppBar(title: const Text('Tareas'), actions: [
        if (canApproveAll)
          TextButton.icon(
            icon: const Icon(Icons.done_all),
            label: const Text('Aprobar todas'),
            onPressed: () {
              ctrl.setTasks(current, current.tasks, approve: true);
              showResult(context, const ActionResult(true, 'Todas las tareas aprobadas'));
            },
          ),
      ]),
      body: asyncView(value, (o) {
        final e = o.elevators.firstWhere((x) => x.id == elevatorId);
        final readOnly = e.isCompleted;
        final modules = e.tasksByModule;
        if (modules.isEmpty) return const Center(child: Text('Este equipo no tiene tareas.'));
        return ListView(padding: listPadding(context, horizontal: 12, top: 12), children: [
          for (final entry in modules.entries)
            Card(
              child: ExpansionTile(
                // Sin las líneas que ExpansionTile dibuja arriba y abajo.
                shape: const Border(),
                collapsedShape: const Border(),
                initiallyExpanded: entry.value.any((t) => !t.isResolved),
                title: Text(entry.value.first.moduleName ?? entry.key),
                subtitle: Text(
                    '${entry.value.where((t) => t.isResolved).length}/${entry.value.length} aprobadas'),
                trailing: readOnly
                    ? null
                    : TextButton(
                        onPressed: () => approveModule(e, entry.key, entry.value),
                        child: Text(entry.value.every((t) => t.isResolved)
                            ? 'Desmarcar'
                            : 'Aprobar todo'),
                      ),
                children: [
                  for (final t in entry.value)
                    CheckboxListTile(
                      value: t.isCompleted,
                      onChanged: readOnly
                          ? null
                          : (v) => ctrl.setTask(
                              e, t, v == true ? TaskStatus.completed : TaskStatus.pending),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(t.description),
                      subtitle: _TaskSubtitle(t, e.photos.where((p) => p.taskId == t.id).length),
                      secondary: readOnly
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.more_vert),
                              onPressed: () => other(e, t),
                            ),
                    ),
                ],
              ),
            ),
        ]);
      }),
    );
  }
}

class _TaskSubtitle extends StatelessWidget {
  const _TaskSubtitle(this.t, this.photoCount);
  final MaintenanceTask t;
  final int photoCount;

  @override
  Widget build(BuildContext context) {
    final parts = <Widget>[
      if (t.isCritical)
        const Text('CRÍTICA', style: TextStyle(color: AppColors.redText, fontWeight: FontWeight.bold)),
      if (t.status == TaskStatus.skipped) const Text('Omitida'),
      if (t.status == TaskStatus.notApplicable) const Text('No aplica'),
      if (photoCount > 0) Text('📷 $photoCount'),
      if (t.observations?.isNotEmpty ?? false)
        Text(t.observations!, maxLines: 2, overflow: TextOverflow.ellipsis),
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, children: parts);
  }
}
