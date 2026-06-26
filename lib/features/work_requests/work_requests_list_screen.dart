import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../billing/entitlement_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/heevy_ui.dart';
import '../../widgets/team_scope_tabs.dart';
import '../capture/quick_capture_screen.dart';
import 'create_work_request_screen.dart';
import 'work_request_detail_screen.dart';
import 'work_request_service.dart';

class WorkRequestsListScreen extends StatefulWidget {
  const WorkRequestsListScreen({super.key, this.entitlement});

  final EntitlementResult? entitlement;

  @override
  State<WorkRequestsListScreen> createState() => _WorkRequestsListScreenState();
}

class _WorkRequestsListScreenState extends State<WorkRequestsListScreen> {
  late Future<Map<String, dynamic>> _future;
  String _scope = 'mine';

  bool get _showTeamTab => widget.entitlement?.isOrgManager == true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = WorkRequestService(Supabase.instance.client)
        .listWorkRequestsMeta(scope: _scope);
  }

  Future<void> _refresh() async {
    final f = WorkRequestService(Supabase.instance.client)
        .listWorkRequestsMeta(scope: _scope);
    setState(() => _future = f);
    await f;
  }

  void _setScope(String scope) {
    if (_scope == scope) return;
    setState(() {
      _scope = scope;
      _reload();
    });
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateWorkRequestScreen()),
    );
    if (created == true && mounted) await _refresh();
  }

  Future<void> _openQuickCapture() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QuickCaptureScreen()),
    );
    if (mounted) await _refresh();
  }

  String _statusLabel(String? status) {
    final s = (status ?? '').toLowerCase();
    if (s == 'draft') return 'Draft';
    if (s == 'open') return 'Open';
    if (s == 'pending approval') return 'Pending approval';
    return status ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: HeevyBrandedAppBar(
        title: _scope == 'team' ? 'Team work requests' : 'Work requests',
        actions: [
          if (_scope == 'mine')
            IconButton(
              tooltip: 'New work request',
              onPressed: _openCreate,
              icon: Icon(Icons.add, color: AppColors.textMuted(context)),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showTeamTab)
            TeamScopeTabs(
              scope: _scope,
              onScopeChanged: _setScope,
              teamLabel: 'Site team',
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.text(context),
              backgroundColor: AppColors.surface(context),
              child: FutureBuilder<Map<String, dynamic>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.35,
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
                          title: 'Could not load work requests',
                          subtitle: snapshot.error.toString(),
                        ),
                      ],
                    );
                  }
                  final meta = snapshot.data ?? {};
                  final items = meta['items'] is List
                      ? List<Map<String, dynamic>>.from(meta['items'] as List)
                      : <Map<String, dynamic>>[];
                  if (items.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      children: [
                        const SizedBox(height: 40),
                        HeevyEmptyState(
                          icon: Icons.assignment_outlined,
                          title: _scope == 'team'
                              ? 'No team work requests'
                              : 'No work requests yet',
                          subtitle: _scope == 'team'
                              ? 'Crew submissions appear here when they log defects or create requests.'
                              : 'Create a draft request for your site, or use Quick capture with photos.',
                        ),
                        if (_scope == 'mine') ...[
                          const SizedBox(height: 24),
                          HeevyPrimaryButton(
                            label: 'New work request',
                            onTap: _openCreate,
                          ),
                          const SizedBox(height: 10),
                          HeevySecondaryButton(
                            label: 'Or use Quick capture',
                            onTap: _openQuickCapture,
                          ),
                        ],
                      ],
                    );
                  }
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final row = items[i];
                      final title =
                          row['work_title']?.toString() ?? 'Work request';
                      final num = row['wr_number']?.toString() ?? '';
                      final status = _statusLabel(row['status']?.toString());
                      final location =
                          row['functional_location']?.toString() ?? '';
                      final creator =
                          row['created_by_name']?.toString() ?? '';
                      final subtitle = [
                        if (num.isNotEmpty) num,
                        status,
                        if (_scope == 'team' && creator.isNotEmpty) creator,
                        location,
                      ].where((s) => s.isNotEmpty).join(' · ');
                      return HeevyListTile(
                        icon: Icons.assignment_outlined,
                        title: title,
                        subtitle: subtitle,
                        onTap: () {
                          final id = row['id']?.toString();
                          if (id == null) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  WorkRequestDetailScreen(workRequestId: id),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
