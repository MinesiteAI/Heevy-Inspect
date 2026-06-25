import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/pm/pm_schedule_templates_api.dart';
import '../../theme/app_colors.dart';
import 'schedule_pm_form_screen.dart';

class PmTemplatesListScreen extends StatefulWidget {
  const PmTemplatesListScreen({super.key});

  @override
  State<PmTemplatesListScreen> createState() => _PmTemplatesListScreenState();
}

class _PmTemplatesListScreenState extends State<PmTemplatesListScreen> {
  late Future<List<PMScheduleTemplateRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = fetchPMScheduleTemplates(Supabase.instance.client);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('PM inspections'),
        backgroundColor: AppColors.bg(context),
        foregroundColor: AppColors.text(context),
      ),
      body: FutureBuilder<List<PMScheduleTemplateRow>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!
              .where((t) => t.hasRenderableChecklist)
              .toList();
          if (items.isEmpty) {
            return const Center(child: Text('No PM templates provisioned yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final t = items[i];
              final title = t.pmName.trim().isNotEmpty ? t.pmName : 'PM';
              return Card(
                color: AppColors.card(context),
                child: ListTile(
                  title: Text(title),
                  subtitle: Text('${t.plantArea} · ${t.frequency}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    if (t.formStructure == null) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SchedulePmFormScreen(
                          pmTemplateShell: t.toPmTemplateShellMap(),
                          scheduleTemplateId: t.id,
                          formStructure: t.formStructure!,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
