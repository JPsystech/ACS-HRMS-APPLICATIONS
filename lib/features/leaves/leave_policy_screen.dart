import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/fade_in_wrapper.dart';
import '../../widgets/acs/acs_stat_tile.dart';
import '../../widgets/acs/acs_section.dart';

/// Leave policy per year: PL, CL, SL, RH, Company Holiday Calendar.
class LeavePolicyScreen extends ConsumerWidget {
  const LeavePolicyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policyAsync = ref.watch(leavePolicyProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final refreshKey = RefreshKeysScope.of(context)?.keyFor(2);

    return FadeInWrapper(
      child: Scaffold(
        backgroundColor: theme.colorScheme.background,
        appBar: AppBar(
          title: const Text('Leave Policy'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: RefreshIndicator(
          key: refreshKey,
          onRefresh: () async {
            ref.invalidate(leavePolicyProvider);
            ref.invalidate(leaveBalanceProvider);
            ref.invalidate(leaveBalanceSummaryProvider);
            ref.invalidate(myLeavesProvider);
            await ref.read(leavePolicyProvider.future);
          },
          child: ListView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.of(context).viewPadding.bottom,
            ),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // Top Summary Card
              policyAsync.when(
                data: (policy) => AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Annual Leave Entitlements',
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your leave benefits for this year',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          ACSStatTile(
                            title: 'Total PL',
                            value: policy.pl.toString(),
                            icon: Icons.work_outline_rounded,
                            backgroundColor: colorScheme.primaryContainer,
                          ),
                          ACSStatTile(
                            title: 'Total SL',
                            value: policy.sl.toString(),
                            icon: Icons.medical_services_outlined,
                            backgroundColor: colorScheme.secondaryContainer,
                          ),
                          ACSStatTile(
                            title: 'Total CL',
                            value: policy.cl.toString(),
                            icon: Icons.beach_access_rounded,
                            backgroundColor: colorScheme.tertiaryContainer,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                loading: () => AppCard(
                  padding: const EdgeInsets.all(16),
                  child: const LinearProgressIndicator(),
                ),
                error: (error, _) => AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Failed to load policy summary',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Leave Types Section
              ACSSection(
                title: 'Leave Types',
                padding: const EdgeInsets.only(bottom: 16),
              ),
              policyAsync.when(
                data: (policy) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PolicyTile(
                      label: 'Paid Leave (PL)',
                      days: policy.pl,
                      theme: theme,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 16),
                    _PolicyTile(
                      label: 'Sick Leave (SL)',
                      days: policy.sl,
                      theme: theme,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 16),
                    _PolicyTile(
                      label: 'Casual Leave (CL)',
                      days: policy.cl,
                      theme: theme,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 16),
                    _PolicyTile(
                      label: 'Restricted Holiday (RH)',
                      days: policy.rh,
                      theme: theme,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 16),
                    _PolicyTile(
                      label: 'Company Holiday Calendar',
                      days: policy.publicHolidays,
                      theme: theme,
                      colorScheme: colorScheme,
                      subtitle: 'Public holidays',
                    ),
                  ],
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (err, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Could not load policy. Pull to refresh.',
                    style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicyTile extends StatelessWidget {
  const _PolicyTile({
    required this.label,
    required this.days,
    required this.theme,
    required this.colorScheme,
    this.subtitle,
  });

  final String label;
  final int days;
  final ThemeData theme;
  final ColorScheme colorScheme;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = theme.textTheme;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$days ${days == 1 ? 'Day' : 'Days'}',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
