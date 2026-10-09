import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:htl_tecnicos/core/providers.dart';
import 'package:htl_tecnicos/data/mock_technician_repository.dart';
import 'package:htl_tecnicos/data/models.dart';

void main() {
  test('flujo completo local (sin servidor)', () async {
    // Las pruebas corren sobre los datos de demostración, sin servidor.
    final c = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(MockTechnicianRepository()),
    ]);
    addTearDown(c.dispose);

    final list = await c.read(workOrdersProvider.future);
    final prev = list.firstWhere((o) => o.serviceTypeCode == 'PREV');
    final provider = workOrderProvider(prev.id);
    await c.read(provider.future);
    final ctrl = c.read(provider.notifier);

    ctrl.start();
    final o = c.read(provider).requireValue;
    expect(o.isInProgress, isTrue);
    final e = o.elevators.first;
    expect(e.safety!.items, isNotEmpty);

    // Seguridad: no se aprueba incompleta; "Aceptar todos" la completa.
    expect(ctrl.approveSafety(e, () async => null), isNotNull);
    ctrl.answerSafety(e, e.safety!.items.first, SafetyResponse.no);
    expect(ctrl.acceptAllSafety(e), e.safety!.items.length - 1);
    expect(ctrl.approveSafety(e, () async => null), contains('observación'));
    ctrl.setSafetyObservation(e, e.safety!.items.first, 'Falta letrero en piso 3');
    expect(ctrl.approveSafety(e, () async => null), isNull);
    expect(e.safetyDone, isTrue);

    // Tareas: aprobar todas de una vez.
    ctrl.setTasks(e, e.tasks, approve: true);
    expect(e.resolvedTasks, e.tasks.length);

    // Preventivo: mínimo 4 fotos.
    expect(e.photosRequired, isTrue);
    expect(ctrl.completeElevator(e, allCompleted: true), contains('4 fotos'));
  });

  test('correctivo sin mínimo de fotos', () async {
    // Las pruebas corren sobre los datos de demostración, sin servidor.
    final c = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(MockTechnicianRepository()),
    ]);
    addTearDown(c.dispose);
    final list = await c.read(workOrdersProvider.future);
    final corr = list.firstWhere((o) => o.serviceTypeCode == 'CORR');
    final provider = workOrderProvider(corr.id);
    await c.read(provider.future);
    final ctrl = c.read(provider.notifier)..start();
    final o = c.read(provider).requireValue;
    final e = o.elevators.single;
    expect(e.photosRequired, isFalse);
    ctrl.acceptAllSafety(e);
    expect(ctrl.approveSafety(e, () async => null), isNull);
    expect(ctrl.completeElevator(e, allCompleted: false), isNull);
    expect(
        ctrl.completeWorkOrder(
            clientName: 'Carlos',
            signaturePng: Uint8List(0),
            elevatorStatuses: {e.id: ElevatorFinalStatus.operative}),
        isNull);
    expect(o.isCompleted, isTrue);
  });

  test('la copia local ida y vuelta conserva el estado', () {
    final o = WorkOrderDetail.fromJson({
      'id': 'wo',
      'otNumber': 'OT-1',
      'status': 'IN_PROGRESS',
      'serviceType': {'code': 'PREV', 'name': 'Preventivo'},
      'elevators': [
        {
          'id': 'e1',
          'internalCode': 'ASC-1',
          'safety': {
            'id': 's',
            'status': 'PENDING',
            'items': [
              {'id': 'i2', 'question': 'B', 'response': 'NO', 'orderIndex': 1},
              {'id': 'i1', 'question': 'A', 'response': 'SI', 'orderIndex': 0},
            ],
          },
          'tasks': [
            {'id': 't', 'taskDescription': 'X', 'isCritical': 1, 'isCompleted': 0, 'moduleCode': 'M1'},
          ],
          'photos': [
            {'id': 'p', 'localPath': '/tmp/p.jpg', 'tag': 'POINT'},
          ],
        },
      ],
    });
    final back = WorkOrderDetail.fromJson(o.toJson());
    final e = back.elevators.single;
    expect(e.photosRequired, isTrue);
    expect(e.safety!.items.first.id, 'i1');
    expect(e.safety!.items.last.isValid, isFalse);
    expect(e.tasks.single.isCritical, isTrue);
    expect(e.photos.single.isPendingUpload, isTrue);
    expect(e.photos.single.tag, PhotoTag.point);
  });

  test('las notas de voz conservan su origen y la marca de ya agregada', () {
    const fromPhoto = ElevatorAudio(id: 'a1', durationMs: 900, photoId: 'p1');
    const fromFinding = ElevatorAudio(
        id: 'a2', durationMs: 900, transcript: 'Freno cambiado', transcriptStatus: 'DONE', appliedToFinding: true);
    final back1 = ElevatorAudio.fromJson(fromPhoto.toJson());
    final back2 = ElevatorAudio.fromJson(fromFinding.toJson());
    expect(back1.isFindingNote, isFalse);
    expect(back1.photoId, 'p1');
    expect(back2.isFindingNote, isTrue);
    expect(back2.appliedToFinding, isTrue);
    // Lo que manda el servidor no trae la marca local.
    expect(ElevatorAudio.fromJson({'id': 'a3', 'durationMs': 1}).appliedToFinding, isFalse);
  });
}
