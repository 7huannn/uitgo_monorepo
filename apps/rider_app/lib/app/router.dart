import 'package:flutter/material.dart';
import 'package:rider_app/app/welcome_page.dart';
import 'package:rider_app/features/auth/login_page.dart';
import 'package:rider_app/features/home/home_page.dart';

/// Tất cả route name được gom chung tại đây
class AppRoutes {
  static const String welcome = '/';
  static const String login = '/login';
  static const String home = '/home';
}

/// Factory tạo routes cho MaterialApp
RouteFactory buildRoutes() {
  return (settings) {
    switch (settings.name) {
      case AppRoutes.welcome:
        return MaterialPageRoute(builder: (_) => const WelcomePage());
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const HomePage());
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('404 - Not Found')),
          ),
        );
    }
  };
}
