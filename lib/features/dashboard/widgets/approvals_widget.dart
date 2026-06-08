import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers.dart';
import '../../../widgets/app_card.dart';
import '../../../core/theme/app_theme.dart';

class ApprovalsWidget extends ConsumerWidget {
  const ApprovalsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canApprove = ref.watch(canApproveLeavesProvider);
    if (!canApprove) return const SizedBox.shrink();
    final countAsync = ref.watch(pendingApprovalsCountProvider);
    final attnCountAsync = ref.watch(pendingAttendanceCorrectionsProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.approval_rounded, color: colorScheme.primary, size: AppDimensions.iconMd),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Approvals',
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          InkWell(
            onTap: () => context.push('/leave/pending-approvals'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 16, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: countAsync.when(
                      data: (n) => Text(
                        n > 0 ? '$n pending leave(s)' : 'No pending leaves',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: n > 0 ? colorScheme.primary : colorScheme.onSurfaceVariant,
                          fontWeight: n > 0 ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      loading: () => const Text('…'),
                      error: (e, _) => const Text('!'),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
          const Divider(height: AppSpacing.md),
          InkWell(
            onTap: () => context.push('/attendance/pending-approvals'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, size: 16, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: attnCountAsync.when(
                      data: (items) {
                        final n = items.where((i) => i.status.toUpperCase() == 'PENDING').length;
                        return Text(
                          n > 0 ? '$n pending correction(s)' : 'No pending corrections',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: n > 0 ? colorScheme.primary : colorScheme.onSurfaceVariant,
                            fontWeight: n > 0 ? FontWeight.w600 : FontWeight.normal,
                          ),
                        );
                      },
                      loading: () => const Text('…'),
                      error: (e, _) => const Text('!'),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
