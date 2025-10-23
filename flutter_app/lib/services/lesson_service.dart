import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lesson.dart';

/// Service for fetching lesson data from backend API
/// Integrates with Story 1.1 backend implementation
class LessonService {
  final Dio _dio;
  final String _baseUrl;
  final String? _authToken;

  LessonService({
    required String baseUrl,
    String? authToken,
    Dio? dio,
  }) : _baseUrl = baseUrl,
       _authToken = authToken,
       _dio = dio ?? Dio() {
    _setupDio();
  }

  void _setupDio() {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);

    // Add auth interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_authToken != null) {
          options.headers['Authorization'] = 'Bearer $_authToken';
        }
        options.headers['Content-Type'] = 'application/json';
        handler.next(options);
      },
      onError: (error, handler) {
        // Log error for debugging
        print('API Error: ${error.response?.statusCode} - ${error.message}');
        handler.next(error);
      },
    ));
  }

  /// Generate a new story lesson
  Future<Lesson> generateStory({
    required String topic,
    required String level,
    int? seed,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/story',
        data: {
          'topic': topic,
          'level': level,
          if (seed != null) 'seed': seed,
        },
      );

      if (response.statusCode == 200) {
        return Lesson.fromJson(response.data);
      } else {
        throw LessonServiceException(
          'Failed to generate story: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Get lesson by ID (if backend supports retrieval)
  Future<Lesson?> getLessonById(String lessonId) async {
    try {
      final response = await _dio.get('/api/v1/lessons/$lessonId');

      if (response.statusCode == 200) {
        return Lesson.fromJson(response.data);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw LessonServiceException(
          'Failed to get lesson: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Get lessons by topic and level
  Future<List<Lesson>> getLessonsByTopicLevel({
    required String topic,
    required String level,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        '/api/v1/lessons',
        queryParameters: {
          'topic': topic,
          'level': level,
          'limit': limit,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> lessonsData = response.data['lessons'] ?? [];
        return lessonsData.map((json) => Lesson.fromJson(json)).toList();
      } else {
        throw LessonServiceException(
          'Failed to get lessons: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Check API health
  Future<bool> checkHealth() async {
    try {
      final response = await _dio.get('/api/v1/health');
      return response.statusCode == 200;
    } on DioException {
      return false;
    }
  }

  LessonServiceException _handleDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return LessonServiceException(
          'Connection timeout. Please check your internet connection.',
          isNetworkError: true,
        );
      case DioExceptionType.connectionError:
        return LessonServiceException(
          'Unable to connect to server. Please try again later.',
          isNetworkError: true,
        );
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = e.response?.data?['detail'] ?? 'Server error occurred';

        if (statusCode == 401) {
          return LessonServiceException(
            'Authentication failed. Please log in again.',
            statusCode: statusCode,
            isAuthError: true,
          );
        } else if (statusCode == 429) {
          return LessonServiceException(
            'Rate limit exceeded. Please try again later.',
            statusCode: statusCode,
            isRateLimitError: true,
          );
        } else {
          return LessonServiceException(
            message,
            statusCode: statusCode,
          );
        }
      default:
        return LessonServiceException(
          'An unexpected error occurred: ${e.message}',
        );
    }
  }
}

/// Exception thrown by LessonService
class LessonServiceException implements Exception {
  final String message;
  final int? statusCode;
  final bool isNetworkError;
  final bool isAuthError;
  final bool isRateLimitError;

  const LessonServiceException(
    this.message, {
    this.statusCode,
    this.isNetworkError = false,
    this.isAuthError = false,
    this.isRateLimitError = false,
  });

  @override
  String toString() => 'LessonServiceException: $message';
}

/// Riverpod providers for lesson service and data

// Configuration provider
final apiConfigProvider = Provider<Map<String, String>>((ref) {
  return {
    'baseUrl': 'http://localhost:8000', // Default for development
    'authToken': '', // Should be provided by auth provider
  };
});

// Lesson service provider
final lessonServiceProvider = Provider<LessonService>((ref) {
  final config = ref.watch(apiConfigProvider);
  return LessonService(
    baseUrl: config['baseUrl']!,
    authToken: config['authToken'],
  );
});

// Current lesson provider
final currentLessonProvider = StateProvider<Lesson?>((ref) => null);

// Lesson cache provider for offline support
final lessonCacheProvider = StateNotifierProvider<LessonCacheNotifier, Map<String, Lesson>>(
  (ref) => LessonCacheNotifier(),
);

/// Notifier for managing lesson cache
class LessonCacheNotifier extends StateNotifier<Map<String, Lesson>> {
  LessonCacheNotifier() : super({});

  void addLesson(Lesson lesson) {
    state = {...state, lesson.lessonId: lesson};
  }

  void addLessons(List<Lesson> lessons) {
    final newState = Map<String, Lesson>.from(state);
    for (final lesson in lessons) {
      newState[lesson.lessonId] = lesson;
    }
    state = newState;
  }

  Lesson? getLesson(String lessonId) {
    return state[lessonId];
  }

  List<Lesson> getLessonsByTopic(String topic) {
    return state.values.where((lesson) => lesson.topic == topic).toList();
  }

  void removeLesson(String lessonId) {
    final newState = Map<String, Lesson>.from(state);
    newState.remove(lessonId);
    state = newState;
  }

  void clear() {
    state = {};
  }

  int get cacheSize => state.length;
}

/// Provider for generating stories with caching
final storyGeneratorProvider = FutureProvider.family<Lesson, StoryRequest>((ref, request) async {
  final service = ref.read(lessonServiceProvider);
  final cache = ref.read(lessonCacheProvider.notifier);

  try {
    final lesson = await service.generateStory(
      topic: request.topic,
      level: request.level,
      seed: request.seed,
    );

    // Cache the generated lesson
    cache.addLesson(lesson);

    // Set as current lesson
    ref.read(currentLessonProvider.notifier).state = lesson;

    return lesson;
  } catch (e) {
    // Re-throw for error handling in UI
    rethrow;
  }
});

/// Provider for fetching lessons by topic/level
final lessonsProvider = FutureProvider.family<List<Lesson>, LessonQuery>((ref, query) async {
  final service = ref.read(lessonServiceProvider);
  final cache = ref.read(lessonCacheProvider.notifier);

  try {
    final lessons = await service.getLessonsByTopicLevel(
      topic: query.topic,
      level: query.level,
      limit: query.limit,
    );

    // Cache the fetched lessons
    cache.addLessons(lessons);

    return lessons;
  } catch (e) {
    // Fallback to cached lessons if available
    final cachedLessons = cache.getLessonsByTopic(query.topic);
    if (cachedLessons.isNotEmpty) {
      return cachedLessons;
    }
    rethrow;
  }
});

/// API health check provider
final apiHealthProvider = FutureProvider<bool>((ref) async {
  final service = ref.read(lessonServiceProvider);
  return service.checkHealth();
});

/// Request model for story generation
class StoryRequest {
  final String topic;
  final String level;
  final int? seed;

  const StoryRequest({
    required this.topic,
    required this.level,
    this.seed,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StoryRequest &&
        other.topic == topic &&
        other.level == level &&
        other.seed == seed;
  }

  @override
  int get hashCode => Object.hash(topic, level, seed);
}

/// Query model for lesson fetching
class LessonQuery {
  final String topic;
  final String level;
  final int limit;

  const LessonQuery({
    required this.topic,
    required this.level,
    this.limit = 20,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LessonQuery &&
        other.topic == topic &&
        other.level == level &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(topic, level, limit);
}