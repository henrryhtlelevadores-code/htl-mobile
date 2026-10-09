import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:signature/signature.dart';

import '../../core/providers.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Cerrar orden')),
      body: asyncView(value, (o) {
        final valid = _name.text.trim().isNotEmpty &&
            _signature.isNotEmpty &&
            o.elevators.every((e) => _statuses.containsKey(e.id));
        return ListView(padding: listPadding(context), children: [
          Text('Estado final de cada equipo', style: Theme.of(context).textTheme.titleMedium),
          for (final e in o.elevators)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.displayName, style: Theme.of(context).textTheme.titleSmall),
                  RadioGroup<ElevatorFinalStatus>(
                    groupValue: _statuses[e.id],
                    onChanged: (v) => setState(() => _statuses[e.id] = v!),
                    child: Column(children: [
                      for (final s in ElevatorFinalStatus.values)
                        RadioListTile<ElevatorFinalStatus>(
                          dense: true,
                          value: s,
                          title: Text(s.label),
                        ),
                    ]),
                  ),
                ]),
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Nombre de quien recibe'),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Text('Firma del cliente', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            TextButton(onPressed: _signature.clear, child: const Text('Limpiar')),
          ]),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
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
