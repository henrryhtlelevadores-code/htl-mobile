import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/models.dart';

/// Guarda el token Bearer que entrega `POST /auth/login` (7 días, renovable
/// con `POST /auth/refresh`) en el almacenamiento seguro del dispositivo.
class SessionStore {
  static const _tokenKey = 'htl_token';
  static const _userKey = 'htl_user';
  final _storage = const FlutterSecureStorage();

  Future<void> save(String token, TechnicianUser user) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
  }

  Future<String?> token() => _storage.read(key: _tokenKey);

  Future<TechnicianUser?> user() async {
    final raw = await _storage.read(key: _userKey);
    if (raw == null) return null;
    return TechnicianUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// El token expira a los 7 días; lo validamos localmente para no
  /// mostrar la app con una sesión vencida.
  ///
  /// Formato del backend: `v2.mobile.<userId>.<version>.<exp>.<firma>`, con
  /// `exp` en segundos. Un token con otro formato (p. ej. el antiguo de tres
  /// partes) se considera inválido y obliga a iniciar sesión de nuevo.
  Future<bool> hasValidToken() async {
    final t = await token();
    if (t == null) return false;
    final parts = t.split('.');
    if (parts.length != 6 || parts[0] != 'v2' || parts[1] != 'mobile') {
      return false;
    }
    final exp = int.tryParse(parts[4]);
    if (exp == null) return false;
    return DateTime.now().millisecondsSinceEpoch < exp * 1000;
  }

  /// Reemplaza solo el token (renovación), conservando el usuario guardado.
  Future<void> replaceToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }
}
