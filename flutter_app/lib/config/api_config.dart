/// API configuration constants
class ApiConfig {
  /// Base URL for the API
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  /// API version
  static const String apiVersion = 'v1';

  /// Request timeout duration
  static const Duration timeout = Duration(seconds: 30);

  /// Retry configuration
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 1);

  /// API endpoints
  static const String lessonsEndpoint = '/api/v1/story';
  static const String quizEndpoint = '/api/v1/quiz';
  static const String progressEndpoint = '/api/v1/progress';
  static const String evaluateEndpoint = '/api/v1/evaluate';
  static const String healthEndpoint = '/health';

  /// Authentication configuration
  static const String tokenStorageKey = 'auth_token';
  static const String userIdStorageKey = 'user_id';

  /// Cache configuration
  static const Duration cacheExpiration = Duration(minutes: 30);

  /// Debug mode
  static const bool isDebugMode = bool.fromEnvironment('DEBUG', defaultValue: false);

  /// Full API URLs
  static String get lessonsUrl => '$baseUrl$lessonsEndpoint';
  static String get quizUrl => '$baseUrl$quizEndpoint';
  static String get progressUrl => '$baseUrl$progressEndpoint';
  static String get evaluateUrl => '$baseUrl$evaluateEndpoint';
  static String get healthUrl => '$baseUrl$healthEndpoint';
}