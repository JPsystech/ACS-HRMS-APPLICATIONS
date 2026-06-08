import 'package:dio/dio.dart';

import 'culture_dto.dart';
import 'endpoints.dart';

class CultureService {
  CultureService({required this.dio});

  final Dio dio;

  Future<Map<String, dynamic>> themeToday() async {
    final res = await dio.get<Map<String, dynamic>>(Endpoints.cultureThemeToday);
    return res.data ?? <String, dynamic>{};
  }

  Future<List<BirthdayEmployeeDto>> birthdaysToday() async {
    final res = await dio.get<dynamic>(Endpoints.birthdaysToday);
    assert(() { print('🎂 [CultureService] GET ${Endpoints.birthdaysToday} → ${res.statusCode}'); return true; }());
    final data = res.data;
    final raw = data is List
        ? data
        : (data is Map<String, dynamic> ? (data['items'] as List<dynamic>? ?? const <dynamic>[]) : const <dynamic>[]);
    return raw
        .map((e) => BirthdayEmployeeDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<BirthdayEmployeeDto>> birthdaysUpcoming(int days) async {
    final res = await dio.get<dynamic>(
      Endpoints.birthdaysUpcoming,
      queryParameters: {'days': days},
    );
    assert(() { print('🎂 [CultureService] GET ${Endpoints.birthdaysUpcoming}?days=$days → ${res.statusCode}'); return true; }());
    final data = res.data;
    final raw = data is List
        ? data
        : (data is Map<String, dynamic> ? (data['items'] as List<dynamic>? ?? const <dynamic>[]) : const <dynamic>[]);
    return raw
        .map((e) => BirthdayEmployeeDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<GreetingDto> generateGreeting(String employeeId, {String? message, bool force = false}) async {
    final res = await dio.post<Map<String, dynamic>>(
      Endpoints.generateGreeting(employeeId),
      data: {
        if (message != null && message.isNotEmpty) 'message': message,
      },
      queryParameters: {
        'force': force,
      },
    );
    return GreetingDto.fromJson(res.data ?? <String, dynamic>{});
  }

  Future<GreetingDto> sendWish(String employeeId, {String? wishMessage}) async {
    final res = await dio.post<Map<String, dynamic>>(
      Endpoints.sendWish(employeeId),
      data: {
        if (wishMessage != null && wishMessage.isNotEmpty) 'wish_message': wishMessage,
      },
    );
    assert(() { print('🎂 [CultureService] POST ${Endpoints.sendWish(employeeId)} → ${res.statusCode}'); return true; }());
    return GreetingDto.fromJson(res.data ?? <String, dynamic>{});
  }

  Future<List<WishDto>> listWishes(String employeeId) async {
    final res = await dio.get<Map<String, dynamic>>(Endpoints.listWishes(employeeId));
    final m = res.data ?? <String, dynamic>{};
    final list = m['items'] is List ? m['items'] as List : <dynamic>[];
    return list.map((e) => WishDto.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> replyToWish(String wishId, {required String message}) async {
    final res = await dio.post<Map<String, dynamic>>(
      Endpoints.replyWish(wishId),
      data: {
        'message': message,
      },
    );
    assert(() { print('🎂 [CultureService] POST ${Endpoints.replyWish(wishId)} → ${res.statusCode}'); return true; }());
  }

  Future<void> updateProfile({String? name, String? dob}) async {
    await dio.put(Endpoints.meProfileUpdate, data: {
      if (name != null) 'name': name,
      if (dob != null) 'dob': dob,
    });
  }

  Future<Map<String, dynamic>> uploadProfilePhoto(String filePath) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: 'avatar.jpg'),
    });
    final res = await dio.post<Map<String, dynamic>>(Endpoints.meProfilePhoto, data: form);
    return res.data ?? <String, dynamic>{};
  }
}
