import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/attendance_correction_service.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ist_time.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/status_chip.dart';
import 'providers/attendance_correction_action_provider.dart';

class AttendanceCorrectionApprovalsScreen extends ConsumerWidget {
  const AttendanceCorrectionApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Corrections'),
      ),
      body: const AttendanceCorrectionApprovalsView(),
    );
  }
}

class AttendanceCorrectionApprovalsView extends ConsumerWidget {
  const AttendanceCorrectionApprovalsView({super.key});

  Future<void> _onRefresh(WidgetRef ref) async {
    ref.invalidate(pendingAttendanceCorrectionsProvider);
    await ref.read(pendingAttendanceCorrectionsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final correctionsAsync = ref.watch(pendingAttendanceCorrectionsProvider);

    return RefreshIndicator(
      onRefresh: () => _onRefresh(ref),
      child: correctionsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const EmptyStateView(
              title: 'No corrections found',
              subtitle: 'Attendance correction requests will appear here.',
              icon: Icons.fact_check_rounded,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _CorrectionRequestCard(item: item),
              );
            },
          );
        },
        loading: () => const LoadingView(),
        error: (err, _) => ErrorView(
          message: 'Failed to load corrections',
          onRetry: () => _onRefresh(ref),
        ),
      ),
    );
  }
}

class _CorrectionRequestCard extends StatelessWidget {
  const _CorrectionRequestCard({required this.item});
  final AttendanceCorrectionDto item;

  AppStatus _getStatus(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return AppStatus.success;
      case 'REJECTED':
        return AppStatus.error;
      case 'PENDING':
        return AppStatus.warning;
      default:
        return AppStatus.info;
    }
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CorrectionDetailBottomSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AppCard(
      onTap: () => _showDetails(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.employeeName ?? 'Employee #${item.employeeId}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              StatusChip(
                status: _getStatus(item.status),
                label: item.status,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            IstTime.formatDateFromUtc(item.date),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            item.requestType.replaceAll('_', ' '),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.reason,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CorrectionDetailBottomSheet extends ConsumerStatefulWidget {
  const _CorrectionDetailBottomSheet({required this.item});
  final AttendanceCorrectionDto item;

  @override
  ConsumerState<_CorrectionDetailBottomSheet> createState() => _CorrectionDetailBottomSheetState();
}

class _CorrectionDetailBottomSheetState extends ConsumerState<_CorrectionDetailBottomSheet> {
  final TextEditingController _remarksController = TextEditingController();

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '--:--';
    return IstTime.formatTimeFromUtc(dt);
  }

  Future<void> _handleApprove() async {
    try {
      await ref.read(attendanceCorrectionActionProvider.notifier).approveCorrection(
        widget.item.id,
        _remarksController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request approved successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleReject() async {
    try {
      await ref.read(attendanceCorrectionActionProvider.notifier).rejectCorrection(
        widget.item.id,
        _remarksController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request rejected successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final actionState = ref.watch(attendanceCorrectionActionProvider);
    final isSubmitting = actionState is AsyncLoading;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        MediaQuery.of(context).padding.bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Request Details',
                style: theme.textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _DetailRow(label: 'Employee', value: widget.item.employeeName ?? 'Employee #${widget.item.employeeId}'),
          _DetailRow(label: 'Date', value: IstTime.formatDateFromUtc(widget.item.date)),
          _DetailRow(label: 'Type', value: widget.item.requestType.replaceAll('_', ' ')),
          _DetailRow(label: 'Requested In', value: _formatTime(widget.item.requestedPunchIn)),
          _DetailRow(label: 'Requested Out', value: _formatTime(widget.item.requestedPunchOut)),
          _DetailRow(label: 'Status', value: widget.item.status),
          if (widget.item.approvedByName != null || widget.item.approvedBy != null)
            _DetailRow(
              label: widget.item.status == 'REJECTED' ? 'Rejected By' : 'Approved By',
              value: '${widget.item.approvedByName ?? 'ID: ${widget.item.approvedBy}'}${widget.item.approvedRole != null ? ' • ${widget.item.approvedRole}' : ''}',
            ),
          if (widget.item.approvedAt != null)
            _DetailRow(label: 'Action At', value: IstTime.formatDateTimeFromUtc(widget.item.approvedAt!)),
          if (widget.item.createdAt != null)
            _DetailRow(label: 'Submitted At', value: IstTime.formatDateTimeFromUtc(widget.item.createdAt!)),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Reason',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(widget.item.reason),
          if (widget.item.remarks != null && widget.item.remarks!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Employee Remarks',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(widget.item.remarks!),
          ],
          if (widget.item.adminRemarks != null && widget.item.adminRemarks!.isNotEmpty && widget.item.status != 'PENDING') ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Admin Remarks',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(widget.item.adminRemarks!),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (widget.item.status == 'PENDING') ...[
            TextField(
              controller: _remarksController,
              decoration: const InputDecoration(
                labelText: 'Admin Remarks (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              enabled: !isSubmitting,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isSubmitting ? null : _handleReject,
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(color: colorScheme.error),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isSubmitting ? null : _handleApprove,
                    icon: isSubmitting 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check),
                    label: Text(isSubmitting ? 'Processing...' : 'Approve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
