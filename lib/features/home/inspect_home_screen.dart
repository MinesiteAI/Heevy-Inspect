import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../analytics/inspect_analytics.dart';
import '../../billing/entitlement_service.dart';
import '../../config/heevy_brand.dart';
import '../../notifications/notification_service.dart';
import '../../sync/offline_sync_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_mode.dart';
import '../../widgets/field_guide_fab.dart';
import '../../widgets/heevy_brand_title.dart';
import '../../widgets/heevy_ui.dart';
import '../../widgets/supervisor_home_strip.dart';
import '../capture/capture_history_screen.dart';
import '../capture/quick_capture_screen.dart';
import '../inspections/inspections_home_screen.dart';
import '../notifications/notifications_screen.dart';
import '../upgrade/upgrade_screen.dart';
import '../work_orders/work_orders_list_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final orgName = widget.entitlement.organizationName;
    final entitlement = widget.entitlement;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        return Scaffold(
          backgroundColor: AppColors.bg(context),
          floatingActionButton: const FieldGuideFab(),
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
              IconButton(
                tooltip: 'Theme',
                onPressed: () {
                  final next = themeMode == ThemeMode.dark
                      ? ThemeMode.light
                      : ThemeMode.dark;
                  setThemeMode(next);
                },
                icon: Icon(
                  themeMode == ThemeMode.dark
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined,
                  color: AppColors.textMuted(context),
                ),
              ),
              IconButton(
                tooltip: 'Sign out',
                onPressed: () => Supabase.instance.client.auth.signOut(),
                icon: Icon(Icons.logout, color: AppColors.textMuted(context)),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
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
                        if (orgName != null && orgName.isNotEmpty) ...[
                          const SizedBox(height: 4),
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
              const SizedBox(height: 24),
              Text(
                'What would you like to do?',
                style: TextStyle(
                  color: AppColors.text(context),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              if (entitlement.allowsFieldCapture)
                HeevyListTile(
                  icon: Icons.add_a_photo_outlined,
                  title: 'Quick capture',
                  subtitle: 'Photo-first — snap, note, auto draft WR',
                  accent: true,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const QuickCaptureScreen(),
                      ),
                    );
                    await InspectAnalytics.track('quick_capture_open');
                    await _refreshBadges();
                  },
                ),
              if (!entitlement.allowsFieldCapture)
                _DisabledTile(
                  icon: Icons.add_a_photo_outlined,
                  title: 'Quick capture',
                  subtitle: 'Not enabled for your organization',
                ),
              const SizedBox(height: 10),
              if (entitlement.allowsFieldCapture)
                HeevyListTile(
                  icon: Icons.assignment_outlined,
                  title: 'Work requests',
                  subtitle: entitlement.isOrgManager
                      ? 'Form-first drafts · team view for supervisors'
                      : 'Form-first — create and submit draft requests',
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
              const SizedBox(height: 10),
              if (entitlement.showPmTemplates)
                HeevyListTile(
                  icon: Icons.fact_check_outlined,
                  title: 'Inspections',
                  subtitle: 'Planned PM checklists · ad-hoc vs scheduled',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            InspectionsHomeScreen(entitlement: entitlement),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 10),
              if (entitlement.showWorkOrders)
                HeevyListTile(
                  icon: Icons.build_outlined,
                  title: 'Work orders',
                  subtitle: 'Create and view basic work orders',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const WorkOrdersListScreen(),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 10),
              HeevyListTile(
                icon: Icons.history,
                title: entitlement.isOrgManager ? 'Captures' : 'My captures',
                subtitle: entitlement.isOrgManager
                    ? 'Your logs and read-only team history'
                    : 'History of field submissions',
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
              const SizedBox(height: 10),
              HeevyListTile(
                icon: Icons.rocket_launch_outlined,
                title: 'Upgrade to Plant CMMS',
                subtitle: 'Scheduling, stores, full lifecycle',
                accent: true,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                  );
                  await InspectAnalytics.track('upgrade_click');
                },
              ),
            ],
          ),
        );
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
