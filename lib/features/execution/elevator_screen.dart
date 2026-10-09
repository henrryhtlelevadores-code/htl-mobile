import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

/// Resumen de un equipo con los pasos en orden. Cada paso se desbloquea
/// cuando el anterior está aprobado, igual que la web (las tareas solo se
/// muestran con la seguridad en `COMPLETED`).
class ElevatorScreen extends ConsumerWidget {
  const ElevatorScreen({super.key, required this.workOrderId, required this.elevatorId});
  final String workOrderId;
  final String elevatorId;

  Future<void> _finish(BuildContext context, WidgetRef ref, Elevator e) async {
    // Hallazgos (el texto `finding` del equipo) es opcional, pero al
    // finalizar queda bloqueado: si está vacío se avisa antes. Los
    // comentarios de las fotos y las notas de voz no lo reemplazan; si los
    // hay, se menciona para que el técnico decida si está conforme.
    if (e.finding?.trim().isEmpty ?? true) {
      final photoNotes = e.photos.where((p) => p.description?.trim().isNotEmpty ?? false).length;
      final audios = e.audios.length;
      final extras = [
        if (photoNotes > 0) photoNotes == 1 ? 'un comentario en una foto' : 'comentarios en $photoNotes fotos',
        if (audios > 0) audios == 1 ? 'una nota de voz' : '$audios notas de voz',
      ];
      final choice = await showChoiceDialog<String>(
        context,
        title: 'Hallazgos está vacío',
        message: extras.isEmpty
            ? 'No escribiste hallazgos para ${e.displayName}. Después de finalizar ya no podrás '
                'agregarlos. ¿Deseas finalizar así?'
            : 'Dejaste ${extras.join(' y ')}, pero el texto de Hallazgos de ${e.displayName} está '
                'vacío. Si estás conforme, continúa; si no, escríbelo antes de finalizar.',
        actions: const [
          DialogAction('Escribir hallazgos', 'add', icon: Icons.edit_note),
          DialogAction('Estoy conforme, continuar', 'continue'),
        ],
      );
      if (!context.mounted || choice == null) return;
      if (choice == 'add') {
        context.push('/ot/$workOrderId/eq/$elevatorId/findings');
        return;
      }
    }

    final pendingTasks = e.tasks.length - e.resolvedTasks;
    final allCompleted = await showChoiceDialog<bool>(
      context,
      title: 'Finalizar ${e.displayName}',
      message: pendingTasks == 0
          ? 'Todas las tareas están resueltas.'
          : 'Quedan $pendingTasks tareas pendientes. ¿Cómo deseas finalizar?',
      actions: [
        DialogAction(pendingTasks > 0 ? 'Marcar todas y finalizar' : 'Finalizar', true, icon: Icons.task_alt),
        if (pendingTasks > 0) const DialogAction('Finalizar y dejarlas como están', false),
      ],
    );
    if (allCompleted == null) return;
    final error = ref
        .read(workOrderProvider(workOrderId).notifier)
        .completeElevator(e, allCompleted: allCompleted);
    if (!context.mounted) return;
    showResult(context, ActionResult(error == null, error ?? 'Equipo finalizado.'));
    if (error == null) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(workOrderProvider(workOrderId));
    final colors = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Equipo')),
      body: asyncView(value, (o) {
        final e = o.elevators.firstWhere((x) => x.id == elevatorId);
        final base = '/ot/$workOrderId/eq/$elevatorId';
        final locked = e.isCompleted;
        final answered = e.safety?.items.where((i) => i.response != null).length ?? 0;
        return ListView(padding: listPadding(context), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.elevator_outlined, color: AppColors.primary, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text([e.name, e.type, e.brand].whereType<String>().join(' · '),
                        style: TextStyle(fontSize: 12.5, color: colors.mutedForeground)),
                  ]),
                ),
                if (locked) const StatusChip('COMPLETED'),
              ]),
            ),
          ),
          const SizedBox(height: 4),
          const SectionLabel('Pasos'),
          _Step(
            n: 1,
            icon: Icons.health_and_safety_outlined,
            title: 'Checklist de seguridad',
            subtitle: e.safetyDone ? 'Aprobado' : '$answered/${e.safety?.items.length ?? 0} respondidas',
            done: e.safetyDone,
            enabled: e.safety != null,
            onTap: () => context.push('$base/safety'),
          ),
          _Step(
            n: 2,
            icon: Icons.checklist_rounded,
            title: 'Tareas de mantenimiento',
            subtitle: '${e.resolvedTasks}/${e.tasks.length} aprobadas',
            done: e.tasks.isNotEmpty && e.resolvedTasks == e.tasks.length,
            enabled: e.safetyDone,
            onTap: () => context.push('$base/tasks'),
          ),
          _Step(
            n: 3,
            icon: Icons.photo_camera_outlined,
            title: 'Fotos del equipo',
            subtitle: e.photosRequired
                ? '${e.photos.length}/${Elevator.minPhotos} mínimo (preventivo)'
                : '${e.photos.length} fotos · sin mínimo',
            done: e.photosRequired ? e.photosOk : e.photos.isNotEmpty,
            enabled: e.safetyDone,
            onTap: () => context.push('$base/photos'),
          ),
          _Step(
            n: 4,
            icon: Icons.sticky_note_2_outlined,
            title: 'Hallazgos',
            subtitle: 'Nota, foto o audio · ${e.audios.length} audio(s)',
            done: (e.finding?.isNotEmpty ?? false) || e.audios.isNotEmpty,
            enabled: e.safetyDone,
            onTap: () => context.push('$base/findings'),
          ),
          const SizedBox(height: 16),
          if (locked)
            Center(
              child: Text('Equipo finalizado.',
                  style: TextStyle(color: colors.mutedForeground, fontWeight: FontWeight.w600)),
            )
          else
            FilledButton.icon(
              icon: const Icon(Icons.task_alt),
              label: Text(!e.safetyDone
                  ? 'Aprueba la seguridad primero'
                  : !e.photosOk
                      ? 'Faltan ${Elevator.minPhotos - e.photos.length} fotos'
                      : 'Finalizar equipo'),
              onPressed: e.safetyDone && e.photosOk ? () => _finish(context, ref, e) : null,
            ),
        ]);
      }),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.n,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.enabled,
    required this.onTap,
  });
  final int n;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final accent = done ? AppColors.emerald : (enabled ? AppColors.primary : colors.mutedForeground);
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: done ? AppColors.emerald : accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: done
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : Text('$n', style: TextStyle(color: accent, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(icon, size: 16, color: accent),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Text(enabled ? subtitle : (n == 1 ? 'Inicia la orden primero' : 'Bloqueado hasta aprobar la seguridad'),
                      style: TextStyle(fontSize: 12, color: colors.mutedForeground)),
                ]),
              ),
              Icon(enabled ? Icons.chevron_right : Icons.lock_outline, color: colors.mutedForeground),
            ]),
          ),
        ),
      ),
    );
  }
}
