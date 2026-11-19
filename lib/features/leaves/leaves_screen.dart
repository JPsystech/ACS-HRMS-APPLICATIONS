import 'package:acs_hrms/core/api/api_repository.dart';
import 'package:acs_hrms/widgets/acs/acs_empty_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/leave_balance_dto.dart';
import '../../core/models/leave_type.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ist_time.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/status_chip.dart';
import 'edit_leave_screen.dart';
import 'pending_leave_approvals_screen.dart';

/// =======================
///  STATUS + UI MAPPINGS
/// =======================

enum LeaveStatus {
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected'),
  cancelled('Cancelled'),
  revoked('Revoked'),
  unknown('Unknown');

  const LeaveStatus(this.label);
  final String label;

  static LeaveStatus fromBackend(String? v) {
    if (v == null || v.trim().isEmpty) return LeaveStatus.unknown;
    final lower = v.trim().toLowerCase().replaceAll('canceled', 'cancelled');
    if (lower.contains('cancel')) return LeaveStatus.cancelled;
    if (lower == 'approved') return LeaveStatus.approved;
    if (lower == 'rejected') return LeaveStatus.rejected;
    if (lower == 'pending') return LeaveStatus.pending;
    if (lower == 'revoked') return LeaveStatus.revoked;
    return LeaveStatus.unknown;
  }
}

AppStatus _getAppStatusFromLeaveStatus(String status) {
  switch (status) {
    case 'PENDING':
      return AppStatus.pending;
    case 'APPROVED':
      return AppStatus.approved;
    case 'REJECTED':
      return AppStatus.rejected;
    case 'CANCELLED':
    case 'CANCELLED_BY_COMPANY':
      return AppStatus.cancelled;
    case 'REVOKED':
      return AppStatus.revoked;
    default:
      return AppStatus.info;
  }
}

/// Single leave request (local model for UI)
class LeaveRequest {
  LeaveRequest({
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    this.status = LeaveStatus.pending,
  });

  final LeaveType leaveType;
  final DateTime fromDate;
  final DateTime toDate;
  final String reason;
  final LeaveStatus status;

  static String _pad(int n) => n.toString().padLeft(2, '0');

  String get dateRange {
    final from = '${_pad(fromDate.day)}/${_pad(fromDate.month)}/${fromDate.year}';
    final to = '${_pad(toDate.day)}/${_pad(toDate.month)}/${toDate.year}';
    return '$from – $to';
  }
}

LeaveRequest _dtoToLeaveRequest(LeaveDto dto) {
  return LeaveRequest(
    leaveType: LeaveType.fromBackend(dto.leaveType),
    fromDate: dto.fromDate,
    toDate: dto.toDate,
    reason: dto.reason,
    status: LeaveStatus.fromBackend(dto.status),
  );
}

String _dateRangeFromDto(LeaveDto dto) {
  final from =
      '${LeaveRequest._pad(dto.fromDate.day)}/${LeaveRequest._pad(dto.fromDate.month)}/${dto.fromDate.year}';
  final to =
      '${LeaveRequest._pad(dto.toDate.day)}/${LeaveRequest._pad(dto.toDate.month)}/${dto.toDate.year}';
  return '$from – $to';
}

AppStatus _appStatusFromLeave(LeaveDto dto) {
  final status = LeaveStatus.fromBackend(dto.status);
  switch (status) {
    case LeaveStatus.approved:
      return AppStatus.approved;
    case LeaveStatus.rejected:
      return AppStatus.rejected;
    case LeaveStatus.cancelled:
      return AppStatus.cancelled;
    case LeaveStatus.revoked:
      return AppStatus.revoked;
    case LeaveStatus.pending:
      return AppStatus.pending;
    case LeaveStatus.unknown:
      return AppStatus.warning;
  }
}

String _formatDateTime(DateTime? d) {
  if (d == null) return '—';
  // Convert UTC from server to IST for display
  final ist = IstTime.toIst(d);
  return '${LeaveRequest._pad(ist.day)}/${LeaveRequest._pad(ist.month)}/${ist.year} '
      '${ist.hour.toString().padLeft(2, '0')}:${ist.minute.toString().padLeft(2, '0')}';
}

String _getStatusUpdateTime(LeaveDto dto) {
  final status = LeaveStatus.fromBackend(dto.status);

  switch (status) {
    case LeaveStatus.approved:
      return _formatDateTime(dto.approvedAt);
    case LeaveStatus.rejected:
      return _formatDateTime(dto.rejectedAt);
    case LeaveStatus.cancelled:
      return _formatDateTime(dto.cancelledAt);
    case LeaveStatus.pending:
    case LeaveStatus.unknown:
      return '—';
    case LeaveStatus.revoked:
      return _formatDateTime(dto.cancelledAt ?? dto.appliedAt);
  }
}

enum LeaveDuration { fullDay, halfDay }
extension LeaveDurationX on LeaveDuration {
  String get label => this == LeaveDuration.fullDay ? 'Full Day' : 'Half Day';
  String get apiValue => this == LeaveDuration.fullDay ? 'FULL_DAY' : 'HALF_DAY';
}

enum HalfDaySession { firstHalf, secondHalf }
extension HalfDaySessionX on HalfDaySession {
  String get label => this == HalfDaySession.firstHalf ? 'First Half' : 'Second Half';
  String get apiValue => this == HalfDaySession.firstHalf ? 'FIRST_HALF' : 'SECOND_HALF';
}

/// =======================
///  LEAVE DETAILS SHEET
/// =======================

void _showLeaveDetail(BuildContext context, LeaveDto dto) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final r = _dtoToLeaveRequest(dto);
  final status = r.status;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Leave details',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Summary Card
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                        ),
                        child: Text(
                          r.leaveType.label,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const Spacer(),
                      StatusChip(
                        status: _getAppStatusFromLeaveStatus(dto.status),
                        label: r.status.label,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _DetailRow(label: 'Date', value: _dateRangeFromDto(dto)),
                  const SizedBox(height: AppSpacing.xs),
                  _DetailRow(
                    label: 'Reason',
                    value: dto.reason.trim().isEmpty ? '—' : dto.reason.trim(),
                  ),
                  _ActionRemarkBlock(dto: dto),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Meta Card (optional)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Timeline',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _DetailRow(
                    label: 'Applied At',
                    value: _formatDateTime(dto.appliedAt),
                  ),
                  if (status == LeaveStatus.approved ||
                      dto.approvedAt != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _DetailRow(
                      label: 'Approved At',
                      value: _formatDateTime(dto.approvedAt),
                    ),
                  ],
                  if (status == LeaveStatus.rejected) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _DetailRow(
                      label: 'Rejected At',
                      value: _formatDateTime(dto.rejectedAt),
                    ),
                  ],
                  if (status == LeaveStatus.cancelled) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _DetailRow(
                      label: 'Cancelled At',
                      value: _formatDateTime(dto.cancelledAt),
                    ),
                  ],
                  if (status == LeaveStatus.pending) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _DetailRow(label: 'Status', value: 'Pending Approval'),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Action Buttons
            Consumer(
              builder: (context, ref, _) {
                final canEdit = _canEdit(dto);
                final canCancel = _canCancel(dto, ref);

                return Column(
                  children: [
                    if (canEdit)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: AppButton(
                          label: 'Edit Leave Request',
                          onPressed: () => _handleEdit(context, ref, dto),
                          variant: AppButtonVariant.primary,
                          fullWidth: true,
                          icon: const Icon(Icons.edit_outlined, size: 20),
                        ),
                      ),
                    if (canCancel)
                      AppButton(
                        label: 'Cancel Leave',
                        onPressed: () => _handleCancel(context, ref, dto),
                        variant: AppButtonVariant.outlined,
                        fullWidth: true,
                        icon: const Icon(Icons.cancel_outlined, size: 20),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

bool _canEdit(LeaveDto dto) {
  final status = LeaveStatus.fromBackend(dto.status);
  if (status != LeaveStatus.pending) return false;

  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final toDate = DateTime(dto.toDate.year, dto.toDate.month, dto.toDate.day);

  // Pending can be edited if not past
  return !toDate.isBefore(todayDate);
}

bool _canCancel(LeaveDto dto, WidgetRef ref) {
  final status = LeaveStatus.fromBackend(dto.status);
  if (status == LeaveStatus.cancelled || status == LeaveStatus.rejected) {
    return false;
  }

  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final fromDate =
      DateTime(dto.fromDate.year, dto.fromDate.month, dto.fromDate.day);
  final toDate = DateTime(dto.toDate.year, dto.toDate.month, dto.toDate.day);

  if (status == LeaveStatus.pending) {
    // Pending can be cancelled if not past
    return !toDate.isBefore(todayDate);
  }

  if (status == LeaveStatus.approved) {
    // Approved future can be cancelled
    if (fromDate.isAfter(todayDate)) return true;

    // Today's approved leave can be cancelled if attendance is not yet marked
    if (fromDate.isAtSameMomentAs(todayDate)) {
      final attendance = ref.read(todayAttendanceProvider);
      return attendance.todayPunchInTime == null;
    }
  }

  return false;
}

Future<void> _handleEdit(BuildContext context, WidgetRef ref, LeaveDto dto) async {
  final updated = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (context) => EditLeaveScreen(
        leave: dto,
        balance: ref.read(leaveBalanceProvider).data,
      ),
    ),
  );

  if (updated == true && context.mounted) {
    Navigator.pop(context); // Close details sheet
  }
}

Future<void> _handleCancel(BuildContext context, WidgetRef ref, LeaveDto dto) async {
  final reasonController = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cancel Leave'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Are you sure you want to cancel this leave request?'),
          const SizedBox(height: 16),
          TextField(
            controller: reasonController,
            decoration: const InputDecoration(
              labelText: 'Reason for cancellation (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('No'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Yes, Cancel'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    try {
      final service = ref.read(leaveServiceProvider);
      await service.cancelLeave(dto.id!, remark: reasonController.text.trim());
      
      if (context.mounted) {
        Navigator.pop(context); // Close details sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave cancelled successfully. Leave balance has been updated.')),
        );
        // Refresh data
        ref.invalidate(myLeavesProvider);
        ref.invalidate(leaveBalanceProvider);
        ref.invalidate(leaveBalanceSummaryProvider);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 86,
          child: Text(
            '$label:',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

/// Action Remark block (Approved/Rejected/Cancelled)
class _ActionRemarkBlock extends StatelessWidget {
  const _ActionRemarkBlock({required this.dto});
  final LeaveDto dto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final status = LeaveStatus.fromBackend(dto.status);

    String title;
    String byLabel;
    String? remark;
    String atLabel;

    switch (status) {
      case LeaveStatus.approved:
        title = 'Approved';
        byLabel = dto.approvedBy?.displayLabel ?? '—';
        if (dto.approvedRole != null && dto.approvedRole!.isNotEmpty) {
          byLabel += ' • ${dto.approvedRole}';
        }
        remark = dto.approvedRemark?.trim().isNotEmpty == true
            ? dto.approvedRemark!.trim()
            : null;
        atLabel = _formatDateTime(dto.approvedAt);
        break;

      case LeaveStatus.rejected:
        title = 'Rejected';
        byLabel = dto.rejectedBy?.displayLabel ?? '—';
        if (dto.approvedRole != null && dto.approvedRole!.isNotEmpty) {
          byLabel += ' • ${dto.approvedRole}';
        }
        remark = dto.rejectedRemark?.trim().isNotEmpty == true
            ? dto.rejectedRemark!.trim()
            : null;
        atLabel = _formatDateTime(dto.rejectedAt);
        break;

      case LeaveStatus.cancelled:
        title = 'Cancelled';
        byLabel = dto.cancelledBy?.displayLabel ?? '—';
        remark = dto.cancelledRemark?.trim().isNotEmpty == true
            ? dto.cancelledRemark!.trim()
            : null;
        atLabel = _formatDateTime(dto.cancelledAt);
        break;

      case LeaveStatus.pending:
      case LeaveStatus.unknown:
        return const SizedBox.shrink();
      case LeaveStatus.revoked:
        title = 'Revoked';
        byLabel = dto.cancelledBy?.displayLabel ?? '—';
        remark = dto.cancelledRemark?.trim().isNotEmpty == true
            ? dto.cancelledRemark!.trim()
            : null;
        atLabel = _formatDateTime(dto.cancelledAt ?? dto.appliedAt);
        break;
    }

    final hasRemark = remark != null && remark.isNotEmpty;
    final hasByOrAt = byLabel != '—' || atLabel != '—';
    if (!hasRemark && !hasByOrAt) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title • Action Remark',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'By: $byLabel',
            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
          ),
          if (hasRemark) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              remark,
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            'At: $atLabel',
            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// =======================
///  MAIN SCREEN
/// =======================

class LeavesScreen extends ConsumerStatefulWidget {
  const LeavesScreen({super.key, this.prefill});
  final Object? prefill;

  @override
  ConsumerState<LeavesScreen> createState() => _LeavesScreenState();
}

class _LeavesScreenState extends ConsumerState<LeavesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _canApprove = false;

  @override
  void initState() {
    super.initState();
    _canApprove = ref.read(canApproveLeavesProvider);
    _tabController = TabController(length: _canApprove ? 3 : 2, vsync: this);

    if (widget.prefill != null) {
      _tabController.index = 0;
    }

    // load all
    Future.microtask(() {
      ref.invalidate(leaveBalanceProvider);
      ref.invalidate(leaveBalanceSummaryProvider);
      ref.invalidate(myLeavesProvider);
      ref.invalidate(compoffBalanceProvider);
      ref.invalidate(myCompoffRequestsProvider);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<({String? error, Map<String, dynamic>? data})> _submitApplyLeave(
      LeaveType type,
      DateTime from,
      DateTime to,
      String reason,
      LeaveDuration duration,
      HalfDaySession? session,
      ) async {
    try {
      final service = ref.read(leaveServiceProvider);
      final data = await service.applyLeave(
        leaveType: type.apiValue,
        fromDate: from,
        toDate: to,
        reason: reason,
        duration: duration.apiValue,
        halfDaySession: duration == LeaveDuration.halfDay ? session?.apiValue : null,
      );

      ref.invalidate(leaveBalanceProvider);
      ref.invalidate(leaveBalanceSummaryProvider);
      ref.invalidate(myLeavesProvider);
      ref.invalidate(compoffBalanceProvider);
      ref.invalidate(myCompoffRequestsProvider);

      return (error: null, data: data);
    } on DioException catch (e) {
      final response = e.response;
      final statusCode = response?.statusCode;
      final responseData = response?.data;

      debugPrint('Leave apply failed: status=$statusCode body=$responseData');

      if (response == null) {
        return (error: 'No response from server. Please check your internet connection.', data: null);
      }

      String errorMsg = 'Could not submit leave request.';

      if (responseData is Map) {
        final data = Map<String, dynamic>.from(responseData);
        final detail = data['detail'];
        final message = data['message'];
        
        if (detail is String && detail.isNotEmpty) {
          errorMsg = detail;
        } else if (message is String && message.isNotEmpty) {
          errorMsg = message;
        } else if (data['error'] is String) {
          errorMsg = data['error'] as String;
        }
      } 
      
      // If no specific message from backend, use status code fallbacks
      if (errorMsg == 'Could not submit leave request.') {
        if (statusCode == 401 || statusCode == 403) {
          errorMsg = 'Session expired. Please login again.';
        } else if (statusCode == 409) {
          errorMsg = 'This date already has a leave application or conflict.';
        } else if (statusCode == 400) {
          errorMsg = 'Invalid leave request. Please check if you already applied for this date.';
        } else if (statusCode != null && statusCode >= 500) {
          errorMsg = 'Server error. Please contact support.';
        }
      }

      return (error: errorMsg, data: null);
    } catch (e) {
      debugPrint('Leave apply unknown error: $e');
      return (error: 'An unexpected error occurred. Please try again.', data: null);
    }
  }

  Future<void> _showLeaveApplySuccess(BuildContext context, LeaveType type, Map<String, dynamic>? responseData) async {
    try {
      debugPrint('Showing Leave Success Dialog...');
      final theme = Theme.of(context);
      final colorScheme = theme.colorScheme;

      // Use latest known balance from provider.
      final balanceState = ref.read(leaveBalanceProvider);
      LeaveBalanceDto? item;
      for (final e in balanceState.data?.items ?? []) {
        if (e.leaveType.toUpperCase() == type.apiValue.toUpperCase()) {
          item = e;
          break;
        }
      }

      String fmt(double v) {
        if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
        return v.toStringAsFixed(1);
      }

      final available = item?.remaining ?? 0.0;
      final used = item?.used ?? 0.0;

      final duration = responseData?['duration']?.toString().toUpperCase();
      final session = responseData?['half_day_session']?.toString().toUpperCase();
      final requested = double.tryParse(responseData?['computed_days']?.toString() ?? '1') ?? 1.0;
      final lwp = double.tryParse(responseData?['lwp_days']?.toString() ?? '0') ?? 0.0;

      final isHalfDay = duration == 'HALF_DAY';
      final sessionLabel = session == 'SECOND_HALF' ? 'Second Half' : 'First Half';
      final timing = session == 'SECOND_HALF' ? '02:00 PM – 06:30 PM' : '09:30 AM – 02:00 PM';

      // New logic
      final paidLeaveUsed = (type == LeaveType.cl || type == LeaveType.sl || type == LeaveType.pl) ? requested.clamp(0.0, available) : 0.0;
      final lwpDays = (type == LeaveType.cl || type == LeaveType.sl || type == LeaveType.pl) ? (requested - paidLeaveUsed).clamp(0.0, requested) : (type == LeaveType.lwp ? requested : 0.0);
      final remainingBalance = available - paidLeaveUsed;

      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: Colors.green.shade400, size: 28),
              const SizedBox(width: 12),
              const Text('Success'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Leave request submitted.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              // Leave Details
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildPopupRow('Leave Type', '${type.label}${isHalfDay ? " (Half Day)" : ""}', theme),
                    if (isHalfDay) ...[
                      const SizedBox(height: 8),
                      _buildPopupRow('Session', sessionLabel, theme),
                      const SizedBox(height: 8),
                      _buildPopupRow('Timing', timing, theme),
                    ],
                    const SizedBox(height: 8),
                    _buildPopupRow('Requested', '${fmt(requested)} Day${requested == 1 ? "" : "s"}', theme),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Balance
              if (type != LeaveType.lwp && type != LeaveType.rh) ...[
                Text(
                  'Leave Balance',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildBalanceMini('Paid Leave Used', fmt(paidLeaveUsed), Colors.blue, theme)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildBalanceMini('LWP Portion', fmt(lwpDays), Colors.orange, theme)),
                  ],
                ),
                const SizedBox(height: 8),
                _buildBalanceMini('Remaining Balance', fmt(remainingBalance), Colors.green, theme),
                const SizedBox(height: 16),
              ],

              if (lwpDays > 0 && (type == LeaveType.cl || type == LeaveType.sl || type == LeaveType.pl))
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This leave includes ${fmt(lwpDays)} day(s) of LWP (Loss of Pay).',
                          style: theme.textTheme.labelSmall?.copyWith(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
                
              if (type == LeaveType.lwp)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This leave will be treated as LWP (Loss of Pay).',
                          style: theme.textTheme.labelSmall?.copyWith(color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),

              Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Status: Pending Approval',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Use standard FilledButton to avoid LayoutBuilder/IntrinsicWidth crash in AlertDialog
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      // If dialog fails, show a simple snackbar so user isn't stuck
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave request submitted successfully.')),
        );
      }
    }
  }

  Widget _buildPopupRow(String label, String value, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        Text(value, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildBalanceMini(String label, String value, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value, style: theme.textTheme.titleSmall?.copyWith(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _refreshAll() async {
    ref.invalidate(myLeavesProvider);
    ref.invalidate(leaveBalanceSummaryProvider);
    ref.invalidate(leaveBalanceProvider);
    ref.invalidate(leavePolicyProvider);
    ref.invalidate(compoffBalanceProvider);
    ref.invalidate(myCompoffRequestsProvider);

    // If your leaveBalanceProvider has notifier.refresh(), keep it:
    try {
      await Future.wait([
        ref.read(myLeavesProvider.future),
        ref.read(leaveBalanceProvider.notifier).refresh(),
      ]);
    } catch (_) {
      // ignore; UI shows snack bars in tabs
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Leave'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Apply Leave', icon: Icon(Icons.edit_calendar_rounded)),
            const Tab(text: 'My Leaves', icon: Icon(Icons.list_rounded)),
            if (_canApprove)
              const Tab(text: 'Approvals', icon: Icon(Icons.approval_rounded)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Top action pills
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Request Comp-Off',
                    onPressed: () => context.push('/leave/compoff-request'),
                    variant: AppButtonVariant.tonal,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AppButton(
                    label: 'Policy',
                    onPressed: () => context.push('/leave/policy'),
                    variant: AppButtonVariant.tonal,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ApplyLeaveTab(
                  prefill: widget.prefill,
                  onSubmit: _submitApplyLeave,
                  onSuccess: (type, data) => _showLeaveApplySuccess(context, type, data),
                  onAfterSubmit: () => _tabController.animateTo(1),
                  balance: ref.watch(leaveBalanceProvider).data,
                  onRefresh: _refreshAll,
                ),
                _MyLeavesTab(
                  onRefresh: _refreshAll,
                  tabController: _tabController,
                ),
                if (_canApprove)
                  PendingLeaveApprovalsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================
///  APPLY TAB
/// =======================

class _ApplyLeaveTab extends ConsumerStatefulWidget {
  const _ApplyLeaveTab({
    this.prefill,
    required this.onSubmit,
    required this.onSuccess,
    required this.onAfterSubmit,
    required this.onRefresh,
    this.balance,
  });

  final Object? prefill;
  final Future<({String? error, Map<String, dynamic>? data})> Function(
      LeaveType type,
      DateTime from,
      DateTime to,
      String reason,
      LeaveDuration duration,
      HalfDaySession? session,
      ) onSubmit;

  final Future<void> Function(LeaveType type, Map<String, dynamic>? responseData) onSuccess;
  final VoidCallback onAfterSubmit;
  final Future<void> Function() onRefresh;
  final LeaveBalanceResponseDto? balance;

  @override
  ConsumerState<_ApplyLeaveTab> createState() => _ApplyLeaveTabState();
}

class _ApplyLeaveTabState extends ConsumerState<_ApplyLeaveTab> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  LeaveType _selectedType = LeaveType.cl;
  DateTime? _fromDate;
  DateTime? _toDate;
  LeaveDuration _selectedDuration = LeaveDuration.fullDay;
  HalfDaySession _selectedSession = HalfDaySession.firstHalf;

  @override
  void initState() {
    super.initState();
    // Prefill from navigation extras (e.g., RH apply)
    if (widget.prefill is Map) {
      final m = widget.prefill as Map;
      try {
        final lt = (m['leaveType'] ?? m['leave_type'])?.toString().toUpperCase();
        if (lt == 'RH') _selectedType = LeaveType.rh;
        final pd = m['prefilledDate'] ?? m['from_date'];
        DateTime? d;
        if (pd is DateTime) d = pd;
        if (pd is String) d = DateTime.tryParse(pd);
        if (d != null) {
          _fromDate = d;
          _toDate = d;
        }
        _selectedDuration = LeaveDuration.fullDay;
      } catch (_) {
        // ignore invalid extras
      }
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  LeaveBalanceDto? _balanceFor(LeaveType type) {
    final items = widget.balance?.items ?? [];
    for (final e in items) {
      if (e.leaveType.toUpperCase() == type.apiValue.toUpperCase()) return e;
    }
    return null;
  }

  String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }

  DateTime _earliestAllowedDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_selectedType == LeaveType.sl || _selectedType == LeaveType.pl) {
      return today.subtract(const Duration(days: 7));
    }
    return today;
  }

  Future<void> _pickFromDate() async {
    final earliest = _earliestAllowedDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime initial = _fromDate ?? today;
    if (initial.isBefore(earliest)) {
      initial = earliest;
    }

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: earliest,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _fromDate = date;
        if (_selectedDuration == LeaveDuration.halfDay) {
          _toDate = date;
        } else if (_toDate != null && _toDate!.isBefore(date)) {
          _toDate = date;
        }
      });
    }
  }

  Future<void> _pickToDate() async {
    final earliest = _fromDate ?? _earliestAllowedDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime initial = _toDate ?? _fromDate ?? today;
    if (initial.isBefore(earliest)) {
      initial = earliest;
    }

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: earliest,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _toDate = date);
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'Select date';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  int _calcDays(DateTime? from, DateTime? to) {
    if (from == null || to == null) return 0;
    final a = DateTime(from.year, from.month, from.day);
    final b = DateTime(to.year, to.month, to.day);
    if (b.isBefore(a)) return 0;
    return b.difference(a).inDays + 1; // inclusive
  }
  
  double _requestedDays() {
    if (_selectedDuration == LeaveDuration.halfDay) return 0.5;
    return _calcDays(_fromDate, _toDate).toDouble();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_fromDate == null || _toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select From and To dates')),
      );
      return;
    }
    if (_toDate!.isBefore(_fromDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('To date must be on or after From date')),
      );
      return;
    }

    // RH Specific Validations
    if (_selectedType == LeaveType.rh) {
      if (_fromDate != _toDate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restricted Holiday (RH) must be applied for a single day only')),
        );
        return;
      }
      
      final myLeaves = ref.read(myLeavesProvider).valueOrNull ?? [];
      final year = _fromDate!.year;
      
      // Check if user already has a pending or approved RH for this year
      final hasExistingRH = myLeaves.any((l) {
        final isRH = l.leaveType.toUpperCase() == 'RH';
        final isSameYear = l.fromDate.year == year;
        final s = l.status.toLowerCase();
        final isActive = s == 'pending' || s == 'approved';
        return isRH && isSameYear && isActive;
      });
      
      if (hasExistingRH) {
        final existing = myLeaves.firstWhere((l) => 
          l.leaveType.toUpperCase() == 'RH' && 
          l.fromDate.year == year &&
          (l.status.toLowerCase() == 'pending' || l.status.toLowerCase() == 'approved')
        );
        
        final isApproved = existing.status.toLowerCase() == 'approved';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isApproved 
                ? 'You have already used your 1 allowed Restricted Holiday for this year.'
                : 'You already have one Restricted Holiday applied. You cannot apply another RH.'
            ),
          ),
        );
        return;
      }
      
      // Ensure selected date is in RH master list
      final rhList = ref.read(holidaysProvider).valueOrNull?.where((h) => h.type == 'restricted').toList() ?? [];
      final isValidRH = rhList.any((rh) => 
        rh.date.year == _fromDate!.year && 
        rh.date.month == _fromDate!.month && 
        rh.date.day == _fromDate!.day
      );
      
      if (!isValidRH) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected date is not a declared Restricted Holiday. Please choose a valid RH date.')),
        );
        return;
      }
    }

    // Conflict check for Half-Day against existing my leaves (pending/approved)
    if (_selectedDuration == LeaveDuration.halfDay && _fromDate != null) {
      final myLeaves = ref.read(myLeavesProvider).valueOrNull ?? const <LeaveDto>[];
      final day = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
      final selSession = _selectedSession.apiValue; // FIRST_HALF / SECOND_HALF
      for (final l in myLeaves) {
        final status = l.status.toLowerCase();
        if (status != 'pending' && status != 'approved') continue;
        final from = DateTime(l.fromDate.year, l.fromDate.month, l.fromDate.day);
        final to = DateTime(l.toDate.year, l.toDate.month, l.toDate.day);
        if (day.isBefore(from) || day.isAfter(to)) continue;
        final existingDuration = (l.duration ?? 'FULL_DAY').toUpperCase();
        if (existingDuration == 'FULL_DAY') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Full-day leave already exists for this date. Half-day cannot be applied.')),
          );
          return;
        }
        if (existingDuration == 'HALF_DAY') {
          final existingSession = (l.halfDaySession ?? '').toUpperCase();
          if (existingSession == selSession.toUpperCase()) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Half-day leave already exists for this session.')),
            );
            return;
          }
        }
      }
    }

    final compoffBalance = ref.read(compoffBalanceProvider).valueOrNull;
    final compoffAvailable = (compoffBalance?.availableDays ?? 0) > 0;
    if (_selectedType == LeaveType.compOff && !compoffAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Comp-Off available. Request Comp-Off first.')),
      );
      return;
    }

    final plBalance = _balanceFor(LeaveType.pl);
    final flBalance = _balanceFor(LeaveType.fl);
    final plLocked = _selectedType == LeaveType.pl && (plBalance?.eligible == false);
    final flLocked = _selectedType == LeaveType.fl && (flBalance?.eligible == false);
    if (plLocked || flLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_selectedType.label} is not available yet. Eligible after 6 months from join date.',
          ),
        ),
      );
      return;
    }

    final result = await widget.onSubmit(
      _selectedType,
      _fromDate!,
      _toDate!,
      _reasonController.text.trim(),
      _selectedDuration,
      _selectedDuration == LeaveDuration.halfDay ? _selectedSession : null,
    );

    if (!mounted) return;

    if (result.error == null) {
      final submittedType = _selectedType;
      final data = result.data;

      if (mounted) {
        // Clear state first so background is clean
        _reasonController.clear();
        setState(() {
          _fromDate = null;
          _toDate = null;
          _selectedType = LeaveType.cl;
          _selectedDuration = LeaveDuration.fullDay;
          _selectedSession = HalfDaySession.firstHalf;
        });
      }

      // Small delay to let keyboard close or UI settle
      await Future.delayed(const Duration(milliseconds: 100));

      // Show dialog and wait for user to click OK
      await widget.onSuccess(submittedType, data);

      if (mounted) {
        widget.onAfterSubmit();
      }
    } else {
      final msg = result.error!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final compoffBalance = ref.watch(compoffBalanceProvider).valueOrNull;
    final compoffAvailable = (compoffBalance?.availableDays ?? 0) > 0;

    final leaveTypesForApply =
        LeaveType.values.where((t) => t != LeaveType.lwp).toList();

    final selectedBal = _balanceFor(_selectedType);
    final requestedDays = _requestedDays();

    final holidaysAsync = ref.watch(holidaysProvider);
    final rhList = holidaysAsync.valueOrNull?.where((h) => h.type == 'restricted').toList() ?? [];

    final myLeaves = ref.watch(myLeavesProvider).valueOrNull ?? [];
    final hasPendingLeave = myLeaves.any((l) => l.status.toLowerCase() == 'pending');

    final disableSubmit = hasPendingLeave ||
        (_selectedType == LeaveType.pl &&
            (_balanceFor(LeaveType.pl)?.eligible == false)) ||
        (_selectedType == LeaveType.fl &&
            (_balanceFor(LeaveType.fl)?.eligible == false)) ||
        (_selectedType == LeaveType.compOff && !compoffAvailable);

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (hasPendingLeave)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You already have a pending leave request. Please wait for manager approval before applying another leave.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Card 1: Leave Type + Remaining inline
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Leave Type',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<LeaveType>(
                    value: leaveTypesForApply.contains(_selectedType)
                        ? _selectedType
                        : LeaveType.cl,
                    decoration: const InputDecoration(
                      labelText: 'Select leave type',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    items: leaveTypesForApply
                        .map(
                          (t) => DropdownMenuItem<LeaveType>(
                        value: t,
                        enabled: t != LeaveType.compOff || compoffAvailable,
                        child: Text(t.label),
                      ),
                    )
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedType = v ?? LeaveType.cl;
                        final earliest = _earliestAllowedDate();
                        if (_fromDate != null && _fromDate!.isBefore(earliest)) {
                          _fromDate = null;
                          _toDate = null;
                        }
                        // For RH, default to full day and ensure fromDate == toDate
                        if (_selectedType == LeaveType.rh) {
                          _selectedDuration = LeaveDuration.fullDay;
                          // Force selection from RH list if current date is not a restricted holiday
                          final rhList = ref.read(holidaysProvider).valueOrNull
                                  ?.where((h) => h.type == 'restricted')
                                  .toList() ?? [];
                          final isValidRH = rhList.any((rh) => 
                            _fromDate != null &&
                            rh.date.year == _fromDate!.year && 
                            rh.date.month == _fromDate!.month && 
                            rh.date.day == _fromDate!.day
                          );
                          if (!isValidRH) {
                            _fromDate = null;
                            _toDate = null;
                          } else {
                            _toDate = _fromDate;
                          }
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Remaining inline
                  if (_selectedType == LeaveType.compOff && !compoffAvailable)
                    Text(
                      'No Comp-Off available. Request Comp-Off first.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else if (_selectedType == LeaveType.rh) ...[
                    // RH balance check (quota 1 per year)
                    Builder(
                      builder: (context) {
                        final myLeaves = ref.watch(myLeavesProvider).valueOrNull ?? [];
                        final year = DateTime.now().year;
                        final existingRH = myLeaves.where((l) => 
                          l.leaveType.toUpperCase() == 'RH' && 
                          l.fromDate.year == year
                        ).firstWhere((l) {
                          final s = l.status.toLowerCase();
                          return s == 'pending' || s == 'approved';
                        }, orElse: () => LeaveDto(leaveType: '', fromDate: DateTime.now(), toDate: DateTime.now(), reason: '', status: ''));
                        
                        if (existingRH.leaveType.isNotEmpty) {
                          final isApproved = existingRH.status.toLowerCase() == 'approved';
                          return Text(
                            isApproved 
                              ? 'You have already used your 1 allowed Restricted Holiday for this year.'
                              : 'You already have one Restricted Holiday applied. You cannot apply another RH.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        } else {
                          return Row(
                            children: [
                              Text(
                                'Remaining: ',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                '1',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ] else if (selectedBal != null) ...[
                    if ((_selectedType == LeaveType.pl ||
                        _selectedType == LeaveType.fl) &&
                        selectedBal.eligible == false)
                      Text(
                        selectedBal.notes?.isNotEmpty == true
                            ? selectedBal.notes!
                            : '${_selectedType.label} eligible after 6 months from join date.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Row(
                        children: [
                          Text(
                            'Remaining: ',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            _fmt(selectedBal.remaining.toDouble()),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Card 2: Date selection + auto Total days display
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date Selection',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_selectedType == LeaveType.rh) ...[
                    if (holidaysAsync.isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (rhList.isEmpty)
                      Text(
                        'No restricted holidays available for this year.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.error,
                        ),
                      )
                    else
                      DropdownButtonFormField<DateTime>(
                        value: rhList.any((rh) => rh.date == _fromDate) ? _fromDate : null,
                        decoration: const InputDecoration(
                          labelText: 'Select Restricted Holiday',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.event_available_rounded),
                        ),
                        items: rhList.map((rh) {
                          return DropdownMenuItem<DateTime>(
                            value: rh.date,
                            child: Text('${rh.name} (${_formatDate(rh.date)})'),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setState(() {
                            _fromDate = v;
                            _toDate = v;
                          });
                        },
                        validator: (v) => v == null ? 'Please select a holiday' : null,
                      ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              OutlinedButton(
                                onPressed: _pickFromDate,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  alignment: Alignment.centerLeft,
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today_rounded,
                                        size: 20, color: colorScheme.primary),
                                    const SizedBox(width: 12),
                                    Text(_formatDate(_fromDate)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'From date',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              OutlinedButton(
                                onPressed: _selectedDuration == LeaveDuration.halfDay ? null : _pickToDate,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  alignment: Alignment.centerLeft,
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today_rounded,
                                        size: 20, color: colorScheme.primary),
                                    const SizedBox(width: 12),
                                    Text(_formatDate(_selectedDuration == LeaveDuration.halfDay ? _fromDate : _toDate)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'To date',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Auto Total days display
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Total Days',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _fmt(requestedDays),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if ((_selectedType == LeaveType.pl ||
                          _selectedType == LeaveType.cl ||
                          _selectedType == LeaveType.sl) &&
                      selectedBal != null &&
                      requestedDays > 0 &&
                      requestedDays > (selectedBal.remaining)) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              () {
                                final req = requestedDays;
                                final paid = req.clamp(0.0, selectedBal.remaining).toDouble();
                                final lwp = (req - paid).clamp(0.0, req).toDouble();
                                return 'Will be applied as: ${_fmt(paid)} ${_selectedType.label} + ${_fmt(lwp)} LWP';
                              }(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Leave Duration',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<LeaveDuration>(
                    value: _selectedDuration,
                    decoration: const InputDecoration(
                      labelText: 'Select duration',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    items: LeaveDuration.values
                        .map(
                          (d) => DropdownMenuItem<LeaveDuration>(
                            value: d,
                            enabled: _selectedType != LeaveType.rh || d == LeaveDuration.fullDay,
                            child: Text(d.label),
                          ),
                        )
                        .toList(),
                    onChanged: _selectedType == LeaveType.rh ? null : (v) {
                      setState(() {
                        _selectedDuration = v ?? LeaveDuration.fullDay;
                        if (_selectedDuration == LeaveDuration.halfDay && _fromDate != null) {
                          _toDate = _fromDate;
                        }
                      });
                    },
                  ),
                  if (_selectedDuration == LeaveDuration.halfDay && _selectedType != LeaveType.rh) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<HalfDaySession>(
                      value: _selectedSession,
                      decoration: const InputDecoration(
                        labelText: 'Session',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      items: HalfDaySession.values
                          .map(
                            (s) => DropdownMenuItem<HalfDaySession>(
                              value: s,
                              child: Text(s.label),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedSession = v ?? HalfDaySession.firstHalf;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    _selectedDuration == LeaveDuration.fullDay
                        ? 'Selected: Full Day'
                        : 'Selected: Half Day (${_selectedSession.label})',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Card 3: Reason textarea
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reason',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _reasonController,
                    label: 'Reason',
                    hintText: 'Enter reason for leave',
                    maxLines: 4,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter a reason';
                      return null;
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Submit button full width, primary gradient
            AppButton(
              label: 'Submit',
              onPressed: disableSubmit ? null : _submit,
              isMainCTA: true,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// =======================
///  MY LEAVES TAB
/// =======================

class _MyLeavesTab extends ConsumerStatefulWidget {
  const _MyLeavesTab({
    required this.onRefresh,
    this.tabController,
  });

  final Future<void> Function() onRefresh;
  final TabController? tabController;

  @override
  ConsumerState<_MyLeavesTab> createState() => _MyLeavesTabState();
}

class _MyLeavesTabState extends ConsumerState<_MyLeavesTab> {
  final TextEditingController _searchController = TextEditingController();
  LeaveStatus? _selectedStatus;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      await widget.onRefresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Refresh failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final leavesAsync = ref.watch(myLeavesProvider);

    // Base list (before applying UI filters)
    final base = leavesAsync.valueOrNull ?? <LeaveDto>[];

    // Filter logic
    var filtered = base;

    final q = _searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      filtered = filtered.where((dto) {
        final reason = dto.reason.toLowerCase();
        final lt = dto.leaveType.toLowerCase();
        final dr = _dateRangeFromDto(dto).toLowerCase();
        return reason.contains(q) || lt.contains(q) || dr.contains(q);
      }).toList();
    }

    if (_selectedStatus != null) {
      filtered = filtered
          .where((dto) => LeaveStatus.fromBackend(dto.status) == _selectedStatus)
          .toList();
    }

    final padding = EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.paddingBottomSafe + AppSpacing.md,
    );

    return RefreshIndicator(
      onRefresh: _refresh,
      child: leavesAsync.when(
        loading: () => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Center(child: CircularProgressIndicator()),
          ],
        ),
        error: (_, __) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: padding,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: colorScheme.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Could not load leaves. Check your connection.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: OutlinedButton.icon(
                onPressed: () => ref.invalidate(myLeavesProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ),
          ],
        ),
        data: (_) {
          if (base.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 48),
                ACSEmptyState(
                  icon: Icons.event_busy_rounded,
                  title: 'No leave requests',
                  subtitle: 'Apply leave and track approvals here.',
                  action: TextButton(
                    onPressed: () => widget.tabController?.animateTo(0),
                    child: const Text('Apply Leave'),
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              // Filter Bar (Always visible if user has any leaves)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search leave requests...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Status chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            label: const Text('All'),
                            selected: _selectedStatus == null,
                            onSelected: (_) =>
                                setState(() => _selectedStatus = null),
                          ),
                          const SizedBox(width: 16),
                          ...[
                            LeaveStatus.pending,
                            LeaveStatus.approved,
                            LeaveStatus.rejected,
                            LeaveStatus.cancelled,
                          ].map((status) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: FilterChip(
                                label: Text(status.label),
                                selected: _selectedStatus == status,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedStatus = selected ? status : null;
                                  });
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content Area
              Expanded(
                child: filtered.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 48),
                          ACSEmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No matching leaves',
                            subtitle: 'Try clearing filters or search query.',
                            action: TextButton(
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _selectedStatus = null;
                                });
                              },
                              child: const Text('Clear Filters'),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final dto = filtered[index];
                          final r = _dtoToLeaveRequest(dto);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: AppCard(
                              onTap: () => _showLeaveDetail(context, dto),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Leave type badge + status chip
                                  Row(
                                    children: [
                                      // Leave type badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primaryContainer,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: Text(
                                          r.leaveType.label,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme
                                                .onPrimaryContainer,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      // Status chip colored
                                      StatusChip(
                                        status: _appStatusFromLeave(dto),
                                        label: r.status.label,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Date range bold
                                  Text(
                                    _dateRangeFromDto(dto),
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),

                                  // Reason smaller
                                  if (r.reason.trim().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      r.reason.trim(),
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],

                                  _ActionRemarkBlock(dto: dto),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
