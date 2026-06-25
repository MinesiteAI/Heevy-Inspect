import 'package:flutter/material.dart';

import '../../billing/entitlement_service.dart';
import '../../config/heevy_brand.dart';
import '../../theme/app_colors.dart';
import '../capture/capture_history_screen.dart';
import '../capture/quick_capture_screen.dart';
import '../inspections/pm_templates_list_screen.dart';
import '../upgrade/upgrade_screen.dart';

class InspectHomeScreen extends StatelessWidget {
  const InspectHomeScreen({super.key, required this.entitlement});

  final EntitlementResult entitlement;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: Text(HeevyBrand.appTitle),
        backgroundColor: AppColors.bg(context),
        foregroundColor: AppColors.text(context),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _HomeTile(
            icon: Icons.add_a_photo_outlined,
            title: 'Quick capture',
            subtitle: 'Photo, area, severity → draft work request',
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const QuickCaptureScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _HomeTile(
            icon: Icons.history,
            title: 'My captures',
            subtitle: 'History of field submissions',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CaptureHistoryScreen()),
              );
            },
          ),
          if (entitlement.showPmTemplates) ...[
            const SizedBox(height: 12),
            _HomeTile(
              icon: Icons.fact_check_outlined,
              title: 'PM inspections',
              subtitle: 'Structured templates from your site',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PmTemplatesListScreen()),
                );
              },
            ),
          ],
          const SizedBox(height: 12),
          _HomeTile(
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
  }
}

class _HomeTile extends StatelessWidget {
  const _HomeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: accent ? HeevyBrand.accent : AppColors.text(context)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                        color: AppColors.text(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: AppColors.muted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
