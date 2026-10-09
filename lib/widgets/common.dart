import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../core/theme_mode.dart';
import '../data/models.dart';

void showResult(BuildContext context, ActionResult r, {String? fallback}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Text(r.message ?? fallback ?? (r.success ? 'Listo' : 'Error')),
    backgroundColor: r.success ? null : Theme.of(context).colorScheme.error,
  ));
}

void showError(BuildContext context, Object e) {
  showResult(context, ActionResult(false, e.toString().replaceFirst('Exception: ', '')));
}

/// Etiqueta redondeada como las del portal web: fondo suave, borde y texto
/// en mayúsculas.
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, required this.color, this.textColor});
  final String label;
  final Color color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = textColor ?? color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.16 : 0.10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: dark ? Color.lerp(fg, Colors.white, 0.35) : fg,
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String? status;

  static const _labels = {
    'PENDING': 'Pendiente',
    'IN_PROGRESS': 'En curso',
    'PAUSED': 'Pausada',
    'COMPLETED': 'Completada',
    'CANCELLED': 'Cancelada',
  };

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.of(context).mutedForeground;
    final (color, text) = switch (status) {
      'IN_PROGRESS' => (AppColors.primary, AppColors.primary),
      'PAUSED' => (AppColors.violetText, AppColors.violetText),
      'COMPLETED' => (AppColors.emerald, AppColors.emeraldText),
      'CANCELLED' => (muted, muted),
      _ => (AppColors.amber, AppColors.amberText),
    };
    return Pill(_labels[status] ?? 'Pendiente', color: color, textColor: text);
  }
}

/// Tipo de servicio, con el mismo código de color que la franja de la tarjeta.
enum ServiceKind {
  preventive(AppColors.emerald, AppColors.emeraldText),
  corrective(AppColors.amber, AppColors.amberText),
  emergency(AppColors.red, AppColors.redText);

  const ServiceKind(this.color, this.textColor);
  final Color color;
  final Color textColor;

  static ServiceKind of(String? code) {
    final c = (code ?? '').toUpperCase();
    if (c.startsWith('EMER')) return ServiceKind.emergency;
    if (c == 'PREV') return ServiceKind.preventive;
    return ServiceKind.corrective;
  }
}

class ServiceTypeChip extends StatelessWidget {
  const ServiceTypeChip({super.key, required this.code, required this.name});
  final String? code;
  final String name;

  @override
  Widget build(BuildContext context) {
    final kind = ServiceKind.of(code);
    return Pill(name, color: kind.color, textColor: kind.textColor);
  }
}

/// Logo pequeño de Fortex para el encabezado, en el color del tema.
class FortexMark extends StatelessWidget {
  const FortexMark({super.key, this.width = 58});
  final double width;

  @override
  Widget build(BuildContext context) => Image.asset(
        Theme.of(context).brightness == Brightness.dark
            ? 'assets/images/fortex-blanco.png'
            : 'assets/images/fortex-azul.png',
        width: width,
        semanticLabel: 'Fortex Business Solutions',
      );
}

/// "Creado por Fortex Business Solutions", discreto, con el logo del color
/// que corresponde al tema (azul en claro, blanco en oscuro).
class FortexCredit extends StatelessWidget {
  const FortexCredit({super.key, this.logoWidth = 84});
  final double logoWidth;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = AppColors.of(context).mutedForeground;
    return Opacity(
      opacity: 0.75,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Creado por', style: TextStyle(fontSize: 10, color: muted, letterSpacing: 0.3)),
        const SizedBox(height: 4),
        Image.asset(
          dark ? 'assets/images/fortex-blanco.png' : 'assets/images/fortex-azul.png',
          width: logoWidth,
          semanticLabel: 'Fortex Business Solutions',
        ),
      ]),
    );
  }
}

/// Botón sol/luna para alternar el tema, como en el portal web.
class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    return IconButton(
      tooltip: brightness == Brightness.dark ? 'Tema claro' : 'Tema oscuro',
      color: AppColors.of(context).mutedForeground,
      icon: Icon(brightness == Brightness.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () => ref.read(themeModeProvider.notifier).toggle(brightness),
    );
  }
}

/// Título de sección en mayúsculas pequeñas.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 8, top: 4),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AppColors.of(context).mutedForeground,
          ),
        ),
      );
}

/// Fila de icono + texto secundario.
class InfoRow extends StatelessWidget {
  const InfoRow(this.icon, this.text, {super.key, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final muted = color ?? AppColors.of(context).mutedForeground;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Icon(icon, size: 15, color: muted),
      ),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: muted))),
    ]);
  }
}

/// Pinta un `AsyncValue` con estados de carga y error estándar.
Widget asyncView<T>(AsyncValue<T> value, Widget Function(T) data,
    {VoidCallback? onRetry}) {
  return value.when(
    data: data,
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (e, _) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off, size: 48),
          const SizedBox(height: 12),
          Text('$e', textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ]),
      ),
    ),
  );
}
