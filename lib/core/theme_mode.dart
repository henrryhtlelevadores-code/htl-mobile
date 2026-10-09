import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tema claro u oscuro elegido por el técnico. Como en el portal web, por
/// defecto sigue al sistema y el botón de la barra lo alterna.
class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'htl_theme_mode';
  final _storage = const FlutterSecureStorage();

  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    try {
      final saved = await _storage.read(key: _key);
      final mode = ThemeMode.values.where((m) => m.name == saved).firstOrNull;
      if (mode != null) state = mode;
    } catch (_) {
      // Sin preferencia guardada: se queda el del sistema.
    }
  }

  /// Pasa al tema contrario del que se ve ahora.
  Future<void> toggle(Brightness current) async {
    state = current == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    try {
      await _storage.write(key: _key, value: state.name);
    } catch (_) {}
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
