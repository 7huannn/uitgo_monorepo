import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:rider_app/app/router.dart';
import 'package:rider_app/core/config/config.dart';
import 'package:rider_app/features/auth/services/auth_service.dart';

/// Splash/Welcome hiển thị khi mở app.
/// - Luôn hiện animation.
/// - Khi animation xong: nếu đã đăng nhập -> /home, chưa đăng nhập -> /login.
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  final AuthService _authService = AuthService();
  bool _navigated = false;
  bool _animationBound = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_navigated) {
        _goNext();
      }
    });
  }

  Future<void> _goNext() async {
    if (_navigated) return;
    final loggedIn = await _authService.isLoggedIn();
    if (loggedIn && !useMock) {
      try {
        await _authService.me();
      } catch (_) {
        // ignore profile refresh errors during splash
      }
    }

    if (!mounted) return;
    _navigated = true;
    if (loggedIn) {
      context.goNamed(AppRouteNames.home);
    } else {
      context.goNamed(AppRouteNames.login);
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
      backgroundColor: const Color(0xFFF4F6FA),
      body: Center(
        child: Lottie.asset(
          'assets/Welcome.json',
          controller: _controller,
          width: 300,
          height: 150,
          fit: BoxFit.contain,
          onLoaded: (comp) {
            if (_animationBound) return;
            _animationBound = true;
            _controller
              ..duration = comp.duration
              ..forward(from: 0);
          },
          errorBuilder: (context, error, stack) {
            debugPrint('❌ Lottie error: $error');
            // Nếu lỗi asset, chờ 800ms rồi điều hướng luôn để không kẹt ở đây
            Future.microtask(() async {
              await Future.delayed(const Duration(milliseconds: 800));
              await _goNext();
            });
            return const Text(
              'Không tải được assets/Welcome.json',
              style: TextStyle(color: Colors.red),
            );
          },
        ),
      ),
    );
  }
}
