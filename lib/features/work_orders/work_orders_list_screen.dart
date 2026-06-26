import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../billing/entitlement_service.dart';
import '../../billing/upgrade_cta_policy.dart';
import '../../theme/app_colors.dart';
import '../../widgets/heevy_ui.dart';
import 'create_work_order_screen.dart';
import 'work_order_detail_screen.dart';
import 'work_order_service.dart';

class WorkOrdersListScreen extends StatefulWidget {
  const WorkOrdersListScreen({super.key, this.entitlement});

  final EntitlementResult? entitlement;

  @override
  State<WorkOrdersListScreen> createState() => _WorkOrdersListScreenState();
}

class _WorkOrdersListScreenState extends State<WorkOrdersListScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = WorkOrderService(Supabase.instance.client).listWorkOrders();
  }

  Future<void> _refresh() async {
    final f = WorkOrderService(Supabase.instance.client).listWorkOrders();
    setState(() => _future = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    final entitlement = widget.entitlement;
    final canCreate = entitlement != null &&
        UpgradeCtaPolicy.canCreateWorkOrderOnMobile(
          isOrgManager: entitlement.isOrgManager,
          allowsPlant: entitlement.allowsPlant,
        );

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: HeevyBrandedAppBar(
        title: 'Work orders',
        actions: [
          if (canCreate)
            IconButton(
              tooltip: 'Create',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateWorkOrderScreen()),
                );
                await _refresh();
              },
              icon: Icon(Icons.add, color: AppColors.textMuted(context)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.text(context),
        backgroundColor: AppColors.surface(context),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.4,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.textMuted(context),
                        strokeWidth: 2.2,
                      ),
                    ),
                  ),
                ],
              );
            }
            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 80),
                  HeevyEmptyState(
                    icon: Icons.error_outline,
                    title: 'Could not load work orders',
                    subtitle: snapshot.error.toString(),
                  ),
                ],
              );
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 80),
                  HeevyEmptyState(
                    icon: Icons.build_outlined,
                    title: 'No work orders yet',
                    subtitle: canCreate
                        ? 'Create one from an approved request or tap + above.'
                        : 'Work orders appear here after supervisor approval on web.',
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final row = items[i];
                final title = row['title']?.toString() ?? 'Work order';
                final status = row['status']?.toString() ?? '';
                final num = row['work_order_number']?.toString() ?? '';
                final subtitle = [
                  if (num.isNotEmpty) num,
                  status,
                  row['priority']?.toString() ?? '',
                ].where((s) => s.isNotEmpty).join(' · ');
                return HeevyListTile(
                  icon: Icons.build_outlined,
                  title: title,
                  subtitle: subtitle,
                  onTap: () {
                    final id = row['id']?.toString();
                    if (id == null) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => WorkOrderDetailScreen(workOrderId: id, entitlement: widget.entitlement),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateWorkOrderScreen()),
                );
                await _refresh();
              },
              backgroundColor: AppColors.text(context),
              child: Icon(Icons.add, color: AppColors.bg(context)),
            )
          : null,
    );
  }
}
