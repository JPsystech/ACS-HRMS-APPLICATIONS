import 'package:flutter/material.dart';
import '../../core/api/event_service.dart';

class EventDetailsBottomSheet extends StatelessWidget {
  const EventDetailsBottomSheet({super.key, required this.event});
  final CompanyEventDto event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if ((event.imageUrl ?? '').isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    event.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: colorScheme.surfaceContainer,
                      child: const Center(child: Icon(Icons.image_not_supported_outlined, size: 40)),
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: Icon(Icons.image_outlined, size: 40)),
              ),
            const SizedBox(height: 16),
            Text(event.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.event, size: 18, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(_fmt(event.date), style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                if ((event.location ?? '').isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.place, size: 18, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Flexible(child: Text(event.location!, style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant))),
                ],
              ],
            ),
            const SizedBox(height: 16),
            if ((event.description ?? '').isNotEmpty)
              Text(event.description!, style: theme.textTheme.bodyLarge)
            else
              Text('No description available', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  }
}
