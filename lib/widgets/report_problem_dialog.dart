import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../data/models.dart';
import 'common.dart';

/// Administrador al que se reporta un mantenimiento sin culminar (el mismo
/// contacto que usa el portal web del técnico).
const _adminName = 'Henrry';
const _adminPhone = '+51963207058';
const _adminPhoneLabel = '+51 963 207 058';

/// Igual que el popup del portal web: al marcar un equipo como
/// "Mantenimiento no culminado", pide contactar a Henrry para coordinar una
/// visita de emergencia, con el mensaje listo para copiar o la llamada.
Future<void> showReportProblemDialog(
  BuildContext context, {
  required Elevator elevator,
  required String? clientName,
}) {
  final message = 'Hola $_adminName, tengo un problema en el equipo ${elevator.displayName}'
      '${clientName == null ? '' : ' del cliente $clientName'}. Se marcó como mantenimiento '
      'sin culminar. Necesito coordinar una visita de emergencia.';

  return showDialog<void>(
    context: context,
    builder: (c) {
      final colors = AppColors.of(c);
      return Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Row(children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.amberText),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Reportar problema al administrador',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.amberText)),
                ),
              ]),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(style: TextStyle(fontSize: 13, color: colors.mutedForeground), children: [
                  const TextSpan(text: 'El equipo '),
                  TextSpan(
                    text: elevator.displayName,
                    style: TextStyle(fontWeight: FontWeight.w700, color: colors.foreground),
                  ),
                  const TextSpan(text: ' se marcó como "Mantenimiento sin culminar".'),
                ]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.10),
                  border: Border.all(color: AppColors.amber.withValues(alpha: 0.30)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Por favor, contacta a $_adminName para reportar la situación y coordinar una '
                  'visita de emergencia.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: colors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  Icon(Icons.phone_outlined, size: 18, color: AppColors.link(c)),
                  const SizedBox(width: 8),
                  const Text(_adminPhoneLabel, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                icon: const Icon(Icons.phone, size: 20),
                label: const Text('Llamar a $_adminName'),
                onPressed: () async {
                  final ok = await launchUrl(Uri(scheme: 'tel', path: _adminPhone));
                  if (!ok && c.mounted) {
                    showResult(c, const ActionResult(false, 'No se pudo abrir el teléfono. Marca $_adminPhoneLabel.'));
                  }
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copiar mensaje'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: message));
                  if (c.mounted) {
                    showResult(c, const ActionResult(true, 'Mensaje copiado. Pégalo en WhatsApp o llámalo.'));
                  }
                },
              ),
              const SizedBox(height: 4),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  foregroundColor: colors.mutedForeground,
                ),
                onPressed: () => Navigator.pop(c),
                child: const Text('Cerrar'),
              ),
            ]),
          ),
        ),
      );
    },
  );
}
