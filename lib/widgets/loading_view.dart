import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Full-screen or inline loading indicator with optional message.
class LoadingView extends StatelessWidget {
  const LoadingView({
    super.key,
    this.message,
    this.compact = false,
  });

  final String? message;
  /// If true, uses smaller padding and no full-screen centering.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(
          strokeWidth: 2,
          color: theme.colorScheme.primary,
        ),
        if (message != null && message!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            message!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: content,
      );
    }
    return Center(child: content);
  }
}
