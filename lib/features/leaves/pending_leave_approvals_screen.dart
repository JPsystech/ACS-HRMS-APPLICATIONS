import 'package:acs_hrms/core/models/role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/pending_leave_dto.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ist_time.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';

class PendingLeaveApprovalsScreen extends ConsumerWidget {
  const PendingLeaveApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Approvals'),
      ),
      body: const PendingLeaveApprovalsView(),
    );
  }
}

class PendingLeaveApprovalsView extends ConsumerStatefulWidget {
  const PendingLeaveApprovalsView({super.key});

  @override
  ConsumerState<PendingLeaveApprovalsView> createState() =>
      _PendingLeaveApprovalsViewState();
}

class _PendingLeaveApprovalsViewState
    extends ConsumerState<PendingLeaveApprovalsView> {
  Future<void> _refreshPendingLeaves() async {
    ref.invalidate(pendingLeavesProvider);
    await ref.read(pendingLeavesProvider.future);
  }

  Future<void> _handleApprove(String id, {String? remarks}) async {
    try {
      final service = ref.read(leaveServiceProvider);
      await service.approveLeave(id, remarks: remarks);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave approved successfully')),
        );
        _refreshPendingLeaves();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _handleReject(String id, {String? remarks}) async {
    try {
      final service = ref.read(leaveServiceProvider);
      await service.rejectLeave(id, remarks: remarks);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave rejected successfully')),
        );
        _refreshPendingLeaves();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _handleCancel(String id, {String? remark}) async {
    try {
      final service = ref.read(leaveServiceProvider);
      await service.cancelLeave(id, remark: remark);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave cancelled successfully')),
        );
        _refreshPendingLeaves();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel: ${e.toString()}')),
        );
      }
    }
  }

  void _showRemarksDialog(PendingLeaveDto leave, String actionType) {
    final remarksController = TextEditingController();
    final isApprove = actionType == 'APPROVE';
    final isReject = actionType == 'REJECT';
    final isCancel = actionType == 'CANCEL';
    
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isApprove ? 'Approve Leave' : (isReject ? 'Reject Leave' : 'Cancel Leave'),
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: remarksController,
                decoration: InputDecoration(
                  labelText: isCancel || isReject ? 'Remarks (required)' : 'Remarks (optional)',
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Cancel',
                      onPressed: () => Navigator.pop(ctx),
                      variant: AppButtonVariant.outlined,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton(
                      label: isApprove ? 'Approve' : (isReject ? 'Reject' : 'Cancel'),
                      onPressed: () {
                        final remark = remarksController.text.trim();
                        if ((isCancel || isReject) && remark.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Remarks are required')),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        if (isApprove) {
                          _handleApprove(leave.id, remarks: remark);
                        } else if (isReject) {
                          _handleReject(leave.id, remarks: remark);
                        } else if (isCancel) {
                          _handleCancel(leave.id, remark: remark);
                        }
                      },
                      variant: isCancel || isReject ? AppButtonVariant.filled : AppButtonVariant.filled,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final theme = Theme.of(context);
    Color color;
    Color onColor;
    
    switch (status.toUpperCase()) {
      case 'APPROVED':
        color = Colors.green.withOpacity(0.2);
        onColor = Colors.green;
        break;
      case 'REJECTED':
        color = Colors.red.withOpacity(0.2);
        onColor = Colors.red;
        break;
      case 'CANCELLED':
      case 'CANCELLED_BY_COMPANY':
        color = Colors.orange.withOpacity(0.2);
        onColor = Colors.orange;
        break;
      case 'PENDING':
      default:
        color = theme.colorScheme.secondaryContainer;
        onColor = theme.colorScheme.onSecondaryContainer;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase().replaceAll('_', ' '),
        style: theme.textTheme.labelSmall?.copyWith(
          color: onColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  bool _canCancel(PendingLeaveDto leave) {
    if (leave.status != 'APPROVED') return false;
    
    final profile = ref.read(profileProvider).valueOrNull;
    if (profile == null) return false;
    
    final role = profile.role;
    // Matching admin panel logic: ADMIN, MD, VP, MANAGER
    if (!(role == Role.admin || role == Role.md || role == Role.vp || role == Role.manager)) return false;
    
    // Only future-dated approved leave can be cancelled
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final fromDate = DateTime(leave.fromDate.year, leave.fromDate.month, leave.fromDate.day);
    
    return fromDate.isAfter(todayDate);
  }

  Widget _buildLeaveCard(PendingLeaveDto leave) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Employee information
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          leave.employeeName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        _buildStatusChip(leave.status),
                      ],
                    ),
                    Text(
                      '${leave.employeeCode} • ${leave.department}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Leave details
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  leave.leaveType,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${_formatDate(leave.fromDate)} – ${_formatDate(leave.toDate)}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          
          if (leave.days != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${leave.days} day${leave.days == 1 ? '' : 's'} (${leave.duration.replaceAll('_', ' ')})',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          
          const SizedBox(height: AppSpacing.md),
          
          // Reason
          if (leave.reason.isNotEmpty) ...[
            Text(
              'Reason: ${leave.reason}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          
          // Action History
          if (leave.status == 'APPROVED' && leave.approvedBy != null) ...[
            Text(
              'Approved by ${leave.approvedBy?.displayLabel} on ${_formatDateTime(leave.approvedAt ?? DateTime.now())}',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.green),
            ),
            if (leave.approvedRemark != null)
              Text('Remark: ${leave.approvedRemark}', style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
          ],

          if (leave.status == 'REJECTED' && leave.rejectedBy != null) ...[
            Text(
              'Rejected by ${leave.rejectedBy?.displayLabel} on ${_formatDateTime(leave.rejectedAt ?? DateTime.now())}',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
            ),
            if (leave.rejectedRemark != null)
              Text('Remark: ${leave.rejectedRemark}', style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
          ],

          if ((leave.status == 'CANCELLED' || leave.status == 'CANCELLED_BY_COMPANY') && leave.cancelledBy != null) ...[
            Text(
              'Cancelled by ${leave.cancelledBy?.displayLabel} on ${_formatDateTime(leave.cancelledAt ?? DateTime.now())}',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange),
            ),
            if (leave.cancelledRemark != null)
              Text('Remark: ${leave.cancelledRemark}', style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
          ],

          // Applied date
          Text(
            'Applied: ${_formatDateTime(leave.appliedAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          // Action buttons
          if (leave.status == 'PENDING')
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Reject',
                    onPressed: () => _showRemarksDialog(leave, 'REJECT'),
                    variant: AppButtonVariant.outlined,
                    icon: const Icon(Icons.close, size: 16),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'Approve',
                    onPressed: () => _showRemarksDialog(leave, 'APPROVE'),
                    icon: const Icon(Icons.check, size: 16),
                  ),
                ),
              ],
            ),
          
          if (_canCancel(leave))
            AppButton(
              label: 'Cancel Leave',
              onPressed: () => _showRemarksDialog(leave, 'CANCEL'),
              variant: AppButtonVariant.outlined,
              icon: const Icon(Icons.cancel_outlined, size: 16),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    // Convert server UTC to IST for display
    final ist = IstTime.toIst(date);
    return '${_formatDate(ist)} ${ist.hour.toString().padLeft(2, '0')}:${ist.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final pendingLeavesAsync = ref.watch(pendingLeavesProvider);
    
    return RefreshIndicator(
      onRefresh: _refreshPendingLeaves,
      child: pendingLeavesAsync.when(
        loading: () => const LoadingView(),
        error: (error, stack) => ErrorView(
          message: error.toString(),
          onRetry: _refreshPendingLeaves,
        ),
        data: (response) {
          final leaves = response.items;
          
          if (leaves.isEmpty) {
            return const EmptyStateView(
              title: 'No leave requests to show',
              icon: Icons.check_circle_outline,
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: leaves.length,
            itemBuilder: (context, index) {
              final leave = leaves[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _buildLeaveCard(leave),
              );
            },
          );
        },
      ),
    );
  }
}