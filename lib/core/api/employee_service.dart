import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'employee_me_dto.dart';
import 'endpoints.dart';

/// Service for employee-related API (e.g. current user profile).
/// Uses GET /api/v1/employees/me per Swagger.
class EmployeeService {
  EmployeeService({required this.dio});

  final Dio dio;

  /// GET /api/v1/employees/me - current user profile (name, empCode, mobileNumber, departmentName, managerName).
  Future<EmployeeMeDto> me() async {
    if (kDebugMode) {
      debugPrint('👤 [EmployeeService] GET ${Endpoints.employeesMe}');
    }
    final response = await dio.get<Map<String, dynamic>>(Endpoints.employeesMe);
    final body = response.data ?? <String, dynamic>{};
    if (kDebugMode) {
      debugPrint('👤 [EmployeeService] ${response.statusCode} ${response.requestOptions.uri}');
    }
    return EmployeeMeDto.fromJson(body);
  }
}
