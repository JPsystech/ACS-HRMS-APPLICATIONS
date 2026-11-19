import 'dart:async';

import 'package:acs_hrms/features/dashboard/dashboard_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_repository.dart';
import '../../core/api/culture_dto.dart';
import '../../core/api/leave_balance_dto.dart';
import '../../core/api/leave_policy_dto.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/wfh_utils.dart';
import '../../core/providers.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/fade_in_wrapper.dart';
import '../../widgets/section_title.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/acs/acs_stat_tile.dart';
import '../../widgets/acs/acs_empty_state.dart';
import 'widgets/approvals_widget.dart';
import 'widgets/thought_of_day_widget.dart';
import 'widgets/attendance_streak_widget.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/app_shell.dart';
import 'dashboard_notifier.dart';
import 'widgets/birthday_theme_wrapper.dart';
import 'widgets/events_widget.dart';
import '../../core/feature_flags.dart';

/// Dashboard: greeting, today attendance, punch actions, leave balance, upcoming holidays, quick actions.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  static const Duration _openSessionRefreshInterval = Duration(seconds: 30);
  Timer? _openSessionTimer;

  @override
  void initState() {
    super.initState();
    // Auto-refresh key leave/WFH-related providers when Dashboard is opened.
    Future.microtask(() {
      final token = ref.read(authProvider).valueOrNull;
      if (token == null || token.isEmpty) return;
      ref.invalidate(leaveBalanceProvider);
      ref.invalidate(leaveBalanceSummaryProvider);
      ref.invalidate(myLeavesProvider);
      // WFH providers are only used when WFH is enabled for the role. They will
      // be lazily fetched from the widgets when needed.
    });
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  static String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.isEmpty) return '';

    // Handle first part
    String firstInitial = '';
    if (parts[0].isNotEmpty) {
      firstInitial = parts[0].substring(0, 1).toUpperCase();
    }

    // Handle second part if available
    String secondInitial = '';
    if (parts.length > 1 && parts[1].isNotEmpty) {
      secondInitial = parts[1].substring(0, 1).toUpperCase();
    }

    return firstInitial + secondInitial;
  }

  static AppStatus _getAttendanceStatus(DashboardState state) {
    if (state.isAttendanceOpen) return AppStatus.pending;
    if (state.isAttendanceComplete) return AppStatus.success;
    return AppStatus.info;
  }

  static String _getAttendanceStatusLabel(DashboardState state) {
    if (state.isAttendanceOpen) return 'Working';
    if (state.isAttendanceComplete) return 'Done';
    return 'Open';
  }

  void _scheduleOpenSessionRefresh(bool isOpen) {
    if (!isOpen) {
      _openSessionTimer?.cancel();
      _openSessionTimer = null;
      return;
    }
    if (_openSessionTimer?.isActive ?? false) return;
    _openSessionTimer = Timer.periodic(_openSessionRefreshInterval, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _openSessionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardProvider);
    final profileAsync = ref.watch(profileProvider);
    final employee = profileAsync.valueOrNull;
    final wfhEnabled = WfhUtils.canSeeWFH(employee);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final themeAsync = ref.watch(birthdayThemeProvider);

    // Refresh UI every 30s while punch-out is pending (OPEN)
    if (!dashboardState.isLoading && dashboardState.isAttendanceOpen) {
      _scheduleOpenSessionRefresh(true);
    } else {
      _scheduleOpenSessionRefresh(false);
    }

    // Handle loading state
    if (dashboardState.isLoading) {
      return const Scaffold(body: LoadingView());
    }

    // Handle error state
    if (dashboardState.error != null) {
      return Scaffold(
        body: ErrorView(
          message: dashboardState.error.toString(),
          onRetry: () => ref.read(dashboardProvider.notifier).refresh(),
        ),
      );
    }

    Future<void> onRefresh() async {
      try {
        // Common leave/profile/attendance invalidations.
        ref.invalidate(leaveBalanceProvider);
        ref.invalidate(leaveBalanceSummaryProvider);
        ref.invalidate(myLeavesProvider);
        if (wfhEnabled) {
          ref.invalidate(myWfhProvider);
        }
        ref.invalidate(todaySessionProvider);
        ref.invalidate(todayAttendanceProvider);
        ref.invalidate(profileProvider);
        ref.invalidate(rolePolicyProvider);
        ref.invalidate(eventsProvider);
        // Screen-specific.
        ref.invalidate(leavePolicyProvider);
        ref.invalidate(holidaysProvider);
        ref.invalidate(compoffBalanceProvider);
        ref.invalidate(myCompoffRequestsProvider);
        if (wfhEnabled) {
          ref.invalidate(wfhBalanceProvider(DateTime.now().year));
        }
        final futures = <Future<dynamic>>[
          ref.read(dashboardProvider.notifier).refresh(),
          ref.read(leaveBalanceProvider.notifier).refresh(),
          ref.read(leaveBalanceSummaryProvider.future),
          ref.read(holidaysProvider.future),
        ];
        if (wfhEnabled) {
          futures.add(ref.read(wfhBalanceProvider(DateTime.now().year).future));
        }
        await Future.wait(futures);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dashboard updated')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Refresh failed: ${e.toString()}')),
        );
      }
    }

    final refreshKey = RefreshKeysScope.of(context)?.keyFor(0);

    return FadeInWrapper(
      child: Scaffold(
        backgroundColor: theme.colorScheme.background,
        appBar: AppBar(title: const Text('Dashboard')),
        body: Builder(builder: (ctx) {
          final themeMap = themeAsync.valueOrNull ?? const <String, dynamic>{};
          final isBday = (themeMap['mode'] as String?) == 'BIRTHDAY';
          final body = RefreshIndicator(
            key: refreshKey,
            onRefresh: onRefresh,
            child: ListView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + MediaQuery.of(context).viewPadding.bottom,
              ),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                themeAsync.when(
                  data: (t) {
                    final mode = (t['mode'] as String?) ?? 'NORMAL';
                    if (mode == 'BIRTHDAY') {
                      final bannerText =
                          (t['bannerText'] as String?) ?? 'Happy Birthday';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Text('🎉 ', style: TextStyle(fontSize: 20)),
                            Expanded(
                              child: Text(
                                bannerText,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                // HERO CARD - Premium Gradient Design
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary, // acsIndigo
                        AppColors.acsBlue,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: -4,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _greeting(),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dashboardState.employeeName,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Stack(
                              children: [
                                SizedBox(
                                  height: 48,
                                  width: 48,
                                  child: Builder(
                                    builder: (context) {
                                      final photoUrl =
                                          employee?.profilePhotoUrl ?? '';
                                      final initials = _getInitials(
                                          dashboardState.employeeName);
                                      if (photoUrl.isNotEmpty) {
                                        return ClipOval(
                                          child: Image.network(
                                            photoUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                CircleAvatar(
                                              radius: 24,
                                              child: Text(initials),
                                            ),
                                          ),
                                        );
                                      }
                                      return CircleAvatar(
                                        radius: 24,
                                        child: Text(initials),
                                      );
                                    },
                                  ),
                                ),
                                if (themeAsync.valueOrNull?['mode'] ==
                                    'BIRTHDAY')
                                  Positioned(
                                    top: -2,
                                    right: -2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '🎂',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: colorScheme.onPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Role Chip - Glassmorphism
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.work_outline, color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              employee?.workMode ?? 'Office Mode',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // ACS Birthdays Section
                // ACS Birthdays Section
                Consumer(
                  builder: (context, ref, child) {
                    final today = ref.watch(birthdaysTodayProvider);
                    final upcoming7 = ref.watch(birthdaysUpcomingProvider(7));
                    // Wider window for computing the nearest next birthday when next 7 days are empty
                    final upcoming30 = ref.watch(birthdaysUpcomingProvider(30));
                    String fmtDayMonth(String? iso) {
                      if (iso == null || iso.isEmpty) return '';
                      final d = DateTime.tryParse(iso);
                      if (d == null) return '';
                      return DateFormat('dd MMM').format(d);
                    }

                    // Hide the entire section if there are no birthdays today and none in the next 7 days
                    final todayEmpty = today.hasValue && (today.value?.isEmpty ?? true);
                    final upcomingEmpty = upcoming7.hasValue && (upcoming7.value?.isEmpty ?? true);
                    if (todayEmpty && upcomingEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle(title: 'Birthdays'),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // TODAY BUCKET
                                today.when(
                                  data: (list) {
                                    if (list.isNotEmpty) {
                                      final items = list.take(3).toList();
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Today's Birthdays",
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          ...items.map((e) => Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 8),
                                                child: Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 14,
                                                      child: Text(
                                                          e.name.isNotEmpty
                                                              ? e.name[0]
                                                                  .toUpperCase()
                                                              : '?'),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(e.name,
                                                              style: theme
                                                                  .textTheme
                                                                  .bodyMedium,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis),
                                                          Text(
                                                              e.department ??
                                                                  '-',
                                                              style: theme
                                                                  .textTheme
                                                                  .bodySmall
                                                                  ?.copyWith(
                                                                      color: colorScheme
                                                                          .onSurfaceVariant),
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    TextButton(
                                                      onPressed: () async {
                                                        await showModalBottomSheet(
                                                          context: context,
                                                          showDragHandle: true,
                                                          builder: (ctx) =>
                                                              _WishesSheet(
                                                                  employeeId: e
                                                                      .employeeId),
                                                        );
                                                      },
                                                      style:
                                                          TextButton.styleFrom(
                                                        minimumSize:
                                                            const Size(0, 26),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 8),
                                                        tapTargetSize:
                                                            MaterialTapTargetSize
                                                                .shrinkWrap,
                                                        visualDensity:
                                                            VisualDensity
                                                                .compact,
                                                      ),
                                                      child:
                                                          const Text('Wishes'),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    _WishButton(
                                                        employeeId:
                                                            e.employeeId),
                                                  ],
                                                ),
                                              )),
                                        ],
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                  loading: () => const SizedBox(
                                      height: 56,
                                      child: Center(
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))),
                                  error: (_, __) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    child: Text('Unable to load birthdays',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                                color: colorScheme.error)),
                                  ),
                                ),
                                // Spacer between today and upcoming blocks
                                const SizedBox(height: 12),
                                // UPCOMING BUCKET if no today
                                today.when(
                                  data: (tList) => tList.isNotEmpty
                                      ? const SizedBox.shrink()
                                      : upcoming7.when(
                                          data: (uList) {
                                            if (uList.isNotEmpty) {
                                              final items =
                                                  uList.take(3).toList();
                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Upcoming Birthdays',
                                                    style: theme
                                                        .textTheme.titleSmall
                                                        ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          colorScheme.primary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  ...items.map((e) => Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                bottom: 8),
                                                        child: Row(
                                                          children: [
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          8,
                                                                      vertical:
                                                                          4),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: colorScheme
                                                                    .surfaceContainerLow,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8),
                                                              ),
                                                              child: Text(
                                                                  fmtDayMonth(e
                                                                      .birthdayDate),
                                                                  style: theme
                                                                      .textTheme
                                                                      .labelSmall),
                                                            ),
                                                            const SizedBox(
                                                                width: 10),
                                                            Expanded(
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Text(e.name,
                                                                      style: theme
                                                                          .textTheme
                                                                          .bodyMedium,
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis),
                                                                  Text(
                                                                      e.department ??
                                                                          '-',
                                                                      style: theme
                                                                          .textTheme
                                                                          .bodySmall
                                                                          ?.copyWith(
                                                                              color: colorScheme
                                                                                  .onSurfaceVariant),
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      )),
                                                  Align(
                                                    alignment:
                                                        Alignment.centerRight,
                                                    child: TextButton(
                                                      onPressed:
                                                          null, // Optional placeholder
                                                      child: const Text(
                                                          'View all'),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            }
                                            // EMPTY STATE: No today and no upcoming
                                            return upcoming30.when(
                                              data: (u30) {
                                                final next = u30.isNotEmpty
                                                    ? u30.first
                                                    : null;
                                                final hasAnyDob =
                                                    (tList.isNotEmpty) ||
                                                        (u30.any((e) =>
                                                            (e.dob ?? '')
                                                                .isNotEmpty));
                                                return Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    ACSEmptyState(
                                                      icon: Icons
                                                          .celebration_outlined,
                                                      title:
                                                          'No birthdays in the next 7 days',
                                                      subtitle: next != null
                                                          ? 'Next: ${fmtDayMonth(next.birthdayDate)} — ${next.name}'
                                                          : (hasAnyDob
                                                              ? null
                                                              : 'Birthdays will appear once DOB is added in Profile.'),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 8),
                                                    ),
                                                  ],
                                                );
                                              },
                                              loading: () => const SizedBox(
                                                  height: 40,
                                                  child: Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth: 2))),
                                              error: (_, __) => ACSEmptyState(
                                                icon:
                                                    Icons.celebration_outlined,
                                                title:
                                                    'No birthdays in the next 7 days',
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 8),
                                              ),
                                            );
                                          },
                                          loading: () => const SizedBox(
                                              height: 56,
                                              child: Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2))),
                                          error: (_, __) => ACSEmptyState(
                                            icon: Icons.error_outline,
                                            title:
                                                'Unable to load upcoming birthdays',
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8),
                                          ),
                                        ),
                                  loading: () => const SizedBox.shrink(),
                                  error: (_, __) => const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                // POWERFUL ATTENDANCE CARD - Control Center Design
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.today_rounded,
                                    color: colorScheme.primary, size: 24),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Today\'s Attendance',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Flexible(
                            child: StatusChip(
                              status: _getAttendanceStatus(dashboardState),
                              label: _getAttendanceStatusLabel(dashboardState),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 24),

                      // DOMINANT WORKING HOURS SECTION
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Working Hours',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              transitionBuilder: (Widget child, Animation<double> animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0.0, 0.1),
                                      end: Offset.zero,
                                    ).animate(CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOutCubic,
                                    )),
                                    child: child,
                                  ),
                                );
                              },
                              child: Text(
                                dashboardState.workingHoursText,
                                key: ValueKey<String>(dashboardState.workingHoursText),
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Attendance Details Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _AttendanceDetailTileCompact(
                            icon: Icons.login_rounded,
                            label: 'Punch In',
                            value: dashboardState.punchInFormatted,
                            theme: theme,
                            colorScheme: colorScheme,
                          ),
                          _AttendanceDetailTileCompact(
                            icon: Icons.logout_rounded,
                            label: 'Punch Out',
                            value: dashboardState.punchOutFormatted,
                            theme: theme,
                            colorScheme: colorScheme,
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Action Buttons - Dynamic Primary/Secondary
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: dashboardState.isAttendanceOpen
                                  ? 'Punch Out'
                                  : 'Punch In',
                              onPressed: () => context.go('/attendance'),
                              isMainCTA: true,
                              icon: Icon(
                                dashboardState.isAttendanceOpen
                                    ? Icons.logout_rounded
                                    : Icons.login_rounded,
                                color: colorScheme.onPrimary,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: AppButton(
                              label: dashboardState.isAttendanceOpen
                                  ? 'Punch In'
                                  : 'Punch Out',
                              onPressed: dashboardState.isAttendanceOpen
                                  ? () => context.go('/attendance')
                                  : null,
                              variant: AppButtonVariant.outlined,
                              icon: Icon(
                                dashboardState.isAttendanceOpen
                                    ? Icons.login_rounded
                                    : Icons.logout_rounded,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Consumer(
                  builder: (context, ref, child) {
                    final countsAsync =
                        ref.watch(attendanceMonthStatsThisMonthProvider);

                    return countsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (counts) {
                        final items = <Widget>[
                          GestureDetector(
                            onTap: () => context.go('/attendance'),
                            child: AppCard(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.success,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Present (This Month)',
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Total present days in current month',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color:
                                                colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.success
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: AppColors.success
                                            .withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: Text(
                                      counts.presentDays.toString(),
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                        color: AppColors.success,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ];

                        if (counts.missPunchTotal > 0) {
                          items.add(const SizedBox(height: 16));
                          items.add(
                            GestureDetector(
                              onTap: () => context.go('/attendance?tab=history'),
                              child: AppCard(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: AppColors.warning,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Miss Punch (This Month)',
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Missing In ${counts.missingPunchIn} • Missing Out ${counts.missingPunchOut}',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: colorScheme
                                                  .onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.warning
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: Border.all(
                                          color: AppColors.warning
                                              .withValues(alpha: 0.35),
                                        ),
                                      ),
                                      child: Text(
                                        counts.missPunchTotal.toString(),
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          color: AppColors.warning,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        return Column(children: items);
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),
                // ACS Leave Balance Section
                Consumer(
                  builder: (context, ref, child) {
                    final balanceState = ref.watch(leaveBalanceProvider);
                    final policyAsync = ref.watch(leavePolicyProvider);
                    final policy = policyAsync.valueOrNull;
                    final dto = balanceState.data;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle(title: 'Leave Balance'),
                        const SizedBox(height: 16),
                        if (balanceState.loading)
                          Center(
                            child: Column(
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 16),
                                Text(
                                  'Loading balance...',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          )
                        else if (balanceState.error != null)
                          ACSEmptyState(
                            icon: Icons.error_outline,
                            title: 'Unable to load balance',
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          )
                        else if (dto != null)
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 1.2,
                            children: [
                              _buildLeaveStatTile('PL', 'Paid Leave', dto.items,
                                  policy, colorScheme, context),
                              _buildLeaveStatTile('CL', 'Casual Leave',
                                  dto?.items, policy, colorScheme, context),
                              _buildLeaveStatTile('SL', 'Sick Leave',
                                  dto?.items, policy, colorScheme, context),
                              _buildLeaveStatTile('FL', 'Flexi Leave',
                                  dto?.items, policy, colorScheme, context),
                              _buildLeaveStatTile('RH', 'Restricted Holiday',
                                  dto?.items, policy, colorScheme, context),
                            ].whereType<Widget>().toList(),
                          )
                        else
                          ACSEmptyState(
                            icon: Icons.account_balance_wallet_outlined,
                            title: 'No leave data',
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                if (wfhEnabled)
                  _MyWfhBalanceCard(
                      theme: theme,
                      colorScheme: colorScheme,
                      textTheme: textTheme),
                const SizedBox(height: 24),
                const AttendanceStreakWidget(),
                const SizedBox(height: 24),
                const ThoughtOfDayWidget(),
                const SizedBox(height: 24),
                const ApprovalsWidget(),
                const SizedBox(height: 24),
                const EventsWidget(),
                const SizedBox(height: 24),
                _UpcomingHolidaysCard(
                    theme: theme,
                    colorScheme: colorScheme,
                    textTheme: textTheme),
                const SizedBox(height: 24),
                const SectionTitle(title: 'Quick Actions'),
                const SizedBox(height: 16),
                // 2x2 Quick Actions Grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.4,
                  children: [
                    // Primary Action - Apply Leave
                    _QuickActionCard(
                      icon: Icons.event_busy_rounded,
                      label: 'Apply Leave',
                      helperText: 'Request time off',
                      onTap: () => context.go('/leave'),
                      isPrimary: true,
                      colorScheme: colorScheme,
                      theme: theme,
                    ),
                    _QuickActionCard(
                      icon: Icons.edit_calendar,
                      label: 'Attendance Correction',
                      helperText: 'Forgot punch fix',
                      onTap: () => context.push('/attendance/correction'),
                      isPrimary: false,
                      colorScheme: colorScheme,
                      theme: theme,
                    ),
                    // Events quick action
                    _QuickActionCard(
                      icon: Icons.celebration_outlined,
                      label: 'Events',
                      helperText: 'Upcoming & past celebrations',
                      onTap: () => context.push('/dashboard/events'),
                      isPrimary: false,
                      colorScheme: colorScheme,
                      theme: theme,
                    ),
                    // Secondary Action - Attendance History
                    _QuickActionCard(
                      icon: Icons.history_rounded,
                      label: 'Attendance History',
                      helperText: 'View punch records',
                      onTap: () => context.go('/attendance'),
                      isPrimary: false,
                      colorScheme: colorScheme,
                      theme: theme,
                    ),
                    // Conditional WFH Action
                    if (wfhEnabled)
                      _QuickActionCard(
                        icon: Icons.home_work_outlined,
                        label: 'WFH Request',
                        helperText: 'Work from home',
                        onTap: () => context.push('/dashboard/wfh'),
                        isPrimary: false,
                        colorScheme: colorScheme,
                        theme: theme,
                      )
                    else
                      // Holiday List as fallback
                      _QuickActionCard(
                        icon: Icons.calendar_today_rounded,
                        label: 'Holiday List',
                        helperText: 'View holidays',
                        onTap: () => context.go('/holidays'),
                        isPrimary: false,
                        colorScheme: colorScheme,
                        theme: theme,
                      ),
                    // Pending Approvals (if user can approve)
                    Consumer(
                      builder: (context, ref, child) {
                        final canApprove = ref.watch(canApproveLeavesProvider);
                        final pendingCountAsync =
                            ref.watch(pendingApprovalsCountProvider);

                        if (!canApprove) {
                          return _QuickActionCard(
                            icon: Icons.pending_actions_rounded,
                            label: 'Pending',
                            helperText: 'No approvals',
                            onTap: null,
                            isPrimary: false,
                            colorScheme: colorScheme,
                            theme: theme,
                          );
                        }

                        return pendingCountAsync.when(
                          loading: () => _QuickActionCard(
                            icon: Icons.pending_actions_rounded,
                            label: 'Pending',
                            helperText: 'Loading...',
                            onTap: null,
                            isPrimary: false,
                            colorScheme: colorScheme,
                            theme: theme,
                          ),
                          error: (error, stack) => _QuickActionCard(
                            icon: Icons.pending_actions_rounded,
                            label: 'Pending',
                            helperText: 'Error loading',
                            onTap: () =>
                                context.push('/leave/pending-approvals'),
                            isPrimary: false,
                            colorScheme: colorScheme,
                            theme: theme,
                          ),
                          data: (count) => _QuickActionCard(
                            icon: Icons.pending_actions_rounded,
                            label: 'Pending',
                            helperText:
                                count > 0 ? '$count requests' : 'No requests',
                            onTap: () =>
                                context.push('/leave/pending-approvals'),
                            isPrimary: false,
                            badgeCount: count,
                            colorScheme: colorScheme,
                            theme: theme,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
          if (FeatureFlags.enableBirthdayTheme && isBday) {
            return BirthdayThemeWrapper(child: body);
          }
          return body;
        }),
      ),
    );
  }

  ACSStatTile? _buildLeaveStatTile(
    String type,
    String title,
    List<LeaveBalanceDto>? items,
    LeavePolicyDto? policy,
    ColorScheme colorScheme,
    BuildContext context,
  ) {
    if (items == null) return null;

    LeaveBalanceDto? item;
    for (final e in items) {
      if (e.leaveType.toUpperCase() == type) {
        item = e;
        break;
      }
    }

    if (item == null) return null;

    final policyLimit = _getPolicyLimit(policy, type);

    final caption = policyLimit != null ? 'Limit: $policyLimit' : null;

    // Define color accents for different leave types
    switch (type) {
      case 'PL': // Paid Leave - Primary accent
        break;
      case 'CL': // Casual Leave - Indigo accent
        break;
      case 'SL': // Sick Leave - Warning accent (orange)
        break;
      case 'FL': // Flexi Leave - Cyan accent
        break;
      case 'RH': // Restricted Holiday - Neutral accent
        break;
    }

    String fmt(double v) {
      if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
      return v.toStringAsFixed(1);
    }

    return ACSStatTile(
      title: title,
      value: fmt(item.remaining),
      caption: caption,
      icon: _getLeaveTypeIcon(type),
      backgroundColor: colorScheme.surfaceContainerLow,
      onTap: () => context.go('/leave'),
    );
  }

  int? _getPolicyLimit(LeavePolicyDto? policy, String type) {
    if (policy == null) return null;

    switch (type) {
      case 'PL':
        return policy.pl;
      case 'CL':
        return policy.cl;
      case 'SL':
        return policy.sl;
      case 'FL':
        return null; // No FL property in LeavePolicyDto
      case 'RH':
        return policy.rh;
      default:
        return null;
    }
  }

  IconData _getLeaveTypeIcon(String type) {
    switch (type) {
      case 'PL':
        return Icons.paid_outlined;
      case 'CL':
        return Icons.beach_access_outlined;
      case 'SL':
        return Icons.local_hospital_outlined;
      case 'FL':
        return Icons.work_outline;
      case 'RH':
        return Icons.calendar_today_outlined;
      default:
        return Icons.account_balance_wallet_outlined;
    }
  }
}

// ignore: unused_element
class _BirthdayMiniCard extends ConsumerWidget {
  const _BirthdayMiniCard({
    required this.birthday,
  });

  final BirthdayEmployeeDto birthday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: () async {
        await showModalBottomSheet(
          context: context,
          showDragHandle: true,
          builder: (ctx) {
            return _WishesSheet(employeeId: birthday.employeeId);
          },
        );
      },
      child: Container(
        width: 110,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                birthday.name.substring(0, 1).toUpperCase(),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              birthday.name.split(' ').first,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              birthday.department ?? '',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            _WishButton(employeeId: birthday.employeeId),
          ],
        ),
      ),
    );
  }
}

class _WishButton extends ConsumerStatefulWidget {
  const _WishButton({required this.employeeId});
  final String employeeId;

  @override
  ConsumerState<_WishButton> createState() => _WishButtonState();
}

class _WishesSheet extends ConsumerStatefulWidget {
  const _WishesSheet({required this.employeeId});
  final String employeeId;

  @override
  ConsumerState<_WishesSheet> createState() => _WishesSheetState();
}

class _WishesSheetState extends ConsumerState<_WishesSheet> {
  late Future<List<WishDto>> _future;
  bool _replying = false;

  @override
  void initState() {
    super.initState();
    _future = ref.read(cultureServiceProvider).listWishes(widget.employeeId);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = ref.read(cultureServiceProvider).listWishes(widget.employeeId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.read(cultureServiceProvider);
    final me = ref.read(profileProvider).valueOrNull;
    final isBirthdayUser = (me?.id.toString() ?? '') == widget.employeeId;
    return FutureBuilder(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
              height: 180, child: Center(child: CircularProgressIndicator()));
        }
        final wishes = snap.data ?? const <WishDto>[];
        if (wishes.isEmpty) {
          return const SizedBox(
              height: 120, child: Center(child: Text('No wishes yet')));
        }
        return SizedBox(
          height: 320,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: wishes.length,
            separatorBuilder: (_, __) => const Divider(height: 16),
            itemBuilder: (context, index) {
              final w = wishes[index];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 14,
                    child: Text((w.senderName ?? '').isNotEmpty
                        ? w.senderName!.substring(0, 1).toUpperCase()
                        : '?'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                                child: Text(w.senderName ?? 'Someone',
                                    style:
                                        Theme.of(context).textTheme.labelMedium,
                                    overflow: TextOverflow.ellipsis)),
                            if (isBirthdayUser)
                              TextButton(
                                onPressed: _replying
                                    ? null
                                    : () async {
                                        final controller =
                                            TextEditingController();
                                        final msg =
                                            await showModalBottomSheet<String?>(
                                          context: context,
                                          showDragHandle: true,
                                          builder: (ctx) {
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      AppSpacing.md,
                                                      0,
                                                      AppSpacing.md,
                                                      AppSpacing.md),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  TextField(
                                                    controller: controller,
                                                    decoration:
                                                        const InputDecoration(
                                                            labelText:
                                                                'Reply message'),
                                                    maxLength: 250,
                                                    maxLines: 3,
                                                  ),
                                                  const SizedBox(
                                                      height: AppSpacing.md),
                                                  Align(
                                                    alignment:
                                                        Alignment.centerRight,
                                                    child: ElevatedButton(
                                                      onPressed: () =>
                                                          Navigator.of(ctx).pop(
                                                              controller.text),
                                                      child: const Text('Send'),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                        if (msg == null || msg.trim().isEmpty)
                                          return;
                                        try {
                                          setState(() => _replying = true);
                                          final wid = w.id ?? '';
                                          if (wid.isEmpty) {
                                            throw Exception('Missing wish id');
                                          }
                                          await service.replyToWish(wid,
                                              message: msg.trim());
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                                    content:
                                                        Text('Failed: $e')));
                                          }
                                        } finally {
                                          setState(() => _replying = false);
                                          await _refresh();
                                          ref.invalidate(
                                              birthdaysTodayProvider);
                                          ref.invalidate(
                                              birthdaysUpcomingProvider(7));
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                                    content: Text('Sent')));
                                          }
                                        }
                                      },
                                child: const Text('Reply'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(w.message ?? '-',
                            style: Theme.of(context).textTheme.bodySmall),
                        if ((w.replyMessage ?? '').isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('Reply: ${w.replyMessage}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary)),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _WishButtonState extends ConsumerState<_WishButton> {
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 26),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          textStyle: Theme.of(context).textTheme.labelSmall,
        ).copyWith(
          side: WidgetStatePropertyAll(
            BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
        ),
        onPressed: _sending
            ? null
            : () async {
                final message = await showModalBottomSheet<String?>(
                  context: context,
                  showDragHandle: true,
                  builder: (ctx) {
                    String text = '';
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            decoration: const InputDecoration(
                                labelText: 'Wish message (optional)'),
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
                if (message == null) return;
                try {
                  setState(() => _sending = true);
                  final service = ref.read(cultureServiceProvider);
                  await service.sendWish(widget.employeeId,
                      wishMessage: message);
                  if (mounted) {
                    setState(() => _sending = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Wish sent')));
                    // Refresh birthday lists to reflect sent status
                    ref.invalidate(birthdaysTodayProvider);
                    ref.invalidate(birthdaysUpcomingProvider(7));
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() => _sending = false);
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Failed: $e')));
                  }
                }
              },
        child: _sending
            ? const SizedBox(
                height: 14,
                width: 14,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Wish'),
      ),
    );
  }
}

class _QuickActionWithBadge extends StatelessWidget {
  const _QuickActionWithBadge({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colorScheme,
    required this.theme,
    required this.badgeCount,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.buttonRadius),
                    ),
                    child: Icon(icon,
                        color: colorScheme.onPrimaryContainer,
                        size: AppDimensions.iconLg),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              if (badgeCount > 0)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : badgeCount.toString(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onError,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
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

/// Leave balance card: PL, CL, SL, RH with remaining prominent; PL shows locked if not eligible.
class _MyLeaveBalanceCard extends ConsumerStatefulWidget {
  const _MyLeaveBalanceCard({
    required this.theme,
    required this.colorScheme,
    required this.textTheme,
  });

  final ThemeData theme;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  ConsumerState<_MyLeaveBalanceCard> createState() =>
      _MyLeaveBalanceCardState();
}

class _MyLeaveBalanceCardState extends ConsumerState<_MyLeaveBalanceCard> {
  static const List<String> _typeOrder = ['PL', 'CL', 'SL', 'FL', 'RH'];

  @override
  Widget build(BuildContext context) {
    final balanceState = ref.watch(leaveBalanceProvider);
    final policyAsync = ref.watch(leavePolicyProvider);
    final theme = widget.theme;
    final colorScheme = widget.colorScheme;
    final textTheme = widget.textTheme;
    final policy = policyAsync.valueOrNull;
    final dto = balanceState.data;

    return AppCard(
      onTap: () => context.go('/leave'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded,
                  color: colorScheme.primary, size: AppDimensions.iconMd),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'My Leave Balance',
                  style: textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (balanceState.loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Fetching…',
                      style: textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            )
          else if (balanceState.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                'Unable to load balance',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
              ),
            )
          else if (dto != null)
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _typeOrder.map((type) {
                LeaveBalanceDto? item;
                for (final e in dto.items) {
                  if (e.leaveType.toUpperCase() == type) {
                    item = e;
                    break;
                  }
                }
                return _BalanceChip(
                  type: type,
                  item: item,
                  policy: policy,
                  theme: theme,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                );
              }).toList(),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: Text(
                  'No balance data',
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// WFH balance card: Entitled, Used, Remaining from wfhBalanceProvider.
class _MyWfhBalanceCard extends ConsumerWidget {
  const _MyWfhBalanceCard({
    required this.theme,
    required this.colorScheme,
    required this.textTheme,
  });

  final ThemeData theme;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  String _fmt(double v) {
    if (v.isNaN) return '—';
    if (v == v.truncateToDouble()) {
      return v.toStringAsFixed(0);
    }
    return v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = DateTime.now().year;
    final async = ref.watch(wfhBalanceProvider(year));

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.home_work_rounded,
                color: colorScheme.primary,
                size: AppDimensions.iconMd,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'My WFH Balance',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          async.when(
            data: (dto) {
              final used = _fmt(dto.used);
              final remaining = _fmt(dto.remaining);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Year: ${dto.year}',
                    style: textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'WFH Remaining: $remaining',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Used $used / Accrued ${_fmt(dto.accrued)}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            },
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Fetching…',
                      style: textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            error: (err, _) {
              String message = 'Unable to load WFH balance';
              if (err is DioException && err.response?.statusCode == 404) {
                message = 'WFH balance not enabled. Contact HR.';
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  message,
                  style:
                      textTheme.bodySmall?.copyWith(color: colorScheme.error),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Upcoming holidays card: only holidays in the current month (date >= today), from holidaysProvider.
class _UpcomingHolidaysCard extends ConsumerWidget {
  const _UpcomingHolidaysCard({
    required this.theme,
    required this.colorScheme,
    required this.textTheme,
  });

  final ThemeData theme;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holidaysAsync = ref.watch(holidaysProvider);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => context.go('/holidays'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                color: colorScheme.primary,
                size: AppDimensions.iconMd,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Upcoming Holidays',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          holidaysAsync.when(
            data: (all) {
              final now = DateTime.now();
              final todayOnly = DateTime(now.year, now.month, now.day);
              final upcoming = all.where((h) {
                final d = DateTime(h.date.year, h.date.month, h.date.day);
                final isCurrentMonth =
                    h.date.year == now.year && h.date.month == now.month;
                final isTodayOrLater =
                    d.isAfter(todayOnly) || d.isAtSameMomentAs(todayOnly);
                return isCurrentMonth && isTodayOrLater;
              }).toList()
                ..sort((a, b) {
                  final da = DateTime(a.date.year, a.date.month, a.date.day);
                  final db = DateTime(b.date.year, b.date.month, b.date.day);
                  return da.compareTo(db);
                });
              final show = upcoming;
              if (show.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(
                    'No upcoming holidays',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: show
                    .map((h) => _HolidayRow(
                        holiday: h,
                        theme: theme,
                        colorScheme: colorScheme,
                        textTheme: textTheme))
                    .toList(),
              );
            },
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: LoadingView(compact: true),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Unable to load holidays',
                      style: textTheme.bodySmall
                          ?.copyWith(color: colorScheme.error),
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(holidaysProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HolidayRow extends StatelessWidget {
  const _HolidayRow({
    required this.holiday,
    required this.theme,
    required this.colorScheme,
    required this.textTheme,
  });

  final HolidayDto holiday;
  final ThemeData theme;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('dd MMM').format(holiday.date);
    final dayName = DateFormat('EEE').format(holiday.date);
    final typeLabel = holiday.type == 'restricted' ? 'RH' : 'Public';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  holiday.name.isNotEmpty ? holiday.name : 'Holiday',
                  style: textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  '$dayName · $typeLabel',
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              dateLabel,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceChip extends StatelessWidget {
  const _BalanceChip({
    required this.type,
    required this.item,
    this.policy,
    required this.theme,
    required this.colorScheme,
    required this.textTheme,
  });

  final String type;
  final LeaveBalanceDto? item;
  final LeavePolicyDto? policy;
  final ThemeData theme;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  int? _policyTotalFor(String type) {
    if (policy == null) return null;
    switch (type.toUpperCase()) {
      case 'PL':
        return policy!.pl;
      case 'CL':
        return policy!.cl;
      case 'SL':
        return policy!.sl;
      case 'RH':
        return policy!.rh;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    String _fmt(double v) {
      if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
      return v.toStringAsFixed(1);
    }

    var remaining = item?.remaining ?? 0.0;
    var used = item?.used ?? 0.0;
    var totalEntitlement = item?.totalEntitlement ?? 0.0;
    // Fallback: if API did not provide total/used, use policy total and derive used = total - remaining
    if (totalEntitlement == 0 && remaining >= 0) {
      final policyTotal = _policyTotalFor(type);
      if (policyTotal != null && policyTotal > 0) {
        totalEntitlement = policyTotal.toDouble();
        used = (totalEntitlement - remaining)
            .clamp(0.0, totalEntitlement)
            .toDouble();
      }
    }
    final eligible = item?.eligible ?? true;
    final notes = item?.notes;

    final upper = type.toUpperCase();
    final showLocked = (upper == 'PL' || upper == 'FL') && !eligible;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppDimensions.cardRadiusSmall),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            type,
            style: textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
          if (showLocked) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              notes?.isNotEmpty == true
                  ? notes!
                  : 'Eligible after 6 months from join date',
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Locked',
              style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.error, fontWeight: FontWeight.w600),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _fmt(remaining),
              style:
                  textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              'Used ${_fmt(used)} / ${_fmt(totalEntitlement)}',
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _AttendanceDetailTile extends StatelessWidget {
  const _AttendanceDetailTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
    this.isHighlighted = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final ThemeData theme;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: isHighlighted
            ? colorScheme.primaryContainer.withValues(alpha: 0.2)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: isHighlighted
            ? Border.all(
                color: colorScheme.primaryContainer.withValues(alpha: 0.5))
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isHighlighted
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isHighlighted
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
              color: isHighlighted
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _AttendanceDetailTileCompact extends StatelessWidget {
  const _AttendanceDetailTileCompact({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
    required this.colorScheme,
  });

  final IconData icon;
  final String label;
  final String value;
  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final String value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    return Row(
      children: [
        Icon(icon,
            size: AppDimensions.iconSm, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Text('$label: ',
            style: textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant)),
        Text(value,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.helperText,
    required this.onTap,
    required this.isPrimary,
    required this.colorScheme,
    required this.theme,
    this.badgeCount,
  });

  final IconData icon;
  final String label;
  final String helperText;
  final VoidCallback? onTap;
  final bool isPrimary;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isPrimary
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isPrimary
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  size: 16,
                ),
              ),
              const SizedBox(height: 3),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 0),
              Expanded(
                child: Text(
                  helperText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 9,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (badgeCount != null && badgeCount! > 0)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeCount! > 99 ? '99+' : badgeCount.toString(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onError,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colorScheme,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primaryContainer,
                      colorScheme.primaryContainer.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: Icon(icon,
                    color: colorScheme.onPrimaryContainer,
                    size: AppDimensions.iconLg),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
