import 'package:acs_hrms/features/events/event_details_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/event_service.dart';
import '../../core/providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/acs/acs_empty_state.dart';

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);
    final theme = Theme.of(context);

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    String fmt(DateTime d) => DateFormat('dd MMM, yyyy').format(d);

    List<CompanyEventDto> upcoming0(List<CompanyEventDto> list) {
      final items = list.where((e) => e.active && !e.date.isBefore(todayDate)).toList();
      items.sort((a, b) => a.date.compareTo(b.date));
      return items;
    }

    List<CompanyEventDto> previous0(List<CompanyEventDto> list) {
      final items = list.where((e) => e.active && e.date.isBefore(todayDate)).toList();
      items.sort((a, b) => b.date.compareTo(a.date));
      return items;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Company Events')),
      body: eventsAsync.when(
        data: (events) {
          final upcoming = upcoming0(events);
          final previous = previous0(events);
          if (upcoming.isEmpty && previous.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ACSEmptyState(
                  icon: Icons.celebration_outlined,
                  title: 'No events to show',
                  subtitle: 'New events will appear here once published',
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (upcoming.isNotEmpty) ...[
                Text(
                  'Upcoming Events',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    children: upcoming.map((e) => _EventCard(event: e, fmt: fmt)).toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (previous.isNotEmpty) ...[
                Text(
                  'Previous Celebrations',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    children: previous.map((e) => _EventCard(event: e, fmt: fmt)).toList(),
                  ),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ACSEmptyState(
              icon: Icons.error_outline,
              title: 'Unable to load events',
            ),
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.fmt});
  final CompanyEventDto event;
  final String Function(DateTime) fmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (ctx) => EventDetailsBottomSheet(event: event),
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
                width: 72,
                height: 72,
                child: _EventImage(url: event.imageUrl),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.event, size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(fmt(event.date), style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                      if ((event.location ?? '').isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.place, size: 14, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(event.location!, style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ],
                  ),
                  if ((event.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      event.description!,
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
