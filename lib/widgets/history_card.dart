import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shared surface card for capture history and work request lists.
class HistoryCard extends StatelessWidget {
  const HistoryCard({
    super.key,
    required this.icon,
    required this.title,
    this.lines = const [],
    this.onTap,
  });

  final IconData icon;
  final String title;
  final List<HistoryCardLine> lines;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: AppColors.textMuted(context),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.text(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    for (final line in lines) ...[
                      const SizedBox(height: 4),
                      Text(
                        line.text,
                        maxLines: line.maxLines,
                        overflow: line.maxLines != null
                            ? TextOverflow.ellipsis
                            : null,
                        style: _lineStyle(context, line.style),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _lineStyle(BuildContext context, HistoryCardLineStyle style) {
    switch (style) {
      case HistoryCardLineStyle.faint:
        return TextStyle(
          color: AppColors.textFaint(context),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        );
      case HistoryCardLineStyle.muted:
        return TextStyle(
          color: AppColors.textMuted(context),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        );
      case HistoryCardLineStyle.body:
        return TextStyle(
          color: AppColors.muted,
          fontSize: 13,
          height: 1.35,
        );
      case HistoryCardLineStyle.date:
        return TextStyle(
          color: AppColors.textFaint(context),
          fontSize: 12,
        );
    }
  }
}

class HistoryCardLine {
  const HistoryCardLine(
    this.text, {
    this.style = HistoryCardLineStyle.muted,
    this.maxLines,
  });

  final String text;
  final HistoryCardLineStyle style;
  final int? maxLines;
}

enum HistoryCardLineStyle { faint, muted, body, date }

String formatHistoryDate(String raw) {
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  final local = dt.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}
