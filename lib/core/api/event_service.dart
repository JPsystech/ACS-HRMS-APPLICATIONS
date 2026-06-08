import 'package:dio/dio.dart';
import 'endpoints.dart';

class CompanyEventDto {
  CompanyEventDto({
    required this.id,
    required this.year,
    required this.date,
    required this.name,
    this.description,
    this.imageUrl,
    this.location,
    required this.active,
  });
  final int id;
  final int year;
  final DateTime date;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? location;
  final bool active;
}

class EventService {
  EventService({required this.dio});
  final Dio dio;

  Future<List<CompanyEventDto>> listEvents({bool onlyActive = true}) async {
    final query = onlyActive ? '?active=true' : '';
    final response = await dio.get<dynamic>(Endpoints.events + query);
    final list = response.data is List ? response.data as List : <dynamic>[];
    return list.map((e) {
      final m = e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};
      // Debug: log image_url from API
      // ignore: avoid_print
      print("[Events] API image_url: ${m['image_url']}");
      return CompanyEventDto(
        id: (m['id'] as num?)?.toInt() ?? 0,
        year: (m['year'] as num?)?.toInt() ?? DateTime.now().year,
        date: _parseTime(m['date']) ?? DateTime.now(),
        name: m['name'] as String? ?? '',
        description: m['description'] as String?,
        imageUrl: m['image_url'] as String?,
        location: m['location'] as String?,
        active: (m['active'] as bool?) ?? true,
      );
    }).toList();
  }

  static DateTime? _parseTime(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
