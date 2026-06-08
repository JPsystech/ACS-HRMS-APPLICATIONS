import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:acs_hrms/core/api/attendance_dto.dart';
import '../../core/config/attendance_punch_config.dart';
import '../../core/device/device_id_service.dart';
import '../../core/location/live_location_result.dart';
import '../../core/location/location_exception.dart';
import '../../core/location/location_service.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ist_time.dart';
import '../../widgets/acs/acs_empty_state.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/error_view.dart';
import '../../widgets/fade_in_wrapper.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/status_chip.dart';
import 'attendance_action_notifier.dart';

/// Default date range for history: this month (local date only, no UTC).
(DateTime, DateTime) _defaultRange() {
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, 1);
  final to = DateTime(now.year, now.month + 1, 0); // last day of current month
  return (from, to);
}

final _historyRangeProvider =
    StateProvider<(DateTime, DateTime)>((ref) => _defaultRange());

/// Attendance screen: Today card (punch in/out) + History tab with date range.
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  final int initialTabIndex;

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Timer? _durationTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );

    // So AppBar action updates when user switches tabs.
    _tabController.addListener(() {
      if (!mounted) return;
      setState(() {});
    });

    // Schedule daily reminders for today (10:15 punch-in if not punched; 19:30 punch-out if open)
    Future.microtask(() => _scheduleRemindersForToday());
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _scheduleRemindersForToday() async {
    try {
      final notif = ref.read(notificationServiceProvider);
      await notif.init();

      // Skip Sundays and holidays
      final now = DateTime.now();
      if (now.weekday == DateTime.sunday) return;
      final holidays = await ref.read(holidaysProvider.future);
      final isHoliday = holidays.any((h) {
        final d = DateTime(h.date.year, h.date.month, h.date.day);
        return d.year == now.year && d.month == now.month && d.day == now.day;
      });
      if (isHoliday) return;

      final session = await ref.read(todaySessionProvider.future);
      final today10_15 = DateTime(now.year, now.month, now.day, 10, 15);
      final today19_30 = DateTime(now.year, now.month, now.day, 19, 30);

      if (session?.isPunchedIn != true && now.isBefore(today10_15)) {
        await notif.schedulePunchInReminder(today10_15);
      } else {
        await notif.cancelPunchInReminder();
      }

      if (session?.isPunchedIn == true &&
          session?.isCompleted != true &&
          now.isBefore(today19_30)) {
        await notif.schedulePunchOutReminder(today19_30);
      } else {
        await notif.cancelPunchOutReminder();
      }
    } catch (_) {
      // Non-critical; ignore scheduling errors
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FadeInWrapper(
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: const Text('Attendance'),
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: theme.colorScheme.onSurface,
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Today', icon: Icon(Icons.today_rounded)),
              Tab(text: 'History', icon: Icon(Icons.history_rounded)),
            ],
          ),
          actions: [
            if (_tabController.index == 0)
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () {
                  ref.invalidate(todaySessionProvider);
                  ref.invalidate(todayAttendanceProvider);
                  // also refresh history for current range
                  final r = ref.read(_historyRangeProvider);
                  ref.invalidate(myAttendanceProvider(r));
                },
              )
            else
              IconButton(
                icon: const Icon(Icons.filter_alt_rounded),
                onPressed: () => _pickRange(context, ref),
              ),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _TodayTab(
              onStartDurationTimer: _startDurationTimer,
              onStopDurationTimer: _stopDurationTimer,
            ),
            const _HistoryTab(),
          ],
        ),
      ),
    );
  }
}

class _TodayTab extends ConsumerStatefulWidget {
  const _TodayTab({
    required this.onStartDurationTimer,
    required this.onStopDurationTimer,
  });

  final VoidCallback onStartDurationTimer;
  final VoidCallback onStopDurationTimer;

  @override
  ConsumerState<_TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends ConsumerState<_TodayTab> {
  bool _locationDialogVisible = false;
  bool _isPunching = false;
  @override
  void dispose() {
    widget.onStopDurationTimer();
    super.dispose();
  }

  /// Fetches live GPS and device id; shows loader and handles GPS/permission dialogs.
  /// Returns null if user cancelled.
  /// When location is unavailable (permission denied or GPS off), returns (location: null, deviceId, locationDenied: true).
  Future<
      ({
        LiveLocationResult? location,
        String deviceId,
        bool locationDenied
      })?> _fetchLocationForPunch() async {
    if (kDebugMode) {
      final status = await Permission.location.status;
      debugPrint('📍 [Punch] location permission status: $status');
    }

    final enabled = await LocationService.isLocationServiceEnabled();
    if (!enabled) {
      final proceed = await _showTurnOnGpsOrContinueDialog();
      if (proceed != true || !mounted) return null;

      final deviceId = await DeviceIdService.getDeviceId();
      if (kDebugMode) {
        debugPrint(
            '📍 [Punch] GPS disabled — proceeding with geo=null, device_id=$deviceId');
      }
      return (location: null, deviceId: deviceId, locationDenied: true);
    }

    var status = await Permission.location.status;
    if (!status.isGranted) {
      status = await Permission.location.request();
      if (!status.isGranted) {
        final proceed = await _showLocationDeniedContinueDialog(
          permanentlyDenied: status.isPermanentlyDenied,
        );
        if (proceed != true || !mounted) return null;

        final deviceId = await DeviceIdService.getDeviceId();
        if (kDebugMode) {
          debugPrint(
              '📍 [Punch] location denied — proceeding with geo=null, device_id=$deviceId');
        }
        return (location: null, deviceId: deviceId, locationDenied: true);
      }
    }

    _showLocationLoader();
    try {
      final location = await LocationService.getLivePosition(
        requireGoodAccuracy: false,
        accuracyThresholdMeters: AttendancePunchConfig.maxAccuracyWarningMeters,
        tryStreamImprovement: true,
        reverseGeocode: true,
      );
      final deviceId = await DeviceIdService.getDeviceId();
      if (kDebugMode) {
        debugPrint(
            '📍 [Punch] lat=${location.lat}, lng=${location.lng}, accuracy=${location.accuracy} m');
      }
      if (location.accuracy > AttendancePunchConfig.maxAccuracyWarningMeters) {
        final retry = await _showPoorAccuracyDialog(location.accuracy);
        if (!retry) return null;
        return _fetchLocationForPunch();
      }
      if (location.isMocked && AttendancePunchConfig.blockPunchOnMockLocation) {
        await _showMockLocationBlockedDialog();
        return null;
      }
      return (location: location, deviceId: deviceId, locationDenied: false);
    } on LocationServiceException catch (e) {
      if (!mounted) return null;
      final proceed = await _handleLocationErrorAndOfferContinue(e);
      if (proceed != true || !mounted) return null;
      final deviceId = await DeviceIdService.getDeviceId();
      if (kDebugMode) {
        debugPrint(
            '📍 [Punch] location error — proceeding with geo=null, device_id=$deviceId');
      }
      return (location: null, deviceId: deviceId, locationDenied: true);
    } catch (e) {
      if (!mounted) return null;
      _showSnackBar(
        'Location error: ${e.toString().replaceFirst(RegExp(r'^Exception: '), '')}',
        isError: true,
      );
      return null;
    } finally {
      _hideLocationLoader();
    }
  }

  void _showLocationLoader() {
    _locationDialogVisible = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Text('Getting live location...'),
          ],
        ),
      ),
    );
  }

  void _hideLocationLoader() {
    if (!mounted) return;
    if (_locationDialogVisible) {
      Navigator.of(context, rootNavigator: true).pop();
      _locationDialogVisible = false;
    }
  }

  Future<bool?> _showTurnOnGpsOrContinueDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Location off'),
        content: const Text(
          'Turn on GPS to record your location. You can still punch without location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue without location'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx, false);
              await LocationService.openSystemLocationSettings();
            },
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showLocationDeniedContinueDialog(
      {required bool permanentlyDenied}) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Location permission'),
        content: Text(
          permanentlyDenied
              ? 'Location was denied permanently. You can still punch without location.'
              : 'Location was denied. You can still punch without location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue without location'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showPoorAccuracyDialog(double accuracyMeters) async {
    final retry = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Location not accurate'),
        content: Text(
          'Current accuracy is about ${accuracyMeters.toStringAsFixed(0)} m. For better records, try again in an open area.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
    return retry ?? false;
  }

  Future<void> _showMockLocationBlockedDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mock location detected'),
        content: const Text(
          'Punch is not allowed when using a fake/mock location. Please disable mock location and try again.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// ✅ FIXED: awaits dialogs properly
  Future<bool> _handleLocationErrorAndOfferContinue(
      LocationServiceException e) async {
    switch (e.reason) {
      case LocationFailureReason.serviceDisabled:
        {
          final proceed = await _showTurnOnGpsOrContinueDialog();
          return proceed == true;
        }
      case LocationFailureReason.permissionDenied:
      case LocationFailureReason.permissionPermanentlyDenied:
        {
          final proceed = await _showLocationDeniedContinueDialog(
            permanentlyDenied:
                e.reason == LocationFailureReason.permissionPermanentlyDenied,
          );
          return proceed == true;
        }
      case LocationFailureReason.timeout:
        _showSnackBar(
            'Location request timed out. You can punch without location.',
            isError: true);
        return false;
      case LocationFailureReason.mockDetected:
        await _showMockLocationBlockedDialog();
        return false;
      case LocationFailureReason.accuracyPoor:
        _showSnackBar('Location accuracy too low. Try again in an open area.',
            isError: true);
        return false;
      default:
        _showSnackBar(e.message ?? 'Location error', isError: true);
        return false;
    }
  }

  Future<void> _performPunchIn() async {
    if (_isPunching) return;
    setState(() => _isPunching = true);

    try {
      final result = await _fetchLocationForPunch();
      if (result == null || !mounted) return;

      final loc = result.location;
      final capturedAt = loc?.timestamp.toUtc().toIso8601String();

      if (loc == null) {
        _showSnackBar('Location is required for Punch In', isError: true);
        return;
      }

      if (kDebugMode) {
        debugPrint(
            '📍 [Punch] Calling punchIn — deviceId=${result.deviceId} lat=${loc.lat} lng=${loc.lng} accuracy=${loc.accuracy} capturedAt=$capturedAt');
      }

      // 1. Perform Punch In
      await ref.read(attendanceActionProvider.notifier).punchIn(
            deviceId: result.deviceId,
            lat: loc.lat,
            lng: loc.lng,
            accuracy: loc.accuracy,
            capturedAt: capturedAt,
            address: loc.address,
          );

      if (!mounted) return;

      // 2. Check result from notifier state
      final actionState = ref.read(attendanceActionProvider);
      if (actionState.errorMessage != null) {
        // Error is handled by the listener in build()
        return;
      }

      // 3. SUCCESS! Show snackbar immediately
      _showSnackBar(
        loc == null
            ? (result.locationDenied
                ? 'Punch In recorded. Location not captured.'
                : 'Punch In recorded (no location).')
            : 'Punch In recorded',
        isError: false,
      );

      // 4. Background tasks (silently handled)
      _runBackgroundTasksAfterPunchIn();
    } finally {
      if (mounted) setState(() => _isPunching = false);
    }
  }

  /// Runs background tasks like refreshing data and canceling reminders.
  /// Any errors here are logged but do not trigger UI error snackbars.
  Future<void> _runBackgroundTasksAfterPunchIn() async {
    // Cancel reminder
    try {
      await ref.read(notificationServiceProvider).cancelPunchInReminder();
      if (kDebugMode) debugPrint('✅ [PunchIn] Reminder cancelled');
    } catch (e) {
      debugPrint('⚠️ [PunchIn] cancelPunchInReminder failed: $e');
    }

    // Background refreshes
    try {
      if (kDebugMode) debugPrint('🔄 [PunchIn] Background refreshes...');
      ref.invalidate(todaySessionProvider);
      final range = ref.read(_historyRangeProvider);
      ref.invalidate(myAttendanceProvider(range));
      if (kDebugMode) debugPrint('✅ [PunchIn] Background refreshes done');
    } catch (refreshErr) {
      debugPrint('⚠️ [PunchIn] background refresh failed: $refreshErr');
    }

    if (mounted) {
      widget.onStartDurationTimer();
    }
  }

  Future<void> _performPunchOut() async {
    if (_isPunching) return;
    setState(() => _isPunching = true);

    try {
      final result = await _fetchLocationForPunch();
      if (result == null || !mounted) return;

      final loc = result.location;
      final capturedAt = loc?.timestamp.toUtc().toIso8601String();

      if (loc == null) {
        _showSnackBar('Location is required for Punch Out', isError: true);
        return;
      }

      if (kDebugMode) {
        debugPrint(
            '📍 [Punch] Calling punchOut — deviceId=${result.deviceId} lat=${loc.lat} lng=${loc.lng} accuracy=${loc.accuracy} capturedAt=$capturedAt');
      }

      // 1. Perform Punch Out
      await ref.read(attendanceActionProvider.notifier).punchOut(
            deviceId: result.deviceId,
            lat: loc.lat,
            lng: loc.lng,
            accuracy: loc.accuracy,
            capturedAt: capturedAt,
            address: loc.address,
          );

      if (!mounted) return;

      // 2. Check result from notifier state
      final actionState = ref.read(attendanceActionProvider);
      if (actionState.errorMessage != null) {
        // Error is handled by the listener in build()
        return;
      }

      // 3. SUCCESS! Show snackbar immediately
      _showSnackBar(
        loc == null
            ? (result.locationDenied
                ? 'Punch Out recorded. Location not captured.'
                : 'Punch Out recorded (no location).')
            : 'Punch Out recorded',
        isError: false,
      );

      // 4. Background tasks (silently handled)
      _runBackgroundTasksAfterPunchOut();
    } finally {
      if (mounted) setState(() => _isPunching = false);
    }
  }

  /// Runs background tasks like refreshing data and canceling reminders.
  /// Any errors here are logged but do not trigger UI error snackbars.
  Future<void> _runBackgroundTasksAfterPunchOut() async {
    // Cancel reminder
    try {
      await ref.read(notificationServiceProvider).cancelPunchOutReminder();
      if (kDebugMode) debugPrint('✅ [PunchOut] Reminder cancelled');
    } catch (e) {
      debugPrint('⚠️ [PunchOut] cancelPunchOutReminder failed: $e');
    }

    // Background refreshes
    try {
      if (kDebugMode) debugPrint('🔄 [PunchOut] Background refreshes...');
      ref.invalidate(todaySessionProvider);
      final range = ref.read(_historyRangeProvider);
      ref.invalidate(myAttendanceProvider(range));
      if (kDebugMode) debugPrint('✅ [PunchOut] Background refreshes done');
    } catch (refreshErr) {
      debugPrint('⚠️ [PunchOut] background refresh failed: $refreshErr');
    }

    if (mounted) {
      widget.onStopDurationTimer();
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;

    // Add debug logs to trace snackbar source in production/release mode
    if (kDebugMode) {
      debugPrint('🔔 SNACKBAR: "$message" (isError: $isError) from AttendanceScreen');
    } else {
      // In release mode, still print to console for logcat/sentry tracking
      print('🔔 SNACKBAR: "$message" (isError: $isError) from AttendanceScreen');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayAsync = ref.watch(todaySessionProvider);
    final actionState = ref.watch(attendanceActionProvider);

    ref.listen<AttendanceActionState>(attendanceActionProvider, (prev, next) {
      final isRealFailure = prev?.isLoading == true &&
          next.isLoading == false &&
          next.errorMessage != null;

      if (isRealFailure) {
        // Log exactly which error is being shown from the listener
        if (kDebugMode) {
          debugPrint('🚩 Attendance Action Listener FAILURE: ${next.errorMessage}');
        } else {
          print('🚩 Attendance Action Listener FAILURE: ${next.errorMessage}');
        }

        _showSnackBar(next.errorMessage!, isError: true);

        // Clear error after showing it to avoid false error snackbars on subsequent successful actions
        ref.read(attendanceActionProvider.notifier).clearError();
      }
    });

    ref.listen<AsyncValue<AttendanceSessionDto?>>(todaySessionProvider,
        (prev, next) {
      next.whenData((session) {
        if (session?.isPunchedIn == true && session?.isCompleted != true) {
          widget.onStartDurationTimer();
        } else {
          widget.onStopDurationTimer();
        }
      });
    });

    Future<void> onRefresh() async {
      try {
        ref.invalidate(leaveBalanceProvider);
        ref.invalidate(leaveBalanceSummaryProvider);
        ref.invalidate(myLeavesProvider);
        ref.invalidate(todaySessionProvider);
        ref.invalidate(todayAttendanceProvider);
        ref.invalidate(profileProvider);

        final range = ref.read(_historyRangeProvider);
        ref.invalidate(myAttendanceProvider(range));

        await ref.read(todaySessionProvider.future);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Refresh failed: ${_friendlyErrorMessage(e)}')),
        );
      }
    }

    return Refresher(
      onRefresh: onRefresh,
      child: todayAsync.when(
        data: (session) => _TodayContent(
          session: session,
          actionState: actionState,
          isPunching: _isPunching,
          onPunchIn: _performPunchIn,
          onPunchOut: _performPunchOut,
        ),
        loading: () => const Center(child: LoadingView()),
        error: (err, _) => Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ErrorView(
            message: _friendlyErrorMessage(err),
            onRetry: () => ref.invalidate(todaySessionProvider),
          ),
        ),
      ),
    );
  }
}

class Refresher extends StatelessWidget {
  const Refresher({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: child,
      ),
    );
  }
}

/// Friendly message for 401, 500 DB migration, or generic errors.
String _friendlyErrorMessage(Object err) {
  if (err is DioException) {
    final res = err.response;
    if (res?.statusCode == 401) return 'Session expired. Please sign in again.';
    if (res?.statusCode == 500) {
      final data = res!.data;
      final str = data is Map
          ? ((data['message'] ?? data['detail'] ?? data['error'])?.toString() ??
              '')
          : data?.toString() ?? '';
      final lower = str.toLowerCase();
      if (lower.contains('migration') ||
          lower.contains('database') ||
          lower.contains('schema')) {
        return 'Server is being updated. Please try again later.';
      }
    }
    if (err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout) {
      return 'Check connection';
    }
    return res?.data?.toString() ?? err.message ?? 'Something went wrong';
  }
  return err.toString();
}

Future<bool> _hasInternet() async {
  try {
    final result = await InternetAddress.lookup('example.com')
        .timeout(const Duration(seconds: 2));
    return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}

Future<String?> _resolveNetworkMessage(DioException e) async {
  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout) {
    return 'Check connection';
  }
  if (e.type == DioExceptionType.unknown) {
    final online = await _hasInternet();
    if (!online) return 'Check connection';
  }
  final res = e.response;
  if (res != null) {
    final data = res.data;
    if (res.statusCode == 400) return data?.toString() ?? 'Invalid request';
    if (res.statusCode == 401) return 'Session expired. Please sign in again.';
    if (res.statusCode == 403) return 'Not allowed';
    if (res.statusCode == 404) return 'Not found';
    if (res.statusCode == 500) {
      final str = data is Map
          ? ((data['message'] ?? data['detail'] ?? data['error'])?.toString() ??
              '')
          : data?.toString();
      return str?.isNotEmpty == true ? str : 'Server error';
    }
    if (data is Map) {
      final msg = data['message'] as String? ??
          data['detail'] as String? ??
          data['error'] as String?;
      if (msg != null && msg.isNotEmpty) return msg;
      final list = data['errors'] as List?;
      if (list != null && list.isNotEmpty && list.first is String)
        return list.first as String;
    }
  }
  return null;
}

class _TodayContent extends StatelessWidget {
  const _TodayContent({
    required this.session,
    required this.actionState,
    required this.isPunching,
    required this.onPunchIn,
    required this.onPunchOut,
  });

  final AttendanceSessionDto? session;
  final AttendanceActionState actionState;
  final bool isPunching;
  final VoidCallback onPunchIn;
  final VoidCallback onPunchOut;

  String _statusLabel(AttendanceSessionDto? s) {
    if (s?.isPunchedIn != true) return 'Open';
    if (s?.isCompleted == true) return 'Done';
    return 'Working';
    // "Open" means no punch-in today yet.
  }

  AppStatus _statusChip(AttendanceSessionDto? s) {
    if (s?.isPunchedIn != true) return AppStatus.warning;
    if (s?.isCompleted == true) return AppStatus.success;
    return AppStatus.info;
  }

  @override
  Widget build(BuildContext context) {
    final session = this.session;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final padding = const EdgeInsets.all(16);

    final notPunchedIn = session?.isPunchedIn != true;
    final punchedInNotOut =
        session?.isPunchedIn == true && session?.isCompleted != true;
    final canPunchIn = notPunchedIn && !actionState.isLoading;
    final canPunchOut = punchedInNotOut && !actionState.isLoading;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Single main status card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with status pill and date chip
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Status pill
                    StatusChip(
                      status: _statusChip(session),
                      label: _statusLabel(session),
                      isSelected: true,
                    ),
                    // Date chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        IstTime.formatDateFromUtc(DateTime.now().toUtc()),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Punch-in/out blocks
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _PunchBlock(
                      title: 'Punch In',
                      time: _formatTimeIst(session?.punchInAt),
                      theme: theme,
                      colorScheme: cs,
                    ),
                    _PunchBlock(
                      title: 'Punch Out',
                      time: _formatTimeIst(session?.punchOutAt),
                      theme: theme,
                      colorScheme: cs,
                    ),
                  ],
                ),
                if (punchedInNotOut) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Punch Out missing. Please Punch Out or raise Attendance Correction.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),

                // Working hours highlighted
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Working Hours',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session?.workingHoursText ?? '--:--',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Primary CTA button
                AppButton(
                  label: notPunchedIn ? 'Punch In' : 'Punch Out',
                  onPressed: notPunchedIn
                      ? (canPunchIn && !isPunching ? onPunchIn : null)
                      : (canPunchOut && !isPunching ? onPunchOut : null),
                  isMainCTA: true,
                  icon: Icon(
                    notPunchedIn ? Icons.login_rounded : Icons.logout_rounded,
                    color: cs.onPrimary,
                    size: 20,
                  ),
                  isLoading: actionState.isLoading || isPunching,
                ),

                // Location warnings (optional)
                if (session?.isPunchedIn == true) ...[
                  const SizedBox(height: 16),
                  if (session?.punchInGeo?.hasLocation != true)
                    _LocationWarningRow(
                      message: 'Punch In: location not captured',
                      theme: theme,
                      colorScheme: cs,
                    ),
                  if (session?.isCompleted == true &&
                      session?.punchOutGeo?.hasLocation != true)
                    _LocationWarningRow(
                      message: 'Punch Out: location not captured',
                      theme: theme,
                      colorScheme: cs,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PunchBlock extends StatelessWidget {
  const _PunchBlock({
    required this.title,
    required this.time,
    required this.theme,
    required this.colorScheme,
  });

  final String title;
  final String time;
  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            time,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '±15m',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PunchColumn extends StatelessWidget {
  const _PunchColumn({
    required this.title,
    required this.time,
    required this.theme,
    required this.colorScheme,
  });

  final String title;
  final String time;
  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          time,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '±15m',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _LocationWarningRow extends StatelessWidget {
  const _LocationWarningRow({
    required this.message,
    required this.theme,
    required this.colorScheme,
  });

  final String message;
  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.warning_amber_rounded,
          size: 16,
          color: AppColors.warning,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.warning,
            ),
          ),
        ),
      ],
    );
  }
}

/// History tab: watches myAttendanceProvider((from, to)) for the selected range (local dates).
class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(_historyRangeProvider);
    final sessionsAsync = ref.watch(myAttendanceProvider(range));
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter section at top
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            children: [
              // Date range text + change button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${_formatDate(range.$1)} – ${_formatDate(range.$2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  AppButton(
                    label: 'Change',
                    onPressed: () => _pickRange(context, ref),
                    variant: AppButtonVariant.outlined,
                    icon: const Icon(Icons.date_range_rounded, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // This Month / Last Month chips
              Row(
                children: [
                  _QuickFilterChip(
                    label: 'This Month',
                    isSelected: _isThisMonth(range),
                    onTap: () => _setThisMonthRange(ref),
                    colorScheme: cs,
                    theme: theme,
                  ),
                  const SizedBox(width: 16),
                  _QuickFilterChip(
                    label: 'Last Month',
                    isSelected: _isLastMonth(range),
                    onTap: () => _setLastMonthRange(ref),
                    colorScheme: cs,
                    theme: theme,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // List cards
        Expanded(
          child: sessionsAsync.when(
            data: (sessions) {
              if (sessions.isEmpty) {
                return ACSEmptyState(
                  title: 'No attendance records',
                  subtitle: 'Try changing date range or check your connection.',
                  action: TextButton(
                    onPressed: () => _pickRange(context, ref),
                    child: const Text('Change dates'),
                  ),
                  icon: Icons.history_rounded,
                );
              }

              return ListView.builder(
                padding: EdgeInsets
                    .zero, // No additional padding since we handle it above
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final s = sessions[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _HistoryCard(session: s),
                  );
                },
              );
            },
            loading: () => const Center(child: LoadingView()),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: ErrorView(
                message: _friendlyErrorMessage(err),
                onRetry: () => ref.invalidate(myAttendanceProvider(range)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Quick filter chip for date range selection
class _QuickFilterChip extends StatelessWidget {
  const _QuickFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
    required this.theme,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: isSelected ? colorScheme.primary : colorScheme.surface,
      selectedColor: colorScheme.primaryContainer,
      labelStyle: theme.textTheme.bodySmall?.copyWith(
        color:
            isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      showCheckmark: false,
      side: BorderSide(
        color: isSelected ? colorScheme.primary : colorScheme.outline,
        width: 1,
      ),
    );
  }
}

/// Premium history card for attendance entries
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.session});

  final AttendanceSessionDto session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final missingPunchIn = session.punchInAt == null && session.punchOutAt != null;
    final missingPunchOut = session.punchInAt != null && session.punchOutAt == null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date as title
          Text(
            IstTime.formatDateFromUtc(
              session.workDate ?? session.punchInAt ?? DateTime.now().toUtc(),
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          if (missingPunchIn || missingPunchOut) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      missingPunchIn
                          ? 'Missing Punch In'
                          : 'Missing Punch Out',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // In/out aligned left-right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'In: ${_formatTimeIst(session.punchInAt)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Out: ${_formatTimeIst(session.punchOutAt)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            '±15m',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 16),

          // Worked hours emphasized
          if (session.isCompleted) ...[
            Text(
              'Worked: ${session.workingHoursText}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Remarks smaller
          if (session.remarks != null &&
              session.remarks!.trim().isNotEmpty) ...[
            Text(
              'Remarks:',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              session.remarks!.trim(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
          ],

          // View Details button
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'View Details',
              onPressed: () => _showDayDetail(context, session),
              variant: AppButtonVariant.outlined,
            ),
          ),
        ],
      ),
    );
  }
}

/// Day detail bottom sheet
void _showDayDetail(BuildContext context, AttendanceSessionDto session) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _DayDetailBottomSheet(
      session: session,
      onOpenCorrection: () {
        final missingPunchIn =
            session.punchInAt == null && session.punchOutAt != null;
        final missingPunchOut =
            session.punchInAt != null && session.punchOutAt == null;
        final type = missingPunchOut
            ? 'FORGOT_PUNCH_OUT'
            : (missingPunchIn ? 'FORGOT_PUNCH_IN' : 'CORRECTION');
        final dt = session.workDate ?? session.punchInAt ?? session.punchOutAt;
        final d = dt == null
            ? DateTime.now()
            : DateTime(dt.year, dt.month, dt.day);
        final dateParam =
            '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        Navigator.of(sheetContext).pop();
        Future.microtask(() =>
            context.push('/attendance/correction?date=$dateParam&type=$type'));
      },
    ),
  );
}

class _DayDetailBottomSheet extends StatelessWidget {
  const _DayDetailBottomSheet({
    required this.session,
    required this.onOpenCorrection,
  });

  final AttendanceSessionDto session;
  final VoidCallback onOpenCorrection;

  AppStatus _status() {
    if (session.isCompleted) return AppStatus.success;
    if (session.isPunchedIn && !session.isCompleted) return AppStatus.info;
    return AppStatus.warning;
  }

  String _statusLabel() {
    if (session.isCompleted) return 'Done';
    if (session.isPunchedIn && !session.isCompleted) return 'Working';
    return 'Open';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final missingPunchIn = session.punchInAt == null && session.punchOutAt != null;
    final missingPunchOut = session.punchInAt != null && session.punchOutAt == null;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.paddingBottomSafe + AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Attendance Details',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  IstTime.formatDateFromUtc(
                    session.workDate ??
                        session.punchInAt ??
                        DateTime.now().toUtc(),
                  ),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: StatusChip(status: _status(), label: _statusLabel()),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (missingPunchIn || missingPunchOut) ...[
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      missingPunchIn
                          ? 'This day has Missing Punch In. Please raise Attendance Correction.'
                          : 'This day has Missing Punch Out. Please raise Attendance Correction.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DetailRow(
                  label: 'Punch In',
                  value: _formatTimeIst(session.punchInAt),
                  subtext: session.punchInGeo?.hasLocation == true
                      ? _geoSummary(session.punchInGeo)
                      : 'No location',
                ),
                const SizedBox(height: AppSpacing.md),
                _DetailRow(
                  label: 'Punch Out',
                  value: _formatTimeIst(session.punchOutAt),
                  subtext: session.punchOutGeo?.hasLocation == true
                      ? _geoSummary(session.punchOutGeo)
                      : 'No location',
                ),
                const SizedBox(height: AppSpacing.md),
                _DetailRow(
                  label: 'Worked Duration',
                  value: session.workingHoursText.isNotEmpty
                      ? session.workingHoursText
                      : '--:--',
                  highlight: true,
                ),
              ],
            ),
          ),
          if (session.remarks != null &&
              session.remarks!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Remarks',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    session.remarks!.trim(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Attendance Correction',
            onPressed: onOpenCorrection,
            variant: AppButtonVariant.outlined,
            icon: const Icon(Icons.edit_calendar, size: 18),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.subtext,
    this.highlight = false,
  });

  final String label;
  final String value;
  final String? subtext;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: highlight ? cs.primary : cs.onSurface,
                  fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
                ),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (subtext != null) ...[
          const SizedBox(height: 4),
          Text(
            subtext!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

String _formatTimeIst(DateTime? utc) {
  if (utc == null) return '--:--';
  return IstTime.formatHHmmFromUtc(utc);
}

bool _isThisMonth((DateTime, DateTime) range) {
  final now = DateTime.now();
  final thisMonthStart = DateTime(now.year, now.month, 1);
  final thisMonthEnd = DateTime(now.year, now.month + 1, 0);
  return range.$1 == thisMonthStart && range.$2 == thisMonthEnd;
}

bool _isLastMonth((DateTime, DateTime) range) {
  final now = DateTime.now();
  final lastMonthStart = DateTime(now.year, now.month - 1, 1);
  final lastMonthEnd = DateTime(now.year, now.month, 0);
  return range.$1 == lastMonthStart && range.$2 == lastMonthEnd;
}

void _setThisMonthRange(WidgetRef ref) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 0);
  ref.read(_historyRangeProvider.notifier).state = (start, end);
}

void _setLastMonthRange(WidgetRef ref) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month - 1, 1);
  final end = DateTime(now.year, now.month, 0);
  ref.read(_historyRangeProvider.notifier).state = (start, end);
}

String _formatDate(DateTime d) {
  const months = 'Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec';
  final idx = (d.month - 1) * 4;
  final mon = months.substring(idx, idx + 3);
  return '${d.day} $mon ${d.year}';
}

/// Summary for UI: address + accuracy or "No location".
String _geoSummary(PunchGeoDto? geo) {
  if (geo == null || !geo.hasLocation) return 'No location';
  final parts = <String>[];
  if (geo.address != null && geo.address!.trim().isNotEmpty) {
    parts.add(geo.address!.trim());
  }
  if (geo.accuracy != null) {
    parts.add('±${geo.accuracy!.toStringAsFixed(0)} m');
  }
  return parts.isEmpty ? 'No location' : parts.join(' ');
}

Future<void> _pickRange(BuildContext context, WidgetRef ref) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final firstDate = DateTime(now.year - 1, 1, 1);

  final initialFrom = DateTime(now.year, now.month, 1);
  final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
  final initialTo = lastDayOfMonth.isAfter(today) ? today : lastDayOfMonth;

  final initialRange = DateTimeRange(
    start: initialFrom.isBefore(initialTo) ? initialFrom : initialTo,
    end: initialTo,
  );

  final picked = await showDateRangePicker(
    context: context,
    firstDate: firstDate,
    lastDate: today,
    initialDateRange: initialRange,
  );

  if (picked != null) {
    ref.read(_historyRangeProvider.notifier).state = (picked.start, picked.end);
  }
}
