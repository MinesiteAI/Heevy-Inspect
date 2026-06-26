import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Mine vs team toggle for supervisors viewing org-scoped lists.
class TeamScopeTabs extends StatelessWidget {
  const TeamScopeTabs({
    super.key,
    required this.scope,
    required this.onScopeChanged,
    this.teamLabel = 'Team',
    this.mineLabel = 'Mine',
  });

  final String scope;
  final ValueChanged<String> onScopeChanged;
  final String teamLabel;
  final String mineLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: SegmentedButton<String>(
        segments: [
          ButtonSegment(value: 'mine', label: Text(mineLabel)),
          ButtonSegment(value: 'team', label: Text(teamLabel)),
        ],
        selected: {scope},
        onSelectionChanged: (s) => onScopeChanged(s.first),
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.text(context);
            }
            return AppColors.textMuted(context);
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.surfaceAlt(context);
            }
            return AppColors.surface(context);
          }),
        ),
      ),
    );
  }
}
