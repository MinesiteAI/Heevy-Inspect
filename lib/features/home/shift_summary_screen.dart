import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../billing/entitlement_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/heevy_ui.dart';
import '../../widgets/history_card.dart';
import '../capture/capture_service.dart';
import '../work_requests/work_request_service.dart';

class ShiftSummaryScreen extends StatefulWidget {
  const ShiftSummaryScreen({super.key, required this.entitlement});

  final EntitlementResult entitlement;

  @override
  State<ShiftSummaryScreen> createState() => _ShiftSummaryScreenState();
}

class _ShiftSummaryScreenState extends State<ShiftSummaryScreen> {
  late Future<_ShiftSummary> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _load();
  }

  Future<_ShiftSummary> _load() async {
    final client = Supabase.instance.client;
    final since = DateTime.now().subtract(const Duration(hours: 24));

    final captures = await CaptureService(client).listCaptures(scope: 'team');
    final wrMeta = await WorkRequestService(client).listWorkRequestsMeta(scope: 'team');
    final wrItems = wrMeta['items'] is List
        ? List<Map<String, dynamic>>.from(wrMeta['items'] as List)
        : <Map<String, dynamic>>[];

    bool inWindow(String? raw) {
      if (raw == null || raw.isEmpty) return false;
      final dt = DateTime.tryParse(raw);
      return dt != null && dt.isAfter(since);
    }

    final recentCaptures = captures.where((r) => inWindow(r['created_at']?.toString())).toList();
    final openWrs = wrItems.where((r) {
      if (!inWindow(r['created_at']?.toString()) && !inWindow(r['updated_at']?.toString())) {
        return false;
      }
      final status = (r['status']?.toString() ?? '').toLowerCase();
      return status != 'closed' && status != 'cancelled';
    }).toList();

    final byArea = <String, _AreaBucket>{};
    void bump(String area, {int captures = 0, int wrs = 0}) {
      final key = area.trim().isEmpty ? 'Unspecified area' : area.trim();
      byArea.putIfAbsent(key, () => _AreaBucket(area: key));
      byArea[key]!.captures += captures;
      byArea[key]!.workRequests += wrs;
    }

    for (final c in recentCaptures) {
      bump(c['plant_area']?.toString() ?? '', captures: 1);
    }
    for (final w in openWrs) {
      bump(w['functional_location']?.toString() ?? w['work_title']?.toString() ?? '', wrs: 1);
    }

    final buckets = byArea.values.toList()
      ..sort((a, b) => (b.captures + b.workRequests).compareTo(a.captures + a.workRequests));

    return _ShiftSummary(
      captureCount: recentCaptures.length,
      workRequestCount: openWrs.length,
      buckets: buckets,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: const HeevyBrandedAppBar(title: 'Last 24 hours'),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(_reload);
          await _future;
        },
        child: FutureBuilder<_ShiftSummary>(
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
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  HeevyEmptyState(
                    icon: Icons.error_outline,
                    title: 'Could not load shift summary',
                    subtitle: snapshot.error.toString(),
                  ),
                ],
              );
            }
            final summary = snapshot.data!;
            if (summary.captureCount == 0 && summary.workRequestCount == 0) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 80),
                  HeevyEmptyState(
                    icon: Icons.wb_twilight_outlined,
                    title: 'Quiet shift so far',
                    subtitle: 'No crew captures or work requests in the last 24 hours.',
                  ),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  '${summary.captureCount} capture${summary.captureCount == 1 ? '' : 's'} · '
                  '${summary.workRequestCount} open request${summary.workRequestCount == 1 ? '' : 's'}',
                  style: TextStyle(color: AppColors.textMuted(context), fontSize: 14),
                ),
                const SizedBox(height: 16),
                Text(
                  'By area',
                  style: TextStyle(
                    color: AppColors.text(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                for (final bucket in summary.buckets) ...[
                  HistoryCard(
                    icon: Icons.place_outlined,
                    title: bucket.area,
                    lines: [
                      if (bucket.captures > 0)
                        HistoryCardLine('${bucket.captures} capture${bucket.captures == 1 ? '' : 's'}'),
                      if (bucket.workRequests > 0)
                        HistoryCardLine('${bucket.workRequests} work request${bucket.workRequests == 1 ? '' : 's'}'),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ShiftSummary {
  const _ShiftSummary({
    required this.captureCount,
    required this.workRequestCount,
    required this.buckets,
  });

  final int captureCount;
  final int workRequestCount;
  final List<_AreaBucket> buckets;
}

class _AreaBucket {
  _AreaBucket({required this.area});

  final String area;
  int captures = 0;
  int workRequests = 0;
}
