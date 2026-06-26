import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../billing/entitlement_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/heevy_ui.dart';
import '../../widgets/history_card.dart';
import '../../widgets/solo_submitter_banner.dart';
import '../../widgets/team_scope_tabs.dart';
import '../capture/quick_capture_screen.dart';
import 'create_work_request_screen.dart';
import 'work_request_detail_screen.dart';
import 'work_request_service.dart';

enum TeamWrFilter { submitted, drafts, all }

class WorkRequestsListScreen extends StatefulWidget {
  const WorkRequestsListScreen({
    super.key,
    this.entitlement,
    this.initialScope,
    this.initialTeamFilter,
  });

  final EntitlementResult? entitlement;
  final String? initialScope;
  final TeamWrFilter? initialTeamFilter;

  @override
  State<WorkRequestsListScreen> createState() => _WorkRequestsListScreenState();
}

class _WorkRequestsListScreenState extends State<WorkRequestsListScreen> {
  late Future<Map<String, dynamic>> _future;
  Future<List<Map<String, dynamic>>>? _teamItemsFuture;
  late String _scope;
  TeamWrFilter _teamFilter = TeamWrFilter.submitted;
  String? _priorityFilter;

  bool get _showTeamTab => widget.entitlement?.isOrgManager == true;

  @override
  void initState() {
    super.initState();
    _scope = widget.initialScope ?? 'mine';
    _teamFilter = widget.initialTeamFilter ?? TeamWrFilter.submitted;
    if (_showTeamTab) {
      _teamItemsFuture = WorkRequestService(Supabase.instance.client)
          .listWorkRequests(scope: 'team');
    }
    _reload();
  }

  void _reload() {
    _future = WorkRequestService(Supabase.instance.client)
        .listWorkRequestsMeta(scope: _scope);
  }

  Future<void> _refresh() async {
    final f = WorkRequestService(Supabase.instance.client)
        .listWorkRequestsMeta(scope: _scope);
    final teamF = _showTeamTab
        ? WorkRequestService(Supabase.instance.client)
            .listWorkRequests(scope: 'team')
        : null;
    setState(() {
      _future = f;
      if (teamF != null) _teamItemsFuture = teamF;
    });
    await f;
    if (teamF != null) await teamF;
  }

  void _setScope(String scope) {
    if (_scope == scope) return;
    setState(() {
      _scope = scope;
      if (scope == 'team') {
        _teamFilter = TeamWrFilter.submitted;
      }
      _reload();
    });
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> items) {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    return items.where((row) {
      final status = (row['status']?.toString() ?? '').toLowerCase();
      final isDraft = status == 'draft';
      final createdBy = row['created_by']?.toString();
      final isOwn = createdBy != null && createdBy == uid;

      if (_scope == 'team') {
        switch (_teamFilter) {
          case TeamWrFilter.submitted:
            if (isDraft) return false;
            break;
          case TeamWrFilter.drafts:
            if (!isDraft || isOwn) return false;
            break;
          case TeamWrFilter.all:
            break;
        }
      }

      if (_priorityFilter != null && _priorityFilter!.isNotEmpty) {
        final p = (row['priority']?.toString() ?? '').toLowerCase();
        final needle = _priorityFilter!.toLowerCase();
        if (!p.contains(needle)) return false;
      }

      return true;
    }).toList();
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

  Widget _soloBanner() {
    if (!_showTeamTab || _teamItemsFuture == null) {
      return const SizedBox.shrink();
    }
    final uid = Supabase.instance.client.auth.currentUser?.id;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _teamItemsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        if (!isSoloSubmitterOnSite(snapshot.data!, uid)) {
          return const SizedBox.shrink();
        }
        return const SoloSubmitterBanner();
      },
    );
  }

  Widget _teamFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilterChip(
            label: const Text('Submitted'),
            selected: _teamFilter == TeamWrFilter.submitted,
            onSelected: (_) => setState(() => _teamFilter = TeamWrFilter.submitted),
          ),
          FilterChip(
            label: const Text('Crew drafts'),
            selected: _teamFilter == TeamWrFilter.drafts,
            onSelected: (_) => setState(() => _teamFilter = TeamWrFilter.drafts),
          ),
          FilterChip(
            label: const Text('All'),
            selected: _teamFilter == TeamWrFilter.all,
            onSelected: (_) => setState(() => _teamFilter = TeamWrFilter.all),
          ),
          DropdownButton<String?>(
            value: _priorityFilter,
            hint: Text(
              'Priority',
              style: TextStyle(color: AppColors.textMuted(context), fontSize: 13),
            ),
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: null, child: Text('All priorities')),
              DropdownMenuItem(value: 'p1', child: Text('P1')),
              DropdownMenuItem(value: 'p2', child: Text('P2')),
              DropdownMenuItem(value: 'p3', child: Text('P3')),
              DropdownMenuItem(value: 'p4', child: Text('P4')),
            ],
            onChanged: (v) => setState(() => _priorityFilter = v),
          ),
        ],
      ),
    );
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
          _soloBanner(),
          if (_scope == 'team') _teamFilterBar(),
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
                  final rawItems = meta['items'] is List
                      ? List<Map<String, dynamic>>.from(meta['items'] as List)
                      : <Map<String, dynamic>>[];
                  final items = _applyFilters(rawItems);
                  if (items.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      children: [
                        const SizedBox(height: 40),
                        HeevyEmptyState(
                          icon: Icons.assignment_outlined,
                          title: _scope == 'team'
                              ? 'No matching team requests'
                              : 'No work requests yet',
                          subtitle: _scope == 'team'
                              ? _teamFilter == TeamWrFilter.drafts
                                  ? 'No crew drafts waiting — switch to Submitted to see the site queue.'
                                  : 'Crew submissions appear here after they submit to the site queue.'
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
                      final priority = row['priority']?.toString() ?? '';
                      final creator =
                          row['created_by_name']?.toString() ?? '';
                      final created = row['created_at']?.toString() ?? '';
                      final lines = <HistoryCardLine>[
                        if (status.isNotEmpty) HistoryCardLine(status),
                        if (num.isNotEmpty)
                          HistoryCardLine(num, style: HistoryCardLineStyle.faint),
                        if (priority.isNotEmpty) HistoryCardLine(priority),
                        if (location.isNotEmpty)
                          HistoryCardLine(location, style: HistoryCardLineStyle.faint),
                        if (_scope == 'team' && creator.isNotEmpty)
                          HistoryCardLine(creator, style: HistoryCardLineStyle.faint),
                        if (created.isNotEmpty)
                          HistoryCardLine(
                            formatHistoryDate(created),
                            style: HistoryCardLineStyle.date,
                          ),
                      ];
                      return HistoryCard(
                        icon: Icons.assignment_outlined,
                        title: title,
                        lines: lines,
                        onTap: () {
                          final id = row['id']?.toString();
                          if (id == null) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  WorkRequestDetailScreen(
                                  workRequestId: id,
                                  entitlement: widget.entitlement,
                                ),
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
