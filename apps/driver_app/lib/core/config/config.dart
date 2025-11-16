const bool useMock = bool.fromEnvironment('USE_MOCK', defaultValue: false);

const String apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://localhost:8080',
);

const String sentryDsn = String.fromEnvironment(
  'SENTRY_DSN',
  defaultValue: '',
);
