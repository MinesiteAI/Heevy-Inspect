import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../billing/entitlement_refresh.dart';
import '../../billing/entitlement_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/heevy_ui.dart';
import 'create_pm_template_screen.dart';
import 'pm_submission_list_screen.dart';
import 'pm_templates_list_screen.dart';

class InspectionsHomeScreen extends StatefulWidget {
  const InspectionsHomeScreen({super.key, required this.entitlement});

  final EntitlementResult entitlement;

  @override
  State<InspectionsHomeScreen> createState() => _InspectionsHomeScreenState();
}

class _InspectionsHomeScreenState extends State<InspectionsHomeScreen> {
  late EntitlementResult _entitlement;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _entitlement = widget.entitlement;
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshEntitlement());
  }

  Future<void> _refreshEntitlement() async {
    setState(() => _refreshing = true);
    try {
      await EntitlementRefresh.of(context)?.refresh();
      final fresh = await EntitlementService(Supabase.instance.client).check();
      if (mounted) setState(() => _entitlement = fresh);
    } catch (_) {
      // Keep passed-in entitlement on failure.
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entitlement = _entitlement;
    final limit = entitlement.pmTemplateLimitPerDiscipline;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: const HeevyBrandedAppBar(title: 'Inspections'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (_refreshing)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(
                color: AppColors.textMuted(context),
                minHeight: 2,
              ),
            ),
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
