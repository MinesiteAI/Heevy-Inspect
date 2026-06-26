import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/heevy_brand.dart';
import '../../config/heevy_urls.dart';
import '../../theme/app_colors.dart';
import '../../widgets/heevy_brand_title.dart';
import '../../widgets/heevy_ui.dart';

class UpgradeScreen extends StatelessWidget {
  const UpgradeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: const HeevyBrandedAppBar(title: 'Upgrade'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HeevyBrandTitle(compact: true, textAlign: TextAlign.start),
                const SizedBox(height: 16),
                Text(
                  'Unlock full Plant CMMS',
                  style: TextStyle(
                    color: AppColors.text(context),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Upgrade to schedule work orders, PM, stores, and reporting. Your field captures and draft work requests carry over — no data migration.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'What you get',
            style: TextStyle(
              color: AppColors.text(context),
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _FeatureRow(
            icon: Icons.assignment_outlined,
            title: 'Work orders & scheduling',
            subtitle: 'Turn captures into tracked maintenance jobs.',
          ),
          const SizedBox(height: 10),
          _FeatureRow(
            icon: Icons.inventory_2_outlined,
            title: 'Stores & parts',
            subtitle: 'Manage spares and procurement on site.',
          ),
          const SizedBox(height: 10),
          _FeatureRow(
            icon: Icons.analytics_outlined,
            title: 'Reporting & analytics',
            subtitle: 'Reliability metrics across your plant.',
          ),
          const SizedBox(height: 28),
          HeevyPrimaryButton(
            label: 'Upgrade on web',
            onTap: () => launchUrl(
              HeevyUrls.captureUpgrade(),
              mode: LaunchMode.externalApplication,
            ),
          ),
          const SizedBox(height: 12),
          HeevySecondaryButton(
            label: 'Learn about Heevy Mining',
            onTap: () => launchUrl(
              HeevyUrls.minesiteMobileApp(),
              mode: LaunchMode.externalApplication,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Heevy ${HeevyBrand.lineInspect} captures stay in your account when you upgrade.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textFaint(context),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: HeevyBrand.accent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.text(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
