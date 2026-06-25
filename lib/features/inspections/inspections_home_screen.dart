import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/heevy_ui.dart';
import 'pm_submission_list_screen.dart';
import 'pm_templates_list_screen.dart';

class InspectionsHomeScreen extends StatelessWidget {
  const InspectionsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: const HeevyBrandedAppBar(title: 'Inspections'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Run PM templates or review your submitted inspections.',
            style: TextStyle(
              color: AppColors.textMuted(context),
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          HeevyListTile(
            icon: Icons.fact_check_outlined,
            title: 'PM templates',
            subtitle: 'Structured checklists from your site',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PmTemplatesListScreen()),
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
