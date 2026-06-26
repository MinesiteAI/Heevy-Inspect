import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../analytics/inspect_analytics.dart';
import '../../billing/entitlement_refresh.dart';
import '../../billing/entitlement_service.dart';
import '../../config/heevy_urls.dart';
import '../../data/pm/pm_schedule_templates_api.dart';
import '../../data/workspace_context.dart';
import '../../theme/app_colors.dart';
import '../../widgets/heevy_ui.dart';
import '../upgrade/upgrade_screen.dart';
import 'create_pm_template_screen.dart';
import 'pm_template_service.dart';
import 'schedule_pm_form_screen.dart';

class PmTemplatesListScreen extends StatefulWidget {
  const PmTemplatesListScreen({super.key, required this.entitlement});

  final EntitlementResult entitlement;

  @override
  State<PmTemplatesListScreen> createState() => _PmTemplatesListScreenState();
}

class _PmTemplatesListScreenState extends State<PmTemplatesListScreen> {
  late EntitlementResult _entitlement;
  late Future<List<PMScheduleTemplateRow>> _templatesFuture;
  late Future<WorkspaceContext> _workspaceFuture;
  bool _refreshingEntitlement = false;
  bool _backfillAttempted = false;

  @override
  void initState() {
    super.initState();
    _entitlement = widget.entitlement;
    _reloadTemplates();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshEntitlement());
  }

  void _reloadTemplates() {
    final client = Supabase.instance.client;
    _templatesFuture = fetchPMScheduleTemplates(client);
    _workspaceFuture = fetchWorkspaceContext(client);
  }

  Future<void> _refreshEntitlement() async {
    setState(() => _refreshingEntitlement = true);
    try {
      await EntitlementRefresh.of(context)?.refresh();
      final fresh = await EntitlementService(Supabase.instance.client).check();
      if (mounted) setState(() => _entitlement = fresh);
    } catch (_) {
      // Keep passed-in entitlement on failure.
    } finally {
      if (mounted) setState(() => _refreshingEntitlement = false);
    }
  }

  Future<void> _refreshAll() async {
    setState(_reloadTemplates);
    await _refreshEntitlement();
  }

  bool get _isProvisioned => _entitlement.onboarding?.provisioned == true;

  bool _canCreateAnyDiscipline(EntitlementResult e) {
    if (!e.allowsPmTemplateCreate) return false;
    final limit = e.pmTemplateLimitPerDiscipline;
    if (limit == null) return true;
    for (final d in kPmDisciplines) {
      if ((e.pmTemplateUsageByDiscipline[d] ?? 0) < limit) return true;
    }
    return false;
  }

  bool _isAtQuota(EntitlementResult e) {
    final limit = e.pmTemplateLimitPerDiscipline;
    if (limit == null || e.allowsPlant) return false;
    return e.allowsPmTemplateCreate && !_canCreateAnyDiscipline(e);
  }

  Future<void> _maybeBackfillStarterTemplates(bool itemsEmpty) async {
    if (!itemsEmpty || !_isProvisioned || _backfillAttempted) return;
    _backfillAttempted = true;
    try {
      await Supabase.instance.client.functions.invoke(
        'manage-applicant-onboarding',
        body: const {'action': 'request_provision'},
      );
      if (mounted) {
        setState(_reloadTemplates);
        await _refreshEntitlement();
      }
    } catch (_) {
      // Non-fatal — user can pull to refresh or continue on web.
    }
  }

  Future<void> _openUpgrade() async {
    await InspectAnalytics.track('upgrade_click');
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UpgradeScreen()),
    );
  }

  Future<void> _openWebTemplates() async {
    await launchUrl(HeevyUrls.authForSetupPortal());
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreatePmTemplateScreen(entitlement: _entitlement),
      ),
    );
    if (created == true && mounted) {
      await _refreshAll();
    }
  }

  Widget _quotaFooterBanner(EntitlementResult entitlement) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt(context),
          borderRadius: BorderRadius.circular(heevyRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Need more templates?',
              style: TextStyle(
                color: AppColors.text(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Upgrade to Plant CMMS for unlimited templates, or manage checklists on the web.',
              style: TextStyle(
                color: AppColors.textMuted(context),
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            HeevySecondaryButton(
              label: 'Upgrade to Plant CMMS',
              onTap: _openUpgrade,
            ),
            const SizedBox(height: 8),
            HeevySecondaryButton(
              label: 'Manage templates on web',
              onTap: _openWebTemplates,
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyStateBody(EntitlementResult entitlement) {
    final limit = entitlement.pmTemplateLimitPerDiscipline;
    final canCreate = entitlement.allowsPmTemplateCreate;
    final canCreateAny = _canCreateAnyDiscipline(entitlement);
    final atQuota = _isAtQuota(entitlement);
    final provisioned = _isProvisioned;

    String title;
    String subtitle;

    if (!provisioned) {
      title = 'Site setup in progress';
      subtitle =
          'Sample checklists appear after your site is provisioned. Continue setup on the web, or upgrade for full template management.';
    } else if (atQuota || (canCreate && !canCreateAny)) {
      title = 'Template limit reached';
      subtitle =
          'Your free tier includes $limit sample templates per discipline. Upgrade to Plant CMMS or create more on the web.';
    } else if (!canCreate) {
      title = 'No PM templates yet';
      subtitle =
          'Create inspection checklists on the web or upgrade the app to build unlimited templates on mobile.';
    } else {
      title = 'No PM templates yet';
      subtitle = limit != null
          ? 'Create your first checklist — up to $limit templates per discipline on the free tier.'
          : 'Create inspection checklists for your site.';
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        if (_refreshingEntitlement)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(
              color: AppColors.textMuted(context),
              minHeight: 2,
            ),
          ),
        const SizedBox(height: 40),
        HeevyEmptyState(
          icon: Icons.fact_check_outlined,
          title: title,
          subtitle: subtitle,
        ),
        const SizedBox(height: 24),
        if (!provisioned) ...[
          HeevyPrimaryButton(
            label: 'Continue setup on web',
            onTap: _openWebTemplates,
          ),
          const SizedBox(height: 10),
          HeevySecondaryButton(
            label: 'Upgrade to Plant CMMS',
            onTap: _openUpgrade,
          ),
        ] else if (atQuota || !canCreate) ...[
          HeevyPrimaryButton(
            label: 'Upgrade to Plant CMMS',
            onTap: _openUpgrade,
          ),
          const SizedBox(height: 10),
          HeevySecondaryButton(
            label: 'Manage templates on web',
            onTap: _openWebTemplates,
          ),
        ] else if (canCreateAny) ...[
          HeevyPrimaryButton(
            label: 'New inspection template',
            onTap: _openCreate,
          ),
          const SizedBox(height: 12),
          Text(
            'Create more on the web or upgrade to Plant CMMS for unlimited templates.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textFaint(context),
              fontSize: 13,
              height: 1.35,
            ),
          ),
          if (limit != null) ...[
            const SizedBox(height: 8),
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

  @override
  Widget build(BuildContext context) {
    final entitlement = _entitlement;
    final canCreateAny = _canCreateAnyDiscipline(entitlement);
    final showAppBarCreate = entitlement.allowsPmTemplateCreate && canCreateAny;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: HeevyBrandedAppBar(
        title: 'PM templates',
        actions: [
          if (showAppBarCreate)
            IconButton(
              tooltip: 'New inspection template',
              onPressed: _openCreate,
              icon: Icon(Icons.add, color: AppColors.textMuted(context)),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.textMuted(context),
        onRefresh: _refreshAll,
        child: FutureBuilder(
          future: Future.wait([_templatesFuture, _workspaceFuture]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.35,
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
            final results = snapshot.data!;
            final items = (results[0] as List<PMScheduleTemplateRow>)
                .where((t) => t.hasRenderableChecklist)
                .toList();
            final workspace = results[1] as WorkspaceContext;
            final siteLabel = workspace.siteDisplayName;

            if (items.isEmpty) {
              if (_isProvisioned) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _maybeBackfillStarterTemplates(true),
                );
              }
              return _emptyStateBody(entitlement);
            }

            final showQuotaBanner = _isAtQuota(entitlement);

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              itemCount: items.length + (showQuotaBanner ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                if (showQuotaBanner && i == items.length) {
                  return _quotaFooterBanner(entitlement);
                }
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
      ),
    );
  }
}
