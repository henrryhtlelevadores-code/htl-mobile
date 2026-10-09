import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/api_client.dart';
import '../core/offline_store.dart';
import '../core/sync_queue.dart';
import 'models.dart';
import 'technician_repository.dart';

const _uuid = Uuid();
int _now() => DateTime.now().millisecondsSinceEpoch;

/// Implementación real contra `/api/mobile/v1`, local primero:
/// lecturas con respaldo en [OfflineStore] y escrituras por [SyncQueue].
class ApiTechnicianRepository implements TechnicianRepository {
  final ApiClient api;
  final SyncQueue queue;
  final OfflineStore store;

  ApiTechnicianRepository(this.api, this.queue, this.store);

  Future<void> _send(String workOrderId, String path, Map<String, dynamic> body,
      {String method = 'POST', String? id, Map<String, String>? files}) {
    return queue.enqueue(PendingMutation(
      id: id ?? _uuid.v4(),
      workOrderId: workOrderId,
      method: method,
      path: path,
      body: body,
      files: files,
    ));
  }

  /// Copia el archivo a una carpeta propia para que sobreviva hasta subirse.
  Future<String> _persistFile(File file, String id, String ext) async {
    final dir = await getApplicationDocumentsDirectory();
    final out = Directory('${dir.path}/evidence');
    await out.create(recursive: true);
    final copy = await file.copy('${out.path}/$id.$ext');
    return copy.path;
  }

  @override
  Future<(String, TechnicianUser)> login(String email, String password) async {
    final Response res;
    try {
      res = await api.dio
          .post('/auth/login', data: {'email': email, 'password': password});
    } on DioException catch (e) {
      // El backend responde 401 (credenciales), 403 (rol sin acceso a la
      // app) o 429 (demasiados intentos) con `{ success: false, message }`.
      final body = e.response?.data;
      if (body is Map && body['message'] is String) {
        throw Exception(body['message']);
      }
      throw Exception('No se pudo conectar con el servidor. Revisa tu conexión.');
    }
    final data = res.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Credenciales inválidas');
    }
    return (
      data['token'] as String,
      TechnicianUser.fromJson(data['user'] as Map<String, dynamic>)
    );
  }

  @override
  Future<List<WorkOrderSummary>> fetchWorkOrders() async {
    try {
      final res = await api.dio.get('/work-orders');
      final data = res.data as Map<String, dynamic>;
      final list = ((data['workOrders'] as List?) ?? [])
          .map((e) => WorkOrderSummary.fromJson(e as Map<String, dynamic>))
          .toList();
      await store.saveList(list);
      // Descarga previa: deja cada OT lista para trabajarla sin señal.
      for (final o in list) {
        if (o.status == 'COMPLETED' || o.status == 'CANCELLED') continue;
        try {
          await fetchWorkOrder(o.id);
        } catch (_) {}
      }
      return await _withLocalStatus(list);
    } catch (e) {
      if (!isNetworkError(e)) rethrow;
      final cached = await store.loadList();
      if (cached == null) rethrow;
      return _withLocalStatus(cached);
    }
  }

  /// El estado de la lista refleja lo que el técnico hizo sin señal.
  Future<List<WorkOrderSummary>> _withLocalStatus(List<WorkOrderSummary> list) async {
    final out = <WorkOrderSummary>[];
    for (final o in list) {
      final local = await store.loadDetail(o.id);
      out.add(local == null || local.status == o.status
          ? o
          : WorkOrderSummary.fromJson({...o.toJson(), 'status': local.status}));
    }
    return out;
  }

  @override
  Future<WorkOrderDetail> fetchWorkOrder(String id) async {
    // Con cambios locales sin enviar, la copia local es la más reciente.
    if (queue.hasPendingFor(id)) {
      final local = await store.loadDetail(id);
      if (local != null) return local;
    }
    try {
      final res = await api.dio.get('/work-orders/$id');
      final fresh = WorkOrderDetail.fromJson(res.data as Map<String, dynamic>);
      await _keepLocalFiles(fresh);
      await store.saveDetail(fresh);
      return fresh;
    } catch (e) {
      if (!isNetworkError(e)) rethrow;
      final local = await store.loadDetail(id);
      if (local == null) rethrow;
      return local;
    }
  }

  /// Conserva la ruta local de fotos/audios ya subidos para no descargarlos.
  Future<void> _keepLocalFiles(WorkOrderDetail fresh) async {
    final local = await store.loadDetail(fresh.id);
    if (local == null) return;
    final paths = <String, String>{
      for (final e in local.elevators) ...{
        for (final p in e.photos)
          if (p.localPath != null) p.id: p.localPath!,
        for (final a in e.audios)
          if (a.localPath != null) a.id: a.localPath!,
      },
    };
    // Marca local: la transcripción ya se pasó al texto de Hallazgos.
    final applied = <String>{
      for (final e in local.elevators)
        for (final a in e.audios)
          if (a.appliedToFinding) a.id,
    };
    for (final e in fresh.elevators) {
      for (var i = 0; i < e.audios.length; i++) {
        if (applied.contains(e.audios[i].id)) {
          e.audios[i] = ElevatorAudio.fromJson({...e.audios[i].toJson(), 'appliedToFinding': true});
        }
      }
    }
    for (final e in fresh.elevators) {
      for (var i = 0; i < e.photos.length; i++) {
        final path = paths[e.photos[i].id];
        if (path != null && File(path).existsSync()) {
          e.photos[i] = ElevatorPhoto.fromJson({...e.photos[i].toJson(), 'localPath': path});
        }
      }
      for (var i = 0; i < e.audios.length; i++) {
        final path = paths[e.audios[i].id];
        if (path != null && File(path).existsSync()) {
          e.audios[i] = ElevatorAudio.fromJson({...e.audios[i].toJson(), 'localPath': path});
        }
      }
    }
  }

  @override
  Future<void> saveLocal(WorkOrderDetail o) => store.saveDetail(o);

  @override
  Future<void> clearLocal() => store.clear();

  @override
  Future<void> startWorkOrder(WorkOrderDetail o) => _send(o.id, '/work-orders/${o.id}/start', {
        'startedAt': o.startedAt,
        'elevators': [
          for (final e in o.elevators)
            {
              'id': e.id,
              'safetyItems': [
                for (final i in e.safety?.items ?? const <SafetyItem>[])
                  {'id': i.id, 'question': i.question, 'orderIndex': i.orderIndex},
              ],
            },
        ],
      });

  @override
  Future<void> saveSafetyItems(String workOrderId, String elevatorId, List<SafetyItem> items) =>
      _send(workOrderId, '/elevators/$elevatorId/safety/items', {
        'items': [
          for (final i in items)
            {
              'id': i.id,
              'response': i.response?.api,
              'observations': i.observations,
              'answeredAt': i.answeredAt,
            },
        ],
      });

  @override
  Future<void> completeSafety(String workOrderId, Elevator e, double? lat, double? lng) =>
      _send(workOrderId, '/elevators/${e.id}/safety/complete', {
        'completedAt': e.safety?.completedAt,
        'geolocation':
            lat == null || lng == null ? null : {'latitude': lat, 'longitude': lng},
      });

  @override
  Future<void> saveTasks(String workOrderId, String elevatorId, List<MaintenanceTask> tasks) =>
      _send(workOrderId, '/elevators/$elevatorId/tasks', {
        'tasks': [
          for (final t in tasks)
            {
              'id': t.id,
              'status': t.status,
              'isCompleted': t.isCompleted,
              'observations': t.observations,
              'completedAt': t.completedAt,
            },
        ],
      });

  @override
  Future<void> updateFindings(String workOrderId, String elevatorId, String findings) =>
      _send(workOrderId, '/elevators/$elevatorId/findings', {'findings': findings});

  @override
  Future<ElevatorPhoto> addPhoto(String workOrderId, String elevatorId, File file, PhotoTag tag,
      {String? description, String? taskId}) async {
    final id = _uuid.v4();
    final local = await _persistFile(file, id, 'jpg');
    await _send(
      workOrderId,
      '/elevators/$elevatorId/photos',
      {
        'id': id,
        'tag': tag.api,
        'description': description,
        'taskId': taskId,
        'createdAt': _now(),
      },
      id: id,
      files: {'file': local},
    );
    return ElevatorPhoto(
        id: id, localPath: local, tag: tag, description: description, taskId: taskId);
  }

  @override
  Future<void> removePhoto(String workOrderId, ElevatorPhoto photo) async {
    // Si aún no se subió, basta con sacarla de la cola.
    if (await queue.cancel(photo.id)) return;
    await _send(workOrderId, '/photos/${photo.id}', {}, method: 'DELETE');
  }

  @override
  Future<ElevatorAudio> addAudio(String workOrderId, String elevatorId, File file, int durationMs,
      {String? photoId}) async {
    final id = _uuid.v4();
    final local = await _persistFile(file, id, 'm4a');
    await _send(
      workOrderId,
      '/elevators/$elevatorId/audios',
      {'id': id, 'durationMs': durationMs, 'createdAt': _now(), 'photoId': ?photoId},
      id: id,
      files: {'file': local},
    );
    return ElevatorAudio(id: id, localPath: local, durationMs: durationMs, photoId: photoId);
  }

  @override
  Future<void> removeAudio(String workOrderId, ElevatorAudio audio) async {
    // Si aún no se subió, basta con sacarlo de la cola (borra la copia local).
    if (await queue.cancel(audio.id)) return;
    await _send(workOrderId, '/audios/${audio.id}', {}, method: 'DELETE');
  }

  @override
  Future<void> completeElevator(String workOrderId, Elevator e, {required bool allCompleted}) =>
      _send(workOrderId, '/elevators/${e.id}/complete', {
        'mode': allCompleted ? 'all_completed' : 'partial',
        'completedAt': e.completedAt,
      });

  @override
  Future<void> completeWorkOrder(WorkOrderDetail o,
          {required String clientName,
          required Uint8List signaturePng,
          required Map<String, ElevatorFinalStatus> elevatorStatuses}) =>
      _send(o.id, '/work-orders/${o.id}/complete', {
        'clientName': clientName,
        'signatureDataUrl': 'data:image/png;base64,${base64Encode(signaturePng)}',
        'elevatorStatuses': {
          for (final e in elevatorStatuses.entries) e.key: e.value.api,
        },
        'completedAt': _now(),
      });
}
