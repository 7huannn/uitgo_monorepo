import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_app/app/router.dart';
import 'package:rider_app/app/theme.dart';

void main() {
  runApp(const UITApp());
}

class UITApp extends StatelessWidget {
  const UITApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeModeController(initialMode: ThemeMode.system),
      child: const _AppView(),
    );
  }
}

class _AppView extends StatelessWidget {
  const _AppView();

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeModeController>();

    return MaterialApp.router(
      title: 'UIT-Go Rider',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeController.themeMode,
      routerConfig: appRouter,
    );
  }
}
