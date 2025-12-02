import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/auth/controllers/auth_controller.dart';
import '../features/auth/pages/login_page.dart';
import '../features/auth/services/auth_service.dart';
import '../features/driver/services/driver_service.dart';
import '../features/home/controllers/driver_home_controller.dart';
import '../features/home/pages/home_page.dart';
import '../features/profile/controllers/driver_profile_controller.dart';
import '../features/profile/pages/profile_page.dart';
import '../features/trips/services/trip_service.dart';
import '../features/trip_detail/pages/trip_detail_page.dart';
import '../features/trips/pages/trip_history_page.dart';
import '../features/wallet/controllers/wallet_controller.dart';
import '../features/wallet/pages/wallet_overview_page.dart';
import '../features/wallet/pages/wallet_route_args.dart';
import '../features/wallet/pages/wallet_transaction_detail_page.dart';
import '../features/wallet/pages/wallet_transactions_page.dart';
import '../features/wallet/services/wallet_service.dart';
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
          initialRoute: '/',
          onGenerateRoute: _onGenerateRoute,
        ),
      ),
    );
  }
}

Route<dynamic> _onGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case '/':
      return MaterialPageRoute(
        builder: (_) => const _AuthGate(),
        settings: settings,
      );
    case HomePage.routeName:
      return MaterialPageRoute(
        builder: (_) => const HomePage(),
        settings: settings,
      );
    case TripDetailPage.routeName:
      final args = settings.arguments;
      if (args is TripDetailPageArgs) {
        return MaterialPageRoute(
          builder: (_) => TripDetailPage(tripId: args.tripId),
          settings: settings,
        );
      }
      if (args is String && args.isNotEmpty) {
        return MaterialPageRoute(
          builder: (_) => TripDetailPage(tripId: args),
          settings: settings,
        );
      }
      return MaterialPageRoute(
        builder: (_) => const _MissingTripIdPage(),
        settings: settings,
      );
    case TripHistoryPage.routeName:
      return MaterialPageRoute(
        builder: (_) => const TripHistoryPage(),
        settings: settings,
      );
    case DriverProfilePage.routeName:
      return MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => DriverProfileController(DriverService())..bootstrap(),
          child: const DriverProfilePage(),
        ),
        settings: settings,
      );
    case WalletOverviewPage.routeName:
      return MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => WalletController(WalletService())..bootstrap(),
          child: const WalletOverviewPage(),
        ),
        settings: settings,
      );
    case WalletTransactionsPage.routeName:
      final args = settings.arguments;
      WalletController? controller;
      if (args is WalletRouteControllerArgs) {
        controller = args.controller;
      }
      return MaterialPageRoute(
        builder: (_) {
          if (controller != null) {
            return ChangeNotifierProvider<WalletController>.value(
              value: controller,
              child: const WalletTransactionsPage(),
            );
          }
          return ChangeNotifierProvider(
            create: (_) => WalletController(WalletService())..bootstrap(),
            child: const WalletTransactionsPage(),
          );
        },
        settings: settings,
      );
    case WalletTransactionDetailPage.routeName:
      final args = settings.arguments;
      if (args is WalletTransactionDetailArgs) {
        return MaterialPageRoute(
          builder: (_) => WalletTransactionDetailPage(
            transaction: args.transaction,
          ),
          settings: settings,
        );
      }
      return MaterialPageRoute(
        builder: (_) => const _MissingWalletTransactionPage(),
        settings: settings,
      );
    default:
      return MaterialPageRoute(
        builder: (_) => const _AuthGate(),
        settings: settings,
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

class _MissingTripIdPage extends StatelessWidget {
  const _MissingTripIdPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Không tìm thấy mã chuyến để hiển thị.'),
      ),
    );
  }
}

class _MissingWalletTransactionPage extends StatelessWidget {
  const _MissingWalletTransactionPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Không tìm thấy thông tin giao dịch.'),
      ),
    );
  }
}
