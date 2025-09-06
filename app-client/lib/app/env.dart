class AppEnv {
  final String baseUrl; // ex: http://localhost:8080
  final String mtxHlsBase; // ex: http://localhost:8888
  const AppEnv({
    required this.baseUrl,
    required this.mtxHlsBase,
  });
}

// Allow overriding via --dart-define for Docker/emulator setups
const defaultEnv = AppEnv(
  baseUrl: String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080'),
  mtxHlsBase: String.fromEnvironment('HLS_BASE_URL', defaultValue: 'http://localhost:8888'),
);
