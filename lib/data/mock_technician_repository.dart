import 'dart:io';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'models.dart';
import 'technician_repository.dart';

const _uuid = Uuid();

/// Datos de demostración en memoria para probar el flujo completo sin
/// backend (`--dart-define=USE_MOCK=true`).
class MockTechnicianRepository implements TechnicianRepository {
  final Map<String, WorkOrderDetail> _orders = {};

  MockTechnicianRepository() {
    _seed();
  }

  Future<void> _delay() => Future.delayed(const Duration(milliseconds: 250));

  void _seed() {
    const questions = [
      '¿Cuenta con EPP completo (casco, arnés, zapatos dieléctricos)?',
      '¿Se colocó el letrero de "Equipo en mantenimiento" en todos los pisos?',
      '¿Se bloqueó y etiquetó el interruptor principal (LOTO)?',
      '¿El cuarto de máquinas está libre de obstáculos y con iluminación?',
      '¿Se verificó el funcionamiento del stop de foso antes de ingresar?',
    ];
    // Fechas relativas a hoy para que la tira de días tenga sentido.
    String day(int offset) {
      final d = DateTime.now().add(Duration(days: offset));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
    Elevator elevator(String code, String name) => Elevator(
          id: _uuid.v4(),
          internalCode: code,
          name: name,
          type: 'Ascensor de pasajeros',
          brand: 'Orona',
          status: 'PENDING',
          photosRequired: false,
          safety: null,
          safetyTemplate: [
            for (var i = 0; i < questions.length; i++) SafetyQuestion(questions[i], i),
          ],
          tasks: [
            for (final (m, d, c) in [
              ('M1', 'Revisar y lubricar guías de cabina', false),
              ('M1', 'Verificar operador de puertas', false),
              ('M1', 'Probar sistema de freno', true),
              ('M2', 'Revisar cables de tracción', true),
              ('M2', 'Limpiar foso', false),
              (null, 'Probar alarma y citófono de cabina', true),
            ])
              MaintenanceTask(
                id: _uuid.v4(),
                description: d,
                isCritical: c,
                isCompleted: false,
                status: TaskStatus.pending,
                moduleId: m,
                moduleCode: m,
                moduleName: m == null ? null : 'Módulo $m',
              ),
          ],
          photos: [],
          audios: [],
        );

    final a = WorkOrderDetail(
      id: 'wo-1',
      otNumber: 'OT-2026-0100',
      status: 'PENDING',
      priority: 'NORMAL',
      scheduledDate: day(0),
      scheduledTime: '09:00',
      clientName: 'Inversiones San Isidro SAC',
      description: 'Mantenimiento preventivo mensual',
      serviceTypeCode: 'PREV',
      serviceTypeName: 'Mantenimiento Preventivo Mensual',
      costCenter: const CostCenter(
        id: 'cc-1',
        name: 'Torre Empresarial A',
        address: 'Av. Las Camelias 450',
        contactName: 'Carlos Mendoza',
        contactPhone: '999888777',
      ),
      elevators: [elevator('ASC-01', 'Ascensor 1'), elevator('ASC-02', 'Ascensor 2')],
    );
    final b = WorkOrderDetail(
      id: 'wo-2',
      otNumber: 'OT-2026-0101',
      status: 'PENDING',
      priority: 'HIGH',
      scheduledDate: day(1),
      scheduledTime: '14:30',
      clientName: 'Condominio Los Rosales',
      serviceTypeCode: 'CORR',
      serviceTypeName: 'Mantenimiento Correctivo',
      costCenter: const CostCenter(
          id: 'cc-2', name: 'Edificio Los Rosales', address: 'Av. Principal 123'),
      elevators: [elevator('ASC-11', 'Ascensor único')],
    );
    _orders[a.id] = a;
    _orders[b.id] = b;
  }

  @override
  Future<(String, TechnicianUser)> login(String email, String password) async {
    await _delay();
    if (email.trim().isEmpty || password.isEmpty) {
      throw Exception('Ingresa tu correo y contraseña');
    }
    final exp = DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch ~/ 1000;
    return (
      'demo-user.$exp.firma',
      TechnicianUser(
          id: 'demo-user', fullName: 'Técnico Demo', email: email, role: 'TECNICO DE CAMPO'),
    );
  }

  @override
  Future<List<WorkOrderSummary>> fetchWorkOrders() async {
    await _delay();
    return _orders.values
        .map((o) => WorkOrderSummary(
              id: o.id,
              otNumber: o.otNumber,
              status: o.status,
              priority: o.priority,
              scheduledDate: o.scheduledDate,
              scheduledTime: o.scheduledTime,
              clientName: o.clientName ?? '',
              costCenterName: o.costCenter?.name ?? '',
              costCenterAddress: o.costCenter?.address,
              serviceTypeCode: o.serviceTypeCode,
              serviceTypeName: o.serviceTypeName,
              equipmentCount: o.elevators.length,
            ))
        .toList();
  }

  @override
  Future<WorkOrderDetail> fetchWorkOrder(String id) async {
    await _delay();
    return _orders[id]!;
  }

  // En modo demostración la app ya aplicó cada cambio sobre el modelo en
  // memoria (local primero), así que las escrituras no hacen nada.

  @override
  Future<void> saveLocal(WorkOrderDetail o) async {}

  @override
  Future<void> clearLocal() async {}

  @override
  Future<void> startWorkOrder(WorkOrderDetail o) async {}

  @override
  Future<void> saveSafetyItems(String workOrderId, String elevatorId, List<SafetyItem> items) async {}

  @override
  Future<void> completeSafety(String workOrderId, Elevator e, double? lat, double? lng) async {}

  @override
  Future<void> saveTasks(String workOrderId, String elevatorId, List<MaintenanceTask> tasks) async {}

  @override
  Future<void> updateFindings(String workOrderId, String elevatorId, String findings) async {}

  @override
  Future<ElevatorPhoto> addPhoto(String workOrderId, String elevatorId, File file, PhotoTag tag,
          {String? description, String? taskId}) async =>
      ElevatorPhoto(
          id: _uuid.v4(), localPath: file.path, tag: tag, description: description, taskId: taskId);

  @override
  Future<void> removePhoto(String workOrderId, ElevatorPhoto photo) async {}

  @override
  Future<ElevatorAudio> addAudio(
          String workOrderId, String elevatorId, File file, int durationMs) async =>
      ElevatorAudio(id: _uuid.v4(), localPath: file.path, durationMs: durationMs);

  @override
  Future<void> removeAudio(String workOrderId, ElevatorAudio audio) async {}

  @override
  Future<void> completeElevator(String workOrderId, Elevator e, {required bool allCompleted}) async {}

  @override
  Future<void> completeWorkOrder(WorkOrderDetail o,
      {required String clientName,
      required Uint8List signaturePng,
      required Map<String, ElevatorFinalStatus> elevatorStatuses}) async {}
}
