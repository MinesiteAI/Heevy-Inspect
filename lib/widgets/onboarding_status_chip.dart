import 'package:flutter/material.dart';

import '../billing/entitlement_service.dart';
import '../theme/app_colors.dart';

class OnboardingStatusChip extends StatelessWidget {
  const OnboardingStatusChip({
    super.key,
    required this.onboarding,
    this.onTap,
    this.compact = false,
  });

  final OnboardingStatus onboarding;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = onboarding.provisioned
        ? 'Site live'
        : '${onboarding.stageLabel} · ${onboarding.uploadsCount}/${onboarding.uploadsTarget} uploads';

    final child = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            onboarding.provisioned
                ? Icons.check_circle_outline
                : Icons.cloud_upload_outlined,
            size: 16,
            color:
                onboarding.provisioned ? Colors.green.shade600 : AppColors.muted,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textMuted(context),
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: AppColors.muted),
          ],
        ],
      ),
    );

    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: child,
      ),
    );
  }
}
