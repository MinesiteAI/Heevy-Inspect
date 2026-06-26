import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../billing/entitlement_service.dart';
import '../features/inspections/pm_schedule_inbox_screen.dart';
import '../features/inspections/pm_schedule_service.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/work_requests/work_request_service.dart';
import '../features/work_requests/work_requests_list_screen.dart';
import '../notifications/notification_service.dart';
import '../config/field_copy.dart';
import '../billing/upgrade_cta_policy.dart';
import '../config/heevy_urls.dart';
import '../theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

/// Summary counts for org managers on the home screen.
class SupervisorSummary {
  const SupervisorSummary({
    required this.overduePms,
    required this.teamDraftWrs,
    required this.unreadNotifications,
  });

  final int overduePms;
  final int teamDraftWrs;
  final int unreadNotifications;

  bool get hasAlerts =>
      overduePms > 0 || teamDraftWrs > 0 || unreadNotifications > 0;
}

class SupervisorHomeStrip extends StatelessWidget {
  const SupervisorHomeStrip({
    super.key,
    required this.entitlement,
    required this.summary,
    this.onRefresh,
  });

  final EntitlementResult entitlement;
  final SupervisorSummary summary;
  final VoidCallback? onRefresh;

  static Future<SupervisorSummary> load(
    SupabaseClient client, {
    required bool isOrgManager,
  }) async {
    if (!isOrgManager) {
      return const SupervisorSummary(
        overduePms: 0,
        teamDraftWrs: 0,
        unreadNotifications: 0,
      );
    }

    var overdue = 0;
    var teamDrafts = 0;
    var unread = 0;
    final uid = client.auth.currentUser?.id;

    try {
      final inbox = await PmScheduleService(client).loadInbox();
      final raw = inbox['overdue'];
      if (raw is List) overdue = raw.length;
    } catch (_) {}

    try {
      final meta = await WorkRequestService(client).listWorkRequestsMeta(
        scope: 'team',
      );
      final items = meta['items'] is List
          ? List<Map<String, dynamic>>.from(meta['items'] as List)
          : <Map<String, dynamic>>[];
      teamDrafts = items.where((row) {
        final status = (row['status']?.toString() ?? '').toLowerCase();
        if (status != 'draft') return false;
        final createdBy = row['created_by']?.toString();
        return createdBy != null && createdBy != uid;
      }).length;
    } catch (_) {}

    try {
      final page = await NotificationService(client).list(limit: 1);
      unread = page.unreadCount;
    } catch (_) {}

    return SupervisorSummary(
      overduePms: overdue,
      teamDraftWrs: teamDrafts,
      unreadNotifications: unread,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!entitlement.isOrgManager || !summary.hasAlerts) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Site overview',
              style: TextStyle(
                color: AppColors.text(context),
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 10),
            if (summary.overduePms > 0) ...[
              _SummaryRow(
                icon: Icons.event_busy_outlined,
                label:
                    '${summary.overduePms} overdue PM${summary.overduePms == 1 ? '' : 's'}',
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PmScheduleInboxScreen(),
                    ),
                  );
                  onRefresh?.call();
                },
              ),
              _SummaryRow(
                icon: Icons.open_in_new,
                label: 'View schedule on web',
                onTap: () => launchUrl(
                  HeevyUrls.plantSchedule(),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              if (UpgradeCtaPolicy.showSupervisorSchedulingUpgrade(
                allowsPlant: entitlement.allowsPlant,
                overduePms: summary.overduePms,
              ))
                _SummaryRow(
                  icon: Icons.rocket_launch_outlined,
                  label: 'Unlock PM scheduling on Plant CMMS',
                  onTap: () => launchUrl(
                    HeevyUrls.captureUpgrade(),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
            ],
            if (summary.teamDraftWrs > 0)
              _SummaryRow(
                icon: Icons.assignment_late_outlined,
                label: FieldCopy.crewDraftsAwaiting(summary.teamDraftWrs),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WorkRequestsListScreen(
                        entitlement: entitlement,
                        initialScope: 'team',
                        initialTeamFilter: TeamWrFilter.drafts,
                      ),
                    ),
                  );
                  onRefresh?.call();
                },
              ),
            if (summary.unreadNotifications > 0)
              _SummaryRow(
                icon: Icons.notifications_active_outlined,
                label:
                    '${summary.unreadNotifications} unread notification${summary.unreadNotifications == 1 ? '' : 's'}',
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  );
                  onRefresh?.call();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textMuted(context)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textFaint(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
