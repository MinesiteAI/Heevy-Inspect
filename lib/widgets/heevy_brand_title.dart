import 'package:flutter/material.dart';

import '../config/heevy_brand.dart';
import '../theme/app_colors.dart';

class HeevyBrandTitle extends StatelessWidget {
  const HeevyBrandTitle({super.key, this.textAlign = TextAlign.center});

  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: textAlign,
      text: TextSpan(
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.text(context),
          height: 1.15,
        ),
        children: [
          TextSpan(text: '${HeevyBrand.lineHeevy} '),
          TextSpan(
            text: HeevyBrand.lineInspect,
            style: const TextStyle(color: HeevyBrand.accent),
          ),
        ],
      ),
    );
  }
}
