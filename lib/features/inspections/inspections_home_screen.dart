import 'package:flutter/material.dart';

import '../../billing/entitlement_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/heevy_ui.dart';
import 'create_pm_template_screen.dart';
import 'pm_submission_list_screen.dart';
import 'pm_templates_list_screen.dart';

class InspectionsHomeScreen extends StatelessWidget {
  const InspectionsHomeScreen({super.key, required this.entitlement});

  final EntitlementResult entitlement;

  @override
  Widget build(BuildContext context) {
    final limit = entitlement.pmTemplateLimitPerDiscipline;
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: const HeevyBrandedAppBar(title: 'Inspections'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            limit != null
                ? 'Run PM templates or create your own (up to $limit per discipline).'
                : 'Run PM templates or review your submitted inspections.',
            style: TextStyle(
              color: AppColors.textMuted(context),
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          if (entitlement.allowsPmTemplateCreate)
            HeevyListTile(
              icon: Icons.add_circle_outline,
              title: 'New inspection template',
              subtitle: limit != null
                  ? 'Free tier: $limit templates per discipline'
                  : 'Build a checklist for your site',
              accent: true,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CreatePmTemplateScreen(entitlement: entitlement),
                  ),
                );
              },
            ),
          if (entitlement.allowsPmTemplateCreate) const SizedBox(height: 10),
          HeevyListTile(
            icon: Icons.fact_check_outlined,
            title: 'PM templates',
            subtitle: 'Structured checklists from your site',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PmTemplatesListScreen(entitlement: entitlement),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          HeevyListTile(
            icon: Icons.assignment_turned_in_outlined,
            title: 'My PM results',
            subtitle: 'History of submitted inspections',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PmSubmissionListScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
