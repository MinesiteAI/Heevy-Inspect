import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../analytics/inspect_analytics.dart';
import '../../billing/entitlement_service.dart';
import '../../billing/upgrade_cta_policy.dart';
import '../../config/field_copy.dart';
import '../../config/heevy_brand.dart';
import '../../data/workspace_context.dart';
import '../../notifications/notification_service.dart';
import '../../sync/offline_sync_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_mode.dart';
import '../../widgets/field_guide_fab.dart';
import '../../widgets/heevy_brand_title.dart';
import '../../widgets/heevy_ui.dart';
import '../../widgets/hero_action_card.dart';
import '../../widgets/home_account_menu.dart';
import '../../widgets/home_section_header.dart';
import '../../widgets/supervisor_home_strip.dart';
import '../capture/capture_history_screen.dart';
import '../capture/quick_capture_screen.dart';
import '../inspections/inspections_home_screen.dart';
import '../notifications/notifications_screen.dart';
import '../upgrade/upgrade_screen.dart';
import '../work_orders/work_orders_list_screen.dart';
import '../home/shift_summary_screen.dart';
import '../work_requests/work_requests_list_screen.dart';

class InspectHomeScreen extends StatefulWidget {
  const InspectHomeScreen({super.key, required this.entitlement});

  final EntitlementResult entitlement;

  @override
  State<InspectHomeScreen> createState() => _InspectHomeScreenState();
}

class _InspectHomeScreenState extends State<InspectHomeScreen> {
  int _offlinePending = 0;
  int _unreadNotifications = 0;
  SupervisorSummary? _supervisorSummary;
  WorkspaceContext _workspace = WorkspaceContext.empty;

  @override
  void initState() {
    super.initState();
    _refreshBadges();
  }

  Future<void> _refreshBadges() async {
    final client = Supabase.instance.client;
    final pending = await OfflineSyncService(client).pendingCount();
    var unread = 0;
    SupervisorSummary? supervisor;
    WorkspaceContext workspace = WorkspaceContext.empty;
    try {
      workspace = await fetchWorkspaceContext(client);
    } catch (_) {}
    try {
      final page = await NotificationService(client).list(limit: 1);
      unread = page.unreadCount;
    } catch (_) {}
    if (widget.entitlement.isOrgManager) {
      try {
        supervisor = await SupervisorHomeStrip.load(
          client,
          isOrgManager: true,
        );
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _offlinePending = pending;
        _unreadNotifications = unread;
        _supervisorSummary = supervisor;
        _workspace = workspace;
      });
    }
  }

  Future<void> _syncOffline() async {
    final result =
        await OfflineSyncService(Supabase.instance.client).syncAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.synced > 0
              ? 'Synced ${result.synced} offline item(s)'
              : result.remaining > 0
              ? 'Some items still waiting — check connection'
              : 'Nothing to sync',
        ),
      ),
    );
    await _refreshBadges();
  }

  Future<void> _openQuickCapture(BuildContext context) async {
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        builder: (_) => QuickCaptureScreen(entitlement: widget.entitlement),
      ),
    );
    await InspectAnalytics.track('quick_capture_open');
    if (!context.mounted) return;
    if (result is Map && result['message'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'].toString()),
          duration: const Duration(seconds: 4),
        ),
      );
    }
    await _refreshBadges();
  }

  @override
  Widget build(BuildContext context) {
    final entitlement = widget.entitlement;
    final isSupervisor = entitlement.isOrgManager;
    final siteLabel = _workspace.siteDisplayName;
    final orgName = entitlement.organizationName?.trim() ?? '';
    final showOrgSecondary = orgName.isNotEmpty &&
        orgName.toLowerCase() != siteLabel.toLowerCase();

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        return Scaffold(
          backgroundColor: AppColors.bg(context),
          floatingActionButton: const FieldGuideFab(compact: true),
          appBar: HeevyBrandedAppBar(
            actions: [
              if (_offlinePending > 0)
                IconButton(
                  tooltip: 'Sync offline queue',
                  onPressed: _syncOffline,
                  icon: Badge(
                    label: Text('$_offlinePending'),
                    child: Icon(
                      Icons.cloud_upload_outlined,
                      color: AppColors.textMuted(context),
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Notifications',
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  );
                  await _refreshBadges();
                },
                icon: Badge(
                  isLabelVisible: _unreadNotifications > 0,
                  label: Text('$_unreadNotifications'),
                  child: Icon(
                    Icons.notifications_outlined,
                    color: AppColors.textMuted(context),
                  ),
                ),
              ),
              HomeAccountMenu(
                themeMode: themeMode,
                siteName: siteLabel.isNotEmpty ? siteLabel : orgName,
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 88),
            children: [
              Row(
                children: [
                  Image.asset(
                    AppColors.isDark(context)
                        ? 'assets/dark.png'
                        : 'assets/light.png',
                    width: 48,
                    height: 48,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const HeevyBrandTitle(
                          compact: true,
                          textAlign: TextAlign.start,
                        ),
                        if (siteLabel.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            siteLabel,
                            style: TextStyle(
                              color: AppColors.text(context),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (showOrgSecondary) ...[
                          const SizedBox(height: 2),
                          Text(
                            orgName,
                            style: TextStyle(
                              color: AppColors.textMuted(context),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                HeevyBrand.tagline,
                style: TextStyle(
                  color: AppColors.textFaint(context),
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              if (_offlinePending > 0) ...[
                const SizedBox(height: 16),
                Material(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    leading: Icon(
                      Icons.cloud_off_outlined,
                      color: AppColors.textMuted(context),
                    ),
                    title: Text(
                      '$_offlinePending item(s) waiting to sync',
                      style: TextStyle(color: AppColors.text(context)),
                    ),
                    trailing: TextButton(
                      onPressed: _syncOffline,
                      child: const Text('Sync now'),
                    ),
                  ),
                ),
              ],
              if (_supervisorSummary != null)
                SupervisorHomeStrip(
                  entitlement: entitlement,
                  summary: _supervisorSummary!,
                  onRefresh: _refreshBadges,
                ),
              if (isSupervisor) ...[
                const SizedBox(height: 10),
                HeevyListTile(
                  icon: Icons.wb_twilight_outlined,
                  title: FieldCopy.todaysHandover,
                  subtitle: FieldCopy.todaysHandoverSubtitle,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ShiftSummaryScreen(entitlement: entitlement),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 20),
              ..._homeSections(context, entitlement),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _homeSections(
    BuildContext context,
    EntitlementResult entitlement,
  ) {
    final isSupervisor = entitlement.isOrgManager;
    final sections = <Widget>[];

    if (isSupervisor) {
      sections.add(const HomeSectionHeader(label: FieldCopy.sectionSite));
      sections.addAll(_siteTiles(context, entitlement));
      sections.add(const SizedBox(height: 20));
      sections.add(const HomeSectionHeader(label: FieldCopy.sectionJobs));
      sections.addAll(_jobTiles(context, entitlement));
      if (UpgradeCtaPolicy.showHomeUpgradeTile(isOrgManager: true)) {
        sections.add(const SizedBox(height: 16));
        sections.add(_upgradeTile(context));
      }
    } else {
      if (entitlement.allowsFieldCapture) {
        sections.add(
          HeroActionCard(
            title: FieldCopy.reportDefectTitle,
            subtitle: FieldCopy.reportDefectSubtitle,
            onTap: () => _openQuickCapture(context),
          ),
        );
        sections.add(const SizedBox(height: 20));
      }
      sections.add(const HomeSectionHeader(label: FieldCopy.sectionReport));
      sections.addAll(_reportTiles(context, entitlement));
      sections.add(const SizedBox(height: 20));
      sections.add(const HomeSectionHeader(label: FieldCopy.sectionJobs));
      sections.addAll(_jobTiles(context, entitlement));
    }

    return sections;
  }

  List<Widget> _reportTiles(
    BuildContext context,
    EntitlementResult entitlement,
  ) {
    if (!entitlement.allowsFieldCapture) {
      return [
        const _DisabledTile(
          icon: Icons.assignment_outlined,
          title: FieldCopy.myReports,
          subtitle: 'Not enabled for your organization',
        ),
      ];
    }
    return [
      HeevyListTile(
        icon: Icons.assignment_outlined,
        title: FieldCopy.myReports,
        subtitle: FieldCopy.myReportsSubtitle,
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WorkRequestsListScreen(
                entitlement: entitlement,
              ),
            ),
          );
          await InspectAnalytics.track('wr_list_view');
        },
      ),
    ];
  }

  List<Widget> _siteTiles(
    BuildContext context,
    EntitlementResult entitlement,
  ) {
    final tiles = <Widget>[];

    void gap() => tiles.add(const SizedBox(height: 10));

    if (entitlement.allowsFieldCapture) {
      tiles.add(
        HeevyListTile(
          icon: Icons.add_a_photo_outlined,
          title: FieldCopy.logDefectTitle,
          subtitle: FieldCopy.logDefectSubtitle,
          onTap: () => _openQuickCapture(context),
        ),
      );
      gap();
      tiles.add(
        HeevyListTile(
          icon: Icons.assignment_outlined,
          title: FieldCopy.crewReports,
          subtitle: FieldCopy.crewReportsSubtitle,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => WorkRequestsListScreen(
                  entitlement: entitlement,
                ),
              ),
            );
            await InspectAnalytics.track('wr_list_view');
          },
        ),
      );
      gap();
      tiles.add(
        HeevyListTile(
          icon: Icons.photo_library_outlined,
          title: FieldCopy.photoLog,
          subtitle: FieldCopy.photoLogSubtitle,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CaptureHistoryScreen(
                  entitlement: entitlement,
                ),
              ),
            );
            await _refreshBadges();
          },
        ),
      );
    }

    return tiles;
  }

  List<Widget> _jobTiles(
    BuildContext context,
    EntitlementResult entitlement,
  ) {
    final isSupervisor = entitlement.isOrgManager;
    final tiles = <Widget>[];

    void gap() => tiles.add(const SizedBox(height: 10));

    if (entitlement.showPmTemplates) {
      tiles.add(
        HeevyListTile(
          icon: Icons.fact_check_outlined,
          title: FieldCopy.inspections,
          subtitle: isSupervisor
              ? FieldCopy.inspectionsSubtitleSupervisor
              : FieldCopy.inspectionsSubtitleField,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    InspectionsHomeScreen(entitlement: entitlement),
              ),
            );
          },
        ),
      );
    }

    if (entitlement.showWorkOrders) {
      if (tiles.isNotEmpty) gap();
      tiles.add(
        HeevyListTile(
          icon: Icons.build_outlined,
          title: FieldCopy.workOrders,
          subtitle: isSupervisor
              ? FieldCopy.workOrdersSubtitleSupervisor
              : FieldCopy.workOrdersSubtitleField,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    WorkOrdersListScreen(entitlement: entitlement),
              ),
            );
          },
        ),
      );
    }

    return tiles;
  }

  Widget _upgradeTile(BuildContext context) {
    return MutedListTile(
      icon: Icons.rocket_launch_outlined,
      title: 'Upgrade to Plant CMMS',
      subtitle: 'Scheduling, stores, full lifecycle',
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const UpgradeScreen()),
        );
        await InspectAnalytics.track('upgrade_click');
      },
    );
  }
}

class _DisabledTile extends StatelessWidget {
  const _DisabledTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.5,
      child: HeevyListTile(
        icon: icon,
        title: title,
        subtitle: subtitle,
        onTap: () {},
      ),
    );
  }
}
