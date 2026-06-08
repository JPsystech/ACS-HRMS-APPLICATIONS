import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/acs/acs_gradient_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _meetsLength => _newController.text.length >= 8;
  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(_newController.text);
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_newController.text);
  bool get _hasSpecial => RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(_newController.text);
  bool get _matchesConfirm => _newController.text == _confirmController.text && _confirmController.text.isNotEmpty;

  bool get _canSubmit =>
      _currentController.text.isNotEmpty &&
      _meetsLength &&
      _hasUppercase &&
      _hasNumber &&
      _hasSpecial &&
      _matchesConfirm &&
      !_isSubmitting;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_canSubmit) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final auth = ref.read(authServiceProvider);
      await auth.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      ref.read(mustChangePasswordProvider.notifier).state = false;
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully')),
      );
      // Navigate to dashboard if we were forced, else pop.
      final location = GoRouter.of(context).state.matchedLocation;
      if (location == '/security/change-password') {
        context.go('/dashboard');
      } else {
        context.pop();
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = _friendlyError(e);
      });
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('current password')) return 'Current password is incorrect';
    if (s.contains('400')) return 'New password does not meet requirements';
    return 'Failed to change password. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Security')),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title and Subtitle
            Text(
              'Security',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Change your password',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            
            // Main Form Card
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: _currentController,
                    label: 'Current Password',
                    hintText: 'Enter current password',
                    obscureText: _obscureCurrent,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                    suffix: IconButton(
                      icon: Icon(_obscureCurrent ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: scheme.onSurfaceVariant),
                      onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _newController,
                    label: 'New Password',
                    hintText: 'Enter new password',
                    obscureText: _obscureNew,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                    suffix: IconButton(
                      icon: Icon(_obscureNew ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: scheme.onSurfaceVariant),
                      onPressed: () => setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _StrengthHints(
                    meetsLength: _meetsLength,
                    hasUppercase: _hasUppercase,
                    hasNumber: _hasNumber,
                    hasSpecial: _hasSpecial,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _confirmController,
                    label: 'Confirm Password',
                    hintText: 'Re-enter new password',
                    obscureText: _obscureConfirm,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    suffix: IconButton(
                      icon: Icon(_obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: scheme.onSurfaceVariant),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  ACSGradientButton(
                    onPressed: _canSubmit ? _handleSubmit : null,
                    minimumSize: const Size.fromHeight(52),
                    borderRadius: BorderRadius.circular(14),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Update Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StrengthHints extends StatelessWidget {
  const _StrengthHints({
    required this.meetsLength,
    required this.hasUppercase,
    required this.hasNumber,
    required this.hasSpecial,
  });

  final bool meetsLength;
  final bool hasUppercase;
  final bool hasNumber;
  final bool hasSpecial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Text row(String text, bool ok) {
      return Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: ok ? scheme.primary : scheme.onSurfaceVariant,
          fontWeight: ok ? FontWeight.w600 : FontWeight.w400,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row('• At least 8 characters', meetsLength),
        row('• At least 1 uppercase letter', hasUppercase),
        row('• At least 1 number', hasNumber),
        row('• At least 1 special character', hasSpecial),
      ],
    );
  }
}
