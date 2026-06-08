import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/payslip_dto.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/fade_in_wrapper.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/status_chip.dart';

class MyPayslipsScreen extends ConsumerStatefulWidget {
  const MyPayslipsScreen({super.key});

  @override
  ConsumerState<MyPayslipsScreen> createState() => _MyPayslipsScreenState();
}

class _MyPayslipsScreenState extends ConsumerState<MyPayslipsScreen> {
  final Set<String> _viewing = <String>{};
  final Set<String> _downloading = <String>{};

  Future<void> _onRefresh() async {
    ref.invalidate(myPayslipsProvider);
    await ref.read(myPayslipsProvider.future);
  }

  Future<Uint8List> _fetchPayslipBytes(PayslipDto p) async {
    final service = ref.read(payslipServiceProvider);
    final endpoint = (p.downloadEndpoint ?? '').trim();
    return endpoint.isNotEmpty ? service.downloadPayslipPdfBytesByEndpoint(endpoint) : service.downloadPayslipPdfBytes(p.id);
  }

  Future<File> _writePayslipTempFile(PayslipDto p, Uint8List bytes) async {
    final tmp = await getTemporaryDirectory();
    final fileName = 'Payslip_${p.salaryYear}_${p.salaryMonth.toString().padLeft(2, '0')}.pdf';
    final file = File('${tmp.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _viewPayslip(PayslipDto p) async {
    if (_viewing.contains(p.id) || _downloading.contains(p.id)) return;
    setState(() => _viewing.add(p.id));
    try {
      final bytes = await _fetchPayslipBytes(p);
      if (bytes.isEmpty) throw Exception('Empty file');

      final file = await _writePayslipTempFile(p, bytes);
      final result = await OpenFilex.open(file.path, type: 'application/pdf');
      if (result.type != ResultType.done) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Payslip ${p.monthYearLabel}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst(RegExp(r'^Exception:?\s*'), ''))),
      );
    } finally {
      if (mounted) setState(() => _viewing.remove(p.id));
    }
  }

  Future<void> _downloadPayslip(PayslipDto p) async {
    if (_downloading.contains(p.id) || _viewing.contains(p.id)) return;
    setState(() => _downloading.add(p.id));
    try {
      final bytes = await _fetchPayslipBytes(p);
      if (bytes.isEmpty) throw Exception('Empty file');

      final file = await _writePayslipTempFile(p, bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Payslip ${p.monthYearLabel}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst(RegExp(r'^Exception:?\s*'), ''))),
      );
    } finally {
      if (mounted) setState(() => _downloading.remove(p.id));
    }
  }

  static AppStatus _mapStatus(String raw) {
    final s = raw.trim().toUpperCase();
    if (s.contains('GENERATED') || s.contains('SUCCESS') || s.contains('APPROVED')) {
      return AppStatus.success;
    }
    if (s.contains('PENDING') || s.contains('PROCESS')) return AppStatus.pending;
    if (s.contains('FAILED') || s.contains('ERROR') || s.contains('REJECT')) return AppStatus.error;
    return AppStatus.info;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final refreshKey = RefreshKeysScope.of(context)?.keyFor(0);
    final async = ref.watch(myPayslipsProvider);

    return FadeInWrapper(
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: const Text('My Payslips'),
          actions: [
            IconButton(
              tooltip: 'Help',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tap View / Download to open your payslip.')),
                );
              },
              icon: const Icon(Icons.help_outline_rounded),
            ),
          ],
        ),
        body: RefreshIndicator(
          key: refreshKey,
          onRefresh: _onRefresh,
          child: async.when(
            loading: () => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: const [
                LoadingView(),
              ],
            ),
            error: (err, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                ErrorView(
                  message: err.toString().replaceFirst(RegExp(r'^Exception:?\s*'), ''),
                  onRetry: () => ref.invalidate(myPayslipsProvider),
                ),
              ],
            ),
            data: (items) {
              if (items.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    const SizedBox(height: 48),
                    const EmptyStateView(
                      title: 'No payslips yet',
                      subtitle: 'Your generated payslips will appear here.',
                      icon: Icons.receipt_long_rounded,
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Retry',
                      onPressed: () => ref.invalidate(myPayslipsProvider),
                      variant: AppButtonVariant.outlined,
                      fullWidth: true,
                    ),
                  ],
                );
              }
              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final p = items[index];
                  final isDownloading = _downloading.contains(p.id);
                  final isViewing = _viewing.contains(p.id);
                  final status = _mapStatus(p.status);
                  return AppCard(
                    padding: const EdgeInsets.all(16),
                    onTap: () {
                      _viewPayslip(p);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                p.monthYearLabel,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            StatusChip(
                              status: status,
                              label: p.status,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 18, color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'Payslip date: ${p.payslipDateLabel}',
                              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            Icon(Icons.payments_rounded, size: 18, color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'Net salary: ${p.netSalaryLabel}',
                              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppButton(
                                label: 'View',
                                isLoading: isViewing,
                                onPressed: () => _viewPayslip(p),
                                variant: AppButtonVariant.outlined,
                                icon: const Icon(Icons.visibility_rounded, size: 18),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              AppButton(
                                label: 'Download',
                                isLoading: isDownloading,
                                onPressed: () => _downloadPayslip(p),
                                variant: AppButtonVariant.filled,
                                icon: const Icon(Icons.download_rounded, size: 18),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
