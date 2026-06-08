import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_card.dart';

class AttendanceStreakWidget extends ConsumerStatefulWidget {
  const AttendanceStreakWidget({super.key});

  @override
  ConsumerState<AttendanceStreakWidget> createState() => _AttendanceStreakWidgetState();
}

class _AttendanceStreakWidgetState extends ConsumerState<AttendanceStreakWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  int _streak = 0;
  int _consistency = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      lowerBound: 0.98,
      upperBound: 1.0,
    )..value = 1.0;
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _streak = 0;
    _consistency = 0;
  }

  void _pulse() {
    _controller.reverse().then((_) => _controller.forward());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    ref.listen(attendanceStreakProvider, (prev, next) {
      next.whenData((v) {
        setState(() {
          _streak = v.currentStreakDays;
          _consistency = v.consistencyPercent;
        });
      });
    });

    final streakAsync = ref.watch(attendanceStreakProvider);
    final shimmer = Opacity(
      opacity: 0.35,
      child: Container(
        width: 64,
        height: 16,
        color: colorScheme.surfaceVariant,
      ),
    );

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: GestureDetector(
        onTap: _pulse,
        child: ScaleTransition(
          scale: _scale,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Icon(Icons.local_fire_department_rounded, 
                  color: colorScheme.onPrimaryContainer,
                  size: AppDimensions.iconMd,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    streakAsync.isLoading
                        ? shimmer
                        : Text('Streak: $_streak days',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                    const SizedBox(height: AppSpacing.xs),
                    streakAsync.isLoading
                        ? shimmer
                        : Text('Consistency: $_consistency%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
