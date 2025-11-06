import 'package:flutter/material.dart';
import 'package:rider_app/app/welcome_page.dart';
import 'package:rider_app/features/auth/pages/login_page.dart';
import 'package:rider_app/features/auth/pages/register_page.dart';
import 'package:rider_app/features/auth/pages/forgot_password_page.dart';
import 'package:rider_app/features/auth/pages/profile_page.dart';
import 'package:rider_app/features/home/home_page.dart';

/// Tất cả route name được gom chung tại đây
class AppRoutes {
  static const String welcome = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String home = '/home';
  static const String profile = '/profile';
}

/// Factory tạo routes cho MaterialApp
RouteFactory buildRoutes() {
  return (settings) {
    switch (settings.name) {
      case AppRoutes.welcome:
        return MaterialPageRoute(builder: (_) => const WelcomePage());
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case AppRoutes.register:
        return MaterialPageRoute(builder: (_) => const RegisterPage());
      case AppRoutes.forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordPage());
      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const HomePage());
      case AppRoutes.profile:
        return MaterialPageRoute(builder: (_) => const ProfilePage());
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('404 - Not Found')),
          ),
        );
    }
  };
}