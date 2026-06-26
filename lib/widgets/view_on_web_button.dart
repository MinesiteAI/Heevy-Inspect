import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';

class ViewOnWebButton extends StatelessWidget {
  const ViewOnWebButton({
    super.key,
    required this.uri,
    this.label = 'View on web',
  });

  final Uri uri;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => launchUrl(uri, mode: LaunchMode.externalApplication),
      icon: Icon(Icons.open_in_new, size: 18, color: AppColors.textMuted(context)),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text(context),
        side: BorderSide(color: AppColors.border(context)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
