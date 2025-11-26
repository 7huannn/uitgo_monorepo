const bool useMock = bool.fromEnvironment('USE_MOCK', defaultValue: false);

const String apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://localhost:8080',
);

const String routingBase = String.fromEnvironment(
  'ROUTING_BASE',
  defaultValue: 'https://router.project-osrm.org',
);

const String routesEndpoint = String.fromEnvironment(
  'ROUTES_ENDPOINT',
  defaultValue: '/routes',
);

const String sentryDsn = String.fromEnvironment(
  'SENTRY_DSN',
  defaultValue: '',
);
