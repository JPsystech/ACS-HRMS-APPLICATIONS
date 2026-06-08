import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Unified footer branding for Login, Profile, and other auth/settings screens.
class AppFooter extends StatelessWidget {
  const AppFooter({
    super.key,
    this.text = 'Developed & Designed by JPSystech',
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
