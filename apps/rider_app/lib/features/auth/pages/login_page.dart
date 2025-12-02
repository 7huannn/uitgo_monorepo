import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:rider_app/app/router.dart';
import 'package:rider_app/features/auth/services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();

  Future<bool> _handleLogin(String email, String password) async {
    final success = await _authService.login(
      email: email,
      password: password,
    );

    if (!mounted) return success;

    if (success) {
      context.goNamed(AppRouteNames.home);
      return true;
    }

    return false;
  }

  void _handleForgotPassword() {
    context.pushNamed(AppRouteNames.forgotPassword);
  }

  void _handleRegister() {
    context.pushNamed(AppRouteNames.register);
  }

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeModeController?>();
    return UitGoLoginScreen(
      logo: Icon(
        Icons.person,
        size: 56,
        color: Theme.of(context).colorScheme.primary,
        semanticLabel: 'UIT-Go Rider',
      ),
      appName: 'UIT-Go Rider',
      tagline: 'Chào mừng trở lại',
      accentColor: const Color(0xFF7C4DFF),
      onLogin: _handleLogin,
      onForgotPassword: _handleForgotPassword,
      onRegister: _handleRegister,
      themeMode: themeController?.themeMode,
      onToggleTheme: themeController?.toggle,
      registerLabel: 'Đăng ký ngay',
      registerMessage: 'Chưa có tài khoản?',
      loginButtonLabel: 'Đăng nhập',
      forgotPasswordLabel: 'Quên mật khẩu?',
    );
  }
}
