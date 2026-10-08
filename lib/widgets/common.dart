import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String? status;

  static const _labels = {
    'PENDING': 'Pendiente',
    'IN_PROGRESS': 'En curso',
    'COMPLETED': 'Completada',
    'CANCELLED': 'Cancelada',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = switch (status) {
      'IN_PROGRESS' => Colors.orange,
      'COMPLETED' => Colors.green,
      'CANCELLED' => cs.outline,
      _ => cs.primary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(_labels[status] ?? 'Pendiente',
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
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
