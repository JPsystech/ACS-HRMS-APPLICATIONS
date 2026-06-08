import 'package:flutter/material.dart';
import '../../../widgets/app_card.dart';
import '../../../core/theme/app_theme.dart';

class FieldToolsWidget extends StatelessWidget {
  const FieldToolsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.work_outline_rounded,
                  color: colorScheme.primary, size: AppDimensions.iconMd),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Field Tools',
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: const [
              _ToolChip(icon: Icons.place_rounded, label: 'Punch (Location)'),
              _ToolChip(
                  icon: Icons.assignment_rounded, label: 'Today’s Assignment'),
              _ToolChip(
                  icon: Icons.photo_camera_back_rounded,
                  label: 'Upload Photos'),
              _ToolChip(icon: Icons.checklist_rounded, label: 'Checklist'),
              _ToolChip(
                  icon: Icons.emoji_transportation_rounded,
                  label: 'Travel Mode'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppDimensions.cardRadiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: AppDimensions.iconSm, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}
