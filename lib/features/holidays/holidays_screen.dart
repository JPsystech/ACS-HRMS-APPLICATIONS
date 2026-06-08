import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_repository.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/fade_in_wrapper.dart';
import '../../widgets/acs/acs_section.dart';
import '../../widgets/acs/acs_empty_state.dart';

/// Holiday type: Public or Restricted.
enum HolidayType { public, restricted }

/// Single holiday (dummy model).
class Holiday {
  Holiday({
    required this.date,
    required this.name,
    required this.type,
    this.description = '',
    this.imageUrl,
  });

  final DateTime date;
  final String name;
  final HolidayType type;
  final String description;
  final String? imageUrl;

  String get dayName => DateFormat('EEEE').format(date);
  String get dateFormatted => DateFormat('d MMM yyyy').format(date);
  int get month => date.month;
  int get year => date.year;
}

/// Map API HolidayDto to UI Holiday.
Holiday _dtoToHoliday(HolidayDto dto) {
  return Holiday(
    date: dto.date,
    name: dto.name,
    type: dto.type == 'restricted' ? HolidayType.restricted : HolidayType.public,
    description: dto.description,
    imageUrl: dto.imageUrl,
  );
}

/// Month option for dropdown ("All" or 1–12).
class _MonthOption {
  const _MonthOption({this.month, required this.label});
  final int? month; // null = All
  final String label;
}

/// Holidays screen with search, optional month filter, and Public / RH sections.
class HolidaysScreen extends ConsumerStatefulWidget {
  const HolidaysScreen({super.key});

  @override
  ConsumerState<HolidaysScreen> createState() => _HolidaysScreenState();
}

class _HolidaysScreenState extends ConsumerState<HolidaysScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  static const List<_MonthOption> _monthOptions = [
    _MonthOption(month: null, label: 'All months'),
    _MonthOption(month: 1, label: 'January'),
    _MonthOption(month: 2, label: 'February'),
    _MonthOption(month: 3, label: 'March'),
    _MonthOption(month: 4, label: 'April'),
    _MonthOption(month: 5, label: 'May'),
    _MonthOption(month: 6, label: 'June'),
    _MonthOption(month: 7, label: 'July'),
    _MonthOption(month: 8, label: 'August'),
    _MonthOption(month: 9, label: 'September'),
    _MonthOption(month: 10, label: 'October'),
    _MonthOption(month: 11, label: 'November'),
    _MonthOption(month: 12, label: 'December'),
  ];

  _MonthOption _selectedMonth = _monthOptions[0];
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<Holiday> _filter(List<Holiday> list) {
    var result = list;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      result = result.where((h) => h.name.toLowerCase().contains(q)).toList();
    }
    if (_selectedMonth.month != null) {
      result = result.where((h) => h.month == _selectedMonth.month).toList();
    }
    result = List.from(result)..sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  Future<void> _onRefresh() async {
    try {
      // Common leave/profile/attendance invalidations.
      ref.invalidate(leaveBalanceProvider);
      ref.invalidate(leaveBalanceSummaryProvider);
      ref.invalidate(myLeavesProvider);
      ref.invalidate(todaySessionProvider);
      ref.invalidate(todayAttendanceProvider);
      ref.invalidate(profileProvider);
      // Screen-specific holidays.
      ref.invalidate(holidaysProvider);
      await ref.read(holidaysProvider.future);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Holidays updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Refresh failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final holidaysAsync = ref.watch(holidaysProvider);
    final refreshKey = RefreshKeysScope.of(context)?.keyFor(3);

    return FadeInWrapper(
      child: Scaffold(
        backgroundColor: theme.colorScheme.background,
        appBar: AppBar(title: const Text('Holidays')),
        body: RefreshIndicator(
          key: refreshKey,
          onRefresh: _onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Holidays',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Public & Restricted Holidays',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Search bar: filled style, rounded 14-16, leading icon
                      TextField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        decoration: InputDecoration(
                          hintText: 'Search by holiday name',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: colorScheme.surfaceVariant,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: colorScheme.primary),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                      const SizedBox(height: 16),
                      // Replace dropdown with filter chips for months
                      SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _monthOptions.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 16),
                          itemBuilder: (context, index) {
                            final option = _monthOptions[index];
                            return FilterChip(
                              label: Text(option.label),
                              selected: _selectedMonth == option,
                              onSelected: (_) => setState(() => _selectedMonth = option),
                              selectedColor: colorScheme.primaryContainer,
                              labelStyle: TextStyle(
                                color: _selectedMonth == option
                                    ? colorScheme.onPrimaryContainer
                                    : colorScheme.onSurface,
                                fontWeight: _selectedMonth == option ? FontWeight.w600 : FontWeight.normal,
                              ),
                              backgroundColor: colorScheme.surface,
                              side: BorderSide(
                                color: _selectedMonth == option ? colorScheme.primary : colorScheme.outline,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                holidaysAsync.when(
                  data: (dtos) {
                    final all = dtos.map(_dtoToHoliday).toList();
                    final publicFiltered =
                        _filter(all.where((h) => h.type == HolidayType.public).toList());
                    final restrictedFiltered =
                        _filter(all.where((h) => h.type == HolidayType.restricted).toList());
                    final authToken = ref.watch(authProvider).asData?.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ACSSection(
                            title: 'Public Holidays',
                            padding: const EdgeInsets.only(bottom: 16),
                          ),
                          if (publicFiltered.isEmpty)
                            ACSEmptyState(
                              icon: Icons.public_rounded,
                              title: 'No public holidays',
                              subtitle: 'No holidays available for selected month.',
                            )
                          else
                            ...publicFiltered.map((h) => _PublicHolidayCard(
                                   holiday: h,
                                   theme: theme,
                                   colorScheme: colorScheme,
                                   authToken: authToken,
                                 )),
                          const SizedBox(height: 24),
                          ACSSection(
                            title: 'Restricted Holidays (RH)',
                            padding: const EdgeInsets.only(bottom: 16),
                          ),
                          if (restrictedFiltered.isEmpty)
                            ACSEmptyState(
                              icon: Icons.event_rounded,
                              title: 'No restricted holidays',
                              subtitle: 'No RH available this month.',
                            )
                          else
                            ...restrictedFiltered.map((h) => _RestrictedHolidayCard(
                                  holiday: h,
                                  theme: theme,
                                  colorScheme: colorScheme,
                                  authToken: authToken,
                                )),
                          const SizedBox(height: 40),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off_rounded, size: 48, color: colorScheme.error),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Could not load holidays. Check your connection.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Bottom padding for safe area
                SizedBox(height: MediaQuery.of(context).viewPadding.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RestrictedHolidayCard extends StatelessWidget {
  const _RestrictedHolidayCard({
    required this.holiday,
    required this.theme,
    required this.colorScheme,
    required this.authToken,
  });

  final Holiday holiday;
  final ThemeData theme;
  final ColorScheme colorScheme;
  final String? authToken;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            showDragHandle: true,
            builder: (ctx) {
              final bottom = MediaQuery.of(ctx).viewPadding.bottom;
              return SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(holiday.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('${holiday.dayName} • ${holiday.dateFormatted}', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 12),
                      Text(
                        (holiday.description.trim().isNotEmpty) ? holiday.description : 'No additional details.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      if (holiday.imageUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: 120,
                              maxHeight: 300,
                              maxWidth: double.infinity,
                            ),
                            child: Image.network(
                              holiday.imageUrl!,
                              width: double.infinity,
                              fit: BoxFit.contain,
                              headers: {
                                if (authToken != null) 'Authorization': 'Bearer $authToken',
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return SizedBox(
                                  height: 180,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              (loadingProgress.expectedTotalBytes ?? 1)
                                          : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 180,
                                  color: theme.colorScheme.surfaceVariant,
                                  alignment: Alignment.center,
                                  child: Icon(Icons.broken_image_outlined, color: theme.colorScheme.onSurfaceVariant),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date badge (smaller for RH)
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    holiday.date.day.toString(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                  Text(
                    DateFormat('MMM').format(holiday.date),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // RH badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'RH',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Holiday name bold
                  Text(
                    holiday.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 4),
                  // Weekday + date small
                  Text(
                    '${holiday.dayName} • ${holiday.dateFormatted}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Apply button on right
            AppButton(
              label: 'Apply',
              onPressed: () {
                // Navigate to leave application screen with pre-filled restricted holiday date
                context.push('/leave', extra: {
                  'prefilledDate': holiday.date,
                  'leaveType': 'RH',
                });
              },
              variant: AppButtonVariant.outlined,
            ),
          ],
        ),
      ),),
    );
  }
}

class _PublicHolidayCard extends StatelessWidget {
  const _PublicHolidayCard({
    required this.holiday,
    required this.theme,
    required this.colorScheme,
    required this.authToken,
  });

  final Holiday holiday;
  final ThemeData theme;
  final ColorScheme colorScheme;
  final String? authToken;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            showDragHandle: true,
            builder: (ctx) {
              final bottom = MediaQuery.of(ctx).viewPadding.bottom;
              return SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(holiday.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('${holiday.dayName} • ${holiday.dateFormatted}', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 12),
                      Text(
                        (holiday.description.trim().isNotEmpty) ? holiday.description : 'No additional details.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      if (holiday.imageUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: 120,
                              maxHeight: 300,
                              maxWidth: double.infinity,
                            ),
                            child: Image.network(
                              holiday.imageUrl!,
                              width: double.infinity,
                              fit: BoxFit.contain,
                              headers: {
                                if (authToken != null) 'Authorization': 'Bearer $authToken',
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return SizedBox(
                                  height: 180,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              (loadingProgress.expectedTotalBytes ?? 1)
                                          : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 180,
                                  color: theme.colorScheme.surfaceVariant,
                                  alignment: Alignment.center,
                                  child: Icon(Icons.broken_image_outlined, color: theme.colorScheme.onSurfaceVariant),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date badge (big day number + month)
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    holiday.date.day.toString(),
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    DateFormat('MMM').format(holiday.date),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Holiday name bold
                  Text(
                    holiday.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  // Weekday + date small
                  Text(
                    '${holiday.dayName} • ${holiday.dateFormatted}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),),
    );
  }
}

// ignore: unused_element
class _HolidayCard extends StatelessWidget {
  const _HolidayCard({
    required this.holiday,
    required this.theme,
    required this.colorScheme,
  });

  final Holiday holiday;
  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    holiday.date.day.toString(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    DateFormat('MMM').format(holiday.date),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    holiday.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    holiday.dayName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    holiday.dateFormatted,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
