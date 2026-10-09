import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models.dart';
import '../../widgets/audio_recorder.dart';
import '../../widgets/common.dart';
import '../../widgets/photo_capture.dart';

/// Hallazgos del equipo: nota escrita, fotos "Punto de atención" y notas
/// de voz. Todo se guarda en el teléfono; cuando hay señal el audio se sube
/// a R2, el servidor lo transcribe y el texto queda en la base de datos.
class FindingsScreen extends ConsumerStatefulWidget {
  const FindingsScreen({super.key, required this.workOrderId, required this.elevatorId});
  final String workOrderId;
  final String elevatorId;

  @override
  ConsumerState<FindingsScreen> createState() => _FindingsScreenState();
}

class _FindingsScreenState extends ConsumerState<FindingsScreen> {
  static const maxLength = 2000;
  late final TextEditingController _text;
  String _saved = '';

  late final WorkOrderController _ctrl;
  Elevator get _e => _ctrl.elevator(widget.elevatorId);

  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _ctrl = ref.read(workOrderProvider(widget.workOrderId).notifier);
    _saved = _e.finding ?? '';
    _text = TextEditingController(text: _saved);
    // Cuando llega la transcripción de una nota grabada aquí, se escribe sola
    // en el texto de Hallazgos.
    ref.listenManual(workOrderProvider(widget.workOrderId), (_, next) {
      final o = next.value;
      if (o == null) return;
      final e = o.elevators.where((x) => x.id == widget.elevatorId).firstOrNull;
      if (e != null) WidgetsBinding.instance.addPostFrameCallback((_) => _applyTranscripts(e));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyTranscripts(_e));
    // Mientras haya notas transcribiéndose, se consulta al servidor.
    _poll = Timer.periodic(const Duration(seconds: 6), (_) {
      if (_waitingTranscripts(_e)) _ctrl.reload();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    // Guarda lo escrito al salir; diferido para no tocar el estado del
    // provider mientras se desmonta el árbol.
    final text = _text.text;
    Future(() => _save(text));
    _text.dispose();
    super.dispose();
  }

  static bool _waitingTranscripts(Elevator e) => !e.isCompleted &&
      e.audios.any((a) =>
          a.isFindingNote && !a.appliedToFinding && (a.isPendingUpload || a.transcriptStatus == 'PENDING'));

  void _applyTranscripts(Elevator e) {
    if (!mounted || e.isCompleted) return;
    var added = 0;
    for (final a in e.audios) {
      final transcript = a.transcript?.trim() ?? '';
      if (!a.isFindingNote || a.appliedToFinding || a.transcriptStatus != 'DONE') continue;
      if (transcript.isNotEmpty && !_text.text.contains(transcript)) {
        _appendTranscript(transcript);
        added++;
      }
      _ctrl.markAudioApplied(e, a);
    }
    if (added > 0) {
      showResult(context,
          ActionResult(true, added == 1 ? 'Transcripción agregada a Hallazgos' : '$added transcripciones agregadas a Hallazgos'));
    }
  }

  void _save([String? raw]) {
    final t = (raw ?? _text.text).trim();
    if (t == _saved) return;
    _saved = t;
    _ctrl.setFindings(_e, t);
  }

  void _appendTranscript(String transcript) {
    final current = _text.text.trim();
    final next = current.isEmpty ? transcript : '$current\n$transcript';
    _text.text = next.length > maxLength ? next.substring(0, maxLength) : next;
    _save();
  }

  Future<void> _deleteAudio(Elevator e, ElevatorAudio a) async {
    final ok = await confirmDialog(
      context,
      title: 'Eliminar nota de voz',
      message: 'Se borrará la grabación. No se puede deshacer.',
      confirmLabel: 'Eliminar',
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (!ok || !mounted) return;
    _ctrl.removeAudio(e, a);
    showResult(context, const ActionResult(true, 'Nota de voz eliminada'));
  }

  Future<void> _addPhoto() async {
    final shot = await capturePhoto(context, initialTag: PhotoTag.point, askTag: false);
    if (shot == null) return;
    final photo = await _ctrl.addPhoto(_e, shot.file, PhotoTag.point, description: shot.description);
    final audio = shot.audio;
    if (audio != null) await _ctrl.addAudio(_e, audio.file, audio.durationMs, photoId: photo.id);
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(workOrderProvider(widget.workOrderId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hallazgos'),
        actions: [
          IconButton(
            tooltip: 'Actualizar transcripciones',
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              _save();
              await _ctrl.reload();
            },
          ),
        ],
      ),
      body: asyncView(value, (o) {
        final e = o.elevators.firstWhere((x) => x.id == widget.elevatorId);
        final readOnly = e.isCompleted;
        final points = e.photos.where((p) => p.tag == PhotoTag.point && p.taskId == null);
        final findingNotes = e.audios.where((a) => a.isFindingNote).toList();
        final photoNotes = e.audios.where((a) => !a.isFindingNote).toList();
        return ListView(padding: listPadding(context), children: [
          TextField(
            controller: _text,
            enabled: !readOnly,
            maxLines: 6,
            maxLength: maxLength,
            onTapOutside: (_) {
              FocusScope.of(context).unfocus();
              _save();
            },
            decoration: const InputDecoration(
              labelText: 'Observaciones del equipo',
              hintText: 'Ej: Se observa desgaste en la guía de cabina...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          if (!readOnly)
            Wrap(spacing: 8, runSpacing: 8, children: [
              AudioRecorderButton(onRecorded: (file, ms) => _ctrl.addAudio(e, file, ms)),
              OutlinedButton.icon(
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Foto del hallazgo'),
                onPressed: _addPhoto,
              ),
            ]),
          if (findingNotes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Notas de voz', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 2),
            Text('Su transcripción se agrega sola al texto de arriba.',
                style: Theme.of(context).textTheme.bodySmall),
            for (final a in findingNotes)
              AudioTile(
                a,
                key: ValueKey(a.id),
                // Ya se pasó al texto: no hace falta el botón.
                onUseTranscript: readOnly || a.appliedToFinding ? null : _appendTranscript,
                onDelete: readOnly ? null : () => _deleteAudio(e, a),
              ),
          ],
          if (photoNotes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Notas de voz de las fotos', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 2),
            Text('Van con su foto; puedes agregarlas al texto si quieres.',
                style: Theme.of(context).textTheme.bodySmall),
            for (final a in photoNotes)
              AudioTile(
                a,
                key: ValueKey(a.id),
                onUseTranscript: readOnly ? null : _appendTranscript,
                onDelete: readOnly ? null : () => _deleteAudio(e, a),
              ),
          ],
          if (points.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Fotos del hallazgo', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [for (final p in points) PhotoThumb(p)],
            ),
          ],
        ]);
      }),
    );
  }
}
