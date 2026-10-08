import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

/// Checklist de seguridad (Sí / No / N/A). Todo se aplica al instante y se
/// envía en segundo plano. "Aceptar todos" responde "Sí" a las pendientes
/// en un solo envío. "Aprobar seguridad" exige todas las respuestas y una
/// observación en cada "No"; la ubicación se adjunta sin hacer esperar.
class SafetyScreen extends ConsumerStatefulWidget {
  const SafetyScreen({super.key, required this.workOrderId, required this.elevatorId});
  final String workOrderId;
  final String elevatorId;

  @override
  ConsumerState<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends ConsumerState<SafetyScreen> {
  final Map<String, String> _draft = {};

  WorkOrderController get _ctrl =>
      ref.read(workOrderProvider(widget.workOrderId).notifier);

  /// Ubicación para el registro de seguridad. Primero la última conocida
  /// (instantánea); si no hay, intenta una lectura corta. Sin GPS se
  /// aprueba igual (el backend acepta geolocation = null).
  static Future<({double lat, double lng})?> _location() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return null;
      }
      final p = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)),
          );
      return (lat: p.latitude, lng: p.longitude);
    } catch (_) {
      return null;
    }
  }

  void _acceptAll(Elevator e) {
    final n = _ctrl.acceptAllSafety(e);
    showResult(
        context,
        ActionResult(true,
            n == 0 ? 'Todas las preguntas ya tienen respuesta.' : '$n respuestas marcadas como "Sí".'));
  }

  void _approve(Elevator e) {
    final error = _ctrl.approveSafety(e, _location);
    showResult(context, ActionResult(error == null, error ?? 'Seguridad aprobada. ¡A trabajar!'));
    if (error == null) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(workOrderProvider(widget.workOrderId));
    return Scaffold(
      appBar: AppBar(title: const Text('Checklist de seguridad')),
      body: asyncView(value, (o) {
        final e = o.elevators.firstWhere((x) => x.id == widget.elevatorId);
        final safety = e.safety!;
        final readOnly = safety.isCompleted;
        final answered = safety.items.where((i) => i.response != null).length;
        final allValid = safety.items.every((i) =>
            i.response != null &&
            (i.response != SafetyResponse.no ||
                (_draft[i.id] ?? i.observations ?? '').trim().isNotEmpty));
        return Column(children: [
          if (readOnly)
            MaterialBanner(
              content: const Text('Seguridad aprobada.'),
              leading: const Icon(Icons.verified_user, color: Colors.green),
              actions: [TextButton(onPressed: () => context.pop(), child: const Text('Volver'))],
            ),
          if (!readOnly)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                Expanded(child: Text('$answered/${safety.items.length} respondidas')),
                OutlinedButton.icon(
                  icon: const Icon(Icons.done_all),
                  label: const Text('Aceptar todos'),
                  onPressed: answered == safety.items.length ? null : () => _acceptAll(e),
                ),
              ]),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: safety.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final item = safety.items[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${i + 1}. ${item.question}'),
                      const SizedBox(height: 8),
                      SegmentedButton<SafetyResponse>(
                        emptySelectionAllowed: true,
                        segments: [
                          for (final r in SafetyResponse.values)
                            ButtonSegment(value: r, label: Text(r.label)),
                        ],
                        selected: {?item.response},
                        onSelectionChanged: readOnly
                            ? null
                            : (s) {
                                if (s.isNotEmpty) _ctrl.answerSafety(e, item, s.first);
                              },
                      ),
                      if (item.response == SafetyResponse.no) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: item.observations,
                          enabled: !readOnly,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Observación (obligatoria)',
                          ),
                          onFieldSubmitted: (t) => _ctrl.setSafetyObservation(e, item, t),
                          onChanged: (t) {
                            // Mantiene el botón "Aprobar" al día sin enviar
                            // cada tecla; se envía al salir del campo.
                            _draft[item.id] = t;
                            setState(() {});
                          },
                          onTapOutside: (_) {
                            FocusScope.of(context).unfocus();
                            final t = _draft.remove(item.id);
                            if (t != null) _ctrl.setSafetyObservation(e, item, t);
                          },
                        ),
                      ],
                    ]),
                  ),
                );
              },
            ),
          ),
          if (!readOnly)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  icon: const Icon(Icons.verified_user),
                  label: Text(allValid ? 'Aprobar seguridad' : 'Responde todas las preguntas'),
                  onPressed: allValid
                      ? () {
                          // Envía las observaciones aún en edición antes de aprobar.
                          for (final i in safety.items) {
                            final t = _draft.remove(i.id);
                            if (t != null) _ctrl.setSafetyObservation(e, i, t);
                          }
                          _approve(e);
                        }
                      : null,
                ),
              ),
            ),
        ]);
      }),
    );
  }
}
