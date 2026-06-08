import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ist_time.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_button.dart';
import '../../widgets/status_chip.dart';
import '../../core/api/attendance_correction_service.dart';

class AttendanceCorrectionScreen extends ConsumerStatefulWidget {
  const AttendanceCorrectionScreen({
    super.key,
    this.initialRequestType,
    this.initialDate,
  });

  final String? initialRequestType;
  final DateTime? initialDate;
  @override
  ConsumerState<AttendanceCorrectionScreen> createState() => _AttendanceCorrectionScreenState();
}

class _AttendanceCorrectionScreenState extends ConsumerState<AttendanceCorrectionScreen> {
  String requestType = 'FORGOT_PUNCH_IN';
  DateTime selectedDate = DateTime.now();
  DateTime? requestedIn;
  DateTime? requestedOut;
  final reasonCtrl = TextEditingController();
  final remarksCtrl = TextEditingController();
  bool submitting = false;
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    final t = (widget.initialRequestType ?? '').trim().toUpperCase();
    if (t == 'FORGOT_PUNCH_IN' || t == 'FORGOT_PUNCH_OUT' || t == 'CORRECTION') {
      requestType = t;
    }
    final d = widget.initialDate;
    if (d != null) {
      selectedDate = DateTime(d.year, d.month, d.day);
    }
  }

  @override
  void dispose() {
    reasonCtrl.dispose();
    remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (reasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reason is required')));
      return;
    }
    setState(() => submitting = true);
    try {
      await ref.read(attendanceCorrectionServiceProvider).submit(
        requestType: requestType,
        date: DateTime(selectedDate.year, selectedDate.month, selectedDate.day),
        requestedPunchIn: requestedIn,
        requestedPunchOut: requestedOut,
        reason: reasonCtrl.text.trim(),
        remarks: remarksCtrl.text.trim().isEmpty ? null : remarksCtrl.text.trim(),
      );
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Success'),
              ],
            ),
            content: const Text('Your attendance correction request has been submitted successfully.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      ref.invalidate(myAttendanceCorrectionsProvider);
      setState(() {
        requestType = 'FORGOT_PUNCH_IN';
        selectedDate = DateTime.now();
        requestedIn = null;
        requestedOut = null;
        reasonCtrl.clear();
        remarksCtrl.clear();
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final response = e.response;
      String message = 'Submit failed. Please try again.';
      if (response != null && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        message = data['detail']?.toString() ?? data['message']?.toString() ?? message;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submit failed: ${e.toString().replaceFirst(RegExp(r'^Exception:?\s*'), '')}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => submitting = false);
      }
    }
  }

  Future<void> _onRefresh() async {
    ref.invalidate(myAttendanceCorrectionsProvider);
    await ref.read(myAttendanceCorrectionsProvider.future);
  }

  String _formatDate(DateTime d) => DateFormat('d MMM yyyy').format(d);
  String _formatTime(DateTime? d) => d == null ? '-' : IstTime.formatTimeFromUtc(d);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final corrections = ref.watch(myAttendanceCorrectionsProvider);
    
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Correction')),
      body: RefreshIndicator(
        key: _refreshKey,
        onRefresh: _onRefresh,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _buildSubmitForm(theme),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'My Requests',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            corrections.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Text('No correction requests found'),
                    ),
                  );
                }
                return Column(
                  children: list.map((r) => _CorrectionRequestCard(
                    item: r,
                    onTap: () => _showDetails(context, r),
                  )).toList(),
                );
              },
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.md), child: CircularProgressIndicator())),
              error: (_, __) => const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Failed to load requests'))),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitForm(ThemeData theme) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Submit Correction', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.md),
          
          // Request Type Dropdown
          DropdownButtonFormField<String>(
            value: requestType,
            decoration: const InputDecoration(
              labelText: 'Request Type',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            items: const [
              DropdownMenuItem(value: 'FORGOT_PUNCH_IN', child: Text('Forgot Punch In')),
              DropdownMenuItem(value: 'FORGOT_PUNCH_OUT', child: Text('Forgot Punch Out')),
              DropdownMenuItem(value: 'CORRECTION', child: Text('Correction')),
            ],
            onChanged: (v) => setState(() => requestType = v ?? 'FORGOT_PUNCH_IN'),
          ),
          const SizedBox(height: AppSpacing.md),

          // Date Picker
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => selectedDate = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today, size: 20),
              ),
              child: Text(_formatDate(selectedDate)),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Punch In Time
          if (requestType != 'FORGOT_PUNCH_OUT') ...[
            InkWell(
              onTap: () async {
                final now = DateTime.now();
                final picked = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now));
                if (picked != null) {
                  setState(() => requestedIn = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, picked.hour, picked.minute));
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Requested Punch In',
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.access_time, size: 20),
                  helperText: requestType == 'CORRECTION' ? 'Optional' : null,
                ),
                child: Text(requestedIn != null ? DateFormat('hh:mm a').format(requestedIn!) : 'Select Time'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Punch Out Time
          if (requestType != 'FORGOT_PUNCH_IN') ...[
            InkWell(
              onTap: () async {
                final now = DateTime.now();
                final picked = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now));
                if (picked != null) {
                  setState(() => requestedOut = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, picked.hour, picked.minute));
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Requested Punch Out',
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.access_time, size: 20),
                  helperText: requestType == 'CORRECTION' ? 'Optional' : null,
                ),
                child: Text(requestedOut != null ? DateFormat('hh:mm a').format(requestedOut!) : 'Select Time'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Reason
          TextFormField(
            controller: reasonCtrl,
            decoration: const InputDecoration(
              labelText: 'Reason',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.md),

          // Remarks
          TextFormField(
            controller: remarksCtrl,
            decoration: const InputDecoration(
              labelText: 'Remarks (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 1,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Submit Button
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Submit Request',
              onPressed: submitting ? null : submit,
              isLoading: submitting,
            ),
          ),
        ],
      ),
    );
  }

  void _showDetails(BuildContext context, AttendanceCorrectionDto item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (context) => _CorrectionDetailBottomSheet(item: item),
    );
  }
}

class _CorrectionRequestCard extends StatelessWidget {
  const _CorrectionRequestCard({required this.item, required this.onTap});
  final AttendanceCorrectionDto item;
  final VoidCallback onTap;

  AppStatus _getStatus(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED': return AppStatus.success;
      case 'REJECTED': return AppStatus.error;
      case 'PENDING': return AppStatus.warning;
      default: return AppStatus.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.requestType.replaceAll('_', ' '),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
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
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'In: ${item.requestedPunchIn != null ? IstTime.formatTimeFromUtc(item.requestedPunchIn) : '-'}   Out: ${item.requestedPunchOut != null ? IstTime.formatTimeFromUtc(item.requestedPunchOut) : '-'}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _CorrectionDetailBottomSheet extends StatelessWidget {
  const _CorrectionDetailBottomSheet({required this.item});
  final AttendanceCorrectionDto item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
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
              Text('Request Details', style: theme.textTheme.titleLarge),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          
          _DetailRow(label: 'Type', value: item.requestType.replaceAll('_', ' ')),
          _DetailRow(label: 'Date', value: IstTime.formatDateFromUtc(item.date)),
          _DetailRow(label: 'Requested In', value: item.requestedPunchIn != null ? IstTime.formatTimeFromUtc(item.requestedPunchIn) : '-'),
          _DetailRow(label: 'Requested Out', value: item.requestedPunchOut != null ? IstTime.formatTimeFromUtc(item.requestedPunchOut) : '-'),
          _DetailRow(label: 'Status', value: item.status),
          
          if (item.createdAt != null)
            _DetailRow(label: 'Submitted At', value: IstTime.formatDateTimeFromUtc(item.createdAt!)),
            
          if (item.approvedByName != null)
            _DetailRow(label: 'Approved By', value: item.approvedByName!),
            
          if (item.approvedAt != null)
            _DetailRow(label: 'Approved At', value: IstTime.formatDateTimeFromUtc(item.approvedAt!)),

          const SizedBox(height: AppSpacing.md),
          Text('Reason', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          Text(item.reason, style: theme.textTheme.bodyMedium),
          
          if (item.remarks != null && item.remarks!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text('My Remarks', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            Text(item.remarks!, style: theme.textTheme.bodyMedium),
          ],
          
          if (item.adminRemarks != null && item.adminRemarks!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Admin Remarks', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            Text(item.adminRemarks!, style: theme.textTheme.bodyMedium),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
