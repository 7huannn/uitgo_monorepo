import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import 'sign_up_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  static const route = '/login';

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _accentColor = Color(0xFF00BFA5);

  Future<bool> _handleLogin(String email, String password) async {
    final auth = context.read<AuthController>();
    final success = await auth.login(email.trim(), password);
    return success;
  }

  void _handleForgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Liên hệ điều phối viên để hỗ trợ đặt lại mật khẩu.',
        ),
      ),
    );
  }

  void _handleRegister() {
    Navigator.of(context).push(_fadeRoute(const SignUpPage()));
  }

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeModeController?>();

    return UitGoLoginScreen(
      logo: Icon(
        Icons.directions_car,
        size: 56,
        color: Theme.of(context).colorScheme.primary,
        semanticLabel: 'UIT-Go Driver',
      ),
      appName: 'UIT-Go Driver',
      tagline: 'Đăng nhập tài xế',
      accentColor: _accentColor,
      onLogin: _handleLogin,
      onForgotPassword: _handleForgotPassword,
      onRegister: _handleRegister,
      loginButtonLabel: 'Bắt đầu ca làm',
      registerLabel: 'Đăng ký',
      registerMessage: 'Chưa có tài khoản?',
      forgotPasswordLabel: 'Quên mật khẩu?',
      failureMessage: 'Sai thông tin đăng nhập. Thử lại nhé.',
      themeMode: themeController?.themeMode,
      onToggleTheme: themeController?.toggle,
    );
  }
}

PageRouteBuilder<bool> _fadeRoute(Widget page) {
  return PageRouteBuilder<bool>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (_, animation, __, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: curve.drive(
            Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ),
          ),
          child: child,
        ),
      );
    },
  );
}
