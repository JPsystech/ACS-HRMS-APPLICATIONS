import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

class WorkModeIndicator extends ConsumerWidget {
  const WorkModeIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profile = ref.watch(profileProvider).valueOrNull;

    String mode = 'OFFICE';
    String label = '🟢 Office Mode';
    Color bg = colorScheme.primaryContainer;
    Color fg = colorScheme.onPrimaryContainer;

    final role = profile?.role;
    final workMode = (profile?.workMode ?? '').toUpperCase();
    final leadership = role != null && role.rank <= 3;
    final field = workMode.contains('SITE') || workMode.contains('FIELD');
    final hybrid = (profile?.wfhEnabled ?? false) && !field && !leadership;

    if (leadership) {
      mode = 'LEADERSHIP';
      label = '🟣 Leadership Mode';
      bg = colorScheme.secondaryContainer;
      fg = colorScheme.onSecondaryContainer;
    } else if (field) {
      mode = 'FIELD';
      label = '🔵 Field Mode';
      bg = colorScheme.tertiaryContainer;
      fg = colorScheme.onTertiaryContainer;
    } else if (hybrid) {
      mode = 'HYBRID';
      label = '🟢 Office / Remote';
      bg = colorScheme.primaryContainer;
      fg = colorScheme.onPrimaryContainer;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppDimensions.cardRadiusSmall),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: fg.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                mode,
                style: theme.textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
