import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import '../../widgets/heevy_ui.dart';
import 'pm_schedule_service.dart';

class PmScheduleInboxScreen extends StatefulWidget {
  const PmScheduleInboxScreen({super.key});

  @override
  State<PmScheduleInboxScreen> createState() => _PmScheduleInboxScreenState();
}

class _PmScheduleInboxScreenState extends State<PmScheduleInboxScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = PmScheduleService(Supabase.instance.client).loadInbox();
  }

  Future<void> _refresh() async {
    final f = PmScheduleService(Supabase.instance.client).loadInbox();
    setState(() => _future = f);
    await f;
  }

  List<Map<String, dynamic>> _rows(dynamic raw) {
    if (raw is! List) return [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Widget _section(String title, List<Map<String, dynamic>> items, {Color? accent}) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              color: accent ?? AppColors.text(context),
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        ...items.map((row) {
          final name = row['pm_template_name']?.toString() ?? 'PM';
          final area = row['area']?.toString() ?? '';
          final date = row['scheduled_date']?.toString() ?? '';
          final status = row['status']?.toString() ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: HeevyListTile(
              icon: Icons.event_note_outlined,
              title: name,
              subtitle: [date, area, status].where((s) => s.isNotEmpty).join(' · '),
              onTap: () {},
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: const HeevyBrandedAppBar(title: 'PM schedule'),
      body: RefreshIndicator(
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
                    title: 'Could not load schedule',
                    subtitle: snapshot.error.toString(),
                  ),
                ],
              );
            }
            final data = snapshot.data ?? {};
            final overdue = _rows(data['overdue']);
            final dueToday = _rows(data['due_today']);
            final upcoming = _rows(data['upcoming']);
            final total = (data['total_open'] as num?)?.toInt() ?? 0;

            if (total == 0) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 80),
                  HeevyEmptyState(
                    icon: Icons.event_available_outlined,
                    title: 'No scheduled PMs',
                    subtitle:
                        'When your site has PM instances on the web calendar, due and overdue items appear here.',
                  ),
                ],
              );
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  'Due and overdue PM inspections for your site.',
                  style: TextStyle(color: AppColors.textMuted(context), height: 1.4),
                ),
                _section(
                  'Overdue',
                  overdue,
                  accent: const Color(0xFFFF453A),
                ),
                _section('Due today', dueToday),
                _section('Upcoming (7 days)', upcoming),
              ],
            );
          },
        ),
      ),
    );
  }
}
