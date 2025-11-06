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
    return MaterialApp(
      title: 'UIT-Go Rider',
      debugShowCheckedModeBanner: false,

      // Theme sáng
      theme: buildLightTheme(),

      // Force light mode (không dùng dark mode)
      themeMode: ThemeMode.light,

      // Định nghĩa route
      onGenerateRoute: buildRoutes(),

      // Mở mặc định trang welcome
      initialRoute: AppRoutes.welcome,
    );
  }
}
