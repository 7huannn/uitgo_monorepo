// lib/core/config/config.dart
const bool useMock = bool.fromEnvironment('USE_MOCK', defaultValue: true);

const String apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://localhost:8080', // đổi tùy bạn muốn
);
