import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

class WorkOrdersScreen extends ConsumerWidget {
  const WorkOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final orders = ref.watch(workOrdersProvider);
    final pending = ref.watch(pendingSyncProvider).value ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Mis órdenes'),
          if (user != null)
            Text(user.fullName, style: Theme.of(context).textTheme.bodySmall),
        ]),
        actions: [
          if (pending > 0)
            Tooltip(
              message: '$pending cambios por sincronizar',
              child: Badge(
                label: Text('$pending'),
                child: const Padding(
                    padding: EdgeInsets.all(8), child: Icon(Icons.cloud_upload_outlined)),
              ),
            ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(workOrdersProvider.future),
        child: asyncView(
          orders,
          (list) => list.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No tienes órdenes asignadas.')),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _WorkOrderCard(list[i]),
                ),
          onRetry: () => ref.invalidate(workOrdersProvider),
        ),
      ),
    );
  }
}

class _WorkOrderCard extends StatelessWidget {
  const _WorkOrderCard(this.o);
  final WorkOrderSummary o;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/ot/${o.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(o.otNumber, style: t.titleMedium),
              const Spacer(),
              if (o.priority == 'HIGH' || o.priority == 'URGENT')
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.priority_high, color: Colors.red, size: 20),
                ),
              StatusChip(o.status),
            ]),
            const SizedBox(height: 8),
            Text(o.costCenterName, style: t.titleSmall),
            if (o.costCenterAddress != null) Text(o.costCenterAddress!, style: t.bodySmall),
            const SizedBox(height: 8),
            Wrap(spacing: 16, children: [
              _Info(Icons.schedule,
                  [o.scheduledDate, o.scheduledTime].whereType<String>().join(' · ')),
              _Info(Icons.elevator, '${o.equipmentCount} equipo(s)'),
              if (o.serviceTypeName != null) _Info(Icons.build, o.serviceTypeName!),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ]);
}
