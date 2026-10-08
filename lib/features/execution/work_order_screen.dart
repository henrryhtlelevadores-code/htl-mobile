import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

/// Paso "revisar": el técnico ve la OT (cliente, sede, contacto, equipos)
/// y la inicia. Iniciar funciona sin señal: crea el checklist de seguridad de
/// cada equipo con la plantilla descargada (ver `WorkOrderController.start`).
class WorkOrderScreen extends ConsumerWidget {
  const WorkOrderScreen({super.key, required this.workOrderId});
  final String workOrderId;

  Future<void> _start(BuildContext context, WidgetRef ref, WorkOrderDetail o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Iniciar trabajo'),
        content: Text('Se registrará la hora de inicio de ${o.otNumber} y los equipos '
            'pasarán a estado de mantenimiento.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Iniciar')),
        ],
      ),
    );
    if (ok != true) return;
    ref.read(workOrderProvider(workOrderId).notifier).start();
    if (context.mounted) {
      showResult(context, const ActionResult(true, 'Orden iniciada'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(workOrderProvider(workOrderId));
    return Scaffold(
      appBar: AppBar(title: Text(value.value?.otNumber ?? 'Orden de trabajo')),
      body: asyncView(value, (o) {
        final cc = o.costCenter;
        return ListView(padding: const EdgeInsets.all(16), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                      child: Text(cc?.name ?? '-',
                          style: Theme.of(context).textTheme.titleMedium)),
                  StatusChip(o.status),
                ]),
                if (o.clientName != null) Text(o.clientName!),
                if (cc?.address != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.place_outlined),
                    title: Text(cc!.address!),
                  ),
                if (cc?.contactName != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_outline),
                    title: Text(cc!.contactName!),
                    subtitle: cc.contactPhone == null ? null : Text(cc.contactPhone!),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: Text([o.scheduledDate, o.scheduledTime]
                      .whereType<String>()
                      .join(' · ')),
                  subtitle: o.serviceTypeName == null ? null : Text(o.serviceTypeName!),
                ),
                if (o.description != null) Text(o.description!),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Text('Equipos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final e in o.elevators)
            Card(
              child: ListTile(
                enabled: !o.isPending,
                leading: Icon(e.isCompleted ? Icons.check_circle : Icons.elevator,
                    color: e.isCompleted ? Colors.green : null),
                title: Text(e.displayName),
                subtitle: Text(o.isPending
                    ? [e.type, e.brand].whereType<String>().join(' · ')
                    : 'Seguridad ${e.safetyDone ? '✓' : 'pendiente'} · '
                        'Tareas ${e.resolvedTasks}/${e.tasks.length} · '
                        'Fotos ${e.photos.length}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/ot/${o.id}/eq/${e.id}'),
              ),
            ),
          const SizedBox(height: 24),
          if (o.isPending)
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Iniciar trabajo'),
              onPressed: () => _start(context, ref, o),
            )
          else if (o.isInProgress)
            FilledButton.icon(
              icon: const Icon(Icons.draw_outlined),
              label: Text(o.allElevatorsCompleted
                  ? 'Cerrar orden y firmar'
                  : 'Finaliza todos los equipos para cerrar'),
              onPressed:
                  o.allElevatorsCompleted ? () => context.push('/ot/${o.id}/close') : null,
            )
          else if (o.isCompleted)
            const Center(child: Text('Orden completada. Pendiente de aprobación del administrador.')),
        ]);
      }, onRetry: () => ref.invalidate(workOrderProvider(workOrderId))),
    );
  }
}
