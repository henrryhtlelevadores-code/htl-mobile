import 'package:dio/dio.dart';

import 'config.dart';
import 'session_store.dart';

/// Cliente HTTP con `Authorization: Bearer <token>`.
class ApiClient {
  final SessionStore session;
  final Dio dio;
  void Function()? onUnauthorized;

  ApiClient(this.session)
      : dio = Dio(BaseOptions(
          baseUrl: AppConfig.apiPrefix,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 60),
          contentType: Headers.jsonContentType,
        )) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await session.token();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (e, handler) {
        if (e.response?.statusCode == 401) onUnauthorized?.call();
        handler.next(e);
      },
    ));
  }
}

/// Error de red (sin respuesta del servidor): la mutación se encola.
bool isNetworkError(Object e) =>
    e is DioException &&
    e.response == null &&
    e.type != DioExceptionType.cancel &&
    e.type != DioExceptionType.badCertificate;
