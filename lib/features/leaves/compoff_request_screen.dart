import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/fade_in_wrapper.dart';
import 'package:acs_hrms/core/api/attendance_dto.dart';
import '../../widgets/acs/acs_stat_tile.dart';

/// Employee screen to request comp-off: date worked, reason, full/half day.
class CompoffRequestScreen extends ConsumerStatefulWidget {
  const CompoffRequestScreen({super.key});

  @override
  ConsumerState<CompoffRequestScreen> createState() => _CompoffRequestScreenState();
}

class _CompoffRequestScreenState extends ConsumerState<CompoffRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  DateTime? _dateWorked;
  bool _halfDay = false;
  bool _loading = false;
  bool _validatingAttendance = false;
  AttendanceSessionDto? _selectedDateAttendance;
  String? _attendanceValidationError;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dateWorked ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (date != null) {
      setState(() {
        _dateWorked = date;
        _selectedDateAttendance = null;
        _attendanceValidationError = null;
      });
      await _validateAttendanceForDate(date);
    }
  }

  Future<void> _validateAttendanceForDate(DateTime date) async {
    setState(() => _validatingAttendance = true);
    try {
      final attendanceApi = ref.read(attendanceApiProvider);
      final attendance = await attendanceApi.getMy(
        from: date,
        to: date.add(const Duration(days: 1)),
      );
      
      if (attendance.isEmpty) {
        setState(() {
          _attendanceValidationError = 'No attendance found for selected date.';
          _selectedDateAttendance = null;
        });
        return;
      }
      
      final session = attendance.first;
      if (!session.isCompleted) {
        setState(() {
          _attendanceValidationError = 'Punch-out required to request Comp-Off.';
          _selectedDateAttendance = session;
        });
        return;
      }
      
      setState(() {
        _selectedDateAttendance = session;
        _attendanceValidationError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _attendanceValidationError = 'Failed to validate attendance: ${e.toString().replaceFirst(RegExp(r'^Exception:?\s*'), '')}';
        _selectedDateAttendance = null;
      });
    } finally {
      if (mounted) setState(() => _validatingAttendance = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_dateWorked == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date worked')),
      );
      return;
    }
    
    // Validate attendance before submission
    if (_attendanceValidationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_attendanceValidationError!)),
      );
      return;
    }
    
    // If attendance hasn't been validated yet, validate it now
    if (_selectedDateAttendance == null && _attendanceValidationError == null) {
      await _validateAttendanceForDate(_dateWorked!);
      if (_attendanceValidationError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_attendanceValidationError!)),
        );
        return;
      }
    }
    setState(() => _loading = true);
    try {
      final service = ref.read(compoffServiceProvider);
      await service.requestCompoff(
        dateWorked: _dateWorked!,
        reason: _reasonController.text.trim(),
        days: _halfDay ? 0.5 : 1.0,
      );
      if (!mounted) return;
      ref.invalidate(compoffBalanceProvider);
      ref.invalidate(myCompoffRequestsProvider);
      ref.invalidate(leaveBalanceProvider);
      ref.invalidate(leaveBalanceSummaryProvider);
      ref.invalidate(myLeavesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comp-Off requested successfully')),
      );
      context.pop();
    } on DioException catch (e) {
      if (!mounted) return;
      final response = e.response;
      String message = 'Comp-Off request failed. Please try again.';
      if (response != null && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        message = data['detail']?.toString() ?? data['message']?.toString() ?? message;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${e.toString().replaceFirst(RegExp(r'^Exception:?\s*'), '')}')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'Select date';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Widget _buildAttendanceStatus() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (_attendanceValidationError != null) {
      return Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 16, color: colorScheme.error),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              _attendanceValidationError!,
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.error),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    
    if (_selectedDateAttendance != null) {
      final session = _selectedDateAttendance!;
      final punchInTime = session.punchInAt != null 
          ? _formatTime(session.punchInAt!) 
          : 'Not punched in';
      final punchOutTime = session.punchOutAt != null 
          ? _formatTime(session.punchOutAt!) 
          : 'Not punched out';
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 16, color: colorScheme.primary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Attendance verified',
                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Punch-in: $punchInTime',
            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          Text(
            'Punch-out: $punchOutTime', 
            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      );
    }
    
    return const SizedBox.shrink();
  }
  
  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final balanceAsync = ref.watch(compoffBalanceProvider);

    return FadeInWrapper(
      child: Scaffold(
        backgroundColor: theme.colorScheme.background,
        appBar: AppBar(
          title: const Text('Request Comp-Off'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).viewPadding.bottom,
            ),
            children: [
              // Top Card - Summary
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Compensatory Off',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Request comp-off for extra hours worked',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Balance Card
              balanceAsync.when(
                data: (balance) => AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Your Balance',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          ACSStatTile(
                            title: 'Available',
                            value: balance.availableDays.toStringAsFixed(1),
                            icon: Icons.check_circle_outline_rounded,
                            backgroundColor: colorScheme.primaryContainer,
                          ),
                          ACSStatTile(
                            title: 'Pending',
                            value: balance.pendingDays.toStringAsFixed(1),
                            icon: Icons.pending_actions_rounded,
                            backgroundColor: colorScheme.secondaryContainer,
                          ),
                          ACSStatTile(
                            title: 'Used',
                            value: balance.usedDays.toStringAsFixed(1),
                            icon: Icons.history_rounded,
                            backgroundColor: colorScheme.tertiaryContainer,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                loading: () => AppCard(
                  padding: const EdgeInsets.all(16),
                  child: const LinearProgressIndicator(),
                ),
                error: (error, _) => AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Failed to load balance: ${error.toString()}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Apply Section
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Date picker
                    AppButton(
                      label: _formatDate(_dateWorked),
                      onPressed: _pickDate,
                      variant: AppButtonVariant.outlined,
                      icon: const Icon(Icons.calendar_today_rounded, size: 20),
                      fullWidth: true,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Date worked',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (_validatingAttendance)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: LinearProgressIndicator(),
                      ),
                    if (_selectedDateAttendance != null || _attendanceValidationError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: _buildAttendanceStatus(),
                      ),
                    const SizedBox(height: 24),
                    AppTextField(
                      controller: _reasonController,
                      label: 'Reason',
                      hintText: 'Reason for comp-off request',
                      maxLines: 3,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter a reason';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    // Full/Half day toggle
                    Row(
                      children: [
                        Text(
                          'Full day',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _halfDay ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
                            fontWeight: _halfDay ? FontWeight.normal : FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Switch(
                          value: _halfDay,
                          onChanged: (v) => setState(() => _halfDay = v),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Half day',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _halfDay ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                            fontWeight: _halfDay ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    if (_halfDay)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '0.5 days will be credited',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    const SizedBox(height: 32),
                    AppButton(
                      label: 'Submit',
                      onPressed: _loading ? null : _submit,
                      isMainCTA: true,
                      fullWidth: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
