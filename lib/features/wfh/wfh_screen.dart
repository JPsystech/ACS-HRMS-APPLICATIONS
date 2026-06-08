import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/wfh_utils.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/fade_in_wrapper.dart';
import '../../widgets/status_chip.dart';
import '../../core/api/wfh_dto.dart';

class WfhScreen extends ConsumerStatefulWidget {
  const WfhScreen({super.key});

  @override
  ConsumerState<WfhScreen> createState() => _WfhScreenState();
}

class _WfhScreenState extends ConsumerState<WfhScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    // Ensure latest data when screen opens.
    Future.microtask(() {
      ref.invalidate(myWfhProvider);
    });
  }

  void _handleTabChange() {
    if (_tabController.index == 1) {
      ref.invalidate(myWfhProvider);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    // When leaving WFH screen, ensure dashboard sees fresh data next time.
    final year = DateTime.now().year;
    ref.invalidate(myWfhProvider);
    ref.invalidate(wfhBalanceProvider(year));
    super.dispose();
  }

  void _goToMyRequestsTab() {
    _tabController.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final rolePolicyAsync = ref.watch(rolePolicyProvider);
    final employee = profileAsync.valueOrNull;
    final rolePolicy = rolePolicyAsync.valueOrNull;
    final wfhEnabled = WfhUtils.canSeeWFH(employee);

    if (!wfhEnabled) {
      final theme = Theme.of(context);
      final colorScheme = theme.colorScheme;
      final message = WfhUtils.getWfhErrorMessage(employee);
      
      return FadeInWrapper(
        child: Scaffold(
          backgroundColor: colorScheme.background,
          appBar: AppBar(
            title: const Text('WFH'),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return FadeInWrapper(
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: AppBar(
          title: const Text('WFH'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(
                text: 'Apply WFH',
                icon: Icon(Icons.home_work_outlined),
              ),
              Tab(
                text: 'My Requests',
                icon: Icon(Icons.list_alt_rounded),
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _ApplyWfhTab(onAfterSubmit: _goToMyRequestsTab),
            const _MyWfhTab(),
          ],
        ),
      ),
    );
  }
}

class _ApplyWfhTab extends ConsumerStatefulWidget {
  const _ApplyWfhTab({
    required this.onAfterSubmit,
  });

  final VoidCallback onAfterSubmit;

  @override
  ConsumerState<_ApplyWfhTab> createState() => _ApplyWfhTabState();
}

class _ApplyWfhTabState extends ConsumerState<_ApplyWfhTab> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickFromDate() async {
    final now = DateTime.now();
    final initial = _fromDate ?? now;
    final firstDate = DateTime(now.year - 1); // allow past dates; backend validates policy
    final lastDate = DateTime(now.year + 1);

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (date != null) {
      setState(() {
        _fromDate = date;
        // Reset to-date if it is before new from-date.
        if (_toDate != null && _toDate!.isBefore(date)) {
          _toDate = null;
        }
      });
    }
  }

  Future<void> _pickToDate() async {
    final now = DateTime.now();
    final base = _toDate ?? _fromDate ?? now;
    final firstDate = _fromDate ?? DateTime(now.year - 1);
    final lastDate = DateTime(now.year + 1);

    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (date != null) {
      setState(() {
        _toDate = date;
      });
    }
  }

  String _formatUiDate(DateTime? d) {
    if (d == null) return 'Select date';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _formatBackendDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    
    // Check WFH permissions before making API call
    final profileAsync = ref.read(profileProvider);
    final employee = profileAsync.valueOrNull;
    final wfhEnabled = WfhUtils.canSeeWFH(employee);
    
    if (!wfhEnabled) {
      final message = WfhUtils.getWfhErrorMessage(employee);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    if (_fromDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date for WFH')),
      );
      return;
    }

    final service = ref.read(wfhServiceProvider);
    final from = _formatBackendDate(_fromDate!);
    final to = _toDate != null ? _formatBackendDate(_toDate!) : null;
    final reason = _reasonController.text.trim();

    try {
      await service.applyWfh(
        fromDate: from,
        toDate: to,
        reason: reason,
      );

      if (!mounted) return;

      // Clear form.
      _reasonController.clear();
      setState(() {
        _fromDate = null;
        _toDate = null;
      });

      // Refresh list and show feedback.
      final year = DateTime.now().year;
      ref.invalidate(myWfhProvider);
      ref.invalidate(wfhBalanceProvider(year));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WFH request submitted')),
      );

      widget.onAfterSubmit();
    } on DioException catch (e) {
      if (!mounted) return;
      final response = e.response;
      String message = 'Could not submit WFH. Please try again.';
      if (response != null) {
        final statusCode = response.statusCode;
        // Prefer backend message when available.
        if (response.data is Map<String, dynamic>) {
          final data = response.data as Map<String, dynamic>;
          if (data['detail'] is String) {
            message = data['detail'] as String;
          } else if (data['errors'] is List && (data['errors'] as List).isNotEmpty) {
            message = (data['errors'] as List).first.toString();
          }
        }
        if (statusCode == 401) {
          message = 'Session expired. Please login again.';
        } else if (statusCode == 403 && (message == 'Could not submit WFH. Please try again.' || message.isEmpty)) {
          // Fallback when WFH is forbidden - use centralized error message
          final profileAsync = ref.read(profileProvider);
          final employee = profileAsync.valueOrNull;
          message = WfhUtils.getWfhErrorMessage(employee);
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not submit WFH. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final padding = EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.paddingBottomSafe + AppSpacing.md,
    );

    return Form(
      key: _formKey,
      child: ListView(
        padding: padding,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: _pickFromDate,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                    alignment: Alignment.centerLeft,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(_formatUiDate(_fromDate)),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'From date',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: _pickToDate,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                    alignment: Alignment.centerLeft,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(_formatUiDate(_toDate ?? _fromDate)),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'To date (optional, for range)',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _reasonController,
                  label: 'Reason',
                  hintText: 'Enter reason for WFH',
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a reason';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Submit',
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MyWfhTab extends ConsumerWidget {
  const _MyWfhTab();

  String _formatDateRange(_DateRange range) {
    final from = range.from;
    final to = range.to;

    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    if (to == null || to.isAtSameMomentAs(from)) {
      return fmt(from);
    }
    return '${fmt(from)} – ${fmt(to)}';
  }

  String _formatCreated(DateTime? createdAt) {
    if (createdAt == null) return '—';
    return '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';
  }

  AppStatus _statusFor(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.contains('cancel')) return AppStatus.cancelled;
    if (s.contains('approve')) return AppStatus.approved;
    if (s.contains('reject')) return AppStatus.rejected;
    if (s.contains('pending')) return AppStatus.pending;
    return AppStatus.warning;
  }

  String _statusLabel(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.contains('cancel')) return 'CANCELLED';
    if (s.contains('approve')) return 'APPROVED';
    if (s.contains('reject')) return 'REJECTED';
    if (s.contains('pending')) return 'PENDING';
    return s.isEmpty ? 'UNKNOWN' : s.toUpperCase();
  }

  void _showDetails(BuildContext context, WfhRequestDto dto) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WfhRequestDetailsBottomSheet(request: dto),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final asyncWfh = ref.watch(myWfhProvider);

    final padding = EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.paddingBottomSafe + AppSpacing.md,
    );

    return asyncWfh.when(
      data: (items) {
        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myWfhProvider);
              await ref.read(myWfhProvider.future);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: const EmptyStateView(
                  title: 'No WFH requests yet',
                  subtitle: 'Apply WFH from the other tab. All statuses are shown here.',
                  icon: Icons.home_work_outlined,
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myWfhProvider);
            await ref.read(myWfhProvider.future);
          },
          child: ListView.builder(
            padding: padding,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final dto = items[index];
              final from = dto.primaryFrom;
              final to = dto.primaryTo;
              if (from == null) {
                return const SizedBox.shrink();
              }
              final range = _DateRange(from: from, to: to);

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  onTap: () => _showDetails(context, dto),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.home_work_outlined,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _formatDateRange(range),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          StatusChip(
                            status: _statusFor(dto.status),
                            label: _statusLabel(dto.status),
                          ),
                        ],
                      ),
                      if (dto.reason.trim().isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          dto.reason.trim(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Created: ${_formatCreated(dto.createdAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: colorScheme.error,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Could not load WFH requests. Check your connection.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateRange {
  const _DateRange({required this.from, this.to});

  final DateTime from;
  final DateTime? to;
}

class _WfhRequestDetailsBottomSheet extends StatelessWidget {
  const _WfhRequestDetailsBottomSheet({required this.request});

  final WfhRequestDto request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;

    final from = request.primaryFrom;
    final to = request.primaryTo;
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('hh:mm a');

    String formatRange() {
      if (from == null) return '—';
      if (to == null || to.isAtSameMomentAs(from)) {
        return dateFormat.format(from);
      }
      return '${dateFormat.format(from)} – ${dateFormat.format(to)}';
    }

    String formatDateTime(DateTime? dt) {
      if (dt == null) return '—';
      // Ensure the DateTime is converted to local time (IST) before formatting
      final localDt = dt.toLocal();
      return '${dateFormat.format(localDt)} at ${timeFormat.format(localDt)}';
    }

    AppStatus getAppStatus(String raw) {
      final s = raw.trim().toLowerCase();
      if (s.contains('cancel')) return AppStatus.cancelled;
      if (s.contains('approve')) return AppStatus.approved;
      if (s.contains('reject')) return AppStatus.rejected;
      if (s.contains('pending')) return AppStatus.pending;
      return AppStatus.warning;
    }

    String getStatusLabel(String raw) {
      final s = raw.trim().toLowerCase();
      if (s.contains('cancel')) return 'CANCELLED';
      if (s.contains('approve')) return 'APPROVED';
      if (s.contains('reject')) return 'REJECTED';
      if (s.contains('pending')) return 'PENDING';
      return s.isEmpty ? 'UNKNOWN' : s.toUpperCase();
    }

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'WFH Request Details',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                StatusChip(
                  status: getAppStatus(request.status),
                  label: getStatusLabel(request.status),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Request ID: ${request.id}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: AppSpacing.xl),

            // Request Details Section
            _buildSection(
              theme,
              'Request Details',
              [
                _buildInfoRow(theme, 'WFH Date', formatRange()),
                _buildInfoRow(theme, 'Applied On', formatDateTime(request.createdAt)),
              ],
            ),

            // Reason Section
            const SizedBox(height: AppSpacing.lg),
            _buildSection(
              theme,
              'Reason',
              [
                Text(
                  request.reason.trim().isNotEmpty ? request.reason.trim() : 'No reason provided',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),

            // Approval Information Section
            if (request.status != 'pending') ...[
              const SizedBox(height: AppSpacing.lg),
              _buildSection(
                theme,
                'Decision Information',
                [
                  _buildInfoRow(
                    theme,
                    request.status == 'approved' ? 'Approved By' : 'Rejected By',
                    request.approvedByName ?? request.approver ?? '—',
                  ),
                  _buildInfoRow(theme, 'Decision Time', formatDateTime(request.decidedAt)),
                  if (request.approvalRemark != null && request.approvalRemark!.isNotEmpty)
                    _buildInfoRow(theme, 'Remark', request.approvalRemark!, isItalic: true),
                ],
              ),
            ] else ...[
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                  border: Border.all(color: colorScheme.primaryContainer),
                ),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_empty_rounded, size: 20, color: colorScheme.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Pending action from manager',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Close',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value, {bool isItalic = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

