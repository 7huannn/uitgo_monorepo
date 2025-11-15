import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/auth/controllers/auth_controller.dart';
import '../features/auth/pages/login_page.dart';
import '../features/auth/services/auth_service.dart';
import '../features/driver/services/driver_service.dart';
import '../features/home/controllers/driver_home_controller.dart';
import '../features/home/pages/home_page.dart';
import '../features/trips/services/trip_service.dart';
import 'theme.dart';

final GlobalKey<NavigatorState> driverNavigatorKey =
    GlobalKey<NavigatorState>();

class DriverApp extends StatelessWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeModeController(initialMode: ThemeMode.system),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthController(AuthService())..bootstrap(),
        ),
        ChangeNotifierProvider(
          create: (_) => DriverHomeController(
            DriverService(),
            TripService(),
          ),
        ),
      ],
      child: Consumer<ThemeModeController>(
        builder: (_, themeController, __) => MaterialApp(
          navigatorKey: driverNavigatorKey,
          title: 'UIT-Go Driver',
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: themeController.themeMode,
          home: const _AuthGate(),
        ),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (auth.initializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return auth.loggedIn ? const HomePage() : const LoginPage();
  }
}
