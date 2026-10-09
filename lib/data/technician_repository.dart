import 'dart:io';
import 'dart:typed_data';

import 'models.dart';

/// Acceso a datos del técnico, pensado para trabajar sin internet:
///
/// - Las lecturas devuelven la copia local cuando no hay señal (o cuando
///   hay cambios locales aún sin enviar, que son más recientes).
/// - Las escrituras no esperan al servidor: se encolan y vuelven al
///   instante. La cola las envía en orden cuando hay conexión.
///
/// Las reglas de negocio (qué se puede aprobar, mínimo de fotos, etc.) se
/// validan en la app con las mismas reglas que el backend, para no depender
/// de la respuesta del servidor. Ver `WorkOrderController`.
abstract class TechnicianRepository {
  /// POST /auth/login (requiere señal la primera vez).
  Future<(String token, TechnicianUser user)> login(String email, String password);

  /// GET /work-orders
  Future<List<WorkOrderSummary>> fetchWorkOrders();

  /// GET /work-orders/:id
  Future<WorkOrderDetail> fetchWorkOrder(String id);

  /// Guarda el estado local de la OT (tras cada cambio del técnico).
  Future<void> saveLocal(WorkOrderDetail o);

  /// Borra la caché local (al cerrar sesión).
  Future<void> clearLocal();

  /// POST /work-orders/:id/start — incluye los ítems de seguridad creados
  /// localmente para que el servidor use los mismos IDs.
  Future<void> startWorkOrder(WorkOrderDetail o);

  /// POST /elevators/:id/safety/items — uno o varios ítems en un envío.
  Future<void> saveSafetyItems(String workOrderId, String elevatorId, List<SafetyItem> items);

  /// POST /elevators/:id/safety/complete
  Future<void> completeSafety(String workOrderId, Elevator e, double? lat, double? lng);

  /// POST /elevators/:id/tasks — una o varias tareas en un envío.
  Future<void> saveTasks(String workOrderId, String elevatorId, List<MaintenanceTask> tasks);

  /// POST /elevators/:id/findings
  Future<void> updateFindings(String workOrderId, String elevatorId, String findings);

  /// POST /elevators/:id/photos (multipart). Devuelve la foto local.
  Future<ElevatorPhoto> addPhoto(String workOrderId, String elevatorId, File file, PhotoTag tag,
      {String? description, String? taskId});

  /// DELETE /photos/:id (o la saca de la cola si no se subió).
  Future<void> removePhoto(String workOrderId, ElevatorPhoto photo);

  /// POST /elevators/:id/audios (multipart). Devuelve el audio local.
  /// [photoId]: foto desde la que se grabó; null si es de Hallazgos.
  Future<ElevatorAudio> addAudio(String workOrderId, String elevatorId, File file, int durationMs,
      {String? photoId});

  /// DELETE /audios/:id (o lo saca de la cola si no se subió).
  Future<void> removeAudio(String workOrderId, ElevatorAudio audio);

  /// POST /elevators/:id/complete
  Future<void> completeElevator(String workOrderId, Elevator e, {required bool allCompleted});

  /// POST /work-orders/:id/complete
  Future<void> completeWorkOrder(WorkOrderDetail o,
      {required String clientName,
      required Uint8List signaturePng,
      required Map<String, ElevatorFinalStatus> elevatorStatuses});
}
