import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

class GreetingCard extends ConsumerStatefulWidget {
  const GreetingCard({super.key});

  @override
  ConsumerState<GreetingCard> createState() => _GreetingCardState();
}

class _GreetingCardState extends ConsumerState<GreetingCard> {
  bool loading = false;
  String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeAsync = ref.watch(birthdayThemeProvider);

    return themeAsync.when(
      data: (t) {
        final mode = (t['mode'] as String?) ?? 'NORMAL';
        if (mode != 'BIRTHDAY') return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🎉 ', style: TextStyle(fontSize: 20)),
                  Expanded(
                    child: Text(
                      (t['bannerText'] as String?) ?? 'Happy Birthday',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 0,
                      maxWidth: 200,
                      minHeight: 36,
                      maxHeight: 40,
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    onPressed: loading
                        ? null
                        : () async {
                            try {
                              setState(() => loading = true);
                              final profile = ref.read(profileProvider).valueOrNull;
                              if (profile == null) return;
                              final service = ref.read(cultureServiceProvider);
                              final res = await service.generateGreeting(profile.id.toString());
                              setState(() {
                                imageUrl = res.greetingImageUrl;
                                loading = false;
                              });
                            } catch (e) {
                              setState(() => loading = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                              }
                            }
                          },
                      child: loading ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Generate Greeting'),
                    ),
                  ),
                ],
              ),
              if (imageUrl != null && imageUrl!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, st) {
                      return Container(
                        height: 180,
                        width: double.infinity,
                        color: colorScheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: Icon(Icons.image_not_supported_outlined, color: colorScheme.onSurfaceVariant),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    onPressed: () {
                      Share.share(imageUrl!);
                    },
                    child: const Text('Share'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
