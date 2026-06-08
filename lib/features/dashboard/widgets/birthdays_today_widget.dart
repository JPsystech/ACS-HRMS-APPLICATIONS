import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/culture_dto.dart';
import '../../../core/providers.dart';
import '../../../widgets/app_card.dart';
import '../../../core/theme/app_theme.dart';

class BirthdaysTodayWidget extends ConsumerWidget {
  const BirthdaysTodayWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(birthdaysTodayProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.celebration, color: colorScheme.primary, size: AppDimensions.iconMd),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Today’s Birthdays',
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          async.when(
            data: (list) {
              if (list.isEmpty) {
                return Text(
                  'No birthdays today',
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                );
              }
              return Column(
                children: list.map((e) => _BirthdayTile(e: e)).toList(),
              );
            },
            loading: () => const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            error: (err, _) => Text(
              'Birthday API error',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _BirthdayTile extends ConsumerWidget {
  const _BirthdayTile({required this.e});

  final BirthdayEmployeeDto e;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        child: Text(e.name.isNotEmpty ? e.name[0].toUpperCase() : '?'),
      ),
      title: Text(e.name, overflow: TextOverflow.ellipsis),
      subtitle: Text(e.department ?? '-', overflow: TextOverflow.ellipsis),
      trailing: _Trailing(e: e),
    );
  }
}

class _Trailing extends ConsumerStatefulWidget {
  const _Trailing({required this.e});
  final BirthdayEmployeeDto e;

  @override
  ConsumerState<_Trailing> createState() => _TrailingState();
}

class _TrailingState extends ConsumerState<_Trailing> {
  bool sending = false;
  String? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final current = status ?? widget.e.wishStatus ?? 'Pending';

    if (current.toUpperCase() == 'SENT') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('Sent', style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSecondaryContainer)),
      );
    }

    return ElevatedButton(
      onPressed: sending
          ? null
          : () async {
              final result = await showModalBottomSheet<String?>(
                context: context,
                showDragHandle: true,
                builder: (ctx) {
                  String text = '';
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          decoration: const InputDecoration(labelText: 'Wish message (optional)'),
                          onChanged: (v) => text = v,
                          maxLines: 3,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(ctx).pop(text),
                            child: const Text('Send'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
              if (result == null) return;
              try {
                setState(() => sending = true);
                final service = ref.read(cultureServiceProvider);
                final res = await service.sendWish(widget.e.employeeId, wishMessage: result);
                setState(() {
                  sending = false;
                  status = 'Sent';
                });
                // Refresh birthday providers to reflect latest status
                ref.invalidate(birthdaysTodayProvider);
                ref.invalidate(birthdaysUpcomingProvider(7));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wish sent')));
                }
              } catch (e) {
                setState(() => sending = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              }
            },
      child: sending ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Send Wish'),
    );
  }
}
