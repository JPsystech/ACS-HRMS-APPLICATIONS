import 'package:flutter/material.dart';
import '../../../widgets/app_card.dart';
import '../../../core/theme/app_theme.dart';

class ThoughtOfDayWidget extends StatefulWidget {
  const ThoughtOfDayWidget({super.key});

  @override
  State<ThoughtOfDayWidget> createState() => _ThoughtOfDayWidgetState();
}

class _ThoughtOfDayWidgetState extends State<ThoughtOfDayWidget>
    with SingleTickerProviderStateMixin {
  static const _thoughts = [
    'Small steps add up to big results.',
    'Focus on progress, not perfection.',
    'Great teams communicate clearly and act fast.',
    'Consistency beats intensity.',
    'Own the outcome.',
  ];

  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final idx = DateTime.now().day % _thoughts.length;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final quote = _thoughts[idx];

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: FadeTransition(
        opacity: _fade,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_rounded, 
              color: colorScheme.secondary, 
              size: AppDimensions.iconMd,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                quote,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
