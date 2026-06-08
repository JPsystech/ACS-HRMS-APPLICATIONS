import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/section_title.dart';
import '../../events/event_details_bottom_sheet.dart';

class EventsWidget extends ConsumerWidget {
  const EventsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return eventsAsync.when(
      data: (events) {
        final upcoming = events
            .where((e) => e.active && !e.date.isBefore(today))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        if (upcoming.isEmpty) return const SizedBox.shrink();
        final top3 = upcoming.take(3).toList();

        String _fmt(DateTime d) => DateFormat('dd MMM, yyyy').format(d);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(title: 'Events & Celebrations'),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                children: top3.map((e) {
                  // Debug: print parsed image URL before rendering
                  // ignore: avoid_print
                  print("[Events] Flutter parsed imageUrl: ${e.imageUrl}");
                  return InkWell(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (ctx) => EventDetailsBottomSheet(event: e),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 64,
                              height: 64,
                              child: _EventImage(url: e.imageUrl),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.name,
                                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.event, size: 14, color: colorScheme.onSurfaceVariant),
                                    const SizedBox(width: 4),
                                    Text(_fmt(e.date), style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                                    if ((e.location ?? '').isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Icon(Icons.place, size: 14, color: colorScheme.onSurfaceVariant),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(e.location!, style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                                      ),
                                    ],
                                  ],
                                ),
                                if ((e.description ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    e.description!,
                                    style: theme.textTheme.bodySmall,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _EventImage extends StatelessWidget {
  const _EventImage({required this.url});
  final String? url;
  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceContainer;
    if (url == null || url!.isEmpty) {
      return Container(color: bg, child: const Icon(Icons.image_not_supported_outlined));
    }
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(color: bg, child: const Icon(Icons.image_not_supported_outlined)),
    );
  }
}
