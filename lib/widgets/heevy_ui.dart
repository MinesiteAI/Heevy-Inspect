import 'package:flutter/material.dart';

import '../config/heevy_brand.dart';
import '../theme/app_colors.dart';

const double heevyRadius = 16;

class HeevyPrimaryButton extends StatelessWidget {
  const HeevyPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return _buttonShell(
      onTap: loading ? null : onTap,
      color: AppColors.inverseBg(context),
      child: loading
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor:
                    AlwaysStoppedAnimation(AppColors.inverseText(context)),
              ),
            )
          : Text(
              label,
              style: TextStyle(
                color: AppColors.inverseText(context),
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
}

class HeevySecondaryButton extends StatelessWidget {
  const HeevySecondaryButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _buttonShell(
      onTap: onTap,
      color: AppColors.surface(context),
      borderColor: AppColors.border(context),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.text(context),
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class HeevyField extends StatelessWidget {
  const HeevyField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.trailing,
    this.onSubmitted,
    this.autocorrect = true,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? trailing;
  final ValueChanged<String>? onSubmitted;
  final bool autocorrect;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final fieldColor = AppColors.surfaceAlt(context);
    final multiline = maxLines > 1;

    return Container(
      constraints: multiline ? null : const BoxConstraints(minHeight: 56),
      decoration: BoxDecoration(
        color: fieldColor,
        borderRadius: BorderRadius.circular(heevyRadius),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        crossAxisAlignment:
            multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: multiline ? 18 : 0),
            child: Icon(icon, color: AppColors.textMuted(context), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              maxLines: maxLines,
              textInputAction:
                  obscure ? TextInputAction.done : TextInputAction.next,
              autocorrect: autocorrect,
              enableSuggestions: !obscure,
              onSubmitted: onSubmitted,
              style: TextStyle(color: AppColors.text(context), fontSize: 16),
              cursorColor: AppColors.text(context),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: AppColors.textFaint(context),
                  fontSize: 16,
                ),
                border: InputBorder.none,
                isCollapsed: !multiline,
                contentPadding: EdgeInsets.symmetric(
                  vertical: multiline ? 16 : 18,
                ),
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class HeevyModeChip extends StatelessWidget {
  const HeevyModeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? HeevyBrand.accent : AppColors.surfaceAlt(context),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.black : AppColors.text(context),
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HeevyListTile extends StatelessWidget {
  const HeevyListTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = false,
    this.step,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool accent;
  final int? step;

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
            children: [
              Icon(
                icon,
                color: accent ? HeevyBrand.accent : AppColors.textMuted(context),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (step != null)
                      Text(
                        'Step $step',
                        style: TextStyle(
                          color: AppColors.textMuted(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    if (step != null) const SizedBox(height: 2),
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.text(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textFaint(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class HeevyBrandedAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HeevyBrandedAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
  });

  final String? title;
  final List<Widget>? actions;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.bg(context),
      foregroundColor: AppColors.text(context),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: leading,
      title: title != null
          ? Text(
              title!,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
            )
          : Image.asset(
              AppColors.isDark(context) ? 'assets/dark.png' : 'assets/light.png',
              height: 28,
            ),
      centerTitle: title != null,
      actions: actions,
    );
  }
}

class HeevyEmptyState extends StatelessWidget {
  const HeevyEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textFaint(context)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.text(context),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HeevyStatusCard extends StatelessWidget {
  const HeevyStatusCard({
    super.key,
    required this.title,
    this.child,
  });

  final String title;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.text(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (child != null) ...[
            const SizedBox(height: 12),
            child!,
          ],
        ],
      ),
    );
  }
}

Widget _buttonShell({
  required VoidCallback? onTap,
  required Color color,
  required Widget child,
  Color? borderColor,
}) {
  return Material(
    color: color,
    borderRadius: BorderRadius.circular(heevyRadius),
    child: InkWell(
      borderRadius: BorderRadius.circular(heevyRadius),
      onTap: onTap,
      child: Container(
        height: 56,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(heevyRadius),
          border: borderColor != null
              ? Border.all(color: borderColor, width: 1)
              : null,
        ),
        child: child,
      ),
    ),
  );
}
