import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app/app.dart';
import 'core/config/config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (sentryDsn.isEmpty) {
    runApp(const UITApp());
    return;
  }
  await SentryFlutter.init(
    (options) {
      options.dsn = sentryDsn;
      options.tracesSampleRate = 1.0;
    },
    appRunner: () => runApp(const UITApp()),
  );
}
