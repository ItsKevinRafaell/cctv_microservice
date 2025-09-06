class AppConfig {
  final String baseUrl;
  final bool useFake;

  const AppConfig({
    required this.baseUrl,
    this.useFake = true,
  });
}
