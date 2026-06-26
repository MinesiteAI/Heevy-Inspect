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
  });

  final String? sourceType;
  final String? sourceId;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      tooltip: 'Field guide',
      onPressed: () async {
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
      },
      backgroundColor: AppColors.text(context),
      child: Icon(Icons.smart_toy_outlined, color: AppColors.bg(context)),
    );
  }
}
