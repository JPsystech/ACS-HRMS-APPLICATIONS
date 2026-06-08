import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import 'endpoints.dart';
import 'payslip_dto.dart';

class PayslipService {
  PayslipService({required this.dio});

  final Dio dio;

  String _normalizeEndpoint(String endpoint) {
    var e = endpoint.trim();
    if (e.isEmpty) return e;

    final parsed = Uri.tryParse(e);
    if (parsed != null && parsed.hasScheme) {
      final base = Uri.tryParse(ApiConfig.apiBaseUrl);
      if (base != null && parsed.host == base.host) {
        e = parsed.path;
        if (parsed.hasQuery) {
          e = '$e?${parsed.query}';
        }
      } else {
        return e;
      }
    }

    while (e.startsWith('/')) {
      e = e.substring(1);
    }

    var lower = e.toLowerCase();
    while (lower == 'api/v1' || lower.startsWith('api/v1/')) {
      e = lower == 'api/v1' ? '' : e.substring('api/v1/'.length);
      while (e.startsWith('/')) {
        e = e.substring(1);
      }
      lower = e.toLowerCase();
    }

    return e;
  }

  Future<List<PayslipDto>> myPayslips() async {
    if (kDebugMode) {
      debugPrint('🌐 My Payslips: GET ${Endpoints.payrollMyPayslips}');
    }
    final response = await dio.get<dynamic>(Endpoints.payrollMyPayslips);
    final list = _extractList(response.data);
    final results = <PayslipDto>[];
    for (final item in list) {
      if (item is Map) {
        results.add(PayslipDto.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    results.sort((a, b) {
      final ay = a.salaryYear;
      final by = b.salaryYear;
      if (ay != by) return by.compareTo(ay);
      final am = a.salaryMonth;
      final bm = b.salaryMonth;
      if (am != bm) return bm.compareTo(am);
      final ad = a.payslipDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.payslipDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    if (kDebugMode) {
      debugPrint('✅ My Payslips: count=${results.length}');
    }
    return results;
  }

  Future<Response<dynamic>> downloadPayslip(String id) {
    return dio.get<dynamic>(
      Endpoints.payrollPayslipDownload(id),
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: false,
        validateStatus: (s) => s != null && s < 500,
      ),
    );
  }

  Future<Response<dynamic>> downloadPayslipByEndpoint(String endpoint) {
    final cleaned = _normalizeEndpoint(endpoint);
    return dio.get<dynamic>(
      cleaned,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: false,
        validateStatus: (s) => s != null && s < 500,
      ),
    );
  }

  Future<Uint8List> downloadPayslipPdfBytes(String id) async {
    final first = await downloadPayslip(id);
    final code = first.statusCode ?? 0;
    if (code == 200) {
      final data = first.data;
      if (data is List<int>) return Uint8List.fromList(data);
      if (data is Uint8List) return data;
      throw Exception('Invalid file bytes');
    }

    if (code == 301 || code == 302 || code == 303 || code == 307 || code == 308) {
      final loc = first.headers.value('location');
      if (loc == null || loc.isEmpty) {
        throw Exception('Download link missing');
      }

      final raw = Uri.tryParse(loc);
      final resolved = raw == null
          ? null
          : raw.hasScheme
              ? raw
              : Uri.parse(ApiConfig.baseUrl).resolveUri(raw);
      if (resolved == null) {
        throw Exception('Invalid download link');
      }

      final client = Dio(
        BaseOptions(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      final second = await client.getUri<dynamic>(resolved);
      final secondCode = second.statusCode ?? 0;
      if (secondCode != 200) {
        throw Exception('Download failed (status $secondCode)');
      }
      final data = second.data;
      if (data is List<int>) return Uint8List.fromList(data);
      if (data is Uint8List) return data;
      throw Exception('Invalid file bytes');
    }

    final msg = _extractErrorMessage(first);
    throw Exception(msg ?? 'Download failed (status $code)');
  }

  Future<Uint8List> downloadPayslipPdfBytesByEndpoint(String endpoint) async {
    final first = await downloadPayslipByEndpoint(endpoint);
    final code = first.statusCode ?? 0;
    if (code == 200) {
      final data = first.data;
      if (data is List<int>) return Uint8List.fromList(data);
      if (data is Uint8List) return data;
      throw Exception('Invalid file bytes');
    }

    if (code == 301 || code == 302 || code == 303 || code == 307 || code == 308) {
      final loc = first.headers.value('location');
      if (loc == null || loc.isEmpty) {
        throw Exception('Download link missing');
      }

      final raw = Uri.tryParse(loc);
      final resolved = raw == null
          ? null
          : raw.hasScheme
              ? raw
              : Uri.parse(ApiConfig.baseUrl).resolveUri(raw);
      if (resolved == null) {
        throw Exception('Invalid download link');
      }

      final client = Dio(
        BaseOptions(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      final second = await client.getUri<dynamic>(resolved);
      final secondCode = second.statusCode ?? 0;
      if (secondCode != 200) {
        throw Exception('Download failed (status $secondCode)');
      }
      final data = second.data;
      if (data is List<int>) return Uint8List.fromList(data);
      if (data is Uint8List) return data;
      throw Exception('Invalid file bytes');
    }

    final msg = _extractErrorMessage(first);
    throw Exception(msg ?? 'Download failed (status $code)');
  }

  static List<dynamic> _extractList(dynamic data) {
    if (data == null) return <dynamic>[];
    if (data is List) return data;
    if (data is Map<String, dynamic>) {
      if (data['items'] is List) return data['items'] as List<dynamic>;
      if (data['data'] is List) return data['data'] as List<dynamic>;
      if (data['results'] is List) return data['results'] as List<dynamic>;
      if (data['payslips'] is List) return data['payslips'] as List<dynamic>;
      for (final v in data.values) {
        if (v is List) return v;
      }
    }
    return <dynamic>[];
  }

  static String? _extractErrorMessage(Response<dynamic> res) {
    try {
      final data = res.data;
      if (data is List<int>) {
        final decoded = utf8.decode(data, allowMalformed: true).trim();
        if (decoded.isEmpty) return null;
        try {
          final parsed = jsonDecode(decoded);
          if (parsed is Map && parsed['detail'] != null) return parsed['detail'].toString();
          if (parsed is Map && parsed['message'] != null) return parsed['message'].toString();
        } catch (_) {
          return decoded;
        }
        return decoded;
      }
      if (data is Map && data['detail'] != null) return data['detail'].toString();
      if (data is Map && data['message'] != null) return data['message'].toString();
      if (data is String && data.trim().isNotEmpty) return data.trim();
    } catch (_) {}
    return null;
  }
}
