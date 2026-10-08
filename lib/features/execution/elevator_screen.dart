import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
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
    final pendingTasks = e.tasks.length - e.resolvedTasks;
    final allCompleted = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Finalizar ${e.displayName}'),
        content: Text(pendingTasks == 0
            ? 'Todas las tareas están resueltas.'
            : 'Quedan $pendingTasks tareas pendientes. ¿Cómo deseas finalizar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          if (pendingTasks > 0)
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Dejar como están')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(pendingTasks > 0 ? 'Marcar todas' : 'Finalizar')),
        ],
      ),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Equipo')),
      body: asyncView(value, (o) {
        final e = o.elevators.firstWhere((x) => x.id == elevatorId);
        final base = '/ot/$workOrderId/eq/$elevatorId';
        final locked = e.isCompleted;
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text(e.displayName, style: Theme.of(context).textTheme.headlineSmall),
          Text([e.name, e.type, e.brand].whereType<String>().join(' · ')),
          const SizedBox(height: 16),
          _Step(
            n: 1,
            title: 'Checklist de seguridad',
            subtitle: e.safetyDone
                ? 'Aprobado'
                : '${e.safety?.items.where((i) => i.response != null).length ?? 0}'
                    '/${e.safety?.items.length ?? 0} respondidas',
            done: e.safetyDone,
            enabled: e.safety != null,
            onTap: () => context.push('$base/safety'),
          ),
          _Step(
            n: 2,
            title: 'Tareas de mantenimiento',
            subtitle: '${e.resolvedTasks}/${e.tasks.length} aprobadas',
            done: e.tasks.isNotEmpty && e.resolvedTasks == e.tasks.length,
            enabled: e.safetyDone,
            onTap: () => context.push('$base/tasks'),
          ),
          _Step(
            n: 3,
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
            title: 'Hallazgos',
            subtitle: 'Nota, foto o audio · ${e.audios.length} audio(s)',
            done: (e.finding?.isNotEmpty ?? false) || e.audios.isNotEmpty,
            enabled: e.safetyDone,
            onTap: () => context.push('$base/findings'),
          ),
          const SizedBox(height: 24),
          if (locked)
            const Center(child: Text('Equipo finalizado.'))
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
    required this.title,
    required this.subtitle,
    required this.done,
    required this.enabled,
    required this.onTap,
  });
  final int n;
  final String title;
  final String subtitle;
  final bool done;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        enabled: enabled,
        leading: CircleAvatar(
          backgroundColor: done ? Colors.green : cs.primaryContainer,
          foregroundColor: done ? Colors.white : cs.onPrimaryContainer,
          child: done ? const Icon(Icons.check) : Text('$n'),
        ),
        title: Text(title),
        subtitle: Text(enabled ? subtitle : 'Bloqueado'),
        trailing: Icon(enabled ? Icons.chevron_right : Icons.lock_outline),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
