import 'package:flutter/material.dart';
import 'package:rider_app/app/router.dart';
import 'theme.dart';

class UITApp extends StatelessWidget {
  const UITApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      onGenerateRoute: buildRoutes(),
      // initialRoute mặc định là '/', sẽ mở WelcomePage
    );
  }
}
