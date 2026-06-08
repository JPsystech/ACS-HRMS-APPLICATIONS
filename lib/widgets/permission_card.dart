import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'app_button.dart';
import 'app_card.dart';

/// Reusable permission card: icon, title, short explanation, "Allow" button.
/// When [isGranted] is true, shows granted state (checkmark, no Allow button).
class PermissionCard extends StatelessWidget {
  const PermissionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.explanation,
    required this.isGranted,
    this.onAllow,
  });

  final IconData icon;
  final String title;
  final String explanation;
  final bool isGranted;
  final VoidCallback? onAllow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: isGranted
                  ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isGranted ? Icons.check_circle_rounded : icon,
              size: 28,
              color: isGranted ? colorScheme.primary : colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  explanation,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (!isGranted) ...[
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'Allow',
                      onPressed: onAllow,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Granted',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
