import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/heevy_urls.dart';
import '../../theme/app_colors.dart';

class UpgradeScreen extends StatelessWidget {
  const UpgradeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Upgrade'),
        backgroundColor: AppColors.bg(context),
        foregroundColor: AppColors.text(context),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unlock full Plant CMMS',
              style: TextStyle(
                color: AppColors.text(context),
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Upgrade to schedule work orders, PM, stores, and reporting. Your field captures and draft work requests carry over — no data migration.',
              style: TextStyle(color: AppColors.muted, fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => launchUrl(
                HeevyUrls.captureUpgrade(),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text('Upgrade on web'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => launchUrl(
                Uri.parse('https://apps.apple.com'),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text('Get Heevy Mining (full mobile CMMS)'),
            ),
          ],
        ),
      ),
    );
  }
}
