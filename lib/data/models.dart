// Modelos que reflejan los tipos de `src/features/technician/server/queries.ts`
// del backend web. Los nombres de campo JSON se mantienen tal cual los
// devuelve el backend (incluidos los snake_case como `client_name`).

int? _int(dynamic v) => v == null ? null : (v as num).toInt();
double? _double(dynamic v) => v == null ? null : (v as num).toDouble();
bool _bool(dynamic v) => v == true || v == 1;

class TechnicianUser {
  final String id;
  final String fullName;
  final String email;
  final String? role;

  const TechnicianUser({
    required this.id,
    required this.fullName,
    required this.email,
    this.role,
  });

  factory TechnicianUser.fromJson(Map<String, dynamic> j) => TechnicianUser(
        id: j['id'] as String,
        fullName: j['fullName'] as String,
        email: j['email'] as String? ?? '',
        role: j['role'] as String?,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'fullName': fullName, 'email': email, 'role': role};
}

/// Fila del listado (`TechnicianWorkOrder`).
class WorkOrderSummary {
  final String id;
  final String otNumber;
  final String? status;
  final String? priority;
  final String? scheduledDate;
  final String? scheduledTime;
  final String clientName;
  final String costCenterName;
  final String? costCenterAddress;
  final String? serviceTypeCode;
  final String? serviceTypeName;
  final int equipmentCount;

  const WorkOrderSummary({
    required this.id,
    required this.otNumber,
    this.status,
    this.priority,
    this.scheduledDate,
    this.scheduledTime,
    required this.clientName,
    required this.costCenterName,
    this.costCenterAddress,
    this.serviceTypeCode,
    this.serviceTypeName,
    required this.equipmentCount,
  });

  factory WorkOrderSummary.fromJson(Map<String, dynamic> j) => WorkOrderSummary(
        id: j['id'] as String,
        otNumber: j['otNumber'] as String,
        status: j['status'] as String?,
        priority: j['priority'] as String?,
        scheduledDate: j['scheduledDate'] as String?,
        scheduledTime: j['scheduledTime'] as String?,
        clientName: j['client_name'] as String? ?? '',
        costCenterName: j['cost_center_name'] as String? ?? '',
        costCenterAddress: j['cost_center_address'] as String?,
        serviceTypeCode: j['service_type_code'] as String?,
        serviceTypeName: j['service_type_name'] as String?,
        equipmentCount: _int(j['equipmentCount']) ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'otNumber': otNumber,
        'status': status,
        'priority': priority,
        'scheduledDate': scheduledDate,
        'scheduledTime': scheduledTime,
        'client_name': clientName,
        'cost_center_name': costCenterName,
        'cost_center_address': costCenterAddress,
        'service_type_code': serviceTypeCode,
        'service_type_name': serviceTypeName,
        'equipmentCount': equipmentCount,
      };
}

/// Respuestas válidas del checklist de seguridad.
enum SafetyResponse { si, no, na }

extension SafetyResponseApi on SafetyResponse {
  String get api => switch (this) {
        SafetyResponse.si => 'SI',
        SafetyResponse.no => 'NO',
        SafetyResponse.na => 'NA',
      };
  String get label => switch (this) {
        SafetyResponse.si => 'Sí',
        SafetyResponse.no => 'No',
        SafetyResponse.na => 'N/A',
      };
  static SafetyResponse? parse(String? v) => switch (v) {
        'SI' => SafetyResponse.si,
        'NO' => SafetyResponse.no,
        'NA' => SafetyResponse.na,
        _ => null,
      };
}

class SafetyItem {
  final String id;
  final String question;
  SafetyResponse? response;
  String? observations;
  final int orderIndex;
  int? answeredAt;

  SafetyItem({
    required this.id,
    required this.question,
    this.response,
    this.observations,
    required this.orderIndex,
    this.answeredAt,
  });

  /// Regla del backend: si la respuesta es NO, la observación es obligatoria.
  bool get isValid =>
      response != null &&
      (response != SafetyResponse.no ||
          (observations?.trim().isNotEmpty ?? false));

  factory SafetyItem.fromJson(Map<String, dynamic> j) => SafetyItem(
        id: j['id'] as String,
        question: j['question'] as String,
        response: SafetyResponseApi.parse(j['response'] as String?),
        observations: j['observations'] as String?,
        orderIndex: _int(j['orderIndex']) ?? 0,
        answeredAt: _int(j['answeredAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'response': response?.api,
        'observations': observations,
        'orderIndex': orderIndex,
        'answeredAt': answeredAt,
      };
}

/// Pregunta de la plantilla de seguridad activa del tipo de equipo. Viene
/// en la descarga de la OT para poder iniciarla sin conexión: la app crea
/// los ítems localmente con IDs propios y el servidor los respeta.
class SafetyQuestion {
  final String question;
  final int orderIndex;

  const SafetyQuestion(this.question, this.orderIndex);

  factory SafetyQuestion.fromJson(Map<String, dynamic> j) =>
      SafetyQuestion(j['question'] as String, _int(j['orderIndex']) ?? 0);

  Map<String, dynamic> toJson() => {'question': question, 'orderIndex': orderIndex};
}

class Safety {
  final String? id;
  String? status;
  String? notes;
  int? completedAt;
  final List<SafetyItem> items;

  Safety({this.id, this.status, this.notes, this.completedAt, required this.items});

  bool get isCompleted => status == 'COMPLETED';

  factory Safety.fromJson(Map<String, dynamic> j) => Safety(
        id: j['id'] as String?,
        status: j['status'] as String?,
        notes: j['notes'] as String?,
        completedAt: _int(j['completedAt']),
        items: ((j['items'] as List?) ?? [])
            .map((e) => SafetyItem.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex)),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status,
        'notes': notes,
        'completedAt': completedAt,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

/// Estados de tarea del backend.
class TaskStatus {
  static const pending = 'PENDING';
  static const completed = 'COMPLETED';
  static const skipped = 'SKIPPED';
  static const notApplicable = 'NOT_APPLICABLE';
}

class MaintenanceTask {
  final String id;
  final String description;
  final bool isCritical;
  bool isCompleted;
  String status;
  String? observations;
  final String? moduleId;
  final String? moduleCode;
  final String? moduleName;
  int? completedAt;

  MaintenanceTask({
    required this.id,
    required this.description,
    required this.isCritical,
    required this.isCompleted,
    required this.status,
    this.observations,
    this.moduleId,
    this.moduleCode,
    this.moduleName,
    this.completedAt,
  });

  bool get isResolved => status != TaskStatus.pending;

  factory MaintenanceTask.fromJson(Map<String, dynamic> j) => MaintenanceTask(
        id: j['id'] as String,
        description: j['taskDescription'] as String,
        isCritical: _bool(j['isCritical']),
        isCompleted: _bool(j['isCompleted']),
        status: j['status'] as String? ?? TaskStatus.pending,
        observations: j['observations'] as String?,
        moduleId: j['moduleId'] as String?,
        moduleCode: j['moduleCode'] as String?,
        moduleName: j['moduleName'] as String?,
        completedAt: _int(j['completedAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'taskDescription': description,
        'isCritical': isCritical,
        'isCompleted': isCompleted,
        'status': status,
        'observations': observations,
        'moduleId': moduleId,
        'moduleCode': moduleCode,
        'moduleName': moduleName,
        'completedAt': completedAt,
      };
}

enum PhotoTag { before, after, point }

extension PhotoTagApi on PhotoTag {
  String get api => switch (this) {
        PhotoTag.before => 'BEFORE',
        PhotoTag.after => 'AFTER',
        PhotoTag.point => 'POINT',
      };
  String get label => switch (this) {
        PhotoTag.before => 'Antes',
        PhotoTag.after => 'Después',
        PhotoTag.point => 'Punto de atención',
      };
  static PhotoTag parse(String? v) => switch (v) {
        'AFTER' => PhotoTag.after,
        'POINT' => PhotoTag.point,
        _ => PhotoTag.before,
      };
}

/// Foto registrada. El [id] lo genera la app (el servidor lo respeta), así
/// se puede borrar o referenciar aunque todavía no se haya subido.
/// Mientras [url] sea nulo, la foto está pendiente de subir.
class ElevatorPhoto {
  final String id;
  final String? url;
  final String? localPath;
  final PhotoTag tag;
  final String? description;
  final String? taskId;

  const ElevatorPhoto({
    required this.id,
    this.url,
    this.localPath,
    required this.tag,
    this.description,
    this.taskId,
  });

  bool get isPendingUpload => url == null;

  factory ElevatorPhoto.fromJson(Map<String, dynamic> j) => ElevatorPhoto(
        id: j['id'] as String,
        url: j['url'] as String?,
        tag: PhotoTagApi.parse(j['tag'] as String?),
        localPath: j['localPath'] as String?,
        description: j['description'] as String?,
        taskId: j['workOrderTaskId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'localPath': localPath,
        'tag': tag.api,
        'description': description,
        'workOrderTaskId': taskId,
      };
}

/// Nota de voz de un hallazgo. Ver `mobile/README.md` (sección Audio): se
/// sube a R2 cuando hay señal y el servidor la transcribe y guarda el texto
/// en la base de datos.
class ElevatorAudio {
  final String id;
  final String? url;
  final String? localPath;
  final int durationMs;
  final String? transcript;

  /// `PENDING` | `DONE` | `FAILED` (estado de la transcripción en servidor).
  final String transcriptStatus;

  /// Foto desde la que se grabó la nota; null = grabada en Hallazgos.
  final String? photoId;

  /// Solo local: su transcripción ya se agregó al texto de Hallazgos, para
  /// no repetirla cada vez que se recarga la orden.
  final bool appliedToFinding;

  const ElevatorAudio({
    required this.id,
    this.url,
    this.localPath,
    required this.durationMs,
    this.transcript,
    this.transcriptStatus = 'PENDING',
    this.photoId,
    this.appliedToFinding = false,
  });

  bool get isPendingUpload => url == null;

  /// Nota grabada en Hallazgos (no desde una foto).
  bool get isFindingNote => photoId == null;

  factory ElevatorAudio.fromJson(Map<String, dynamic> j) => ElevatorAudio(
        id: j['id'] as String,
        url: j['url'] as String?,
        localPath: j['localPath'] as String?,
        durationMs: _int(j['durationMs']) ?? 0,
        transcript: j['transcript'] as String?,
        transcriptStatus: j['transcriptStatus'] as String? ?? 'PENDING',
        photoId: j['photoId'] as String?,
        appliedToFinding: j['appliedToFinding'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'localPath': localPath,
        'durationMs': durationMs,
        'transcript': transcript,
        'transcriptStatus': transcriptStatus,
        'photoId': photoId,
        'appliedToFinding': appliedToFinding,
      };
}

class Elevator {
  final String id;
  final String? internalCode;
  final String? name;
  final String? type;
  final String? brand;
  String? status;
  String? finding;

  /// Mínimo de fotos: solo en preventivos (PREV). Se calcula en la OT.
  bool photosRequired;
  Safety? safety;
  final List<SafetyQuestion> safetyTemplate;
  int? startedAt;
  int? completedAt;
  final List<MaintenanceTask> tasks;
  final List<ElevatorPhoto> photos;
  final List<ElevatorAudio> audios;

  Elevator({
    required this.id,
    this.internalCode,
    this.name,
    this.type,
    this.brand,
    this.status,
    this.finding,
    required this.photosRequired,
    this.safety,
    this.safetyTemplate = const [],
    this.startedAt,
    this.completedAt,
    required this.tasks,
    required this.photos,
    required this.audios,
  });

  static const minPhotos = 4;

  String get displayName => internalCode ?? name ?? 'Equipo';
  bool get isCompleted => status == 'COMPLETED';
  bool get safetyDone => safety?.isCompleted ?? false;
  bool get photosOk => !photosRequired || photos.length >= minPhotos;
  int get resolvedTasks => tasks.where((t) => t.isResolved).length;

  /// Tareas agrupadas por módulo (M1..M8) o "General".
  Map<String, List<MaintenanceTask>> get tasksByModule {
    final map = <String, List<MaintenanceTask>>{};
    for (final t in tasks) {
      final key = t.moduleCode ?? 'General';
      map.putIfAbsent(key, () => []).add(t);
    }
    return map;
  }

  factory Elevator.fromJson(Map<String, dynamic> j) => Elevator(
        id: j['id'] as String,
        internalCode: j['internalCode'] as String?,
        name: j['elevatorName'] as String?,
        type: j['elevatorType'] as String?,
        brand: j['brand'] as String?,
        status: j['status'] as String?,
        finding: j['finding'] as String?,
        photosRequired: _bool(j['photosRequired']),
        safety: j['safety'] == null
            ? null
            : Safety.fromJson(j['safety'] as Map<String, dynamic>),
        safetyTemplate: ((j['safetyTemplate'] as List?) ?? [])
            .map((e) => SafetyQuestion.fromJson(e as Map<String, dynamic>))
            .toList(),
        startedAt: _int(j['startedAt']),
        completedAt: _int(j['completedAt']),
        tasks: ((j['tasks'] as List?) ?? [])
            .map((e) => MaintenanceTask.fromJson(e as Map<String, dynamic>))
            .toList(),
        photos: ((j['photos'] as List?) ?? [])
            .map((e) => ElevatorPhoto.fromJson(e as Map<String, dynamic>))
            .toList(),
        audios: ((j['audios'] as List?) ?? [])
            .map((e) => ElevatorAudio.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'internalCode': internalCode,
        'elevatorName': name,
        'elevatorType': type,
        'brand': brand,
        'status': status,
        'finding': finding,
        'photosRequired': photosRequired,
        'safety': safety?.toJson(),
        'safetyTemplate': safetyTemplate.map((e) => e.toJson()).toList(),
        'startedAt': startedAt,
        'completedAt': completedAt,
        'tasks': tasks.map((e) => e.toJson()).toList(),
        'photos': photos.map((e) => e.toJson()).toList(),
        'audios': audios.map((e) => e.toJson()).toList(),
      };
}

class CostCenter {
  final String id;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? contactName;
  final String? contactPhone;

  const CostCenter({
    required this.id,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.contactName,
    this.contactPhone,
  });

  factory CostCenter.fromJson(Map<String, dynamic> j) {
    final contact = j['contact'] as Map<String, dynamic>?;
    return CostCenter(
      id: j['id'] as String,
      name: j['name'] as String,
      address: j['address'] as String?,
      latitude: _double(j['latitude']),
      longitude: _double(j['longitude']),
      contactName: contact?['fullName'] as String?,
      contactPhone: contact?['phone'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'contact': contactName == null ? null : {'fullName': contactName, 'phone': contactPhone},
      };
}

/// Detalle de ejecución (`TechnicianWorkOrderExecution`).
class WorkOrderDetail {
  final String id;
  final String otNumber;
  String? status;
  final String? priority;
  final String? scheduledDate;
  final String? scheduledTime;
  final String? clientName;
  final String? description;
  final String? serviceTypeCode;
  final String? serviceTypeName;
  final CostCenter? costCenter;
  final List<Elevator> elevators;
  int? startedAt;

  WorkOrderDetail({
    required this.id,
    required this.otNumber,
    this.status,
    this.priority,
    this.scheduledDate,
    this.scheduledTime,
    this.clientName,
    this.description,
    this.serviceTypeCode,
    this.serviceTypeName,
    this.costCenter,
    required this.elevators,
    this.startedAt,
  }) {
    // Regla de negocio: mínimo de 4 fotos solo en preventivos; en
    // correctivos y emergencias no hay mínimo.
    for (final e in elevators) {
      e.photosRequired = isPreventive;
    }
  }

  bool get isPreventive => serviceTypeCode?.toUpperCase() == 'PREV';

  bool get isPending => status == 'PENDING' || status == null;
  bool get isInProgress => status == 'IN_PROGRESS';
  bool get isCompleted => status == 'COMPLETED';
  bool get allElevatorsCompleted => elevators.every((e) => e.isCompleted);

  factory WorkOrderDetail.fromJson(Map<String, dynamic> j) {
    final st = j['serviceType'] as Map<String, dynamic>?;
    return WorkOrderDetail(
      id: j['id'] as String,
      otNumber: j['otNumber'] as String,
      status: j['status'] as String?,
      priority: j['priority'] as String?,
      scheduledDate: j['scheduledDate'] as String?,
      scheduledTime: j['scheduledTime'] as String?,
      clientName: j['client_name'] as String?,
      description: j['description'] as String?,
      serviceTypeCode: st?['code'] as String?,
      serviceTypeName: st?['name'] as String?,
      costCenter: j['costCenter'] == null
          ? null
          : CostCenter.fromJson(j['costCenter'] as Map<String, dynamic>),
      elevators: ((j['elevators'] as List?) ?? [])
          .map((e) => Elevator.fromJson(e as Map<String, dynamic>))
          .toList(),
      startedAt: _int(j['startedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'otNumber': otNumber,
        'status': status,
        'priority': priority,
        'scheduledDate': scheduledDate,
        'scheduledTime': scheduledTime,
        'client_name': clientName,
        'description': description,
        'serviceType': {'code': serviceTypeCode, 'name': serviceTypeName},
        'costCenter': costCenter?.toJson(),
        'elevators': elevators.map((e) => e.toJson()).toList(),
        'startedAt': startedAt,
      };
}

enum ElevatorFinalStatus { operative, outOfService, uncompletedMaintenance }

extension ElevatorFinalStatusApi on ElevatorFinalStatus {
  String get api => switch (this) {
        ElevatorFinalStatus.operative => 'OPERATIVE',
        ElevatorFinalStatus.outOfService => 'OUT_OF_SERVICE',
        ElevatorFinalStatus.uncompletedMaintenance => 'UNCOMPLETED_MAINTENANCE',
      };
  String get label => switch (this) {
        ElevatorFinalStatus.operative => 'Operativo',
        ElevatorFinalStatus.outOfService => 'Fuera de servicio',
        ElevatorFinalStatus.uncompletedMaintenance => 'Mantenimiento no culminado',
      };
}

/// Resultado estándar de las acciones (`ActionState` del backend).
class ActionResult {
  final bool success;
  final String? message;

  const ActionResult(this.success, [this.message]);

  factory ActionResult.fromJson(Map<String, dynamic> j) => ActionResult(
        j['success'] == true,
        (j['message'] ?? j['error']) as String?,
      );
}
