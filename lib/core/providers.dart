import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/api_technician_repository.dart';
import '../data/mock_technician_repository.dart';
import '../data/models.dart';
import '../data/technician_repository.dart';
import 'api_client.dart';
import 'config.dart';
import 'offline_store.dart';
import 'session_store.dart';
import 'sync_queue.dart';

const _uuid = Uuid();
int _now() => DateTime.now().millisecondsSinceEpoch;

final sessionStoreProvider = Provider((_) => SessionStore());

final apiClientProvider =
    Provider((ref) => ApiClient(ref.watch(sessionStoreProvider)));

/// Se sobreescribe en `main.dart` con la cola ya inicializada.
final syncQueueProvider = Provider<SyncQueue>((_) => throw UnimplementedError());

final repositoryProvider = Provider<TechnicianRepository>((ref) {
  if (AppConfig.useMock) return MockTechnicianRepository();
  return ApiTechnicianRepository(
      ref.watch(apiClientProvider), ref.watch(syncQueueProvider), OfflineStore());
});

/// Sesión del técnico: `null` = sin sesión. Con un token vigente guardado
/// la app abre sin señal.
class AuthController extends AsyncNotifier<TechnicianUser?> {
  @override
  Future<TechnicianUser?> build() async {
    final store = ref.read(sessionStoreProvider);
    ref.read(apiClientProvider).onUnauthorized = logout;
    if (!await store.hasValidToken()) return null;
    if (!AppConfig.useMock) unawaited(_refreshToken());
    return store.user();
  }

  /// Con señal, cambia el token por uno con la duración completa para que
  /// no venza en mitad de una jornada sin cobertura. Sin señal no pasa nada:
  /// el token actual sigue valiendo hasta su vencimiento.
  Future<void> _refreshToken() async {
    try {
      final res = await ref.read(apiClientProvider).dio.post('/auth/refresh');
      final token = (res.data as Map<String, dynamic>)['token'];
      if (token is String) {
        await ref.read(sessionStoreProvider).replaceToken(token);
      }
    } catch (_) {
      // Sin señal, o sesión revocada (el 401 ya dispara el cierre de sesión).
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final (token, user) =
          await ref.read(repositoryProvider).login(email.trim(), password);
      await ref.read(sessionStoreProvider).save(token, user);
      if (!AppConfig.useMock) unawaited(ref.read(syncQueueProvider).flush());
      return user;
    });
  }

  Future<void> logout() async {
    await ref.read(sessionStoreProvider).clear();
    // La caché solo se borra si no quedan cambios por enviar.
    final pending = AppConfig.useMock ? 0 : ref.read(syncQueueProvider).length;
    if (pending == 0) await ref.read(repositoryProvider).clearLocal();
    state = const AsyncData(null);
  }
}

final authProvider =
    AsyncNotifierProvider<AuthController, TechnicianUser?>(AuthController.new);

final workOrdersProvider = FutureProvider.autoDispose<List<WorkOrderSummary>>(
    (ref) => ref.watch(repositoryProvider).fetchWorkOrders());

/// Estado y reglas de una OT, local primero.
///
/// Cada acción del técnico se aplica al modelo y se ve al instante, se
/// guarda en la copia local y se encola para el servidor; la pantalla nunca
/// espera la red. Por eso las reglas que el backend valida (seguridad
/// completa, mínimo de fotos, equipos finalizados) se validan aquí también.
/// Los métodos devuelven un mensaje de error o `null` si todo fue bien.
class WorkOrderController extends AsyncNotifier<WorkOrderDetail> {
  WorkOrderController(this.workOrderId);
  final String workOrderId;

  /// Encadena los envíos para que lleguen a la cola en el orden en que el
  /// técnico hizo las cosas (p. ej. aprobar seguridad antes que tareas).
  Future<void> _chain = Future.value();

  TechnicianRepository get _repo => ref.read(repositoryProvider);
  WorkOrderDetail get _o => state.requireValue;

  @override
  Future<WorkOrderDetail> build() => _repo.fetchWorkOrder(workOrderId);

  @override
  bool updateShouldNotify(
          AsyncValue<WorkOrderDetail> previous, AsyncValue<WorkOrderDetail> next) =>
      true;

  Future<void> reload() async {
    await _chain;
    state = await AsyncValue.guard(() => _repo.fetchWorkOrder(workOrderId));
  }

  Elevator elevator(String id) => _o.elevators.firstWhere((e) => e.id == id);

  /// Repinta, guarda localmente y encola [send] en orden.
  ///
  /// [send] recibe el repositorio y la OT capturados ahora, para que el
  /// envío ocurra aunque el técnico ya haya salido de la pantalla.
  void _commit([Future<void> Function(TechnicianRepository r, WorkOrderDetail o)? send]) {
    final o = _o;
    final repo = _repo;
    state = AsyncData(o);
    _chain = _chain.then((_) async {
      await repo.saveLocal(o);
      if (send != null) await send(repo, o);
    }).catchError((_) {});
  }

  void _refreshListAfterSave() => _chain = _chain.then((_) {
        if (ref.mounted) ref.invalidate(workOrdersProvider);
      });

  // --- Iniciar ---------------------------------------------------------

  /// Igual que `startWorkOrder` del backend: marca la OT en curso y crea el
  /// checklist de seguridad de cada equipo, aquí con la plantilla descargada.
  void start() {
    final o = _o;
    if (!o.isPending) return;
    final now = _now();
    o.status = 'IN_PROGRESS';
    o.startedAt = now;
    for (final e in o.elevators) {
      e.startedAt = now;
      e.safety ??= Safety(id: _uuid.v4(), status: 'PENDING', items: [
        for (final q in e.safetyTemplate)
          SafetyItem(id: _uuid.v4(), question: q.question, orderIndex: q.orderIndex),
      ]);
    }
    _commit((r, o) => r.startWorkOrder(o));
    _refreshListAfterSave();
  }

  // --- Seguridad -------------------------------------------------------

  void answerSafety(Elevator e, SafetyItem item, SafetyResponse r) {
    item.response = r;
    item.answeredAt = _now();
    if (r != SafetyResponse.no) item.observations = null;
    _commit((r, o) => r.saveSafetyItems(o.id, e.id, [item]));
  }

  void setSafetyObservation(Elevator e, SafetyItem item, String text) {
    final t = text.trim();
    if ((item.observations ?? '') == t) return;
    item.observations = t.isEmpty ? null : t;
    _commit((r, o) => r.saveSafetyItems(o.id, e.id, [item]));
  }

  /// "Aceptar todos": responde "Sí" a todas las preguntas sin responder, en
  /// un solo envío. Las que ya tienen respuesta (p. ej. un "No" con su
  /// observación) se respetan.
  int acceptAllSafety(Elevator e) {
    final now = _now();
    final changed = [
      for (final i in e.safety!.items)
        if (i.response == null) i,
    ];
    for (final i in changed) {
      i.response = SafetyResponse.si;
      i.answeredAt = now;
    }
    if (changed.isNotEmpty) _commit((r, o) => r.saveSafetyItems(o.id, e.id, changed));
    return changed.length;
  }

  /// Aprueba la seguridad al instante. La ubicación se obtiene después y
  /// viaja en el mismo envío; si no hay GPS se envía sin ubicación.
  String? approveSafety(Elevator e, Future<({double lat, double lng})?> Function() location) {
    final safety = e.safety;
    if (safety == null) return 'Inicia la orden primero.';
    if (safety.items.any((i) => i.response == null)) {
      return 'Debes responder todas las preguntas antes de aprobar.';
    }
    if (safety.items.any((i) => !i.isValid)) {
      return 'Agrega una observación en cada respuesta "No".';
    }
    safety.status = 'COMPLETED';
    safety.completedAt = _now();
    _commit((r, o) async {
      final loc = await location();
      await r.completeSafety(o.id, e, loc?.lat, loc?.lng);
    });
    return null;
  }

  // --- Tareas ----------------------------------------------------------

  void _setTaskState(MaintenanceTask t, String status, int now) {
    t.status = status;
    t.isCompleted = status == TaskStatus.completed;
    t.completedAt = status == TaskStatus.pending ? null : now;
  }

  void setTask(Elevator e, MaintenanceTask t, String status, {String? observations}) {
    _setTaskState(t, status, _now());
    if (observations != null) t.observations = observations.isEmpty ? null : observations;
    _commit((r, o) => r.saveTasks(o.id, e.id, [t]));
  }

  /// Aprueba (o desmarca) varias tareas de una vez, como la web: se ven
  /// aprobadas al instante y van al servidor en un solo envío.
  void setTasks(Elevator e, List<MaintenanceTask> tasks, {required bool approve}) {
    final now = _now();
    final changed = [
      for (final t in tasks)
        if (approve ? !t.isResolved : t.isCompleted) t,
    ];
    for (final t in changed) {
      _setTaskState(t, approve ? TaskStatus.completed : TaskStatus.pending, now);
    }
    if (changed.isNotEmpty) _commit((r, o) => r.saveTasks(o.id, e.id, changed));
  }

  // --- Hallazgos, fotos y audio ----------------------------------------

  void setFindings(Elevator e, String text) {
    final t = text.trim();
    if ((e.finding ?? '') == t) return;
    e.finding = t;
    _commit((r, o) => r.updateFindings(o.id, e.id, t));
  }

  Future<ElevatorPhoto> addPhoto(Elevator e, File file, PhotoTag tag,
      {String? description, String? taskId}) async {
    final photo = await _repo.addPhoto(_o.id, e.id, file, tag,
        description: description, taskId: taskId);
    e.photos.add(photo);
    _commit();
    return photo;
  }

  void removePhoto(Elevator e, ElevatorPhoto p) {
    e.photos.removeWhere((x) => x.id == p.id);
    _commit((r, o) => r.removePhoto(o.id, p));
  }

  /// [photoId]: foto desde la que se grabó la nota; null si es de Hallazgos.
  Future<void> addAudio(Elevator e, File file, int durationMs, {String? photoId}) async {
    final audio = await _repo.addAudio(_o.id, e.id, file, durationMs, photoId: photoId);
    e.audios.add(audio);
    _commit();
  }

  /// Marca la nota como ya agregada al texto de Hallazgos (solo local).
  void markAudioApplied(Elevator e, ElevatorAudio a) {
    final i = e.audios.indexWhere((x) => x.id == a.id);
    if (i < 0) return;
    e.audios[i] = ElevatorAudio.fromJson({...a.toJson(), 'appliedToFinding': true});
    _commit();
  }

  void removeAudio(Elevator e, ElevatorAudio a) {
    e.audios.removeWhere((x) => x.id == a.id);
    _commit((r, o) => r.removeAudio(o.id, a));
  }

  // --- Cierre ----------------------------------------------------------

  String? completeElevator(Elevator e, {required bool allCompleted}) {
    if (!e.safetyDone) return 'Aprueba primero el checklist de seguridad.';
    if (!e.photosOk) {
      return 'Debes subir al menos ${Elevator.minPhotos} fotos. '
          'Faltan ${Elevator.minPhotos - e.photos.length}.';
    }
    final now = _now();
    if (allCompleted) {
      for (final t in e.tasks.where((t) => !t.isResolved)) {
        _setTaskState(t, TaskStatus.completed, now);
      }
    }
    e.status = 'COMPLETED';
    e.completedAt = now;
    _commit((r, o) => r.completeElevator(o.id, e, allCompleted: allCompleted));
    return null;
  }

  String? completeWorkOrder({
    required String clientName,
    required Uint8List signaturePng,
    required Map<String, ElevatorFinalStatus> elevatorStatuses,
  }) {
    final o = _o;
    if (!o.allElevatorsCompleted) return 'Todos los equipos deben estar finalizados.';
    if (clientName.trim().isEmpty) return 'Ingresa el nombre de quien recibe.';
    if (o.elevators.any((e) => !elevatorStatuses.containsKey(e.id))) {
      return 'Indica el estado final de cada equipo.';
    }
    o.status = 'COMPLETED';
    _commit((r, o) => r.completeWorkOrder(o,
        clientName: clientName.trim(),
        signaturePng: signaturePng,
        elevatorStatuses: elevatorStatuses));
    _refreshListAfterSave();
    return null;
  }
}

final workOrderProvider = AsyncNotifierProvider.family<WorkOrderController,
    WorkOrderDetail, String>(WorkOrderController.new);

/// Número de cambios pendientes de sincronizar (para el indicador).
final pendingSyncProvider = StreamProvider<int>((ref) {
  if (AppConfig.useMock) return Stream.value(0);
  return ref.watch(syncQueueProvider).pendingCount;
});
