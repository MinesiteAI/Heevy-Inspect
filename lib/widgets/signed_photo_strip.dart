import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Horizontal strip of signed network photos with graceful error placeholders.
class SignedPhotoStrip extends StatelessWidget {
  const SignedPhotoStrip({
    super.key,
    required this.urlsFuture,
    this.height = 120,
    this.itemSize = 120,
  });

  final Future<List<String>> urlsFuture;
  final double height;
  final double itemSize;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: urlsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: height,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textMuted(context),
                ),
              ),
            ),
          );
        }
        final urls = snapshot.data ?? [];
        if (urls.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: urls.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                urls[i],
                width: itemSize,
                height: itemSize,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _photoPlaceholder(context),
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _photoPlaceholder(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      color: AppColors.surfaceAlt(context),
      child: Icon(
        Icons.broken_image_outlined,
        color: AppColors.textMuted(context),
      ),
    );
  }
}
