import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/pm/pm_schedule_templates_api.dart';
import '../../data/workspace_context.dart';
import '../../theme/app_colors.dart';
import '../../widgets/heevy_ui.dart';
import 'pm_submission_service.dart';
import 'schedule_pm_form_screen.dart';

class PmSubmissionDetailScreen extends StatefulWidget {
  const PmSubmissionDetailScreen({super.key, required this.submissionId});

  final String submissionId;

  @override
  State<PmSubmissionDetailScreen> createState() =>
      _PmSubmissionDetailScreenState();
}

class _PmSubmissionDetailScreenState extends State<PmSubmissionDetailScreen> {
  late Future<({Map<String, dynamic>? submission, PMScheduleTemplateRow? template, WorkspaceContext workspace})> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<({Map<String, dynamic>? submission, PMScheduleTemplateRow? template, WorkspaceContext workspace})> _load() async {
    final client = Supabase.instance.client;
    final submission =
        await PmSubmissionService(client).getSubmission(widget.submissionId);
    final workspace = await fetchWorkspaceContext(client);
    PMScheduleTemplateRow? template;
    if (submission != null) {
      final templateId = submission['template_id']?.toString();
      if (templateId != null && templateId.isNotEmpty) {
        final templates = await fetchPMScheduleTemplates(client);
        for (final t in templates) {
          if (t.id == templateId) {
            template = t;
            break;
          }
        }
      }
    }
    return (submission: submission, template: template, workspace: workspace);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppColors.bg(context),
            appBar: const HeevyBrandedAppBar(title: 'PM result'),
            body: Center(
              child: CircularProgressIndicator(
                color: AppColors.textMuted(context),
                strokeWidth: 2.2,
              ),
            ),
          );
        }
        final data = snapshot.data;
        final submission = data?.submission;
        final template = data?.template;
        if (submission == null || template == null || template.formStructure == null) {
          return Scaffold(
            backgroundColor: AppColors.bg(context),
            appBar: const HeevyBrandedAppBar(title: 'PM result'),
            body: const HeevyEmptyState(
              icon: Icons.error_outline,
              title: 'Could not load submission',
              subtitle: 'The template may no longer be available.',
            ),
          );
        }
        return SchedulePmFormScreen(
          pmTemplateShell: template.toPmTemplateShellMap(),
          scheduleTemplateId: template.id,
          scheduleName: template.pmName,
          formStructure: template.formStructure!,
          initialSubmission: submission,
          readOnly: true,
          siteDisplayName: data!.workspace.siteDisplayName.isNotEmpty
              ? data.workspace.siteDisplayName
              : null,
        );
      },
    );
  }
}
