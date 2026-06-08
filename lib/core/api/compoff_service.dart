import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'compoff_dto.dart';
import 'endpoints.dart';

class CompoffService {
  CompoffService({required this.dio});

  final Dio dio;

  /// GET /api/v1/compoff/balance
  Future<CompoffBalanceDto> getBalance() async {
    if (kDebugMode) {
      debugPrint('🌐 Compoff Balance: GET ${Endpoints.compoffBalance}');
    }
    final response = await dio.get<dynamic>(Endpoints.compoffBalance);
    final data = response.data;
    if (kDebugMode) {
      debugPrint('✅ Compoff Balance: ${response.statusCode}');
    }
    return CompoffBalanceDto.fromJson(data is Map ? data : <String, dynamic>{});
  }

  /// POST /api/v1/compoff/request. Backend expects worked_date (YYYY-MM-DD), reason.
  Future<Map<String, dynamic>> requestCompoff({
    required DateTime dateWorked,
    required String reason,
    double days = 1.0,
  }) async {
    final workedDate = dateWorked.toIso8601String().split('T').first;
    final payload = <String, dynamic>{
      'worked_date': workedDate,
      'reason': reason,
    };
    if (kDebugMode) {
      debugPrint('🌐 Compoff Request: POST ${Endpoints.compoffRequest}');
      debugPrint('📋 [Compoff] payload: $payload');
    }
    final response = await dio
        .post<Map<String, dynamic>>(Endpoints.compoffRequest, data: payload);
    if (kDebugMode) {
      debugPrint('✅ Compoff Request: ${response.statusCode}');
    }
    return response.data ?? <String, dynamic>{};
  }

  /// GET /api/v1/compoff/my-requests
  Future<List<CompoffRequestDto>> listMyRequests() async {
    if (kDebugMode) {
      debugPrint('🌐 Compoff My Requests: GET ${Endpoints.compoffMyRequests}');
    }
    final response = await dio.get<dynamic>(Endpoints.compoffMyRequests);
    final data = response.data;
    if (data is! List) return [];
    final list = data;
    return list
        .map((e) => CompoffRequestDto.fromJson(e))
        .whereType<CompoffRequestDto>()
        .toList();
  }
}
