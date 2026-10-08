/// Configuración por `--dart-define`.
///
/// Ejemplos:
///   flutter run                                  (next dev local, desde el emulador)
///   flutter run --dart-define=API_BASE_URL=https://tu-dominio
///   flutter run --dart-define=USE_MOCK=true      (demostración, sin servidor)
class AppConfig {
  /// URL base del backend Next.js. Los endpoints viven en `/api/mobile/v1`.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  /// Por defecto la app habla con el backend real. `USE_MOCK=true` la
  /// arranca con datos de demostración en memoria, sin servidor.
  static const useMock = bool.fromEnvironment('USE_MOCK', defaultValue: false);

  static String get apiPrefix => '$apiBaseUrl/api/mobile/v1';
}
