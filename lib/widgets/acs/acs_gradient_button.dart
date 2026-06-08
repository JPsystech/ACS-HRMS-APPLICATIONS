import 'package:flutter/material.dart';

import '../../core/theme/acs_theme_ext.dart';
import '../../core/theme/app_theme.dart';

/// ACS Gradient Button for primary CTA actions
class ACSGradientButton extends StatelessWidget {
  const ACSGradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.minimumSize = const Size.fromHeight(AppDimensions.buttonMinHeight),
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    this.borderRadius,
    this.disabled = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Size? minimumSize;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final acsTheme = theme.acs;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: disabled
            ? LinearGradient(
                colors: [
                  Colors.grey.shade400,
                  Colors.grey.shade500,
                ],
              )
            : acsTheme.gradientPrimary,
        borderRadius: borderRadius ?? BorderRadius.circular(AppRadii.md),
      ),
      child: ElevatedButton(
        onPressed: disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          minimumSize: minimumSize,
          padding: padding,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius ?? BorderRadius.circular(AppRadii.md),
          ),
          foregroundColor: Colors.white,
          textStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        child: child,
      ),
    );
  }
}