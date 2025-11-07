import 'package:flutter/material.dart';
import 'package:rider_app/app/router.dart';
import 'package:rider_app/app/theme.dart'; // Import theme

void main() {
  runApp(const UITApp());
}

class UITApp extends StatelessWidget {
  const UITApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'UIT-Go Rider',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      themeMode: ThemeMode.light,
      routerConfig: appRouter,
    );
  }
}
