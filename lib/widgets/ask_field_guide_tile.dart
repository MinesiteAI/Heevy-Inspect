import 'package:flutter/material.dart';

import '../features/chat/field_guide_screen.dart';
import 'heevy_ui.dart';

/// Contextual Field Guide entry — same pattern on capture, WR, and WO detail.
class AskFieldGuideTile extends StatelessWidget {
  const AskFieldGuideTile({
    super.key,
    required this.subtitle,
    this.sourceType,
    this.sourceId,
  });

  final String subtitle;
  final String? sourceType;
  final String? sourceId;

  @override
  Widget build(BuildContext context) {
    return HeevyListTile(
      icon: Icons.psychology_outlined,
      title: 'Ask Field Guide',
      subtitle: subtitle,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FieldGuideScreen(
              sourceType: sourceType,
              sourceId: sourceId,
            ),
          ),
        );
      },
    );
  }
}
