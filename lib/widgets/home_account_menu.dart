import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/field_copy.dart';
import '../theme/app_colors.dart';
import '../theme/theme_mode.dart';

/// Overflow menu: theme toggle and sign-out (with confirm).
class HomeAccountMenu extends StatelessWidget {
  const HomeAccountMenu({
    super.key,
    required this.themeMode,
    required this.siteName,
  });

  final ThemeMode themeMode;
  final String? siteName;

  Future<void> _confirmSignOut(BuildContext context) async {
    final site = siteName?.trim() ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(ctx),
        title: Text(
          FieldCopy.signOutConfirmTitle,
          style: TextStyle(color: AppColors.text(ctx)),
        ),
        content: Text(
          FieldCopy.signOutConfirmBody(site),
          style: TextStyle(color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              FieldCopy.signOut,
              style: TextStyle(color: AppColors.text(ctx)),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await Supabase.instance.client.auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeMode == ThemeMode.dark;
    return PopupMenuButton<String>(
      tooltip: 'Account',
      icon: Icon(Icons.more_vert, color: AppColors.textMuted(context)),
      color: AppColors.surface(context),
      onSelected: (value) async {
        switch (value) {
          case 'theme':
            setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
          case 'sign_out':
            await _confirmSignOut(context);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'theme',
          child: Row(
            children: [
              Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: 20,
                color: AppColors.textMuted(context),
              ),
              const SizedBox(width: 12),
              Text(
                isDark ? FieldCopy.themeLight : FieldCopy.themeDark,
                style: TextStyle(color: AppColors.text(context)),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'sign_out',
          child: Row(
            children: [
              Icon(Icons.logout, size: 20, color: AppColors.textMuted(context)),
              const SizedBox(width: 12),
              Text(
                FieldCopy.signOut,
                style: TextStyle(color: AppColors.text(context)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
