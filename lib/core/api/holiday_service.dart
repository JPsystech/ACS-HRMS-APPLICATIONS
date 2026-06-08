import 'package:dio/dio.dart';

import 'api_repository.dart';
import 'endpoints.dart';

class HolidayService {
  HolidayService({required this.dio});

  final Dio dio;

  Future<List<HolidayDto>> listHolidays() async {
    final response = await dio.get<dynamic>(Endpoints.calendarsHolidays);
    final list = response.data is List ? response.data as List : <dynamic>[];
    return list.map((e) {
      final m = e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};
      return HolidayDto(
        date: _parseTime(m['date']) ?? DateTime.now(),
        name: m['name'] as String? ?? '',
        type: (m['type'] as String? ?? 'public') == 'restricted' ? 'restricted' : 'public',
        description: m['description'] as String? ?? '',
        imageUrl: m['image_url'] as String?,
      );
    }).toList();
  }

  Future<List<HolidayDto>> listRestrictedHolidays() async {
    final response = await dio.get<dynamic>(Endpoints.calendarsRestrictedHolidays);
    final list = response.data is List ? response.data as List : <dynamic>[];
    return list.map((e) {
      final m = e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};
      return HolidayDto(
        date: _parseTime(m['date']) ?? DateTime.now(),
        name: m['name'] as String? ?? '',
        type: 'restricted',
        description: m['description'] as String? ?? '',
        imageUrl: m['image_url'] as String?,
      );
    }).toList();
  }

  static DateTime? _parseTime(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
