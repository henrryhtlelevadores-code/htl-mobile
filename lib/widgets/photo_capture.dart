import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models.dart';

/// Toma una foto (cámara o galería), comprimida igual que la web
/// (`fileToCompressedDataUrl`: lado máx. 1600 px, JPEG calidad 82) y pide
/// el tipo (Antes / Después / Punto de atención) y una descripción.
Future<({File file, PhotoTag tag, String? description})?> capturePhoto(
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

  final picked = await ImagePicker()
      .pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 82);
  if (picked == null || !context.mounted) return null;

  var tag = initialTag;
  final desc = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: const Text('Detalle de la foto'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(File(picked.path), height: 160, fit: BoxFit.cover),
          ),
          const SizedBox(height: 12),
          if (askTag)
            SegmentedButton<PhotoTag>(
              segments: [
                for (final t in PhotoTag.values)
                  ButtonSegment(value: t, label: Text(t.label, textAlign: TextAlign.center)),
              ],
              selected: {tag},
              onSelectionChanged: (s) => setState(() => tag = s.first),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: desc,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Descartar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Guardar')),
        ],
      ),
    ),
  );
  if (ok != true) return null;
  final d = desc.text.trim();
  return (file: File(picked.path), tag: tag, description: d.isEmpty ? null : d);
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
    return Stack(fit: StackFit.expand, children: [
      ClipRRect(borderRadius: BorderRadius.circular(8), child: img),
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
