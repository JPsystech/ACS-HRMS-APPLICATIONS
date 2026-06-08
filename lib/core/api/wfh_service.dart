import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'endpoints.dart';
import 'wfh_balance_dto.dart';
import 'wfh_dto.dart';

class WfhService {
  WfhService({required this.dio});

  final Dio dio;

  /// POST /api/v1/wfh/apply
  /// Backend expects request_date (YYYY-MM-DD) and reason.
  Future<void> applyWfh({
    required String fromDate,
    String? toDate,
    required String reason,
  }) async {
    final now = DateTime.now();
    final today = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final payload = <String, dynamic>{
      // API requires request_date (today) in addition to from_date/to_date and reason.
      'request_date': today,
      'from_date': fromDate,
      'reason': reason,
    };
    if (toDate != null && toDate.trim().isNotEmpty) {
      payload['to_date'] = toDate.trim();
    }

    if (kDebugMode) {
      debugPrint('🌐 WFH Apply: POST ${Endpoints.wfhApply} payload=$payload');
    }

    await dio.post<dynamic>(Endpoints.wfhApply, data: payload);
  }

  /// GET /api/v1/wfh/my
  Future<List<WfhRequestDto>> myWfh() async {
    if (kDebugMode) {
      debugPrint('🌐 My WFH: GET ${Endpoints.wfhMy}');
    }
    final response = await dio.get<dynamic>(Endpoints.wfhMy);
    final data = response.data;

    List<dynamic> extractList(dynamic value) {
      if (value == null) return <dynamic>[];
      if (value is List) return value;
      if (value is Map<String, dynamic>) {
        if (value['items'] is List) return value['items'] as List<dynamic>;
        if (value['data'] is List) return value['data'] as List<dynamic>;
        if (value['results'] is List) return value['results'] as List<dynamic>;
        if (value['wfh'] is List) return value['wfh'] as List<dynamic>;
        for (final v in value.values) {
          if (v is List) return v;
        }
      }
      return <dynamic>[];
    }

    final list = extractList(data);
    final results = <WfhRequestDto>[];
    for (final item in list) {
      final dto = WfhRequestDto.fromJson(item);
      if (dto != null) {
        results.add(dto);
      }
    }

    // Newest first: prefer createdAt, else from-date.
    results.sort((a, b) {
      final aDate = a.createdAt ?? a.primaryFrom ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? b.primaryFrom ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    if (kDebugMode) {
      debugPrint('✅ My WFH: count=${results.length}');
    }

    return results;
  }

  /// GET /api/v1/wfh/balance/me?year=YYYY
  Future<WfhBalanceDto> getMyWfhBalance(int year) async {
    if (kDebugMode) {
      debugPrint('🌐 WFH Balance: GET ${Endpoints.wfhBalanceMe}?year=$year');
    }
    final response = await dio.get<dynamic>(
      Endpoints.wfhBalanceMe,
      queryParameters: {'year': year},
    );
    final data = response.data;
    if (kDebugMode) {
      debugPrint('✅ WFH Balance: ${response.statusCode}');
    }
    return WfhBalanceDto.fromJson(data);
  }
}

