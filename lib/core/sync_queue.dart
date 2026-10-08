import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'api_client.dart';

/// Mutación pendiente de envío. Equivalente móvil del `pending-actions`
/// de IndexedDB que usa la web (`src/features/technician/lib/sync-client.ts`).
class PendingMutation {
  final String id;
  final String workOrderId;
  final String method;
  final String path;
  final Map<String, dynamic>? body;

  /// Para subidas multipart (fotos y audios): campo -> ruta local.
  final Map<String, String>? files;
  int attempts;

  PendingMutation({
    required this.id,
    required this.workOrderId,
    required this.method,
    required this.path,
    this.body,
    this.files,
    this.attempts = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'workOrderId': workOrderId,
        'method': method,
        'path': path,
        'body': body,
        'files': files,
        'attempts': attempts,
      };

  factory PendingMutation.fromJson(Map<String, dynamic> j) => PendingMutation(
        id: j['id'] as String,
        workOrderId: j['workOrderId'] as String? ?? '',
        method: j['method'] as String,
        path: j['path'] as String,
        body: (j['body'] as Map?)?.cast<String, dynamic>(),
        files: (j['files'] as Map?)?.cast<String, String>(),
        attempts: (j['attempts'] as num?)?.toInt() ?? 0,
      );
}

/// Cola persistente en disco. Toda escritura del técnico entra aquí y la
/// pantalla no espera al servidor: el cambio ya se ve aplicado y la cola
/// lo envía en segundo plano, en orden, cuando hay señal.
///
/// - Sin señal o error 5xx: se reintenta con espera exponencial y en cada
///   cambio de conectividad.
/// - 401: sesión vencida; se detiene hasta que el técnico vuelva a entrar.
/// - Otros 4xx (validación): se descarta para no bloquear la cola, igual
///   que en la web.
class SyncQueue {
  final ApiClient api;
  final List<PendingMutation> _items = [];
  final _controller = StreamController<int>.broadcast();
  StreamSubscription? _connSub;
  Timer? _retry;
  bool _flushing = false;
  String? _inFlightId;
  File? _file;

  SyncQueue(this.api);

  Stream<int> get pendingCount async* {
    yield _items.length;
    yield* _controller.stream;
  }

  int get length => _items.length;

  bool hasPendingFor(String workOrderId) =>
      _items.any((m) => m.workOrderId == workOrderId);

  Future<void> init() async {
    final dir = await getApplicationSupportDirectory();
    _file = File('${dir.path}/sync_queue.json');
    if (await _file!.exists()) {
      final raw = jsonDecode(await _file!.readAsString()) as List;
      _items.addAll(
          raw.map((e) => PendingMutation.fromJson(e as Map<String, dynamic>)));
    }
    _controller.add(_items.length);
    _connSub = Connectivity().onConnectivityChanged.listen((r) {
      if (!r.contains(ConnectivityResult.none)) flush();
    });
    unawaited(flush());
  }

  Future<void> _persist() async {
    await _file?.writeAsString(jsonEncode(_items.map((e) => e.toJson()).toList()));
    _controller.add(_items.length);
  }

  /// Encola y vuelve de inmediato; el envío ocurre en segundo plano.
  Future<void> enqueue(PendingMutation m) async {
    _items.add(m);
    await _persist();
    unawaited(flush());
  }

  /// Quita una mutación que aún no se envió (p. ej. borrar una foto que
  /// todavía no se subió). Devuelve `true` si estaba en cola.
  Future<bool> cancel(String id) async {
    final idx = _items.indexWhere((m) => m.id == id);
    if (idx < 0 || _items[idx].id == _inFlightId) return false;
    final m = _items.removeAt(idx);
    await _deleteFiles(m);
    await _persist();
    return true;
  }

  Future<void> _deleteFiles(PendingMutation m) async {
    for (final path in m.files?.values ?? const <String>[]) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  Future<Response> _execute(PendingMutation m) async {
    final options = Options(method: m.method, headers: {'Idempotency-Key': m.id});
    if (m.files != null && m.files!.isNotEmpty) {
      final form = FormData.fromMap({
        for (final e in (m.body ?? const {}).entries)
          if (e.value != null) e.key: e.value is String ? e.value : jsonEncode(e.value),
        for (final e in m.files!.entries) e.key: await MultipartFile.fromFile(e.value),
      });
      return api.dio.request(m.path, data: form, options: options);
    }
    return api.dio.request(m.path, data: m.body ?? const {}, options: options);
  }

  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    _retry?.cancel();
    try {
      while (_items.isNotEmpty) {
        final m = _items.first;
        _inFlightId = m.id;
        try {
          await _execute(m);
          // Los archivos locales se conservan: la caché los sigue mostrando
          // sin descargarlos de R2.
          _items.removeAt(0);
          await _persist();
        } catch (e) {
          final status = e is DioException ? e.response?.statusCode : null;
          if (status == 401) return;
          if (isNetworkError(e) || (status != null && status >= 500)) {
            m.attempts++;
            await _persist();
            final wait = Duration(seconds: 1 << m.attempts.clamp(1, 7));
            _retry = Timer(wait, flush);
            return;
          }
          _items.removeAt(0);
          await _persist();
        }
      }
    } finally {
      _inFlightId = null;
      _flushing = false;
    }
  }

  void dispose() {
    _retry?.cancel();
    _connSub?.cancel();
    _controller.close();
  }
}
