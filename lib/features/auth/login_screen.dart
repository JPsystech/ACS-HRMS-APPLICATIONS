import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';

/// Professional Enterprise Login Screen for ACS HRMS - Figma Match (same file, no new files)
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _empCodeController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  String? _errorMessage;
  bool _isInfoMessage = false;

  @override
  void dispose() {
    _empCodeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    final empCode = _empCodeController.text.trim();
    final password = _passwordController.text.trim();

    if (empCode.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both code and password.';
        _isInfoMessage = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isInfoMessage = false;
    });

    try {
      final mustChange = await ref.read(authProvider.notifier).login(
            empCode,
            password,
            rememberMe: _rememberMe,
          );
      if (!mounted) return;

      if (mustChange) {
        context.go('/security/change-password');
      } else {
        context.go('/dashboard');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = _userFriendlyMessage(e);
        _isInfoMessage = false;
      });
    }
  }

  String _userFriendlyMessage(dynamic e) {
    if (e is DioException) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        return 'Invalid employee code or password. Please try again.';
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Request timed out. Please try again.';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'Network error. Check your connection and try again.';
      }
    }

    final s = e.toString().toLowerCase();
    if (s.contains('401') ||
        s.contains('unauthorized') ||
        s.contains('invalid')) {
      return 'Invalid employee code or password. Please try again.';
    }
    if (s.contains('socket') ||
        s.contains('connection') ||
        s.contains('network')) {
      return 'Network error. Check your connection and try again.';
    }
    if (s.contains('timeout')) return 'Request timed out. Please try again.';

    return 'Login failed. Please try again.';
  }

  void _showForgotPasswordDialog() {
    const contactNo = '9313361114'; // change if needed

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          title: const Text(
            'Forgot Password',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'Password reset is handled by Admin.\n\nPlease contact Admin on:\n9313361114',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final keyboardOpen = bottomInset > 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use scroll if landscape OR height is too small for the card
        final isSmallHeight = constraints.maxHeight < 600;
        final useScroll = isLandscape || isSmallHeight;

        // KEY TWEAK: shift login a bit up when keyboard opens in STATIC mode
        final yOffset = keyboardOpen ? -70.0 : -18.0;

        return Scaffold(
          // Allow keyboard to push content up in scroll mode, but keep static in portrait
          resizeToAvoidBottomInset: useScroll,
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: Stack(
              children: [
                // Base background
                Positioned.fill(child: Container(color: Colors.white)),

                // Bottom diagonal behind everything (static)
                Positioned.fill(child: _bottomDiagonalDecor()),

                // Foreground content
                SafeArea(
                  child: useScroll
                      ? _buildScrollingContent(context)
                      : _buildStaticContent(context, yOffset),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Responsive scrollable layout for Landscape or Small screens
  Widget _buildScrollingContent(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: _loginContent(context),
        ),
      ),
    );
  }

  /// Current static centered layout for Portrait mode
  Widget _buildStaticContent(BuildContext context, double yOffset) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Transform.translate(
            offset: Offset(0, yOffset),
            child: _loginContent(context),
          ),
        ),
      ),
    );
  }

  // Bottom diagonal decor - 2 layers like Figma
  Widget _bottomDiagonalDecor() {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    return Stack(
      children: [
        // Back layer (darker)
        Positioned(
          bottom: 0,
          right: 0,
          child: ClipPath(
            clipper: _BottomDiagonalClipper(),
            child: Container(
              width: w,
              height: h * 0.37,
              color: const Color(0xFF5E47AB),
            ),
          ),
        ),

        // Front layer (main purple)
        Positioned(
          bottom: -6,
          right: 0,
          child: ClipPath(
            clipper: _BottomDiagonalClipper(),
            child: Container(
              width: w,
              height: h * 0.34,
              decoration: BoxDecoration(
                color: const Color(0xFF6C54B5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 14,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Login content
  Widget _loginContent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 32.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Welcome',
            style: const TextStyle(
              fontSize: 34.0,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6C54B5),
              height: 1.15,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10.0),
          const Text(
            'Start your day strong',
            style: TextStyle(
              fontSize: 22.0,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2A5A),
              height: 1.15,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6.0),
          const Text(
            'log in and make it productive',
            style: TextStyle(
              fontSize: 13.0,
              color: Color(0xFF7B8196),
              fontWeight: FontWeight.w400,
              letterSpacing: 0.3,
              height: 1.15,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32.0),

          if (_errorMessage != null) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
              decoration: BoxDecoration(
                color:
                    _isInfoMessage ? const Color(0xFFF0F7FF) : Colors.red[50],
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: _isInfoMessage
                      ? const Color(0xFFB3D1FF)
                      : Colors.red[100]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isInfoMessage ? Icons.info_outline : Icons.error_outline,
                    size: 20,
                    color: _isInfoMessage
                        ? const Color(0xFF0052CC)
                        : Colors.red[700],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: _isInfoMessage
                            ? const Color(0xFF0052CC)
                            : Colors.red[700],
                        fontSize: 13.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),
          ],

          // EMP CODE
          TextFormField(
            controller: _empCodeController,
            cursorColor: const Color(0xFF1F2A5A),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF5F7FF),
              hintText: 'EMP CODE',
              hintStyle: const TextStyle(
                color: Color(0xFF7B8196),
                fontSize: 13.0,
                fontWeight: FontWeight.w400,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(
                  color: const Color(0xFF1F2A5A).withValues(alpha: 0.15),
                  width: 1.1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(
                  color: const Color(0xFF1F2A5A).withValues(alpha: 0.15),
                  width: 1.1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: const BorderSide(
                  color: Color(0xFF6C54B5),
                  width: 1.5,
                ),
              ),
            ),
            style: const TextStyle(
              fontSize: 14.0,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2A5A),
            ),
            textCapitalization: TextCapitalization.characters,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
          ),

          const SizedBox(height: 16.0),

          // PASSWORD
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            cursorColor: const Color(0xFF1F2A5A),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF5F7FF),
              hintText: 'Password',
              hintStyle: const TextStyle(
                color: Color(0xFF7B8196),
                fontSize: 13.0,
                fontWeight: FontWeight.w400,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(
                  color: const Color(0xFF1F2A5A).withValues(alpha: 0.15),
                  width: 1.1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(
                  color: const Color(0xFF1F2A5A).withValues(alpha: 0.15),
                  width: 1.1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: const BorderSide(
                  color: Color(0xFF6C54B5),
                  width: 1.5,
                ),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFF7B8196),
                  size: 18.0,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
            ),
            style: const TextStyle(
              fontSize: 14.0,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2A5A),
            ),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _onLogin(),
          ),

          const SizedBox(height: 12.0),

          // Remember + Forgot
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (value) {
                        setState(() => _rememberMe = value ?? false);
                      },
                      activeColor: const Color(0xFF6C54B5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    const Flexible(
                      child: Text(
                        'Remember Me',
                        style: TextStyle(
                          fontSize: 12.0,
                          color: Color(0xFF1F2A5A),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _showForgotPasswordDialog,
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    fontSize: 12.0,
                    color: Color(0xFF6C54B5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18.0),

          // Sign In button
          SizedBox(
            height: 52.0,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _onLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C54B5),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.0),
                ),
                elevation: 0,
                padding: EdgeInsets.zero,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20.0,
                      height: 20.0,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text('Sign In'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom clipper for bottom diagonal shape
class _BottomDiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    // Start from bottom-left
    path.moveTo(0, size.height);

    // Up to 65% height
    path.lineTo(0, size.height * 0.65);

    // Diagonal to right at 35% height
    path.lineTo(size.width, size.height * 0.35);

    // Down to bottom-right
    path.lineTo(size.width, size.height);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
