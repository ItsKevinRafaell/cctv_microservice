class AppEnv {
  final String baseUrl; // ex: http://localhost:8080
  final String mtxHlsBase; // ex: http://localhost:8888
  const AppEnv({
    required this.baseUrl,
    required this.mtxHlsBase,
  });
}

const defaultEnv = AppEnv(
  baseUrl: 'http://localhost:8080',
  mtxHlsBase: 'http://localhost:8888',
);
