import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/acs_theme_ext.dart';

/// Status for chips (leave, attendance, etc.).
enum AppStatus {
  pending,
  approved,
  rejected,
  cancelled,
  revoked,
  success,
  warning,
  error,
  info,
}

/// Reusable status chip — Pending / Approved / Rejected and semantic statuses.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.status,
    this.label,
    this.isSelected = false,
  });

  final AppStatus status;
  final String? label;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final acsTheme = theme.acs;
    final text = label ?? _defaultLabel;
    final bg = isSelected 
        ? colorScheme.primaryContainer
        : _backgroundColor(colorScheme, acsTheme);
    final fg = isSelected 
        ? colorScheme.onPrimaryContainer
        : _foregroundColor(colorScheme, acsTheme);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(
          color: colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: fg,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  String get _defaultLabel {
    switch (status) {
      case AppStatus.pending:
        return 'Pending';
      case AppStatus.approved:
        return 'Approved';
      case AppStatus.rejected:
        return 'Rejected';
      case AppStatus.cancelled:
        return 'Cancelled';
      case AppStatus.revoked:
        return 'Revoked';
      case AppStatus.success:
        return 'Success';
      case AppStatus.warning:
        return 'Warning';
      case AppStatus.error:
        return 'Error';
      case AppStatus.info:
        return 'Info';
    }
  }

  Color _backgroundColor(ColorScheme scheme, ACSThemeExtension acsTheme) {
    switch (status) {
      case AppStatus.pending:
        return Colors.amber.shade100;
      case AppStatus.approved:
      case AppStatus.success:
        return Colors.green.shade100;
      case AppStatus.rejected:
      case AppStatus.error:
        return Colors.red.shade100;
      case AppStatus.cancelled:
      case AppStatus.revoked:
      case AppStatus.info:
        return scheme.surfaceContainerHighest;
      case AppStatus.warning:
        return scheme.errorContainer.withValues(alpha: 0.1);
    }
  }

  Color _foregroundColor(ColorScheme scheme, ACSThemeExtension acsTheme) {
    switch (status) {
      case AppStatus.pending:
        return Colors.amber.shade900;
      case AppStatus.approved:
      case AppStatus.success:
        return Colors.green.shade900;
      case AppStatus.rejected:
      case AppStatus.error:
        return Colors.red.shade900;
      case AppStatus.cancelled:
      case AppStatus.revoked:
      case AppStatus.info:
        return scheme.onSurfaceVariant;
      case AppStatus.warning:
        return scheme.error;
    }
  }
}
