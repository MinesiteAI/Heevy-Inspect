import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../billing/entitlement_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/heevy_ui.dart';
import '../../widgets/history_card.dart';
import '../../widgets/solo_submitter_banner.dart';
import '../../widgets/team_scope_tabs.dart';
import 'capture_detail_screen.dart';
import 'capture_service.dart';

class CaptureHistoryScreen extends StatefulWidget {
  const CaptureHistoryScreen({super.key, this.entitlement});

  final EntitlementResult? entitlement;

  @override
  State<CaptureHistoryScreen> createState() => _CaptureHistoryScreenState();
}

class _CaptureHistoryScreenState extends State<CaptureHistoryScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  Future<List<Map<String, dynamic>>>? _teamItemsFuture;
  String _scope = 'mine';

  bool get _showTeamTab => widget.entitlement?.isOrgManager == true;

  @override
  void initState() {
    super.initState();
    if (_showTeamTab) {
      _teamItemsFuture =
          CaptureService(Supabase.instance.client).listCaptures(scope: 'team');
    }
    _reload();
  }

  void _reload() {
    _future = CaptureService(Supabase.instance.client).listCaptures(scope: _scope);
  }

  Future<void> _refresh() async {
    final f = CaptureService(Supabase.instance.client).listCaptures(scope: _scope);
    final teamF = _showTeamTab
        ? CaptureService(Supabase.instance.client).listCaptures(scope: 'team')
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
      _reload();
    });
  }

  String _formatDate(String raw) => formatHistoryDate(raw);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: HeevyBrandedAppBar(
        title: _scope == 'team' ? 'Team capture history' : 'Capture history',
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
          Expanded(
            child: RefreshIndicator(
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
                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        HeevyEmptyState(
                          icon: Icons.camera_alt_outlined,
                          title: _scope == 'team'
                              ? 'No team captures yet'
                              : 'No captures yet',
                          subtitle: _scope == 'team'
                              ? 'Field captures from your crew appear here.'
                              : 'Use Quick capture to log your first defect or inspection.',
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
                      final area = row['plant_area']?.toString() ?? '—';
                      final sev = row['severity']?.toString() ?? '';
                      final notes = row['notes']?.toString() ?? '';
                      final wrNum = row['wr_number']?.toString() ?? '';
                      final created = row['created_at']?.toString() ?? '';
                      final creator = row['created_by_name']?.toString() ?? '';
                      final lines = <HistoryCardLine>[
                        if (_scope == 'team' && creator.isNotEmpty)
                          HistoryCardLine(creator, style: HistoryCardLineStyle.faint),
                        if (sev.isNotEmpty) HistoryCardLine(sev),
                        if (wrNum.isNotEmpty)
                          HistoryCardLine(wrNum, style: HistoryCardLineStyle.faint),
                        if (notes.isNotEmpty)
                          HistoryCardLine(
                            notes,
                            style: HistoryCardLineStyle.body,
                            maxLines: 2,
                          ),
                        if (created.isNotEmpty)
                          HistoryCardLine(
                            _formatDate(created),
                            style: HistoryCardLineStyle.date,
                          ),
                      ];
                      return HistoryCard(
                        icon: Icons.camera_alt_outlined,
                        title: area,
                        lines: lines,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  CaptureDetailScreen(
                                  capture: row,
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
