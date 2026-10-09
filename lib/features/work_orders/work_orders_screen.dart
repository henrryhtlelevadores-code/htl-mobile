import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/permissions.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

const _active = {'IN_PROGRESS', 'PAUSED'};
const _closed = {'COMPLETED', 'CANCELLED'};

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class WorkOrdersScreen extends ConsumerStatefulWidget {
  const WorkOrdersScreen({super.key});

  @override
  ConsumerState<WorkOrdersScreen> createState() => _WorkOrdersScreenState();
}

class _WorkOrdersScreenState extends ConsumerState<WorkOrdersScreen> {
  /// Día elegido en la tira; `null` = todos. Mientras el técnico no elija,
  /// se usa el día por defecto (hoy, o el próximo con órdenes).
  String? _selected;
  bool _userPicked = false;

  @override
  void initState() {
    super.initState();
    // Permisos de cámara, micrófono y ubicación de una vez, al entrar.
    WidgetsBinding.instance.addPostFrameCallback((_) => StartupPermissions.request());
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    final orders = ref.watch(workOrdersProvider);
    final pending = ref.watch(pendingSyncProvider).value ?? 0;
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(children: [
          const FortexMark(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Técnico de Campo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              if (user != null)
                Text(
                  user.fullName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: colors.mutedForeground),
                ),
            ]),
          ),
        ]),
        actions: [
          if (pending > 0)
            Tooltip(
              message: '$pending cambios por sincronizar',
              child: Badge(
                label: Text('$pending'),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.cloud_upload_outlined, color: colors.mutedForeground),
                ),
              ),
            ),
          const ThemeToggleButton(),
          IconButton(
            tooltip: 'Cerrar sesión',
            color: colors.mutedForeground,
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(workOrdersProvider.future),
        child: asyncView(orders, _buildList, onRetry: () => ref.invalidate(workOrdersProvider)),
      ),
    );
  }

  Widget _buildList(List<WorkOrderSummary> list) {
    final today = _iso(DateTime.now());

    // Órdenes por hacer (ni completadas ni canceladas) por día, para el círculo.
    final counts = <String, int>{};
    for (final o in list) {
      final d = o.scheduledDate;
      if (d == null || _closed.contains(o.status)) continue;
      counts[d] = (counts[d] ?? 0) + 1;
    }

    // Próximos 14 días más cualquier día con órdenes fuera de ese rango
    // (p. ej. una pendiente de ayer).
    final now = DateTime.now();
    final days = <String>{
      for (var i = 0; i < 14; i++) _iso(DateTime(now.year, now.month, now.day + i)),
      ...counts.keys,
    }.toList()
      ..sort();

    final selected = _userPicked
        ? _selected
        : (counts.containsKey(today) ? today : days.where((d) => d.compareTo(today) >= 0 && counts.containsKey(d)).firstOrNull);

    int byTime(WorkOrderSummary a, WorkOrderSummary b) {
      final date = (a.scheduledDate ?? '9999').compareTo(b.scheduledDate ?? '9999');
      if (date != 0) return date;
      return (a.scheduledTime ?? '99:99').compareTo(b.scheduledTime ?? '99:99');
    }

    // En curso: siempre arriba, sea del día que sea.
    final inProgress = list.where((o) => _active.contains(o.status)).toList()..sort(byTime);
    bool onDay(WorkOrderSummary o) => selected == null || o.scheduledDate == selected;
    final todo = list
        .where((o) => !_active.contains(o.status) && !_closed.contains(o.status) && onDay(o))
        .toList()
      ..sort(byTime);
    final done = list.where((o) => o.status == 'COMPLETED' && selected != null && o.scheduledDate == selected).toList()
      ..sort(byTime);

    final colors = AppColors.of(context);
    return ListView(
      padding: listPadding(context, horizontal: 0, top: 0),
      children: [
        const SizedBox(height: 12),
        _DayStrip(
          days: days,
          today: today,
          selected: selected,
          counts: counts,
          onSelect: (d) => setState(() {
            _userPicked = true;
            _selected = d == selected ? null : d;
          }),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (inProgress.isNotEmpty) ...[
              SectionLabel('En curso · ${inProgress.length}'),
              for (final o in inProgress) _WorkOrderCard(o),
              const SizedBox(height: 4),
            ],
            SectionLabel('${selected == null ? 'Todas las pendientes' : _dayLabel(selected, today)} · ${todo.length}'),
            if (todo.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(children: [
                  Icon(Icons.event_available_outlined, size: 40, color: colors.mutedForeground),
                  const SizedBox(height: 8),
                  Text(
                    selected == null ? 'No tienes órdenes pendientes.' : 'Sin órdenes pendientes este día.',
                    style: TextStyle(color: colors.mutedForeground),
                  ),
                ]),
              )
            else
              for (final o in todo) _WorkOrderCard(o),
            if (done.isNotEmpty) ...[
              const SizedBox(height: 4),
              SectionLabel('Completadas · ${done.length}'),
              for (final o in done) _WorkOrderCard(o),
            ],
          ]),
        ),
      ],
    );
  }

  String _dayLabel(String iso, String today) {
    final d = DateTime.parse(iso);
    final now = DateTime.now();
    if (iso == today) return 'Hoy';
    if (iso == _iso(DateTime(now.year, now.month, now.day + 1))) return 'Mañana';
    final label = DateFormat("EEEE d 'de' MMMM", 'es_PE').format(d);
    return label[0].toUpperCase() + label.substring(1);
  }
}

/// Tira horizontal de días (01, 02, 03…) con un círculo en los que tienen
/// órdenes. Tocar un día filtra la lista; tocarlo de nuevo muestra todo.
class _DayStrip extends StatelessWidget {
  const _DayStrip({
    required this.days,
    required this.today,
    required this.selected,
    required this.counts,
    required this.onSelect,
  });
  final List<String> days;
  final String today;
  final String? selected;
  final Map<String, int> counts;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final weekday = DateFormat('EEE', 'es_PE');
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final iso = days[i];
          final date = DateTime.parse(iso);
          final isSelected = iso == selected;
          final isToday = iso == today;
          final isPast = iso.compareTo(today) < 0;
          final count = counts[iso] ?? 0;
          final fg = isSelected ? Colors.white : colors.foreground;
          final sub = isSelected
              ? Colors.white.withValues(alpha: 0.8)
              : isToday
                  ? AppColors.link(context)
                  : colors.mutedForeground;

          return Padding(
            padding: const EdgeInsets.only(top: 6, right: 4),
            child: Stack(clipBehavior: Clip.none, children: [
              Material(
                color: isSelected
                    ? AppColors.primary
                    : isToday
                        ? AppColors.primary.withValues(alpha: 0.06)
                        : colors.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isSelected
                        ? Colors.transparent
                        : isToday
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : colors.border,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onSelect(iso),
                  child: SizedBox(
                    width: 56,
                    child: Opacity(
                      opacity: isPast && !isSelected ? 0.6 : 1,
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(
                          weekday.format(date).replaceAll('.', '').toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: sub),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          date.day.toString().padLeft(2, '0'),
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, height: 1.1, color: fg),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isToday ? 'HOY' : '',
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: sub),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
              if (count > 0)
                Positioned(
                  top: -6,
                  right: -4,
                  child: Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.background, width: 1.5),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? AppColors.primary : Colors.white,
                      ),
                    ),
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }
}

/// Tarjeta igual a la del portal web: franja de color por tipo de servicio,
/// hora y etiquetas arriba, N° de OT en azul y botón de acción al pie.
class _WorkOrderCard extends StatelessWidget {
  const _WorkOrderCard(this.o);
  final WorkOrderSummary o;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final kind = ServiceKind.of(o.serviceTypeCode);
    final status = o.status ?? 'PENDING';
    final done = status == 'COMPLETED';
    final started = _active.contains(status);
    final urgent = o.priority == 'HIGH' || o.priority == 'URGENT';
    void open() => context.push('/ot/${o.id}');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 4, color: kind.color),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              InkWell(
                onTap: open,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.schedule, size: 14, color: colors.mutedForeground),
                      const SizedBox(width: 4),
                      Text(
                        [o.scheduledDate, o.scheduledTime ?? 'Sin hora'].whereType<String>().join(' · '),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.mutedForeground),
                      ),
                      if (urgent) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.priority_high, size: 16, color: AppColors.red),
                      ],
                    ]),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      if (o.serviceTypeName != null)
                        ServiceTypeChip(code: o.serviceTypeCode, name: o.serviceTypeName!),
                      StatusChip(status),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Icon(Icons.assignment_outlined, size: 15, color: AppColors.link(context)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          o.otNumber,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.link(context),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(o.costCenterName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3)),
                    if (o.costCenterAddress != null) ...[
                      const SizedBox(height: 3),
                      InfoRow(Icons.place_outlined, o.costCenterAddress!),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${o.clientName}${o.equipmentCount > 0 ? ' · ${o.equipmentCount} equipo(s)' : ''}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: colors.mutedForeground),
                    ),
                  ]),
                ),
              ),
              Divider(height: 1, color: colors.border),
              Padding(
                padding: const EdgeInsets.all(8),
                child: done
                    ? OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                        onPressed: open,
                        icon: const Icon(Icons.check_circle_outline, size: 20, color: AppColors.emerald),
                        label: const Text('Ver detalle'),
                      )
                    : FilledButton.icon(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                        onPressed: open,
                        icon: Icon(started ? Icons.edit_note : Icons.play_arrow_rounded, size: 20),
                        label: Text(started ? 'Continuar' : 'Iniciar'),
                      ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
