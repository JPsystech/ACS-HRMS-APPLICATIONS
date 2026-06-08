import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'core/theme/app_theme.dart';
import 'features/attendance/attendance_screen.dart';
import 'features/attendance/attendance_correction_screen.dart';
import 'features/attendance/attendance_correction_approvals_screen.dart';
import 'features/attendance/punch_confirm_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/security/change_password_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/holidays/holidays_screen.dart';
import 'features/events/events_screen.dart';
import 'features/leaves/compoff_request_screen.dart';
import 'features/leaves/leave_policy_screen.dart';
import 'features/leaves/leaves_screen.dart';
import 'features/leaves/pending_leave_approvals_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/payslips/my_payslips_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/wfh/wfh_screen.dart';
import 'widgets/app_shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Smooth fade + slight slide for page transitions (production ERP feel).
CustomTransitionPage<void> _buildFadeSlidePage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      final slide = Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero).animate(curved);
      return SlideTransition(
        position: slide,
        child: FadeTransition(opacity: curved, child: child),
      );
    },
    transitionDuration: const Duration(milliseconds: 280),
  );
}

/// Custom fade + slide up transition for splash to login animation
CustomTransitionPage<void> _buildSplashToLoginTransition({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      final slide = Tween<Offset>(begin: const Offset(0, 0.24), end: Offset.zero).animate(curved);
      final fade = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
      
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: slide,
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 400),
  );
}

final _routerProvider = Provider<GoRouter>((ref) {
  final authRefresh = ref.watch(authRefreshProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final location = state.matchedLocation;
      if (location == '/' || location.startsWith('/login')) return null;
      final auth = ProviderScope.containerOf(context).read(authProvider);
      if (auth.isLoading) return '/';
      final token = auth.valueOrNull;
      if (token == null || token.isEmpty) return '/login';
      final mustChange = ProviderScope.containerOf(context).read(mustChangePasswordProvider);
      if (mustChange && location != '/security/change-password') {
        return '/security/change-password';
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => _buildSplashToLoginTransition(
          state: state,
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _buildFadeSlidePage(
          state: state,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/security/change-password',
        pageBuilder: (context, state) => _buildFadeSlidePage(
          state: state,
          child: const ChangePasswordScreen(),
        ),
      ),
      GoRoute(
        path: '/payslips',
        pageBuilder: (context, state) => _buildFadeSlidePage(
          state: state,
          child: const MyPayslipsScreen(),
        ),
      ),
      GoRoute(
        path: '/punch-confirm',
        pageBuilder: (context, state) => _buildFadeSlidePage(
          state: state,
          child: const PunchConfirmScreen(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'wfh',
                    redirect: (context, state) {
                      final container = ProviderScope.containerOf(context);
                      final profileAsync = container.read(profileProvider);
                      final employee = profileAsync.valueOrNull;
                      final shouldShowWfh = employee?.workMode.toUpperCase() == 'OFFICE';
                      
                      if (!shouldShowWfh) {
                        // Redirect to dashboard - WFH is only available for OFFICE employees
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Work From Home is only available for office employees'),
                          ),
                        );
                        return '/dashboard';
                      }
                      return null; // Allow navigation
                    },
                    pageBuilder: (context, state) => _buildFadeSlidePage(
                      state: state,
                      child: const WfhScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'events',
                    pageBuilder: (context, state) => _buildFadeSlidePage(
                      state: state,
                      child: const EventsScreen(),
                    ),
                  ),
                 
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/attendance',
                builder: (context, state) {
                  final tab = (state.uri.queryParameters['tab'] ?? '')
                      .trim()
                      .toLowerCase();
                  final initialTabIndex = tab == 'history' || tab == '1' ? 1 : 0;
                  return AttendanceScreen(initialTabIndex: initialTabIndex);
                },
                routes: <RouteBase>[
                  GoRoute(
                    path: 'correction',
                    pageBuilder: (context, state) => _buildFadeSlidePage(
                      state: state,
                      child: AttendanceCorrectionScreen(
                        initialRequestType: state.uri.queryParameters['type'],
                        initialDate: DateTime.tryParse(
                          state.uri.queryParameters['date'] ?? '',
                        ),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'pending-approvals',
                    pageBuilder: (context, state) => _buildFadeSlidePage(
                      state: state,
                      child: const AttendanceCorrectionApprovalsScreen(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/leave',
                builder: (context, state) => LeavesScreen(prefill: state.extra),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'policy',
                    builder: (context, state) => const LeavePolicyScreen(),
                  ),
                  GoRoute(
                    path: 'compoff-request',
                    builder: (context, state) => const CompoffRequestScreen(),
                  ),
                  GoRoute(
                    path: 'pending-approvals',
                    builder: (context, state) => const PendingLeaveApprovalsScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/holidays',
                builder: (context, state) => const HolidaysScreen(),
              ),
            ],
          ),
          // Profile tab: single source of truth — ProfileScreen (provider-driven, GET /api/v1/employees/me).
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Root HRMS app with Material 3 theme and GoRouter.
class HrmsApp extends ConsumerWidget {
  const HrmsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(auth401ListenerProvider);
    ref.watch(authStateListenerProvider);
    ref.watch(fcmInitProvider);
    final router = ref.watch(_routerProvider);
    return MaterialApp.router(
      title: 'ACS HRMS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
