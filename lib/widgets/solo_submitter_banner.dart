import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// True when every row in the team list was created by [userId] only.
bool isSoloSubmitterOnSite(
  List<Map<String, dynamic>> teamItems,
  String? userId,
) {
  if (userId == null || userId.isEmpty || teamItems.isEmpty) return false;
  final creators = teamItems
      .map((r) => r['created_by']?.toString().trim())
      .where((s) => s != null && s.isNotEmpty)
      .cast<String>()
      .toSet();
  return creators.length == 1 && creators.first == userId;
}

class SoloSubmitterBanner extends StatelessWidget {
  const SoloSubmitterBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          "You're the only submitter on this site so far — Site team will show crew once others log.",
          style: TextStyle(
            color: AppColors.textMuted(context),
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
