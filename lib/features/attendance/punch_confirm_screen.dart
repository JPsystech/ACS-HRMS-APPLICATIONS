import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/device/device_id_service.dart';
import '../../core/location/location_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers.dart';
import '../../core/utils/ist_time.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/fade_in_wrapper.dart';
import '../../widgets/status_chip.dart';
import 'punch_session.dart';

/// Step 2 of 2: Confirm punch — Face card, Location card, Confirm button.
class PunchConfirmScreen extends ConsumerWidget {
  const PunchConfirmScreen({super.key});

  static final Random _random = Random();

  /// Fetch real location using device GPS
  static Future<void> _fetchRealLocation(WidgetRef ref) async {
    try {
      // Check location permission
      final hasPermission = await LocationService.isLocationPermissionGranted();
      if (!hasPermission) {
        final granted = await LocationService.requestLocationPermission();
        if (!granted) {
          throw Exception('Location permission denied');
        }
      }

      // Check if location services are enabled
      final isEnabled = await LocationService.isLocationServiceEnabled();
      if (!isEnabled) {
        throw Exception('Location services are disabled');
      }

      // Get current location
      final position = await LocationService.getCurrentLocation();

      final controller = ref.read(punchSessionProvider.notifier);
      controller.setLocation(
        position.latitude,
        position.longitude,
        position.accuracy,
      );
    } catch (e) {
      // Fallback to dummy location if real location fails
      final controller = ref.read(punchSessionProvider.notifier);
      final lat = 12.9 + _random.nextDouble() * 2; // 12.9–14.9 (Bangalore area)
      final lng = 77.5 + _random.nextDouble() * 2; // 77.5–79.5 (Bangalore area)
      final accuracy = 5.0 + _random.nextDouble() * 25; // 5–30
      controller.setLocation(lat, lng, accuracy);

      // Re-throw to show error message
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(punchSessionProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (session == null) {
      return FadeInWrapper(
        child: Scaffold(
          backgroundColor: AppColors.backgroundLight,
          appBar: AppBar(title: const Text('Confirm Punch')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No active punch session.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Back to Dashboard',
                    icon: Icon(Icons.dashboard_rounded,
                        size: AppDimensions.iconSm),
                    onPressed: () => context.go('/dashboard'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final canConfirm = session.isFaceCaptured && session.isLocationCaptured;
    final confirmLabel =
        session.isPunchIn ? 'Punch In Confirm' : 'Punch Out Confirm';

    return FadeInWrapper(
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(title: const Text('Confirm Punch')),
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.paddingBottomSafe + AppSpacing.md,
            ),
            children: [
              Text(
                'Step 2 of 2: Confirm Punch',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _FaceCard(
                session: session,
                theme: theme,
                colorScheme: colorScheme,
              ),
              const SizedBox(height: AppSpacing.md),
              _LocationCard(
                session: session,
                theme: theme,
                colorScheme: colorScheme,
                onFetchLocation: () => _fetchRealLocation(ref),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: confirmLabel,
                  icon: Icon(
                    session.isPunchIn
                        ? Icons.login_rounded
                        : Icons.logout_rounded,
                    size: AppDimensions.iconSm,
                  ),
                  onPressed: canConfirm
                      ? () => _onConfirm(context, ref, session)
                      : null,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'Back to Dashboard',
                  variant: AppButtonVariant.tonal,
                  icon:
                      Icon(Icons.dashboard_rounded, size: AppDimensions.iconSm),
                  onPressed: () {
                    ref.read(punchSessionProvider.notifier).reset();
                    context.go('/dashboard');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onConfirm(
      BuildContext context, WidgetRef ref, PunchSession session) async {
    HapticFeedback.lightImpact();
    final facePath = session.faceImagePath;
    if (facePath == null || !session.isLocationCaptured) return;

    try {
      final service = ref.read(attendanceServiceProvider);
      final deviceId = await DeviceIdService.getDeviceId();
      final capturedAt = (session.locationCapturedAt ?? DateTime.now())
          .toUtc()
          .toIso8601String();
      if (session.isPunchIn) {
        await service.punchIn(
          deviceId: deviceId,
          lat: session.lat,
          lng: session.lng,
          accuracy: session.accuracy,
          capturedAt: capturedAt,
          address: null,
        );
      } else {
        await service.punchOut(
          deviceId: deviceId,
          lat: session.lat,
          lng: session.lng,
          accuracy: session.accuracy,
          capturedAt: capturedAt,
          address: null,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, e);
      return;
    }

    ref.read(punchSessionProvider.notifier).reset();

    try {
      final service = ref.read(attendanceServiceProvider);
      final dto = await service.today();
      ref.read(todayAttendanceProvider.notifier).setFromApi(
            punchInTime: dto.punchInTime,
            punchOutTime: dto.punchOutTime,
          );
    } catch (_) {
      final nowUtc = DateTime.now().toUtc();
      final todayNotifier = ref.read(todayAttendanceProvider.notifier);
      if (session.isPunchIn) {
        todayNotifier.setPunchIn(nowUtc);
      } else {
        todayNotifier.setPunchOut(nowUtc);
      }
    }

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PunchSuccessDialog(
        theme: Theme.of(context),
        colorScheme: Theme.of(context).colorScheme,
      ),
    );
    if (!context.mounted) return;
    context.go('/dashboard');
  }

  void _showError(BuildContext context, dynamic e) {
    final message = e is Exception
        ? (e.toString().toLowerCase().contains('socket') ||
                e.toString().toLowerCase().contains('network')
            ? 'Network error. Please try again.'
            : 'Punch failed. Please try again.')
        : 'Punch failed. Please try again.';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Face card: "Face Captured ✅" + small thumbnail placeholder.
class _FaceCard extends StatelessWidget {
  const _FaceCard({
    required this.session,
    required this.theme,
    required this.colorScheme,
  });

  final PunchSession session;
  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.face_rounded,
                  color: colorScheme.primary, size: AppDimensions.iconMd),
              const SizedBox(width: AppSpacing.sm),
              Text('Face', style: theme.textTheme.titleMedium),
              const Spacer(),
              if (session.isFaceCaptured)
                const StatusChip(status: AppStatus.success, label: 'Captured ✅')
              else
                StatusChip(status: AppStatus.warning, label: 'Not captured'),
            ],
          ),
          if (session.isFaceCaptured) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.cardRadiusSmall),
                    border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.5)),
                  ),
                  child: Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 28),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  'Face Captured ✅',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Location card: not captured vs captured with lat/lng/accuracy/time + Fetch / Re-fetch.
class _LocationCard extends StatefulWidget {
  const _LocationCard({
    required this.session,
    required this.theme,
    required this.colorScheme,
    required this.onFetchLocation,
  });

  final PunchSession session;
  final ThemeData theme;
  final ColorScheme colorScheme;
  final Future<void> Function() onFetchLocation;

  @override
  State<_LocationCard> createState() => __LocationCardState();
}

class __LocationCardState extends State<_LocationCard> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleFetchLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onFetchLocation();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatTime(DateTime d) {
    final utc = d.isUtc ? d : d.toUtc();
    return IstTime.formatHHmmFromUtc(utc);
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_rounded,
                  color: widget.colorScheme.primary,
                  size: AppDimensions.iconMd),
              const SizedBox(width: AppSpacing.sm),
              Text('Location', style: widget.theme.textTheme.titleMedium),
              const Spacer(),
              if (widget.session.isLocationCaptured)
                const StatusChip(status: AppStatus.success, label: 'Captured')
              else
                const StatusChip(
                    status: AppStatus.warning, label: 'Not captured'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_errorMessage != null) ...[
            Text(
              'Location unavailable: $_errorMessage',
              style: widget.theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (!widget.session.isLocationCaptured) ...[
            Text(
              'Location not captured',
              style: widget.theme.textTheme.bodyMedium?.copyWith(
                color: widget.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : AppButton(
                      label: 'Fetch Location',
                      variant: AppButtonVariant.outlined,
                      icon: Icon(Icons.my_location_rounded,
                          size: AppDimensions.iconSm),
                      onPressed: _handleFetchLocation,
                    ),
            ),
          ] else ...[
            _InfoRow(
                label: 'Latitude',
                value: widget.session.lat!.toStringAsFixed(4),
                theme: widget.theme,
                colorScheme: widget.colorScheme),
            const SizedBox(height: AppSpacing.sm),
            _InfoRow(
                label: 'Longitude',
                value: widget.session.lng!.toStringAsFixed(4),
                theme: widget.theme,
                colorScheme: widget.colorScheme),
            const SizedBox(height: AppSpacing.sm),
            _InfoRow(
                label: 'Accuracy',
                value: '${widget.session.accuracy!.toStringAsFixed(0)} m',
                theme: widget.theme,
                colorScheme: widget.colorScheme),
            if (widget.session.locationCapturedAt != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _InfoRow(
                label: 'Time',
                value: _formatTime(widget.session.locationCapturedAt!),
                theme: widget.theme,
                colorScheme: widget.colorScheme,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : AppButton(
                      label: 'Re-fetch Location',
                      variant: AppButtonVariant.outlined,
                      icon: Icon(Icons.refresh_rounded,
                          size: AppDimensions.iconSm),
                      onPressed: _handleFetchLocation,
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.theme,
    required this.colorScheme,
  });

  final String label;
  final String value;
  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            '$label:',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

/// Success dialog with scale + pulse animation, then auto-close.
class _PunchSuccessDialog extends StatefulWidget {
  const _PunchSuccessDialog({
    required this.theme,
    required this.colorScheme,
  });

  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  State<_PunchSuccessDialog> createState() => _PunchSuccessDialogState();
}

class _PunchSuccessDialogState extends State<_PunchSuccessDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scale;
  late AnimationController _pulseController;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _scaleController.forward();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _pulse = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.06), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0), weight: 1),
    ]).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _scaleController.addStatusListener((status) {
      if (status == AnimationStatus.completed) _pulseController.forward();
    });

    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      final navigator = Navigator.maybeOf(context);
      if (navigator != null && navigator.canPop()) {
        navigator.pop();
      }
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final colorScheme = widget.colorScheme;
    return PopScope(
      canPop: false,
      child: Dialog(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _scale,
                child: ScaleTransition(
                  scale: _pulse,
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 64,
                    color: AppColors.success,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Punch recorded successfully',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Redirecting to Dashboard...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
