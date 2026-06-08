import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/culture_dto.dart';
import '../../../core/providers.dart';
import '../../../widgets/app_card.dart';
import '../../../core/theme/app_theme.dart';

class BirthdayBadge extends ConsumerWidget {
  const BirthdayBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = ref.watch(birthdaysUpcomingProvider(7));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return upcoming.when(
      data: (list) {
        final count = list.length;
        return AppCard(
          onTap: () => _showUpcomingSheet(context, list),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
                ),
                child: Icon(Icons.cake_outlined, color: colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '🎂 $count birthdays this week',
                  style: theme.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const Icon(Icons.keyboard_arrow_up_rounded),
            ],
          ),
        );
      },
      loading: () => AppCard(
        child: Row(
          children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: AppSpacing.sm),
            Text('Loading birthdays', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      error: (err, _) => AppCard(
        child: Text('Birthday API error', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error)),
      ),
    );
  }

  void _showUpcomingSheet(BuildContext context, List<BirthdayEmployeeDto> list) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.paddingBottomSafe + AppSpacing.md),
          child: ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (c, i) {
              final e = list[i];
              return ListTile(
                leading: const CircleAvatar(child: Text('🎂')),
                title: Text(e.name),
                subtitle: Text(e.department ?? '-'),
                trailing: Text(e.birthdayDate ?? ''),
              );
            },
          ),
        );
      },
    );
  }
}
