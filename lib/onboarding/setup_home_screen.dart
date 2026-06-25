import 'package:flutter/material.dart';

import '../billing/entitlement_service.dart';
import '../config/heevy_brand.dart';
import '../deep_link_handler.dart';
import '../theme/app_colors.dart';
import '../widgets/heevy_brand_title.dart';
import '../widgets/heevy_ui.dart';
import '../widgets/onboarding_status_chip.dart';

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
    final muted = AppColors.muted;
    final provisioned = entitlement.onboarding?.provisioned == true;
    final statusLabel = entitlement.isApplicant
        ? 'Company site setup in progress'
        : 'Complete setup to unlock your site';

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: onRefresh ?? () async {},
          color: AppColors.text(context),
          backgroundColor: AppColors.surface(context),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              Image.asset(
                AppColors.isDark(context)
                    ? 'assets/dark.png'
                    : 'assets/light.png',
                width: 72,
                height: 72,
              ),
              const SizedBox(height: 16),
              const HeevyBrandTitle(textAlign: TextAlign.start),
              const SizedBox(height: 8),
              Text(
                HeevyBrand.setupTagline,
                style: TextStyle(color: muted, fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 20),
              HeevyStatusCard(
                title: statusLabel,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (entitlement.onboarding != null)
                      OnboardingStatusChip(
                        onboarding: entitlement.onboarding!,
                        onTap: () => DeepLinkHandler.openSetupPortal(),
                      )
                    else if (entitlement.applicationId != null)
                      Text(
                        'Application in progress',
                        style: TextStyle(color: muted, fontSize: 13),
                      )
                    else
                      Text(
                        'Complete site setup on the web to unlock captures for your team.',
                        style: TextStyle(color: muted, fontSize: 13, height: 1.35),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Get started',
                style: TextStyle(
                  color: AppColors.text(context),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Employees: use Join company on the login screen — your employer provisions access.',
                style: TextStyle(color: muted, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 12),
              HeevyListTile(
                step: 1,
                icon: Icons.add_a_photo_outlined,
                title: 'Try quick capture',
                subtitle: 'Log a defect with a photo while your site is being set up.',
                onTap: onContinueToApp,
              ),
              const SizedBox(height: 10),
              HeevyListTile(
                step: 2,
                icon: Icons.cloud_upload_outlined,
                title: 'Upload asset data on web',
                subtitle: 'Finish site readiness, validation, and provisioning.',
                onTap: () => DeepLinkHandler.openSetupPortal(),
              ),
              if (provisioned)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: HeevyListTile(
                    step: 3,
                    icon: Icons.fact_check_outlined,
                    title: 'Run PM inspections',
                    subtitle: 'Structured templates from your provisioned site.',
                    onTap: onContinueToApp,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: HeevyListTile(
                  step: provisioned ? 4 : 3,
                  icon: Icons.language_outlined,
                  title: 'Apply for a new company site',
                  subtitle:
                      'Organization owners: complete the web application. Heevy provisions your site after approval.',
                  onTap: () => DeepLinkHandler.openApplyOnWeb(),
                ),
              ),
              const SizedBox(height: 28),
              HeevyPrimaryButton(
                label: 'Continue to app',
                onTap: onContinueToApp,
              ),
              const SizedBox(height: 12),
              HeevySecondaryButton(
                label: 'Open setup portal',
                onTap: () => DeepLinkHandler.openSetupPortal(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
