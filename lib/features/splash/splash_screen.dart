import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../core/auth/auth_constants.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _totalDuration = Duration(milliseconds: 6000); // Increased from 2200ms to 6000ms for better visibility
  
  late final AnimationController _controller;
  String _targetRoute = '/login';
  
  // Safe phase helper for normalized animation progress
  double _phase(int startMs, int endMs, double t) {
    final totalMs = _controller.duration!.inMilliseconds;
    final start = startMs / totalMs;
    final end = endMs / totalMs;
    final x = ((t - start) / (end - start));
    return x.clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: _totalDuration,
    )..addStatusListener((status) {
        debugPrint('🟣 [Splash] Animation status: $status');
        if (status == AnimationStatus.completed) {
          debugPrint('🟣 [Splash] Navigating to $_targetRoute');
          context.go(_targetRoute);
        }
      });
    debugPrint('🟣 [Splash] Starting splash animation');
    _controller.forward();
    Future.microtask(() async {
      await _bootstrapSession();
    });
  }

  Future<void> _bootstrapSession() async {
    try {
      final sw = Stopwatch()..start();
      while (ref.read(authProvider).isLoading &&
          sw.elapsed < const Duration(seconds: 5)) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }

      final auth = ref.read(authProvider);
      final token = auth.valueOrNull;
      final refreshToken = await ref
          .read(secureStoreProvider)
          .read(AuthConstants.refreshTokenKey);
      debugPrint(
        '[AUTH_BOOT] hasToken=${token != null && token.isNotEmpty} hasRefresh=${refreshToken != null && refreshToken.isNotEmpty}',
      );
      _targetRoute = (token != null && token.isNotEmpty) ? '/dashboard' : '/login';
      if (!mounted) return;
      if (_targetRoute == '/login') {
        _controller.stop();
        context.go('/login');
      }
    } catch (e) {
      debugPrint('🟣 [Splash] Bootstrap error: $e');
      _targetRoute = '/login';
      if (!mounted) return;
      _controller.stop();
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox.expand(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            
            return Stack(
              fit: StackFit.expand,
              children: [
                // White background
                Container(color: Colors.white),
                
                // Left card
                _buildAnimatedCard(
                  direction: const Offset(-1.0, 0.0),
                  size: width * 1.25,
                  width: width,
                  height: height,
                  offX: -width * 1.1,
                  offY: 0.0,
                ),
                
                // Right card
                _buildAnimatedCard(
                  direction: const Offset(1.0, 0.0),
                  size: width * 1.25,
                  width: width,
                  height: height,
                  offX: width * 1.1,
                  offY: 0.0,
                ),
                
                // Top card
                _buildAnimatedCard(
                  direction: const Offset(0.0, -1.0),
                  size: width * 0.78,
                  width: width,
                  height: height,
                  offX: 0.0,
                  offY: -height * 0.9,
                ),
                
                // Bottom card
                _buildAnimatedCard(
                  direction: const Offset(0.0, 1.0),
                  size: width * 0.78,
                  width: width,
                  height: height,
                  offX: 0.0,
                  offY: height * 0.9,
                ),
                
                // Logo
                _buildLogoAnimation(width, height),
              ],
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildAnimatedCard({
    required Offset direction,
    required double size,
    required double width,
    required double height,
    required double offX,
    required double offY,
  }) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        double translateX = 0.0;
        double translateY = 0.0;
        double opacity = 1.0;
        
        final value = _controller.value;
        
        // IN phase: 0-2000ms - cards slide to center (slower for visibility)
        if (value <= 2000 / 6000) {
          final progress = _phase(0, 2000, value);
          final curve = Curves.easeOutBack.transform(progress);
          
          // Cards start at off-screen positions and move to center (0,0)
          translateX = offX * (1 - curve);
          translateY = offY * (1 - curve);
          
          // Debug: print animation values
          if (progress > 0 && progress < 0.1) {
            debugPrint('Card IN - progress: $progress, curve: $curve, translateX: $translateX, translateY: $translateY');
          }
        }
        // OUT phase: 2000-3000ms - cards split out
        else if (value <= 3000 / 6000) {
          final progress = _phase(2000, 3000, value);
          final curve = Curves.easeInCubic.transform(progress);
          
          translateX = direction.dx * curve * width;
          translateY = direction.dy * curve * height;
          
          // Fade out between 2500-3000ms
          if (value >= 2500 / 6000) {
            final fadeProgress = _phase(2500, 3000, value);
            opacity = (1.0 - fadeProgress).clamp(0.0, 1.0);
          }
        }
        // After 3000ms: cards are gone
        else {
          opacity = 0.0;
        }
        
        return Center(
          child: Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(translateX, translateY),
              child: Transform.rotate(
                angle: 0.785, // 45 degrees
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B56A9),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildLogoAnimation(double width, double height) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        double scale = 0.6;
        double opacity = 0.0;
        
        final value = _controller.value;
        
        // Logo IN: 3000-4000ms - appears after cards exit
        if (value >= 3000 / 6000) {
          final progress = _phase(3000, 4000, value);
          final curve = Curves.easeOutBack.transform(progress);
          
          scale = (0.6 + 0.4 * curve).clamp(0.6, 1.0);
          opacity = curve.clamp(0.0, 1.0);
        }
        
        // Logo slight fade out: 4000-6000ms
        if (value >= 4000 / 6000) {
          final progress = _phase(4000, 6000, value);
          opacity = (1.0 - progress * 0.2).clamp(0.8, 1.0); // Slight fade to 80% opacity
        }
        
        // Debug assert to catch invalid opacity values
        assert(() {
          if (opacity < 0 || opacity > 1) {
            debugPrint('logoOpacity BAD: $opacity');
          }
          if (scale < 0.6 || scale > 1.0) {
            debugPrint('logoScale BAD: $scale');
          }
          return true;
        }());
        
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale.clamp(0.6, 1.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 30,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: const Color(0xFF6B56A9).withValues(alpha: 0.2),
                      blurRadius: 40,
                      spreadRadius: -5,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/ACS-logo.png',
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Text(
                      'ACS HRMS',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B56A9),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
