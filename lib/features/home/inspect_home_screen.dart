import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../billing/entitlement_service.dart';
import '../../config/heevy_brand.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_mode.dart';
import '../../widgets/heevy_brand_title.dart';
import '../../widgets/heevy_ui.dart';
import '../capture/capture_history_screen.dart';
import '../capture/quick_capture_screen.dart';
import '../inspections/pm_templates_list_screen.dart';
import '../upgrade/upgrade_screen.dart';

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
              HeevyListTile(
                icon: Icons.add_a_photo_outlined,
                title: 'Quick capture',
                subtitle: 'Photo, area, severity → draft work request',
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const QuickCaptureScreen(),
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
              if (entitlement.showPmTemplates) ...[
                const SizedBox(height: 10),
                HeevyListTile(
                  icon: Icons.fact_check_outlined,
                  title: 'PM inspections',
                  subtitle: 'Structured templates from your site',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PmTemplatesListScreen(),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 10),
              HeevyListTile(
                icon: Icons.rocket_launch_outlined,
                title: 'Upgrade to Plant CMMS',
                subtitle: 'Work orders, scheduling, stores',
                accent: true,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
