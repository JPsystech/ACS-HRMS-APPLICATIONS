import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'endpoints.dart';
import 'role_policy_dto.dart';

/// Service for safely fetching role policy information.
/// Handles 403 errors gracefully for non-HR users.
class RolePolicyService {
  RolePolicyService({required this.dio});

  final Dio dio;

  /// Safely fetch role policy for current user.
  /// Returns null if endpoint is not accessible (403) or on error.
  Future<RolePolicyDto?> getCurrentUserPolicy() async {
    try {
      if (kDebugMode) {
        debugPrint('🔐 [RolePolicyService] Trying user-allowed policy endpoint');
      }
      
      // First try user-allowed endpoints in order of preference
      final endpointsToTry = [
        '${Endpoints.policy}/me',      // Preferred: /api/v1/policy/me
        '${Endpoints.policy}/current', // Alternative: /api/v1/policy/current
      ];
      
      for (final endpoint in endpointsToTry) {
        try {
          if (kDebugMode) {
            debugPrint('🔐 [RolePolicyService] Trying GET endpoint');
          }
          
          final response = await dio.get<Map<String, dynamic>>(
            endpoint,
            options: Options(
              validateStatus: (status) => status != null && status < 500,
            ),
          );
          
          if (response.statusCode == 200) {
            if (kDebugMode) {
              debugPrint('✅ [RolePolicyService] Policy found at endpoint');
            }
            return RolePolicyDto.fromJson(response.data);
          }
          
          if (response.statusCode == 404) {
            if (kDebugMode) {
              debugPrint('ℹ️ [RolePolicyService] Endpoint not found: endpoint');
            }
            continue; // Try next endpoint
          }
          
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ [RolePolicyService] Endpoint failed: endpoint - e');
          }
          continue; // Try next endpoint
        }
      }
      
      // If no user-allowed endpoints work, return null (safe fallback)
      if (kDebugMode) {
        debugPrint('ℹ️ [RolePolicyService] No user-allowed policy endpoint available');
      }
      return null;
      
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        if (kDebugMode) {
          debugPrint('🔒 [RolePolicyService] Access denied (403) - user not authorized for policy endpoint');
        }
        return null; // Safe fallback for non-HR users
      }
      
      if (kDebugMode) {
        debugPrint('❌ [RolePolicyService] Error fetching policy: e');
      }
      return null; // Safe fallback on any error
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [RolePolicyService] Unexpected error: e');
      }
      return null; // Safe fallback on any error
    }
  }
}