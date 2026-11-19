import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_repository.dart';
import '../../core/api/leave_balance_dto.dart';
import '../../core/models/leave_type.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import 'leaves_screen.dart';

class EditLeaveScreen extends ConsumerStatefulWidget {
  const EditLeaveScreen({
    super.key,
    required this.leave,
    this.balance,
  });

  final LeaveDto leave;
  final LeaveBalanceResponseDto? balance;

  @override
  ConsumerState<EditLeaveScreen> createState() => _EditLeaveScreenState();
}

class _EditLeaveScreenState extends ConsumerState<EditLeaveScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  late LeaveType _selectedType;
  late DateTime _fromDate;
  late DateTime _toDate;
  late LeaveDuration _selectedDuration;
  late HalfDaySession _selectedSession;
  
  bool _isSubmitting = false;
  List<HolidayDto> _restrictedHolidays = [];
  bool _isLoadingRH = false;

  @override
  void initState() {
    super.initState();
    _selectedType = LeaveType.fromBackend(widget.leave.leaveType);
    _fromDate = widget.leave.fromDate;
    _toDate = widget.leave.toDate;
    _reasonController.text = widget.leave.reason;
    _selectedDuration = widget.leave.duration == 'HALF_DAY' 
        ? LeaveDuration.halfDay 
        : LeaveDuration.fullDay;
    _selectedSession = widget.leave.halfDaySession == 'SECOND_HALF'
        ? HalfDaySession.secondHalf
        : HalfDaySession.firstHalf;

    _fetchRH();
  }

  Future<void> _fetchRH() async {
    setState(() => _isLoadingRH = true);
    try {
      final service = ref.read(holidayServiceProvider);
      final list = await service.listRestrictedHolidays();
      if (mounted) {
        setState(() {
          _restrictedHolidays = list;
          _isLoadingRH = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRH = false);
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

    DateTime initial = _fromDate;
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
        } else if (_toDate.isBefore(date)) {
          _toDate = date;
        }
      });
    }
  }

  Future<void> _pickToDate() async {
    final earliest = _fromDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime initial = _toDate.isBefore(_fromDate) ? _fromDate : _toDate;
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

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  double _requestedDays() {
    if (_selectedDuration == LeaveDuration.halfDay) return 0.5;
    final a = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    final b = DateTime(_toDate.year, _toDate.month, _toDate.day);
    return (b.difference(a).inDays + 1).toDouble();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(leaveServiceProvider);
      await service.updateLeave(
        leaveId: widget.leave.id!,
        leaveType: _selectedType.apiValue,
        fromDate: _fromDate,
        toDate: _toDate,
        reason: _reasonController.text.trim(),
        duration: _selectedDuration.apiValue,
        halfDaySession: _selectedDuration == LeaveDuration.halfDay 
            ? _selectedSession.apiValue 
            : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave request updated successfully.')),
        );
        // Refresh lists
        ref.invalidate(myLeavesProvider);
        ref.invalidate(leaveBalanceProvider);
        ref.invalidate(leaveBalanceSummaryProvider);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bal = _balanceFor(_selectedType);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Leave Request'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Balance Card (Info)
              if (bal != null)
                AppCard(
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: colorScheme.primary, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Available ${_selectedType.label}: ${_fmt(bal.remaining)} days',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.md),

              // Form Card
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Leave Type
                    DropdownButtonFormField<LeaveType>(
                      value: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Leave Type',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: LeaveType.values.map((t) {
                        return DropdownMenuItem(
                          value: t,
                          child: Text(t.label),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedType = v);
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Duration (Full/Half)
                    if (_selectedType != LeaveType.rh && 
                        _selectedType != LeaveType.compOff)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: SegmentedButton<LeaveDuration>(
                          segments: LeaveDuration.values.map((d) {
                            return ButtonSegment(
                              value: d,
                              label: Text(d.label),
                            );
                          }).toList(),
                          selected: {_selectedDuration},
                          onSelectionChanged: (set) {
                            setState(() {
                              _selectedDuration = set.first;
                              if (_selectedDuration == LeaveDuration.halfDay) {
                                _toDate = _fromDate;
                              }
                            });
                          },
                        ),
                      ),

                    if (_selectedDuration == LeaveDuration.halfDay)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: SegmentedButton<HalfDaySession>(
                          segments: HalfDaySession.values.map((s) {
                            return ButtonSegment(
                              value: s,
                              label: Text(s.label),
                            );
                          }).toList(),
                          selected: {_selectedSession},
                          onSelectionChanged: (set) =>
                              setState(() => _selectedSession = set.first),
                        ),
                      ),

                    // Dates
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _pickFromDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'From',
                                prefixIcon: Icon(Icons.calendar_today_outlined),
                              ),
                              child: Text(_formatDate(_fromDate)),
                            ),
                          ),
                        ),
                        if (_selectedDuration == LeaveDuration.fullDay) ...[
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: InkWell(
                              onTap: _pickToDate,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'To',
                                  prefixIcon: Icon(Icons.calendar_today_outlined),
                                ),
                                child: Text(_formatDate(_toDate)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Reason
                    AppTextField(
                      controller: _reasonController,
                      label: 'Reason',
                      maxLines: 3,
                      hintText: 'Enter reason for leave...',
                      validator: (v) => v == null || v.trim().isEmpty 
                          ? 'Please enter a reason' 
                          : null,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Requested Days Info
              Center(
                child: Text(
                  'Requested: ${_fmt(_requestedDays())} day(s)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              AppButton(
                label: 'Update Request',
                onPressed: _submit,
                isLoading: _isSubmitting,
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
