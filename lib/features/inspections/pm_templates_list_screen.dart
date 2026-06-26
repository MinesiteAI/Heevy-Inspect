import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../billing/entitlement_service.dart';
import '../../data/pm/pm_schedule_templates_api.dart';
import '../../data/workspace_context.dart';
import '../../theme/app_colors.dart';
import '../../widgets/heevy_ui.dart';
import 'create_pm_template_screen.dart';
import 'schedule_pm_form_screen.dart';

class PmTemplatesListScreen extends StatefulWidget {
  const PmTemplatesListScreen({super.key, required this.entitlement});

  final EntitlementResult entitlement;

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

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreatePmTemplateScreen(entitlement: widget.entitlement),
      ),
    );
    if (created == true && mounted) {
      setState(() {
        _templatesFuture = fetchPMScheduleTemplates(Supabase.instance.client);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final entitlement = widget.entitlement;
    final canCreate = entitlement.allowsPmTemplateCreate;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: HeevyBrandedAppBar(
        title: 'PM templates',
        actions: [
          if (canCreate)
            IconButton(
              tooltip: 'New inspection template',
              onPressed: _openCreate,
              icon: Icon(Icons.add, color: AppColors.textMuted(context)),
            ),
        ],
      ),
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
            final limit = entitlement.pmTemplateLimitPerDiscipline;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const SizedBox(height: 40),
                HeevyEmptyState(
                  icon: Icons.fact_check_outlined,
                  title: 'No PM templates yet',
                  subtitle: limit != null
                      ? 'Create your first checklist — up to $limit templates per discipline on the free tier.'
                      : 'Create a checklist or wait for site provisioning on the web.',
                ),
                if (canCreate) ...[
                  const SizedBox(height: 24),
                  HeevyPrimaryButton(
                    label: 'New inspection template',
                    onTap: _openCreate,
                  ),
                  if (limit != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Free tier: $limit templates per discipline',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textFaint(context),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ],
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
