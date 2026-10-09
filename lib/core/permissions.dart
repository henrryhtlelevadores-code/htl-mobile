import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Pide de una vez, al entrar, los permisos que usa el trabajo de campo, para
/// que no aparezcan en mitad de una orden:
///
/// - cámara: fotos de evidencia;
/// - micrófono: notas de voz;
/// - ubicación: se registra al aprobar el checklist de seguridad;
/// - fotos (solo iOS): elegir de la galería. En Android la galería usa el
///   selector del sistema, que no necesita permiso.
///
/// Los ya concedidos o rechazados no se vuelven a preguntar (el sistema no
/// lo permite); cada función sigue comprobando su permiso al usarse.
class StartupPermissions {
  static bool _asked = false;

  static Future<void> request() async {
    if (_asked) return;
    _asked = true;
    final wanted = <Permission>[
      Permission.camera,
      Permission.microphone,
      Permission.locationWhenInUse,
      if (Platform.isIOS) Permission.photos,
    ];
    try {
      final pending = <Permission>[
        for (final p in wanted)
          if (await p.status.isDenied) p,
      ];
      if (pending.isNotEmpty) await pending.request();
    } catch (_) {
      // Sin el plugin (pruebas) o sin soporte: cada función pedirá el suyo.
    }
  }
}
