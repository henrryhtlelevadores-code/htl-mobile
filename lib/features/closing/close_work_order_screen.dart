import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:signature/signature.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/report_problem_dialog.dart';

/// Cierre de la OT (`completeWorkOrder`): estado final de cada equipo,
/// nombre de quien recibe y firma manuscrita (PNG -> R2).
class CloseWorkOrderScreen extends ConsumerStatefulWidget {
  const CloseWorkOrderScreen({super.key, required this.workOrderId});
  final String workOrderId;

  @override
  ConsumerState<CloseWorkOrderScreen> createState() => _CloseWorkOrderScreenState();
}

class _CloseWorkOrderScreenState extends ConsumerState<CloseWorkOrderScreen> {
  final _name = TextEditingController();
  final _signature = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  final Map<String, ElevatorFinalStatus> _statuses = {};
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _signature.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _signature.dispose();
    super.dispose();
  }

  void _setStatus(WorkOrderDetail o, Elevator e, ElevatorFinalStatus s) {
    final changed = _statuses[e.id] != s;
    setState(() => _statuses[e.id] = s);
    // Como en el portal web: un mantenimiento sin culminar se reporta a
    // Henrry para coordinar una visita de emergencia.
    if (changed && s == ElevatorFinalStatus.uncompletedMaintenance) {
      showReportProblemDialog(context, elevator: e, clientName: o.clientName);
    }
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    final png = await _signature.toPngBytes();
    if (!mounted) return;
    setState(() => _sending = false);
    if (png == null) return;
    final error = ref.read(workOrderProvider(widget.workOrderId).notifier).completeWorkOrder(
        clientName: _name.text, signaturePng: png, elevatorStatuses: _statuses);
    showResult(
        context,
        ActionResult(error == null,
            error ?? 'Orden cerrada. Se enviará automáticamente si no hay señal.'));
    if (error == null) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(workOrderProvider(widget.workOrderId));
    final colors = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Cerrar orden')),
      body: asyncView(value, (o) {
        final valid = _name.text.trim().isNotEmpty &&
            _signature.isNotEmpty &&
            o.elevators.every((e) => _statuses.containsKey(e.id));
        return ListView(padding: listPadding(context), children: [
          const SectionLabel('Estado final de cada equipo'),
          const SizedBox(height: 4),
          for (final e in o.elevators)
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.elevator_outlined, size: 18, color: AppColors.link(context)),
                    const SizedBox(width: 6),
                    Text(e.displayName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  ]),
                  if (e.name != null && e.name != e.displayName)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, left: 24),
                      child: Text(e.name!, style: TextStyle(fontSize: 12, color: colors.mutedForeground)),
                    ),
                  const SizedBox(height: 12),
                  for (final s in ElevatorFinalStatus.values) ...[
                    _StatusOption(
                      status: s,
                      selected: _statuses[e.id] == s,
                      onTap: () => _setStatus(o, e, s),
                    ),
                    if (s != ElevatorFinalStatus.values.last) const SizedBox(height: 8),
                  ],
                ]),
              ),
            ),
          const SizedBox(height: 12),
          const SectionLabel('Recepción'),
          TextField(
            controller: _name,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre de quien recibe',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 20),
          Row(children: [
            const Expanded(child: SectionLabel('Firma del cliente')),
            TextButton(onPressed: _signature.clear, child: const Text('Limpiar')),
          ]),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Signature(controller: _signature, height: 200, backgroundColor: Colors.white),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: _sending
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: const Text('Cerrar y enviar'),
            onPressed: valid && !_sending ? _submit : null,
          ),
        ]);
      }),
    );
  }
}

/// Opción de estado final: tarjeta seleccionable con icono y color.
class _StatusOption extends StatelessWidget {
  const _StatusOption({required this.status, required this.selected, required this.onTap});
  final ElevatorFinalStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final (icon, color) = switch (status) {
      ElevatorFinalStatus.operative => (Icons.check_circle_outline, AppColors.emerald),
      ElevatorFinalStatus.outOfService => (Icons.block, AppColors.red),
      ElevatorFinalStatus.uncompletedMaintenance => (Icons.warning_amber_rounded, AppColors.amber),
    };
    return Material(
      color: selected ? color.withValues(alpha: 0.10) : colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: selected ? color : colors.border, width: selected ? 1.5 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(status.label,
                  style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 20,
              color: selected ? color : colors.mutedForeground,
            ),
          ]),
        ),
      ),
    );
  }
}
