import 'package:flutter/material.dart';

import '../config/heevy_brand.dart';
import '../theme/app_colors.dart';

/// Stacked "Heevy" / "Inspect" lockup for auth and chrome.
class HeevyBrandTitle extends StatelessWidget {
  const HeevyBrandTitle({
    super.key,
    this.compact = false,
    this.textAlign = TextAlign.center,
  });

  final bool compact;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final heevySize = compact ? 20.0 : 30.0;
    final inspectSize = compact ? 15.0 : 19.0;
    final lineHeight = compact ? 1.05 : 1.0;

    return Column(
      crossAxisAlignment: textAlign == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          HeevyBrand.lineHeevy,
          textAlign: textAlign,
          style: TextStyle(
            color: AppColors.text(context),
            fontSize: heevySize,
            fontWeight: FontWeight.w700,
            letterSpacing: compact ? -0.2 : -0.5,
            height: lineHeight,
          ),
        ),
        Text(
          HeevyBrand.lineInspect,
          textAlign: textAlign,
          style: TextStyle(
            color: HeevyBrand.accent,
            fontSize: inspectSize,
            fontWeight: FontWeight.w600,
            letterSpacing: compact ? 0.1 : 0.2,
            height: lineHeight,
          ),
        ),
      ],
    );
  }
}
