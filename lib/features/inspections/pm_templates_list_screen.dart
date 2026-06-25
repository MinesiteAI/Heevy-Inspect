import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/pm/pm_schedule_templates_api.dart';
import '../../data/workspace_context.dart';
import '../../theme/app_colors.dart';
import '../../widgets/heevy_ui.dart';
import 'schedule_pm_form_screen.dart';

class PmTemplatesListScreen extends StatefulWidget {
  const PmTemplatesListScreen({super.key});

  @override
  State<PmTemplatesListScreen> createState() => _PmTemplatesListScreenState();
}

class _PmTemplatesListScreenState extends State<PmTemplatesListScreen> {
  late Future<List<PMScheduleTemplateRow>> _templatesFuture;
  late Future<WorkspaceContext> _workspaceFuture;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _templatesFuture = fetchPMScheduleTemplates(client);
    _workspaceFuture = fetchWorkspaceContext(client);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: const HeevyBrandedAppBar(title: 'PM inspections'),
      body: FutureBuilder(
        future: Future.wait([_templatesFuture, _workspaceFuture]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: AppColors.textMuted(context),
                strokeWidth: 2.2,
              ),
            );
          }
          final results = snapshot.data!;
          final items = (results[0] as List<PMScheduleTemplateRow>)
              .where((t) => t.hasRenderableChecklist)
              .toList();
          final workspace = results[1] as WorkspaceContext;
          final siteLabel = workspace.siteDisplayName;

          if (items.isEmpty) {
            return const HeevyEmptyState(
              icon: Icons.fact_check_outlined,
              title: 'No PM templates yet',
              subtitle:
                  'Templates appear here once your company site is provisioned on the web.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final t = items[i];
              final title = t.pmName.trim().isNotEmpty ? t.pmName : 'PM';
              return HeevyListTile(
                icon: Icons.fact_check_outlined,
                title: title,
                subtitle: '${t.plantArea} · ${t.frequency}',
                onTap: () {
                  if (t.formStructure == null) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SchedulePmFormScreen(
                        pmTemplateShell: t.toPmTemplateShellMap(),
                        scheduleTemplateId: t.id,
                        formStructure: t.formStructure!,
                        siteDisplayName:
                            siteLabel.isNotEmpty ? siteLabel : null,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
