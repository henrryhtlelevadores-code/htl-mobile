import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

class WorkOrdersScreen extends ConsumerWidget {
  const WorkOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final orders = ref.watch(workOrdersProvider);
    final pending = ref.watch(pendingSyncProvider).value ?? 0;
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(children: [
          const HtlMark(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Técnico de Campo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              if (user != null)
                Text(
                  user.fullName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: colors.mutedForeground),
                ),
            ]),
          ),
        ]),
        actions: [
          if (pending > 0)
            Tooltip(
              message: '$pending cambios por sincronizar',
              child: Badge(
                label: Text('$pending'),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.cloud_upload_outlined, color: colors.mutedForeground),
                ),
              ),
            ),
          const ThemeToggleButton(),
          IconButton(
            tooltip: 'Cerrar sesión',
            color: colors.mutedForeground,
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(workOrdersProvider.future),
        child: asyncView(
          orders,
          (list) => list.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 120),
                  Icon(Icons.assignment_turned_in_outlined, size: 48, color: colors.mutedForeground),
                  const SizedBox(height: 12),
                  Center(
                    child: Text('No tienes órdenes asignadas.',
                        style: TextStyle(color: colors.mutedForeground)),
                  ),
                ])
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    SectionLabel('Mis órdenes · ${list.length}'),
                    for (final o in list) _WorkOrderCard(o),
                  ],
                ),
          onRetry: () => ref.invalidate(workOrdersProvider),
        ),
      ),
    );
  }
}

/// Tarjeta igual a la del portal web: franja de color por tipo de servicio,
/// hora y etiquetas arriba, N° de OT en azul y botón de acción al pie.
class _WorkOrderCard extends StatelessWidget {
  const _WorkOrderCard(this.o);
  final WorkOrderSummary o;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final kind = ServiceKind.of(o.serviceTypeCode);
    final status = o.status ?? 'PENDING';
    final done = status == 'COMPLETED';
    final started = status == 'IN_PROGRESS' || status == 'PAUSED';
    final urgent = o.priority == 'HIGH' || o.priority == 'URGENT';
    void open() => context.push('/ot/${o.id}');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 4, color: kind.color),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              InkWell(
                onTap: open,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.schedule, size: 14, color: colors.mutedForeground),
                      const SizedBox(width: 4),
                      Text(
                        [o.scheduledDate, o.scheduledTime ?? 'Sin hora'].whereType<String>().join(' · '),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.mutedForeground),
                      ),
                      if (urgent) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.priority_high, size: 16, color: AppColors.red),
                      ],
                    ]),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      if (o.serviceTypeName != null)
                        ServiceTypeChip(code: o.serviceTypeCode, name: o.serviceTypeName!),
                      StatusChip(status),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Icon(Icons.assignment_outlined, size: 15, color: AppColors.link(context)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          o.otNumber,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.link(context),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(o.costCenterName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3)),
                    if (o.costCenterAddress != null) ...[
                      const SizedBox(height: 3),
                      InfoRow(Icons.place_outlined, o.costCenterAddress!),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${o.clientName}${o.equipmentCount > 0 ? ' · ${o.equipmentCount} equipo(s)' : ''}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: colors.mutedForeground),
                    ),
                  ]),
                ),
              ),
              Divider(height: 1, color: colors.border),
              Padding(
                padding: const EdgeInsets.all(8),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                  onPressed: open,
                  icon: Icon(
                    done
                        ? Icons.check_circle_outline
                        : started
                            ? Icons.edit_note
                            : Icons.play_arrow_rounded,
                    size: 20,
                  ),
                  label: Text(done
                      ? 'Ver detalle'
                      : started
                          ? 'Continuar'
                          : 'Iniciar'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
