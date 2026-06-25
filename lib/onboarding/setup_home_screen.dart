import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../billing/entitlement_service.dart';
import '../config/heevy_brand.dart';
import '../config/heevy_urls.dart';
import '../theme/app_colors.dart';
import '../widgets/heevy_brand_title.dart';

class SetupHomeScreen extends StatelessWidget {
  const SetupHomeScreen({
    super.key,
    required this.entitlement,
    required this.onContinueToApp,
    this.onRefresh,
  });

  final EntitlementResult entitlement;
  final VoidCallback onContinueToApp;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: onRefresh ?? () async {},
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const HeevyBrandTitle(textAlign: TextAlign.start),
              const SizedBox(height: 8),
              Text(HeevyBrand.tagline, style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 24),
              Text(
                'Complete site setup on the web to unlock captures for your team.',
                style: TextStyle(color: AppColors.text(context), fontSize: 16),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => launchUrl(
                  HeevyUrls.authForSetupPortal(),
                  mode: LaunchMode.externalApplication,
                ),
                child: const Text('Open setup portal'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onContinueToApp,
                child: const Text('Continue to app'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
