import 'package:acs_hrms/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/api/employee_me_dto.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/config/api_config.dart';

import '../../widgets/app_card.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/error_view.dart';
import '../../widgets/fade_in_wrapper.dart';
import '../../widgets/loading_view.dart';

/// App version shown in Settings (not from API).
const String _kAppVersion = '1.0.5';

/// Cache busting version for profile photo.
final photoVersionProvider = StateProvider.autoDispose<String>(
    (ref) => DateTime.now().millisecondsSinceEpoch.toString());

/// Profile tab screen — the only profile UI. Uses [profileProvider] (EmployeeMeDto from GET /api/v1/employees/me).
/// No hardcoded name/emp code/department/manager/mobile; all values from API.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _onRefresh(WidgetRef ref, BuildContext context) async {
    try {
      ref.invalidate(leaveBalanceProvider);
      ref.invalidate(leaveBalanceSummaryProvider);
      ref.invalidate(myLeavesProvider);
      ref.invalidate(todaySessionProvider);
      ref.invalidate(todayAttendanceProvider);
      ref.refresh(profileProvider);
      await ref.read(profileProvider.future);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Refresh failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final refreshKey = RefreshKeysScope.of(context)?.keyFor(4);
    final profileAsync = ref.watch(profileProvider);

    return FadeInWrapper(
      child: Scaffold(
        backgroundColor: theme.colorScheme.background,
        appBar: AppBar(title: const Text('Profile')),
        body: RefreshIndicator(
          key: refreshKey,
          onRefresh: () => _onRefresh(ref, context),
          child: profileAsync.when(
            data: (employee) {
              if (employee == null) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const Center(child: LoadingView(compact: true)),
                    const SizedBox(height: 40),
                    const AppFooter(),
                  ],
                );
              }
              return _ProfileContent(
                ref: ref,
                employee: employee,
                theme: theme,
                colorScheme: colorScheme,
                refreshKey: refreshKey,
                onRefresh: () => _onRefresh(ref, context),
              );
            },
            loading: () => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: _ProfileSkeleton(theme: theme, colorScheme: colorScheme),
            ),
            error: (err, _) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: ErrorView(
                  message: err
                      .toString()
                      .replaceFirst(RegExp(r'^Exception:?\s*'), ''),
                  onRetry: () => ref.invalidate(profileProvider),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.ref,
    required this.employee,
    required this.theme,
    required this.colorScheme,
    required this.refreshKey,
    required this.onRefresh,
  });

  final WidgetRef ref;
  final EmployeeMeDto employee;
  final ThemeData theme;
  final ColorScheme colorScheme;
  final GlobalKey<RefreshIndicatorState>? refreshKey;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final name = employee.name.isEmpty ? '—' : employee.name;
    final empCode = employee.empCode.isEmpty ? '—' : employee.empCode;
    final department =
        employee.departmentName.isEmpty ? '—' : employee.departmentName;
    final manager = employee.managerName.isEmpty ? '—' : employee.managerName;
    final mobile = employee.mobileNumber.isEmpty ? '—' : employee.mobileNumber;
    final initial =
        name != '—' && name.isNotEmpty ? name[0].toUpperCase() : '?';
    final dobText = employee.dob.isNotEmpty ? employee.dob : '—';

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        // Top profile card
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar + upload button
              Row(
                children: [
                  _AvatarBlock(
                      employee: employee,
                      colorScheme: colorScheme,
                      theme: theme,
                      initial: initial),
                  const Spacer(),
                  AppButton(
                    label: 'Upload',
                    onPressed: () =>
                        _pickAndUploadImage(ref, context, employee),
                    variant: AppButtonVariant.outlined,
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Name + emp code + department
              Text(
                name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 4),
              Text(
                empCode,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              if (department != '—') ...[
                const SizedBox(height: 4),
                Text(
                  department,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Personal Section
        Text(
          'Personal',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // Date of Birth
              ListTile(
                leading: Icon(Icons.cake_rounded,
                    color: colorScheme.primary, size: 24),
                title: Text('Date of Birth'),
                subtitle:
                    Text(dobText != '—' ? _formatDobForDisplay(dobText) : '—'),
                trailing: Icon(Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant),
                onTap: () async {
                  final now = DateTime.now();
                  final initial = _parseDate(employee.dob) ??
                      DateTime(now.year - 25, now.month, now.day);
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: DateTime(1900),
                    lastDate: DateTime(now.year, now.month, now.day),
                  );
                  if (picked != null) {
                    final dob = DateFormat('yyyy-MM-dd').format(picked);
                    try {
                      await ref
                          .read(cultureServiceProvider)
                          .updateProfile(dob: dob);
                      ref.invalidate(profileProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('DOB updated')));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed: $e')));
                      }
                    }
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Work Section
        Text(
          'Work',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // Department
              ListTile(
                leading: Icon(Icons.business_rounded,
                    color: colorScheme.primary, size: 24),
                title: Text('Department'),
                subtitle: Text(department),
              ),
              Divider(height: 1, color: colorScheme.outlineVariant),
              // Reporting Manager
              ListTile(
                leading: Icon(Icons.person_rounded,
                    color: colorScheme.primary, size: 24),
                title: Text('Reporting Manager'),
                subtitle: Text(manager),
              ),
              Divider(height: 1, color: colorScheme.outlineVariant),
              // Mobile Number
              ListTile(
                leading: Icon(Icons.phone_rounded,
                    color: colorScheme.primary, size: 24),
                title: Text('Mobile Number'),
                subtitle: Text(mobile),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Settings Section
        Text(
          'Settings',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  Icons.receipt_long_rounded,
                  color: colorScheme.primary,
                  size: 24,
                ),
                title: const Text('My Payslips'),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.push('/payslips');
                },
              ),
              Divider(height: 1, color: colorScheme.outlineVariant),
              ListTile(
                leading: Icon(
                  Icons.lock_rounded,
                  color: colorScheme.primary,
                  size: 24,
                ),
                title: const Text('Security'),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.push('/security/change-password');
                },
              ),
              Divider(height: 1, color: colorScheme.outlineVariant),
              ListTile(
                leading: Icon(
                  Icons.info_outline_rounded,
                  color: colorScheme.primary,
                  size: 24,
                ),
                title: const Text('App Version'),
                trailing: Text(
                  _kAppVersion,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AppButton(
          label: 'Logout',
          variant: AppButtonVariant.tonal,
          onPressed: () async {
            await ref.read(authProvider.notifier).manualLogout();
            if (context.mounted) context.go('/login');
          },
        ),
        const SizedBox(height: AppSpacing.xl),
        const AppFooter(),
      ],
    );
  }

  DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  String _formatDobForDisplay(String dob) {
    try {
      final date = DateTime.parse(dob);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (_) {
      return dob;
    }
  }

  Future<void> _pickAndUploadImage(
      WidgetRef ref, BuildContext context, EmployeeMeDto employee) async {
    final picker = ImagePicker();
    try {
      final picked =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;

      // Upload to new R2 endpoint
      await ref.read(cultureServiceProvider).uploadProfilePhoto(picked.path);

      // Success! Update local photo version for cache busting
      ref.read(photoVersionProvider.notifier).state =
          DateTime.now().millisecondsSinceEpoch.toString();

      // Refresh profile info (though we use /me/photo directly now)
      ref.invalidate(profileProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }
}

/// Skeleton placeholder for profile loading state.
class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton({required this.theme, required this.colorScheme});

  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.paddingBottomSafe + AppSpacing.md,
    );
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: 160,
                  height: 24,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  width: 80,
                  height: 18,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Info',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SkeletonTile(colorScheme: colorScheme),
                Divider(height: 1, color: colorScheme.outlineVariant),
                _SkeletonTile(colorScheme: colorScheme),
                Divider(height: 1, color: colorScheme.outlineVariant),
                _SkeletonTile(colorScheme: colorScheme),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      title: Container(
        height: 16,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _AvatarBlock extends ConsumerWidget {
  const _AvatarBlock(
      {required this.employee,
      required this.colorScheme,
      required this.theme,
      required this.initial});
  final EmployeeMeDto employee;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final String initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final token = ref.watch(authProvider).asData?.value;
    final photoVersion = ref.watch(photoVersionProvider);
    final baseUrl = ApiConfig.apiBaseUrl;
    final photoUrl = '${baseUrl}me/photo?v=$photoVersion';

    return SizedBox(
      width: 96,
      height: 96,
      child: ClipOval(
        child: Container(
          color: colorScheme.primaryContainer,
          child: Image.network(
            photoUrl,
            headers: {
              if (token != null) 'Authorization': 'Bearer $token',
            },
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Text(
                  initial,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
