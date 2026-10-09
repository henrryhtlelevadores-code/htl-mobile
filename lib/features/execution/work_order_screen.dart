import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

/// Paso "revisar": el técnico ve la OT (cliente, sede, contacto, equipos)
/// y la inicia. Iniciar funciona sin señal: crea el checklist de seguridad de
/// cada equipo con la plantilla descargada (ver `WorkOrderController.start`).
class WorkOrderScreen extends ConsumerWidget {
  const WorkOrderScreen({super.key, required this.workOrderId});
  final String workOrderId;

  Future<void> _start(BuildContext context, WidgetRef ref, WorkOrderDetail o) async {
    final ok = await confirmDialog(
      context,
      title: 'Iniciar trabajo',
      message: 'Se registrará la hora de inicio de ${o.otNumber} y los equipos '
          'pasarán a estado de mantenimiento.',
      confirmLabel: 'Iniciar',
      icon: Icons.play_arrow_rounded,
    );
    if (!ok) return;
    ref.read(workOrderProvider(workOrderId).notifier).start();
    if (context.mounted) {
      showResult(context, const ActionResult(true, 'Orden iniciada'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(workOrderProvider(workOrderId));
    final colors = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(value.value?.otNumber ?? 'Orden de trabajo')),
      body: asyncView(value, (o) {
        final cc = o.costCenter;
        final kind = ServiceKind.of(o.serviceTypeCode);
        return ListView(padding: listPadding(context), children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(width: 4, color: kind.color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        if (o.serviceTypeName != null)
                          ServiceTypeChip(code: o.serviceTypeCode, name: o.serviceTypeName!),
                        StatusChip(o.status),
                      ]),
                      const SizedBox(height: 10),
                      Text(o.otNumber,
                          style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.link(context))),
                      const SizedBox(height: 4),
                      Text(cc?.name ?? '-',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.25)),
                      if (o.clientName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(o.clientName!,
                              style: TextStyle(fontSize: 12.5, color: colors.mutedForeground)),
                        ),
                      const SizedBox(height: 12),
                      Divider(color: colors.border),
                      const SizedBox(height: 12),
                      InfoRow(Icons.schedule,
                          [o.scheduledDate, o.scheduledTime].whereType<String>().join(' · ')),
                      if (cc?.address != null) ...[
                        const SizedBox(height: 8),
                        InfoRow(Icons.place_outlined, cc!.address!),
                      ],
                      if (cc?.contactName != null) ...[
                        const SizedBox(height: 8),
                        InfoRow(Icons.person_outline,
                            [cc!.contactName, cc.contactPhone].whereType<String>().join(' · ')),
                      ],
                      if (o.description != null && o.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.muted,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(o.description!, style: const TextStyle(fontSize: 13)),
                        ),
                      ],
                    ]),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          SectionLabel('Equipos · ${o.elevators.length}'),
          for (final e in o.elevators) _ElevatorTile(order: o, elevator: e),
          const SizedBox(height: 16),
          if (o.isPending)
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow_rounded),
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
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.10),
                border: Border.all(color: AppColors.emerald.withValues(alpha: 0.25)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(children: [
                Icon(Icons.check_circle, color: AppColors.emerald),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Orden completada. Pendiente de aprobación del administrador.',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
        ]);
      }, onRetry: () => ref.invalidate(workOrderProvider(workOrderId))),
    );
  }
}

/// Equipo de la OT con su avance (seguridad, tareas y fotos).
class _ElevatorTile extends StatelessWidget {
  const _ElevatorTile({required this.order, required this.elevator});
  final WorkOrderDetail order;
  final Elevator elevator;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final e = elevator;
    final pending = order.isPending;
    final total = e.tasks.length;
    final progress = total == 0 ? 0.0 : e.resolvedTasks / total;
    final safety = e.safetyDone ? '✓' : 'pendiente';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: pending ? null : () => context.push('/ot/${order.id}/eq/${e.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: e.isCompleted
                    ? AppColors.emerald.withValues(alpha: 0.12)
                    : AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(e.isCompleted ? Icons.check_circle : Icons.elevator_outlined,
                  color: e.isCompleted ? AppColors.emerald : AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.displayName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  pending
                      ? [e.type, e.brand].whereType<String>().join(' · ')
                      : 'Seguridad $safety · Tareas ${e.resolvedTasks}/$total · Fotos ${e.photos.length}',
                  style: TextStyle(fontSize: 12, color: colors.mutedForeground),
                ),
                if (!pending && total > 0) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      color: e.isCompleted ? AppColors.emerald : AppColors.primary,
                    ),
                  ),
                ],
              ]),
            ),
            if (!pending) ...[
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: colors.mutedForeground),
            ],
          ]),
        ),
      ),
    );
  }
}
