import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/photo_capture.dart';

/// Evidencia fotográfica del equipo (Antes / Después / Punto de atención).
/// Solo en preventivos se exigen al menos 4 fotos para finalizar; en
/// correctivos no hay mínimo. Se guardan en el teléfono y se suben solas
/// cuando hay señal.
class PhotosScreen extends ConsumerWidget {
  const PhotosScreen({super.key, required this.workOrderId, required this.elevatorId});
  final String workOrderId;
  final String elevatorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(workOrderProvider(workOrderId));
    final ctrl = ref.read(workOrderProvider(workOrderId).notifier);

    Future<void> add(Elevator e) async {
      final shot = await capturePhoto(context,
          initialTag: e.photos.isEmpty ? PhotoTag.before : PhotoTag.after);
      if (shot == null) return;
      await ctrl.addPhoto(e, shot.file, shot.tag, description: shot.description);
    }

    Future<void> remove(Elevator e, ElevatorPhoto p) async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('¿Eliminar foto?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar')),
          ],
        ),
      );
      if (ok != true) return;
      ctrl.removePhoto(e, p);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Fotos del equipo')),
      body: asyncView(value, (o) {
        final e = o.elevators.firstWhere((x) => x.id == elevatorId);
        return Column(children: [
          if (!e.photosRequired)
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Sin mínimo de fotos para este servicio'),
            )
          else
            ListTile(
              leading: Icon(e.photosOk ? Icons.check_circle : Icons.info_outline,
                  color: e.photosOk ? AppColors.emerald : AppColors.amber),
              title: Text('${e.photos.length}/${Elevator.minPhotos} fotos mínimas'),
              subtitle: e.photosOk
                  ? null
                  : Text('Faltan ${Elevator.minPhotos - e.photos.length} para finalizar'),
            ),
          Expanded(
            child: e.photos.isEmpty
                ? const Center(child: Text('Aún no hay fotos.'))
                : GridView.count(
                    padding: const EdgeInsets.all(12),
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [
                      for (final p in e.photos)
                        PhotoThumb(p,
                            onDelete: e.isCompleted ? null : () => remove(e, p)),
                    ],
                  ),
          ),
        ]);
      }),
      floatingActionButton: value.hasValue &&
              !value.requireValue.elevators.firstWhere((x) => x.id == elevatorId).isCompleted
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Tomar foto'),
              onPressed: () => add(ctrl.elevator(elevatorId)),
            )
          : null,
    );
  }
}
