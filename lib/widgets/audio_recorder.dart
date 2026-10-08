import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../data/models.dart';

/// Grabadora de notas de voz.
///
/// Graba AAC mono a 16 kHz y 32 kbps (~240 KB por minuto): suficiente para
/// voz, liviano para subir con datos móviles y aceptado tal cual por
/// Whisper. No se transcribe en el teléfono: el archivo se sube a R2 y el
/// servidor genera el texto una sola vez sobre el audio completo, por eso
/// no aparecen palabras repetidas como en el dictado web.
class AudioRecorderButton extends StatefulWidget {
  const AudioRecorderButton({super.key, required this.onRecorded, this.maxDuration});

  final Future<void> Function(File file, int durationMs) onRecorded;
  final Duration? maxDuration;

  @override
  State<AudioRecorderButton> createState() => _AudioRecorderButtonState();
}

class _AudioRecorderButtonState extends State<AudioRecorderButton> {
  final _recorder = AudioRecorder();
  final _watch = Stopwatch();
  Timer? _ticker;
  bool _recording = false;
  bool _busy = false;

  Duration get _max => widget.maxDuration ?? const Duration(minutes: 5);

  Future<void> _start() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Permite el acceso al micrófono en Ajustes para grabar audio.')));
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/nota_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 32000,
      ),
      path: path,
    );
    _watch
      ..reset()
      ..start();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_watch.elapsed >= _max) _stop();
      if (mounted) setState(() {});
    });
    setState(() => _recording = true);
  }

  Future<void> _stop() async {
    if (!_recording) return;
    _ticker?.cancel();
    _watch.stop();
    final path = await _recorder.stop();
    setState(() {
      _recording = false;
      _busy = true;
    });
    try {
      if (path != null && _watch.elapsedMilliseconds > 700) {
        await widget.onRecorded(File(path), _watch.elapsedMilliseconds);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    _ticker?.cancel();
    _watch.stop();
    await _recorder.cancel();
    setState(() => _recording = false);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const OutlinedButton(
        onPressed: null,
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (!_recording) {
      return OutlinedButton.icon(
        icon: const Icon(Icons.mic),
        label: const Text('Grabar audio'),
        onPressed: _start,
      );
    }
    final s = _watch.elapsed.inSeconds;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.fiber_manual_record, color: Colors.red),
      const SizedBox(width: 4),
      Text('${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}'),
      const SizedBox(width: 8),
      IconButton(tooltip: 'Descartar', icon: const Icon(Icons.close), onPressed: _cancel),
      FilledButton.icon(
        style: FilledButton.styleFrom(
            backgroundColor: Colors.red, minimumSize: const Size(0, 40)),
        icon: const Icon(Icons.stop),
        label: const Text('Detener'),
        onPressed: _stop,
      ),
    ]);
  }
}

/// Fila de un audio: reproducir y ver el estado de la transcripción.
class AudioTile extends StatefulWidget {
  const AudioTile(this.audio, {super.key, this.onUseTranscript});
  final ElevatorAudio audio;
  final void Function(String text)? onUseTranscript;

  @override
  State<AudioTile> createState() => _AudioTileState();
}

class _AudioTileState extends State<AudioTile> {
  final _player = AudioPlayer();
  bool _loaded = false;

  Future<void> _toggle() async {
    if (_player.playing) {
      await _player.pause();
      return;
    }
    if (!_loaded) {
      final a = widget.audio;
      if (a.localPath != null) {
        await _player.setFilePath(a.localPath!);
      } else {
        await _player.setUrl(a.url!);
      }
      _loaded = true;
    }
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    await _player.play();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.audio;
    final secs = (a.durationMs / 1000).round();
    final status = a.isPendingUpload
        ? 'Guardado en el teléfono. Se subirá y transcribirá cuando haya señal.'
        : switch (a.transcriptStatus) {
            // NONE: el servidor guardó el audio pero no lo transcribe.
            'DONE' || 'NONE' => null,
            'FAILED' => 'No se pudo transcribir',
            _ => 'Transcribiendo en el servidor…',
          };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            StreamBuilder<PlayerState>(
              stream: _player.playerStateStream,
              builder: (_, snap) => IconButton.filledTonal(
                icon: Icon(snap.data?.playing == true ? Icons.pause : Icons.play_arrow),
                onPressed: _toggle,
              ),
            ),
            const SizedBox(width: 8),
            Text('Nota de voz · ${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}'),
            const Spacer(),
            if (a.isPendingUpload) const Icon(Icons.cloud_upload_outlined, size: 18),
          ]),
          if (status != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Text(status, style: Theme.of(context).textTheme.bodySmall),
            ),
          if (a.transcript != null && a.transcript!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('“${a.transcript}”'),
            ),
            if (widget.onUseTranscript != null)
              TextButton.icon(
                icon: const Icon(Icons.playlist_add),
                label: const Text('Agregar al texto del hallazgo'),
                onPressed: () => widget.onUseTranscript!(a.transcript!),
              ),
          ],
        ]),
      ),
    );
  }
}
