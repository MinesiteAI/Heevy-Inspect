import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../analytics/inspect_analytics.dart';
import '../../billing/entitlement_service.dart';
import '../../config/heevy_brand.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_mode.dart';
import '../../widgets/heevy_brand_title.dart';
import '../../widgets/heevy_ui.dart';
import '../capture/capture_history_screen.dart';
import '../capture/quick_capture_screen.dart';
import '../chat/field_guide_screen.dart';
import '../inspections/inspections_home_screen.dart';
import '../upgrade/upgrade_screen.dart';
import '../work_orders/work_orders_list_screen.dart';

class InspectHomeScreen extends StatelessWidget {
  const InspectHomeScreen({super.key, required this.entitlement});

  final EntitlementResult entitlement;

  @override
  Widget build(BuildContext context) {
    final orgName = entitlement.organizationName;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        return Scaffold(
          backgroundColor: AppColors.bg(context),
          appBar: HeevyBrandedAppBar(
            actions: [
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
                  subtitle: 'Photo, area, severity → work request or WO',
                  accent: true,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const QuickCaptureScreen(),
                      ),
                    );
                    await InspectAnalytics.track('quick_capture_open');
                  },
                ),
              if (!entitlement.allowsFieldCapture)
                _DisabledTile(
                  icon: Icons.add_a_photo_outlined,
                  title: 'Quick capture',
                  subtitle: 'Not enabled for your organization',
                ),
              const SizedBox(height: 10),
              if (entitlement.showPmTemplates)
                HeevyListTile(
                  icon: Icons.fact_check_outlined,
                  title: 'Inspections',
                  subtitle: 'PM templates and your submitted results',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const InspectionsHomeScreen(),
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
              if (entitlement.showFieldGuide)
                HeevyListTile(
                  icon: Icons.chat_bubble_outline,
                  title: 'Field guide',
                  subtitle: 'AI assistant for your field data',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const FieldGuideScreen(),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 10),
              HeevyListTile(
                icon: Icons.history,
                title: 'My captures',
                subtitle: 'History of field submissions',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CaptureHistoryScreen(),
                    ),
                  );
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
