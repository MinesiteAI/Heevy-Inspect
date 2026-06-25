import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import '../../widgets/heevy_ui.dart';
import 'pm_submission_detail_screen.dart';
import 'pm_submission_service.dart';

class PmSubmissionListScreen extends StatefulWidget {
  const PmSubmissionListScreen({super.key});

  @override
  State<PmSubmissionListScreen> createState() => _PmSubmissionListScreenState();
}

class _PmSubmissionListScreenState extends State<PmSubmissionListScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = PmSubmissionService(Supabase.instance.client).listMySubmissions();
  }

  Future<void> _refresh() async {
    final f = PmSubmissionService(Supabase.instance.client).listMySubmissions();
    setState(() => _future = f);
    await f;
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final local = dt.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  String _titleFor(Map<String, dynamic> row) {
    final fv = row['form_values'];
    if (fv is Map) {
      final mv = fv['__mobile_v1'];
      if (mv is Map) {
        final title = mv['mobile_context_pm_title']?.toString();
        if (title != null && title.isNotEmpty) return title;
      }
    }
    return 'PM inspection';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: const HeevyBrandedAppBar(title: 'My PM results'),
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
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 80),
                  HeevyEmptyState(
                    icon: Icons.fact_check_outlined,
                    title: 'No submissions yet',
                    subtitle: 'Complete a PM template to see results here.',
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
                final title = _titleFor(row);
                final status = row['status']?.toString() ?? '';
                final date = _formatDate(
                  row['submitted_at']?.toString() ?? row['created_at']?.toString(),
                );
                return HeevyListTile(
                  icon: Icons.assignment_turned_in_outlined,
                  title: title,
                  subtitle: [status, date].where((s) => s.isNotEmpty).join(' · '),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PmSubmissionDetailScreen(
                          submissionId: row['id']?.toString() ?? '',
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
    );
  }
}
