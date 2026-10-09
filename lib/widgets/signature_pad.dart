import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hand_signature/signature.dart';

/// Controlador de la firma: une los puntos con curvas suavizadas en lugar de
/// segmentos rectos (`lineTo`), que hacían que el trazo se viera quebrado.
HandSignatureControl createSignatureControl() => HandSignatureControl(
      initialSetup: const SignaturePathSetup(
        threshold: 3.0,
        smoothRatio: 0.65,
        velocityRange: 2.0,
      ),
    );

/// Trazo tipo tinta: más fino al ir rápido y más grueso al ir lento.
const _inkDrawer = ShapeSignatureDrawer(color: Colors.black, width: 1.5, maxWidth: 5.0);

/// Recuadro donde el cliente firma.
///
/// [onActiveChanged] avisa cuando un dedo está sobre el recuadro: la pantalla
/// debe desactivar su scroll mientras tanto, porque el reconocedor de
/// hand_signature no reclama el gesto y un trazo vertical desplazaría la
/// página cortando la firma.
class SignaturePad extends StatelessWidget {
  const SignaturePad({super.key, required this.control, this.height = 200, this.onActiveChanged});
  final HandSignatureControl control;
  final double height;
  final ValueChanged<bool>? onActiveChanged;

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => onActiveChanged?.call(true),
        onPointerUp: (_) => onActiveChanged?.call(false),
        onPointerCancel: (_) => onActiveChanged?.call(false),
        child: SizedBox(
          height: height,
          child: ColoredBox(
            color: Colors.white,
            child: HandSignature(control: control, drawer: _inkDrawer),
          ),
        ),
      );
}

/// Exporta la firma como PNG sobre fondo blanco, ajustada al lienzo, para
/// guardarla en la OT. Devuelve null si no hay trazos.
Future<Uint8List?> exportSignaturePng(HandSignatureControl control) async {
  if (!control.isFilled) return null;
  final data = await control.toImage(
    width: 800,
    height: 400,
    color: Colors.black,
    background: Colors.white,
    drawer: _inkDrawer,
    border: 24,
    fit: true,
  );
  return data?.buffer.asUint8List();
}
