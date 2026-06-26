import 'package:flutter/material.dart';

import '../analytics/inspect_analytics.dart';
import '../../theme/app_colors.dart';
import '../features/chat/field_guide_screen.dart';

/// Persistent chat entry point for Field Guide (replaces home list tile).
class FieldGuideFab extends StatelessWidget {
  const FieldGuideFab({
    super.key,
    this.sourceType,
    this.sourceId,
    this.compact = false,
  });

  final String? sourceType;
  final String? sourceId;

  /// Home screen: icon + label, no solid fill — easy to spot without blocking content.
  final bool compact;

  Future<void> _open(BuildContext context) async {
    await InspectAnalytics.track('field_guide_fab_open');
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FieldGuideScreen(
          sourceType: sourceType,
          sourceId: sourceId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.textMuted(context).withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.psychology_outlined,
                  size: 22,
                  color: AppColors.text(context),
                ),
                const SizedBox(width: 6),
                Text(
                  'Field Guide',
                  style: TextStyle(
                    color: AppColors.text(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return FloatingActionButton.extended(
      tooltip: 'Ask Field Guide',
      heroTag: 'field_guide_fab',
      onPressed: () => _open(context),
      backgroundColor: AppColors.text(context),
      icon: Icon(Icons.psychology_outlined, color: AppColors.bg(context)),
      label: Text(
        'Ask Field Guide',
        style: TextStyle(
          color: AppColors.bg(context),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
