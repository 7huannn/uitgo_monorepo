import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rider_app/app/welcome_page.dart';
import 'package:rider_app/features/auth/pages/forgot_password_page.dart';
import 'package:rider_app/features/auth/pages/login_page.dart';
import 'package:rider_app/features/auth/pages/profile_page.dart';
import 'package:rider_app/features/auth/pages/register_page.dart';
import 'package:rider_app/features/help/pages/help_page.dart';
import 'package:rider_app/features/home/home_page.dart';
import 'package:rider_app/features/trip/models/trip_models.dart';
import 'package:rider_app/features/notifications/pages/notifications_page.dart';
import 'package:rider_app/features/payments/pages/payment_methods_page.dart';
import 'package:rider_app/features/places/pages/saved_places_page.dart';
import 'package:rider_app/features/settings/pages/settings_page.dart';
import 'package:rider_app/features/trip/pages/trip_history_page.dart';
import 'package:rider_app/features/trip/pages/trip_tracking_page.dart';

class AppRouteNames {
  static const welcome = 'welcome';
  static const login = 'login';
  static const register = 'register';
  static const forgotPassword = 'forgot-password';
  static const home = 'home';
  static const profile = 'profile';
  static const tripHistory = 'trip-history';
  static const payments = 'payments';
  static const savedPlaces = 'saved-places';
  static const settings = 'settings';
  static const help = 'help';
  static const notifications = 'notifications';
  static const tripTracking = 'trip-tracking';
}

class AppRoutePaths {
  static const welcome = '/';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const home = '/home';
  static const profile = '/profile';
  static const tripHistory = '/trip-history';
  static const payments = '/payments';
  static const savedPlaces = '/saved-places';
  static const settings = '/settings';
  static const help = '/help';
  static const notifications = '/notifications';
  static const tripTracking = '/trips/:id/live';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutePaths.welcome,
  routes: [
    GoRoute(
      name: AppRouteNames.welcome,
      path: AppRoutePaths.welcome,
      builder: (context, state) => const WelcomePage(),
    ),
    GoRoute(
      name: AppRouteNames.login,
      path: AppRoutePaths.login,
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      name: AppRouteNames.register,
      path: AppRoutePaths.register,
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      name: AppRouteNames.forgotPassword,
      path: AppRoutePaths.forgotPassword,
      builder: (context, state) => const ForgotPasswordPage(),
    ),
    GoRoute(
      name: AppRouteNames.home,
      path: AppRoutePaths.home,
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      name: AppRouteNames.profile,
      path: AppRoutePaths.profile,
      builder: (context, state) => const ProfilePage(),
    ),
    GoRoute(
      name: AppRouteNames.tripHistory,
      path: AppRoutePaths.tripHistory,
      builder: (context, state) => const TripHistoryPage(),
    ),
    GoRoute(
      name: AppRouteNames.tripTracking,
      path: AppRoutePaths.tripTracking,
      builder: (context, state) {
        final tripId = state.pathParameters['id']!;
        final extra = state.extra;
        TripDetail? trip;
        if (extra is TripDetail) {
          trip = extra;
        }
        return TripTrackingPage(
          tripId: tripId,
          initialTrip: trip,
        );
      },
    ),
    GoRoute(
      name: AppRouteNames.payments,
      path: AppRoutePaths.payments,
      builder: (context, state) => const PaymentMethodsPage(),
    ),
    GoRoute(
      name: AppRouteNames.savedPlaces,
      path: AppRoutePaths.savedPlaces,
      builder: (context, state) => const SavedPlacesPage(),
    ),
    GoRoute(
      name: AppRouteNames.settings,
      path: AppRoutePaths.settings,
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      name: AppRouteNames.help,
      path: AppRoutePaths.help,
      builder: (context, state) => const HelpPage(),
    ),
    GoRoute(
      name: AppRouteNames.notifications,
      path: AppRoutePaths.notifications,
      builder: (context, state) => const NotificationsPage(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text(
        state.error?.toString() ?? 'Trang không tồn tại',
        textAlign: TextAlign.center,
      ),
    ),
  ),
);
