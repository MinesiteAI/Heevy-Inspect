import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../billing/entitlement_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/heevy_ui.dart';
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
  String _scope = 'mine';

  bool get _showTeamTab => widget.entitlement?.isOrgManager == true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = CaptureService(Supabase.instance.client).listCaptures(scope: _scope);
  }

  Future<void> _refresh() async {
    final f = CaptureService(Supabase.instance.client).listCaptures(scope: _scope);
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

  String _formatDate(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final local = dt.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: HeevyBrandedAppBar(
        title: _scope == 'team' ? 'Team captures' : 'My captures',
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
                      return Material(
                        color: AppColors.surface(context),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    CaptureDetailScreen(capture: row),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceAlt(context),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.camera_alt_outlined,
                                    color: AppColors.textMuted(context),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        area,
                                        style: TextStyle(
                                          color: AppColors.text(context),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (_scope == 'team' &&
                                          creator.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          creator,
                                          style: TextStyle(
                                            color: AppColors.textFaint(context),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                      if (sev.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          sev,
                                          style: TextStyle(
                                            color: AppColors.textMuted(context),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                      if (wrNum.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          wrNum,
                                          style: TextStyle(
                                            color: AppColors.textFaint(context),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                      if (notes.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          notes,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: AppColors.muted,
                                            fontSize: 13,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                      if (created.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          _formatDate(created),
                                          style: TextStyle(
                                            color: AppColors.textFaint(context),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
