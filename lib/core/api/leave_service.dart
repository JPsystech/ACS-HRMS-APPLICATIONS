import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../utils/server_datetime_util.dart';
import 'api_repository.dart';
import 'endpoints.dart';
import 'leave_balance_dto.dart';
import 'leave_policy_dto.dart';
import 'pending_leave_dto.dart';
import '../models/role.dart';

class LeaveService {
  LeaveService({required this.dio});

  final Dio dio;

  /// Returns response body on success (may contain balance/LWP). Throws on error.
  Future<Map<String, dynamic>?> applyLeave({
    required String leaveType,
    required DateTime fromDate,
    required DateTime toDate,
    required String reason,
    required String duration,
    String? halfDaySession,
  }) async {
    final payload = {
      'leave_type': leaveType,
      'from_date': fromDate.toIso8601String().split('T').first,
      'to_date': toDate.toIso8601String().split('T').first,
      'reason': reason,
      'duration': duration,
      if (duration == 'HALF_DAY') 'half_day_session': halfDaySession,
    };
    if (kDebugMode) {
      debugPrint('🌐 Leave Apply Request: POST ${Endpoints.applyLeave}');
      if (duration == 'HALF_DAY') {
        debugPrint('📝 Payload: $payload');
      }
    }
    try {
      final response = await dio.post<Map<String, dynamic>>(Endpoints.applyLeave, data: payload);
      if (kDebugMode) {
        debugPrint('✅ Leave Apply Success: ${response.statusCode}');
      }
      return response.data;
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Leave Apply Error: ${e.response?.statusCode}');
      }
      
      // Re-throw with more detailed error information
      if (e.response != null && e.response!.data is Map) {
        final data = e.response!.data as Map<String, dynamic>;
        if (data.containsKey('detail')) {
          throw Exception(data['detail'] as String);
        }
      }
      
      rethrow;
    }
  }

  /// Update a pending leave request (Employee self-edit).
  Future<Map<String, dynamic>?> updateLeave({
    required String leaveId,
    required String leaveType,
    required DateTime fromDate,
    required DateTime toDate,
    required String reason,
    required String duration,
    String? halfDaySession,
  }) async {
    final payload = {
      'leave_type': leaveType,
      'from_date': fromDate.toIso8601String().split('T').first,
      'to_date': toDate.toIso8601String().split('T').first,
      'reason': reason,
      'duration': duration,
      if (duration == 'HALF_DAY') 'half_day_session': halfDaySession,
    };
    final url = Endpoints.leaveUpdate(leaveId);
    if (kDebugMode) {
      debugPrint('🌐 Leave Update Request: PUT $url');
      debugPrint('📝 Payload: $payload');
    }
    try {
      final response = await dio.put<Map<String, dynamic>>(url, data: payload);
      if (kDebugMode) {
        debugPrint('✅ Leave Update Success: ${response.statusCode}');
      }
      return response.data;
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Leave Update Error: ${e.response?.statusCode}');
      }
      
      if (e.response != null && e.response!.data is Map) {
        final data = e.response!.data as Map<String, dynamic>;
        if (data.containsKey('detail')) {
          throw Exception(data['detail'] as String);
        }
      }
      rethrow;
    }
  }

  /// GET /api/v1/leaves/balance/summary/me?year=YYYY for dashboard card.
  Future<LeaveBalanceResponseDto> getLeaveBalanceSummary(int year) async {
    if (kDebugMode) {
        debugPrint('🌐 Leave Balance Summary: GET ${Endpoints.leaveBalanceSummaryMe}?year=$year');
      }
    try {
      final response = await dio.get<dynamic>(
        Endpoints.leaveBalanceSummaryMe,
        queryParameters: {'year': year},
      );
      final data = response.data;
      if (kDebugMode) {
        debugPrint('✅ Leave Balance Summary: ${response.statusCode}');
      }
      return LeaveBalanceResponseDto.fromJson(data);
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Leave Balance Summary Error: ${e.response?.statusCode}');
      }
      rethrow;
    }
  }

  /// GET /api/v1/policy/{year}
  /// Only HR/ADMIN users can access this endpoint. For non-HR users, returns default policy.
  Future<LeavePolicyDto> getPolicy(int year, {Role? userRole}) async {
    // Check if user is HR/ADMIN - only these roles can access the policy endpoint
    final isHrOrAdmin = userRole == Role.admin;
    
    if (!isHrOrAdmin) {
      if (kDebugMode) {
        // print('🔒 Leave Policy: Skipping API call for non-HR user (role: ${userRole?.backendValue ?? \'unknown\'})');
      }
      return LeavePolicyDto(year: year);
    }
    
    if (kDebugMode) {
      print('🌐 Leave Policy: GET ${Endpoints.policy}/$year');
    }
    try {
      final response = await dio.get<dynamic>('${Endpoints.policy}/$year');
      return LeavePolicyDto.fromJson(response.data, year: year);
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ Leave Policy Error: ${e.response?.statusCode} — using defaults');
      }
      return LeavePolicyDto(year: year);
    }
  }

  /// GET /api/v1/leaves/balance/me?year=YYYY
  Future<LeaveBalanceResponseDto> getLeaveBalance(int year) async {
    if (kDebugMode) {
      print('🌐 Leave Balance Request: GET ${Endpoints.leaveBalanceMe}?year=$year');
    }
    try {
      final response = await dio.get<dynamic>(
        Endpoints.leaveBalanceMe,
        queryParameters: {'year': year},
      );
      final data = response.data;
      if (kDebugMode) {
        debugPrint('✅ Leave Balance Success: ${response.statusCode}');
      }
      return LeaveBalanceResponseDto.fromJson(data);
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Leave Balance Error: ${e.response?.statusCode}');
      }
      rethrow;
    }
  }

  Future<List<LeaveDto>> listLeaves() async {
    if (kDebugMode) {
      debugPrint('🌐 My Leaves Request:');
      debugPrint('   URL: GET ${Endpoints.leavesMy}');
    }
    
    try {
      final response = await dio.get<dynamic>(Endpoints.leavesMy);
      final rawList = _extractList(response.data ?? <String, dynamic>{});

      if (kDebugMode) {
        debugPrint('✅ My Leaves: resolved URL: ${response.requestOptions.uri}');
        debugPrint('   Status: ${response.statusCode}');
        debugPrint('   Parsed items[] count: ${rawList.length}');
      }

      if (rawList.isEmpty) {
        return [];
      }
      
      // Parse each item safely; do NOT filter by status (include pending, approved, rejected, cancelled)
      final List<LeaveDto> leaves = [];
      for (final item in rawList) {
        try {
          final leave = _parseLeaveItem(item);
          if (leave != null) {
            leaves.add(leave);
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️  Skipping invalid leave item: $item');
            print('   Error: $e');
          }
          continue;
        }
      }

      // Sort by fromDate descending (newest first)
      leaves.sort((a, b) => b.fromDate.compareTo(a.fromDate));

      if (kDebugMode) {
        final byStatus = <String, int>{};
        for (final l in leaves) {
          byStatus[l.status] = (byStatus[l.status] ?? 0) + 1;
        }
        print('📈 [Leave] list: total=${leaves.length} byStatus=$byStatus');
        for (var i = 0; i < leaves.length; i++) {
          final l = leaves[i];
          final idStr = l.id ?? '${l.fromDate.toIso8601String().split('T').first}_${l.leaveType}';
          final remark = l.status == 'cancelled'
              ? (l.cancelledRemark ?? '(none)')
              : l.status == 'rejected'
                  ? (l.rejectedRemark ?? '(none)')
                  : l.status == 'approved'
                      ? (l.approvedRemark ?? '(none)')
                      : '(n/a)';
          final dur = (l.duration ?? 'FULL_DAY').toUpperCase();
          final sess = (l.halfDaySession ?? '').toUpperCase();
          final fromStr = l.fromDate.toIso8601String().split('T').first;
          final toStr = l.toDate.toIso8601String().split('T').first;
          print('   [$i] id=$idStr status="${l.status}" dur=$dur session=$sess from=$fromStr to=$toStr remark=$remark');
        }
      }
      
      return leaves;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ My Leaves Error:');
        print('   Status: ${e.response?.statusCode}');
        print('   Response: ${e.response?.data}');
        print('   URL: ${e.response?.requestOptions.uri}');
      }
      rethrow;
    }
  }
  
  /// Extracts list from various response formats
  List<dynamic> _extractList(dynamic responseData) {
    if (responseData == null) return [];
    
    // Handle direct list response
    if (responseData is List) return responseData;
    
    // Handle object with list properties
    if (responseData is Map<String, dynamic>) {
      // Try common response formats
      if (responseData.containsKey('items') && responseData['items'] is List) {
        return responseData['items'] as List;
      }
      if (responseData.containsKey('data') && responseData['data'] is List) {
        return responseData['data'] as List;
      }
      if (responseData.containsKey('results') && responseData['results'] is List) {
        return responseData['results'] as List;
      }
      if (responseData.containsKey('leaves') && responseData['leaves'] is List) {
        return responseData['leaves'] as List;
      }
      
      // If no known list property found, check if any property is a list
      for (final value in responseData.values) {
        if (value is List) return value;
      }
    }
    
    return [];
  }
  
  /// Parses a single leave item with robust field extraction
  LeaveDto? _parseLeaveItem(dynamic item) {
    if (item == null) return null;
    if (item is! Map<String, dynamic>) return null;
    
    final map = Map<String, dynamic>.from(item);

    final id = map['id']?.toString() ?? map['leave_id']?.toString();

    // Extract leave type with multiple key support
    final leaveType = _readString(map, ['leave_type', 'leaveType', 'type']);
    
    // Extract dates with multiple key support and robust parsing
    final fromDate = _readDate(map, ['from_date', 'fromDate', 'startDate']);
    final toDate = _readDate(map, ['to_date', 'toDate', 'endDate']);
    
    // Employee's reason for leave (do not use approval/reject/cancel remark keys)
    final reason = _readString(map, ['reason', 'description']);

    // Status: read raw first, then normalize. Do NOT default unknown to PENDING.
    final rawStatus = _readString(map, ['status', 'state', 'leave_status', 'status_code']);
    final status = _normalizeStatus(rawStatus);

    // Action remarks: backend may send cancel_remark / reject_remark / approve_remark or action_remark
    final approvedRemark = _readString(map, [
      'approved_remark', 'approvedRemark', 'approve_remark', 'approveRemark',
      'approver_remark', 'approverRemark', 'approval_remark', 'approvalRemark',
      'action_remark', 'actionRemark',
    ]);
    final rejectedRemark = _readString(map, [
      'rejected_remark', 'rejectedRemark', 'reject_remark', 'rejectRemark',
      'action_remark', 'actionRemark',
    ]);
    final cancelledRemark = _readString(map, [
      'cancelled_remark', 'cancelledRemark', 'cancel_remark', 'cancelRemark',
      'action_remark', 'actionRemark',
    ]);
    final approvedAt = _readDate(map, ['approved_at', 'approvedAt']);
    final rejectedAt = _readDate(map, ['rejected_at', 'rejectedAt']);
    final cancelledAt = _readDate(map, ['cancelled_at', 'cancelledAt']);
    final appliedAt = _readDate(map, ['applied_at', 'appliedAt', 'created_at', 'createdAt']);
    // Approved by: prefer explicit approved_by; fallback to approver object
    final approvedBy = LeaveActionBy.fromJson(
      map['approved_by'] ?? map['approvedBy'] ?? map['approver'],
    );
    final rejectedBy = LeaveActionBy.fromJson(map['rejected_by'] ?? map['rejectedBy']);
    final cancelledBy = LeaveActionBy.fromJson(map['cancelled_by'] ?? map['cancelledBy']);

    // Validate required fields
    if (leaveType.isEmpty || fromDate == null || toDate == null) {
      return null;
    }

    if (kDebugMode) {
      final mapped = _uiStatusLabel(status);
      print('Leave ${id ?? "${fromDate.toIso8601String().split('T').first}_$leaveType"} rawStatus=$rawStatus mapped=$mapped cancelRemark=${cancelledRemark.isEmpty ? null : cancelledRemark}');
    }

    final duration = _readString(map, ['duration']);
    final halfDaySession = _readString(map, ['half_day_session', 'halfDaySession']);

    return LeaveDto(
      id: id?.isEmpty == true ? null : id,
      leaveType: leaveType,
      fromDate: fromDate,
      toDate: toDate,
      reason: reason,
      status: status,
      duration: duration.isEmpty ? null : duration,
      halfDaySession: halfDaySession.isEmpty ? null : halfDaySession,
      approvedRemark: approvedRemark.isEmpty ? null : approvedRemark,
      rejectedRemark: rejectedRemark.isEmpty ? null : rejectedRemark,
      cancelledRemark: cancelledRemark.isEmpty ? null : cancelledRemark,
      approvedAt: approvedAt,
      rejectedAt: rejectedAt,
      cancelledAt: cancelledAt,
      appliedAt: appliedAt,
      approvedBy: approvedBy,
      rejectedBy: rejectedBy,
      cancelledBy: cancelledBy,
    );
  }
  
  /// Reads a string value from map with multiple possible keys
  String _readString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null) {
        if (value is String) return value.trim();
        if (value is num) return value.toString();
        if (value is bool) return value.toString();
      }
    }
    return '';
  }
  
  /// Reads a date value from map with multiple possible keys and formats
  DateTime? _readDate(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null) {
        return parseServerDateTime(value);
      }
    }
    return null;
  }
  
  /// Normalizes status string. Do NOT default unknown to PENDING.
  /// Supports: CANCELLED, CANCELED, CANCELLED_AFTER_APPROVAL -> cancelled.
  String _normalizeStatus(String raw) {
    if (raw.trim().isEmpty) return 'unknown';
    final s = raw.trim().toLowerCase().replaceAll('canceled', 'cancelled');
    // Check cancel first so CANCELLED_AFTER_APPROVAL is not treated as approved
    if (s.contains('cancel')) return 'cancelled';
    if (s.contains('approve')) return 'approved';
    if (s.contains('reject')) return 'rejected';
    if (s.contains('pending')) return 'pending';
    switch (s) {
      case 'approved':
      case 'approve':
      case 'accept':
      case 'accepted':
        return 'approved';
      case 'rejected':
      case 'reject':
      case 'denied':
      case 'deny':
        return 'rejected';
      case 'pending':
      case 'waiting':
      case 'requested':
      case 'in_review':
        return 'pending';
      case 'cancelled':
      case 'cancel':
        return 'cancelled';
      default:
        return s;
    }
  }


  static String _uiStatusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'APPROVED';
      case 'rejected':
        return 'REJECTED';
      case 'cancelled':
        return 'CANCELLED';
      case 'pending':
        return 'PENDING';
      default:
        return 'UNKNOWN';
    }
  }


  /// GET /api/v1/leaves/pending - fetch pending leave requests for approvers
  Future<PendingLeavesResponse> fetchPendingLeaves() async {
    if (kDebugMode) {
      print('🌐 Pending Leaves: GET ${Endpoints.leavesPending}');
      print('   Base URL: ${dio.options.baseUrl}');
    }
    
    try {
      final response = await dio.get<dynamic>(Endpoints.leavesPending);
      final data = response.data;
      
      if (kDebugMode) {
        print('✅ Pending Leaves Success: ${response.statusCode}');
        print('📋 [Pending Leaves] raw response: $data');
        print('   Request URL: ${response.requestOptions.uri}');
        print('   Headers: ${response.requestOptions.headers}');
        
        // Log parsed response details
        final parsedResponse = PendingLeavesResponse.fromJson(data);
        print('   Parsed total: ${parsedResponse.total}');
        print('   Parsed items count: ${parsedResponse.items.length}');
        if (parsedResponse.items.isNotEmpty) {
          print('   First item: ${parsedResponse.items.first}');
        }
      }
      
      return PendingLeavesResponse.fromJson(data);
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ Pending Leaves Error: ${e.response?.statusCode}');
        print('   Response: ${e.response?.data}');
        print('   URL: ${e.response?.requestOptions.uri}');
        print('   Error: ${e.message}');
        print('   Headers: ${e.response?.requestOptions.headers}');
      }
      
      // Return empty response on error
      return const PendingLeavesResponse(items: [], total: 0);
    }
  }

  /// POST /api/v1/leaves/{id}/approve - approve a leave request with optional remarks
  /// Remarks must be at least 2 characters if provided
  Future<PendingLeaveDto> approveLeave(String id, {String? remarks}) async {
    if (kDebugMode) {
      print('🌐 Approve Leave: POST ${Endpoints.leaveApprove(id)}');
      print('   Remarks: ${remarks ?? "(none)"}');
      print('   Remarks length: ${remarks?.length ?? 0}');
    }
    
    // Validate remarks if provided (min 2 chars)
    if (remarks != null && remarks.isNotEmpty && remarks.length < 2) {
      throw Exception('Remarks must be at least 2 characters if provided');
    }
    
    try {
      final payload = {'remarks': remarks ?? ''};
      final response = await dio.post<dynamic>(
        Endpoints.leaveApprove(id),
        data: payload,
      );
      
      if (kDebugMode) {
        print('✅ Leave Approved: ${response.statusCode}');
        print('📋 Response: ${response.data}');
        print('   Request URL: ${response.requestOptions.uri}');
        print('   Headers: ${response.requestOptions.headers}');
      }
      
      // Parse the response back to PendingLeaveDto
      final approvedLeave = PendingLeaveDto.fromJson(response.data);
      if (approvedLeave == null) {
        throw Exception('Failed to parse approved leave response');
      }
      
      return approvedLeave;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ Approve Leave Error: ${e.response?.statusCode}');
        print('   Response: ${e.response?.data}');
        print('   URL: ${e.response?.requestOptions.uri}');
        print('   Error: ${e.message}');
      }
      
      // Re-throw with more detailed error information
      if (e.response != null && e.response!.data is Map) {
        final data = e.response!.data as Map<String, dynamic>;
        if (data.containsKey('detail')) {
          throw Exception(data['detail'] as String);
        }
      }
      
      rethrow;
    }
  }

  /// POST /api/v1/leaves/{id}/reject - reject a leave request with optional remarks
  /// Remarks must be at least 2 characters if provided
  Future<PendingLeaveDto> rejectLeave(String id, {String? remarks}) async {
    if (kDebugMode) {
      print('🌐 Reject Leave: POST ${Endpoints.leaveReject(id)}');
      print('   Remarks: ${remarks ?? "(none)"}');
      print('   Remarks length: ${remarks?.length ?? 0}');
    }
    
    // Validate remarks if provided (min 2 chars)
    if (remarks != null && remarks.isNotEmpty && remarks.length < 2) {
      throw Exception('Remarks must be at least 2 characters if provided');
    }
    
    try {
      final payload = {'remarks': remarks ?? ''};
      final response = await dio.post<dynamic>(
        Endpoints.leaveReject(id),
        data: payload,
      );
      
      if (kDebugMode) {
        print('✅ Leave Rejected: ${response.statusCode}');
        print('📋 Response: ${response.data}');
        print('   Request URL: ${response.requestOptions.uri}');
        print('   Headers: ${response.requestOptions.headers}');
      }
      
      // Parse the response back to PendingLeaveDto
      final rejectedLeave = PendingLeaveDto.fromJson(response.data);
      if (rejectedLeave == null) {
        throw Exception('Failed to parse rejected leave response');
      }
      
      return rejectedLeave;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ Reject Leave Error: ${e.response?.statusCode}');
        print('   Response: ${e.response?.data}');
        print('   URL: ${e.response?.requestOptions.uri}');
        print('   Error: ${e.message}');
      }
      
      // Re-throw with more detailed error information
      if (e.response != null && e.response!.data is Map) {
        final data = e.response!.data as Map<String, dynamic>;
        if (data.containsKey('detail')) {
          throw Exception(data['detail'] as String);
        }
      }
      
      rethrow;
    }
  }

  /// POST /api/v1/leaves/{id}/cancel - cancel a leave request (Self or Manager)
  Future<void> cancelLeave(String id, {String? remark}) async {
    if (kDebugMode) {
      print('🌐 Cancel Leave: POST ${Endpoints.leaveCancel(id)}');
      print('   Remark: ${remark ?? "(none)"}');
    }
    
    try {
      final payload = {'remark': remark?.trim() ?? ''};
      final response = await dio.post<dynamic>(
        Endpoints.leaveCancel(id),
        data: payload,
      );
      
      if (kDebugMode) {
        print('✅ Leave Cancelled: ${response.statusCode}');
        print('📋 Response: ${response.data}');
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ Cancel Leave Error: ${e.response?.statusCode}');
        print('   Response: ${e.response?.data}');
      }
      
      if (e.response != null && e.response!.data is Map) {
        final data = e.response!.data as Map<String, dynamic>;
        if (data.containsKey('detail')) {
          throw Exception(data['detail'] as String);
        }
      }
      
      rethrow;
    }
  }

  /// GET /api/v1/leaves/list with filters for approvers (to see approved leaves)
  Future<PendingLeavesResponse> fetchAllLeavesForApprover() async {
    if (kDebugMode) {
      print('🌐 Fetch All Leaves for Approver: GET ${Endpoints.leavesList}');
    }
    
    try {
      final response = await dio.get<dynamic>(Endpoints.leavesList);
      final data = response.data;
      
      if (kDebugMode) {
        print('✅ Fetch All Leaves Success: ${response.statusCode}');
      }
      
      return PendingLeavesResponse.fromJson(data);
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ Fetch All Leaves Error: ${e.response?.statusCode}');
      }
      return const PendingLeavesResponse(items: [], total: 0);
    }
  }
}
