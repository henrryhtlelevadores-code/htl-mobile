import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme.dart';
import '../data/models.dart';
import 'audio_recorder.dart';

/// Resultado de [capturePhoto]. [audio] es una nota de voz opcional grabada
/// desde el detalle de la foto; se guarda con las notas de voz del equipo.
typedef PhotoShot = ({
  File file,
  PhotoTag tag,
  String? description,
  ({File file, int durationMs})? audio,
});

/// Toma una foto (cámara o galería), comprimida igual que la web
/// (`fileToCompressedDataUrl`: lado máx. 1600 px, JPEG calidad 82) y abre
/// el detalle: tipo (Antes / Después / Punto de atención) y anotación.
Future<PhotoShot?> capturePhoto(
  BuildContext context, {
  PhotoTag initialTag = PhotoTag.before,
  bool askTag = true,
}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (c) => SafeArea(
      child: Wrap(children: [
        ListTile(
          leading: const Icon(Icons.photo_camera),
          title: const Text('Tomar foto'),
          onTap: () => Navigator.pop(c, ImageSource.camera),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library),
          title: const Text('Elegir de la galería'),
          onTap: () => Navigator.pop(c, ImageSource.gallery),
        ),
      ]),
    ),
  );
  if (source == null) return null;

  // Cámara trasera por defecto: es la de las evidencias. La vista previa en
  // vivo y el zoom al encuadrar los da la app de cámara del teléfono.
  final picked = await ImagePicker().pickImage(
    source: source,
    preferredCameraDevice: CameraDevice.rear,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 82,
  );
  if (picked == null || !context.mounted) return null;

  return showModalBottomSheet<PhotoShot>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (c) => PhotoDetailSheet(
      file: File(picked.path),
      initialTag: initialTag,
      askTag: askTag,
    ),
  );
}

/// Detalle de la foto en una hoja inferior:
///
/// - el contenido (vista previa, tipo y anotación) va en una zona con su
///   propio scroll;
/// - el pie con "Guardar" queda fijo abajo;
/// - la hoja se recorta con el teclado (`viewInsets`), así el pie queda
///   siempre visible encima del teclado y nada se desborda.
class PhotoDetailSheet extends StatefulWidget {
  const PhotoDetailSheet({super.key, required this.file, required this.initialTag, required this.askTag});
  final File file;
  final PhotoTag initialTag;
  final bool askTag;

  @override
  State<PhotoDetailSheet> createState() => _PhotoDetailSheetState();
}

enum _NoteMode { text, audio }

class _PhotoDetailSheetState extends State<PhotoDetailSheet> {
  late PhotoTag _tag = widget.initialTag;
  final _desc = TextEditingController();
  _NoteMode _mode = _NoteMode.text;
  ({File file, int durationMs})? _audio;

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  void _save() {
    final d = _desc.text.trim();
    Navigator.pop<PhotoShot>(context, (
      file: widget.file,
      tag: _tag,
      description: d.isEmpty ? null : d,
      audio: _audio,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    // Alto disponible por encima del teclado; la hoja nunca pasa del 90 %.
    final maxHeight = (media.size.height - keyboard) * 0.9;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Detalle de la foto', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // 1. Vista previa compacta con la foto ENTERA (sin recorte);
                //    al tocarla se abre a pantalla completa con zoom.
                _PhotoPreview(file: widget.file),
                // 2. Tipo de foto.
                if (widget.askTag) ...[
                  const SizedBox(height: 16),
                  _Label('Tipo de foto', colors),
                  Row(children: [
                    for (final (i, t) in PhotoTag.values.indexed) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _TagOption(
                          tag: t,
                          selected: t == _tag,
                          onTap: () => setState(() => _tag = t),
                        ),
                      ),
                    ],
                  ]),
                ],
                // 3 y 4. Anotación: texto o nota de voz.
                const SizedBox(height: 16),
                _Label('Anotación (opcional)', colors),
                SegmentedButton<_NoteMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: _NoteMode.text, icon: Icon(Icons.notes, size: 18), label: Text('Texto')),
                    ButtonSegment(value: _NoteMode.audio, icon: Icon(Icons.mic_none, size: 18), label: Text('Audio')),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => setState(() => _mode = s.first),
                ),
                const SizedBox(height: 12),
                if (_mode == _NoteMode.text)
                  TextField(
                    controller: _desc,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Describe esa foto',
                      alignLabelWithHint: true,
                    ),
                  )
                else
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (_audio == null)
                      Center(
                        child: AudioRecorderButton(
                          onRecorded: (file, ms) async => setState(() => _audio = (file: file, durationMs: ms)),
                        ),
                      )
                    else
                      AudioTile(
                        ElevatorAudio(
                          id: 'borrador',
                          localPath: _audio!.file.path,
                          durationMs: _audio!.durationMs,
                        ),
                        onDelete: () => setState(() => _audio = null),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'La nota de voz se guarda junto a las notas de voz del equipo, en Hallazgos.',
                      style: TextStyle(fontSize: 12, color: colors.mutedForeground),
                    ),
                  ]),
                if (_mode == _NoteMode.audio && _desc.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('También se guardará el texto escrito.',
                        style: TextStyle(fontSize: 12, color: colors.mutedForeground)),
                  ),
              ]),
            ),
          ),
          // Pie fijo: siempre visible, encima del teclado.
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(top: BorderSide(color: colors.border)),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + (keyboard > 0 ? 0 : media.viewPadding.bottom)),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Descartar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: _save,
                    icon: const Icon(Icons.check, size: 20),
                    label: const Text('Guardar'),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Vista previa que muestra el encuadre completo (`contain`, sin recortar)
/// y abre el visor con zoom al tocarla.
class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.file});
  final File file;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: () => showPhotoViewer(context, FileImage(file)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 170,
          color: colors.muted,
          child: Stack(fit: StackFit.expand, children: [
            Image.file(file, fit: BoxFit.contain),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.zoom_in, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('Ampliar', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Visor a pantalla completa: la foto entera sobre fondo negro, con zoom
/// por pellizco (hasta 6x) y doble toque para acercar o volver.
Future<void> showPhotoViewer(BuildContext context, ImageProvider image) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, _, _) => _PhotoViewer(image: image),
      transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
    ),
  );
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.image});
  final ImageProvider image;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  final _controller = TransformationController();
  TapDownDetails? _doubleTap;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    if (_controller.value.getMaxScaleOnAxis() > 1.01) {
      _controller.value = Matrix4.identity();
      return;
    }
    final p = _doubleTap?.localPosition ?? Offset.zero;
    const scale = 2.5;
    _controller.value = Matrix4.identity()
      ..translateByDouble(-p.dx * (scale - 1), -p.dy * (scale - 1), 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            onDoubleTapDown: (d) => _doubleTap = d,
            onDoubleTap: _toggleZoom,
            child: InteractiveViewer(
              transformationController: _controller,
              minScale: 1,
              maxScale: 6,
              child: Center(child: Image(image: widget.image, fit: BoxFit.contain)),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.viewPaddingOf(context).top + 8,
          right: 8,
          child: IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: Colors.black54),
            tooltip: 'Cerrar',
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.viewPaddingOf(context).bottom + 16,
          child: const Text(
            'Pellizca o toca dos veces para acercar',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ]),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, this.colors);
  final String text;
  final AppColors colors;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: colors.mutedForeground),
        ),
      );
}

/// Opción del tipo de foto: icono y texto en una tarjeta seleccionable.
class _TagOption extends StatelessWidget {
  const _TagOption({required this.tag, required this.selected, required this.onTap});
  final PhotoTag tag;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final icon = switch (tag) {
      PhotoTag.before => Icons.history,
      PhotoTag.after => Icons.task_alt,
      PhotoTag.point => Icons.report_gmailerrorred,
    };
    final fg = selected ? Colors.white : colors.foreground;
    return Material(
      color: selected ? AppColors.primary : colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? AppColors.primary : colors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 72,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 20, color: selected ? Colors.white : AppColors.link(context)),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                tag.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(fontSize: 11.5, height: 1.15, fontWeight: FontWeight.w600, color: fg),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Miniatura que muestra la foto local (pendiente de subir) o la de R2.
class PhotoThumb extends StatelessWidget {
  const PhotoThumb(this.photo, {super.key, this.onDelete});
  final ElevatorPhoto photo;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final img = photo.localPath != null
        ? Image.file(File(photo.localPath!), fit: BoxFit.cover)
        : Image.network(photo.url!, fit: BoxFit.cover);
    final provider = photo.localPath != null
        ? FileImage(File(photo.localPath!)) as ImageProvider
        : NetworkImage(photo.url!);
    return Stack(fit: StackFit.expand, children: [
      GestureDetector(
        onTap: () => showPhotoViewer(context, provider),
        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: img),
      ),
      Positioned(
        left: 4,
        bottom: 4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
              color: Colors.black54, borderRadius: BorderRadius.circular(4)),
          child: Text(photo.tag.label,
              style: const TextStyle(color: Colors.white, fontSize: 10)),
        ),
      ),
      if (photo.isPendingUpload)
        const Positioned(
          right: 4,
          top: 4,
          child: Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 18),
        ),
      if (onDelete != null)
        Positioned(
          right: 0,
          bottom: 0,
          child: IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: onDelete,
          ),
        ),
    ]);
  }
}
