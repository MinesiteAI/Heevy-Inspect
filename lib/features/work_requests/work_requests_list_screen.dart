import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import '../../widgets/heevy_ui.dart';
import 'work_request_detail_screen.dart';
import 'work_request_service.dart';

class WorkRequestsListScreen extends StatefulWidget {
  const WorkRequestsListScreen({super.key});

  @override
  State<WorkRequestsListScreen> createState() => _WorkRequestsListScreenState();
}

class _WorkRequestsListScreenState extends State<WorkRequestsListScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = WorkRequestService(Supabase.instance.client).listWorkRequests();
  }

  Future<void> _refresh() async {
    final f = WorkRequestService(Supabase.instance.client).listWorkRequests();
    setState(() => _future = f);
    await f;
  }

  String _statusLabel(String? status) {
    final s = (status ?? '').toLowerCase();
    if (s == 'draft') return 'Draft';
    if (s == 'open') return 'Open';
    return status ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: const HeevyBrandedAppBar(title: 'Work requests'),
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
                    title: 'Could not load work requests',
                    subtitle: snapshot.error.toString(),
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
                    icon: Icons.assignment_outlined,
                    title: 'No work requests yet',
                    subtitle: 'Submit a quick capture to create your first draft work request.',
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
                final title = row['work_title']?.toString() ?? 'Work request';
                final num = row['wr_number']?.toString() ?? '';
                final status = _statusLabel(row['status']?.toString());
                final location = row['functional_location']?.toString() ?? '';
                final subtitle = [
                  if (num.isNotEmpty) num,
                  status,
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
                        builder: (_) => WorkRequestDetailScreen(workRequestId: id),
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
