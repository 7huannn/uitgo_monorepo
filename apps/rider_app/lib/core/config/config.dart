// lib/core/config/config.dart
const bool useMock = bool.fromEnvironment('USE_MOCK', defaultValue: false);

const String apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://localhost:8080', // đổi tùy bạn muốn
);

const String geocodeBase = String.fromEnvironment(
  'GEOCODE_BASE',
  defaultValue: 'https://photon.komoot.io',
);

const String routingBase = String.fromEnvironment(
  'ROUTING_BASE',
  defaultValue: 'https://router.project-osrm.org',
);

const bool useNominatimFallback =
    bool.fromEnvironment('USE_NOMINATIM', defaultValue: true);

const String sentryDsn = String.fromEnvironment(
  'SENTRY_DSN',
  defaultValue: '',
);
