abstract class AuthTokenProvider {
  Future<String?> accessToken();
  Future<bool> refreshToken();
}

class GlobalTokenManager {
  static AuthTokenProvider? instance;
}
