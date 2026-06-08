import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';

/// Primary app button with optional loading state, icon, and large touch target.
/// Safe for use in Row/Column/SliverList/Center contexts - never forces infinite width.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.variant = AppButtonVariant.filled,
    this.fullWidth = false,
    this.isMainCTA = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;
  final AppButtonVariant variant;
  final bool fullWidth;
  final bool isMainCTA;

  void _onTap() {
    HapticFeedback.lightImpact();
    onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget button;
    switch (variant) {
      case AppButtonVariant.filled:
        if (isMainCTA) {
          // Gradient main CTA button
          button = Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                  theme.colorScheme.tertiary,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: FilledButton(
              onPressed: isLoading ? null : _onTap,
              style: _filledStyle(context, isMainCTA),
              child: _child(context, colorScheme.onPrimary),
            ),
          );
        } else {
          button = FilledButton(
            onPressed: isLoading ? null : _onTap,
            style: _filledStyle(context, isMainCTA),
            child: _child(context, colorScheme.onPrimary),
          );
        }
        break;
      case AppButtonVariant.tonal:
        button = FilledButton.tonal(
          onPressed: isLoading ? null : _onTap,
          style: _tonalStyle(context),
          child: _child(context, colorScheme.onSecondaryContainer),
        );
        break;
      case AppButtonVariant.outlined:
        button = OutlinedButton(
          onPressed: isLoading ? null : _onTap,
          style: _outlinedStyle(context),
          child: _child(context, colorScheme.primary),
        );
        break;
      case AppButtonVariant.primary:
        button = FilledButton(
          onPressed: isLoading ? null : _onTap,
          style: _filledStyle(context, false),
          child: _child(context, colorScheme.onPrimary),
        );
        break;
    }

    // Wrap in SizedBox to control height only
    final sizedButton = SizedBox(
      height: 52,
      child: button,
    );

    if (!fullWidth) return sizedButton;

    // Safe full width: only if parent provides finite maxWidth
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        if (maxW.isFinite) {
          return SizedBox(width: maxW, child: sizedButton);
        }
        // If width is unbounded (infinite), do NOT force infinity.
        // This prevents "BoxConstraints forces an infinite width" errors
        return sizedButton;
      },
    );
  }

  ButtonStyle _filledStyle(BuildContext context, bool isMainCTA) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (isMainCTA) {
      // Gradient for main CTA
      return FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: null, // Use gradient overlay
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        shadowColor: Colors.transparent,
        textStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      );
    }
    
    return FilledButton.styleFrom(
      minimumSize: const Size(0, 52),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 0,
      shadowColor: Colors.transparent,
      textStyle: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  ButtonStyle _tonalStyle(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return FilledButton.styleFrom(
      minimumSize: const Size(0, 52),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: colorScheme.secondaryContainer,
      foregroundColor: colorScheme.onSecondaryContainer,
      elevation: 0,
      shadowColor: Colors.transparent,
      textStyle: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    ).copyWith(
      overlayColor: WidgetStateProperty.all(colorScheme.primary.withValues(alpha: 0.1)),
    );
  }

  ButtonStyle _outlinedStyle(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return OutlinedButton.styleFrom(
      minimumSize: const Size(0, 52),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outline, width: 1),
      ),
      backgroundColor: Colors.transparent,
      foregroundColor: colorScheme.primary,
      elevation: 0,
      shadowColor: Colors.transparent,
      textStyle: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _child(BuildContext context, Color color) {
    if (isLoading) {
      return SizedBox(
        height: AppDimensions.iconMd,
        width: AppDimensions.iconMd,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      );
    }
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon!,
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      );
    }
    return Text(
      label,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
}

enum AppButtonVariant { filled, tonal, outlined, primary }
