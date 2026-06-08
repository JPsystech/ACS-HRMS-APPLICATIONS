import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';

/// Provides refresh indicator keys so shell can trigger pull-to-refresh when user taps same tab.
class RefreshKeysScope extends InheritedWidget {
  const RefreshKeysScope({
    super.key,
    required this.refreshKeys,
    required super.child,
  });

  final List<GlobalKey<RefreshIndicatorState>> refreshKeys;

  static RefreshKeysScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<RefreshKeysScope>();
  }

  GlobalKey<RefreshIndicatorState>? keyFor(int index) {
    if (index < 0 || index >= refreshKeys.length) return null;
    return refreshKeys[index];
  }

  @override
  bool updateShouldNotify(RefreshKeysScope oldWidget) =>
      refreshKeys != oldWidget.refreshKeys;
}

/// Shell scaffold with bottom navigation for main app tabs.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with SingleTickerProviderStateMixin {
  static const int _tabCount = 5;
  late final List<GlobalKey<RefreshIndicatorState>> _refreshKeys;
  bool _isExitDialogOpen = false;

  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard'),
    _NavItem(icon: Icons.fingerprint_outlined, activeIcon: Icons.fingerprint, label: 'Attendance'),
    _NavItem(icon: Icons.event_busy_outlined, activeIcon: Icons.event_busy, label: 'Leave'),
    _NavItem(icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today, label: 'Holidays'),
    _NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
  ];

  late final AnimationController _introController;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _refreshKeys = List.generate(
      _tabCount,
      (index) => GlobalKey<RefreshIndicatorState>(),
    );
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fade = CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic));
    _introController.forward();
  }

  @override
  void dispose() {
    _introController.dispose();
    super.dispose();
  }

  Future<bool?> _showExitConfirmationDialog(BuildContext context) async {
    if (_isExitDialogOpen) return false;
    _isExitDialogOpen = true;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Exit App'),
        content: const Text('Do you really want to exit the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    _isExitDialogOpen = false;
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 1. If we can go back within the current tab (inner pages like /leave/policy), do it.
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
          return;
        }

        // 2. If we are NOT on the first tab (Dashboard), switch to the first tab.
        if (widget.navigationShell.currentIndex != 0) {
          widget.navigationShell.goBranch(0);
          return;
        }

        // 3. We are on the root Dashboard page. Show exit confirmation.
        final shouldExit = await _showExitConfirmationDialog(context);
        if (shouldExit ?? false) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: RefreshKeysScope(
        refreshKeys: _refreshKeys,
        child: AnimatedBuilder(
          animation: _introController,
          builder: (context, _) => FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: widget.navigationShell,
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: (int index) {
          HapticFeedback.selectionClick();
          final current = widget.navigationShell.currentIndex;
          if (index == current) {
            _refreshKeys[index].currentState?.show();
          }
          widget.navigationShell.goBranch(index);
        },
        destinations: _navItems
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon, size: AppDimensions.iconMd),
                selectedIcon: Icon(item.activeIcon, size: AppDimensions.iconMd),
                label: item.label,
              ),
            )
            .toList(),
      ),
      )
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}
