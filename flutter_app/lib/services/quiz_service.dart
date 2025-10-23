import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/quiz.dart';
import 'lesson_service.dart';

/// Service for quiz generation and management
/// Integrates with Story 1.3 backend implementation
class QuizService {
  final Dio _dio;
  final String _baseUrl;
  final String? _authToken;

  QuizService({
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
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 15);

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
        print('Quiz API Error: ${error.response?.statusCode} - ${error.message}');
        handler.next(error);
      },
    ));
  }

  /// Generate a quiz for a specific lesson
  Future<Quiz> generateQuiz({
    required String lessonId,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/quiz',
        data: {
          'lesson_id': lessonId,
        },
      );

      if (response.statusCode == 200) {
        return Quiz.fromJson(response.data);
      } else {
        throw QuizServiceException(
          'Failed to generate quiz: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Get quiz by ID (if backend supports retrieval)
  Future<Quiz?> getQuizById(String quizId) async {
    try {
      final response = await _dio.get('/api/v1/quiz/$quizId');

      if (response.statusCode == 200) {
        return Quiz.fromJson(response.data);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw QuizServiceException(
          'Failed to get quiz: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Submit quiz responses (for future implementation)
  Future<Map<String, dynamic>> submitQuizResponses({
    required String quizId,
    required List<Map<String, dynamic>> responses,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/quiz/$quizId/submit',
        data: {
          'responses': responses,
        },
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw QuizServiceException(
          'Failed to submit quiz: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  QuizServiceException _handleDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return QuizServiceException(
          'Connection timeout. Please check your internet connection.',
          isNetworkError: true,
        );
      case DioExceptionType.connectionError:
        return QuizServiceException(
          'Unable to connect to server. Please try again later.',
          isNetworkError: true,
        );
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = e.response?.data?['detail'] ?? 'Server error occurred';

        if (statusCode == 401) {
          return QuizServiceException(
            'Authentication failed. Please log in again.',
            statusCode: statusCode,
            isAuthError: true,
          );
        } else if (statusCode == 404) {
          return QuizServiceException(
            'Lesson not found. Please ensure the lesson exists.',
            statusCode: statusCode,
          );
        } else if (statusCode == 400) {
          return QuizServiceException(
            'Invalid lesson for quiz generation. Lesson must have both English and Arabic text.',
            statusCode: statusCode,
          );
        } else if (statusCode == 429) {
          return QuizServiceException(
            'Rate limit exceeded. Please try again later.',
            statusCode: statusCode,
            isRateLimitError: true,
          );
        } else {
          return QuizServiceException(
            message,
            statusCode: statusCode,
          );
        }
      default:
        return QuizServiceException(
          'An unexpected error occurred: ${e.message}',
        );
    }
  }
}

/// Exception thrown by QuizService
class QuizServiceException implements Exception {
  final String message;
  final int? statusCode;
  final bool isNetworkError;
  final bool isAuthError;
  final bool isRateLimitError;

  const QuizServiceException(
    this.message, {
    this.statusCode,
    this.isNetworkError = false,
    this.isAuthError = false,
    this.isRateLimitError = false,
  });

  @override
  String toString() => 'QuizServiceException: $message';
}

/// Riverpod providers for quiz service and data

// Quiz service provider
final quizServiceProvider = Provider<QuizService>((ref) {
  final config = ref.watch(apiConfigProvider);
  return QuizService(
    baseUrl: config['baseUrl']!,
    authToken: config['authToken'],
  );
});

// Current quiz provider
final currentQuizProvider = StateProvider<Quiz?>((ref) => null);

// Quiz cache provider for offline support
final quizCacheProvider = StateNotifierProvider<QuizCacheNotifier, Map<String, Quiz>>(
  (ref) => QuizCacheNotifier(),
);

/// Notifier for managing quiz cache
class QuizCacheNotifier extends StateNotifier<Map<String, Quiz>> {
  QuizCacheNotifier() : super({});

  void addQuiz(Quiz quiz) {
    state = {...state, quiz.quizId: quiz};
  }

  void addQuizzes(List<Quiz> quizzes) {
    final newState = Map<String, Quiz>.from(state);
    for (final quiz in quizzes) {
      newState[quiz.quizId] = quiz;
    }
    state = newState;
  }

  Quiz? getQuiz(String quizId) {
    return state[quizId];
  }

  Quiz? getQuizByLessonId(String lessonId) {
    return state.values
        .cast<Quiz?>()
        .firstWhere((quiz) => quiz?.lessonId == lessonId, orElse: () => null);
  }

  List<Quiz> getQuizzesByLessonIds(List<String> lessonIds) {
    return state.values
        .where((quiz) => lessonIds.contains(quiz.lessonId))
        .toList();
  }

  void removeQuiz(String quizId) {
    final newState = Map<String, Quiz>.from(state);
    newState.remove(quizId);
    state = newState;
  }

  void clear() {
    state = {};
  }

  int get cacheSize => state.length;
}

/// Provider for generating quizzes with caching
final quizGeneratorProvider = FutureProvider.family<Quiz, String>((ref, lessonId) async {
  final service = ref.read(quizServiceProvider);
  final cache = ref.read(quizCacheProvider.notifier);

  try {
    // Check cache first
    final cachedQuiz = cache.getQuizByLessonId(lessonId);
    if (cachedQuiz != null) {
      return cachedQuiz;
    }

    // Generate new quiz
    final quiz = await service.generateQuiz(lessonId: lessonId);

    // Cache the generated quiz
    cache.addQuiz(quiz);

    // Set as current quiz
    ref.read(currentQuizProvider.notifier).state = quiz;

    return quiz;
  } catch (e) {
    // Re-throw for error handling in UI
    rethrow;
  }
});

/// Provider for quiz by lesson ID
final quizByLessonProvider = FutureProvider.family<Quiz?, String>((ref, lessonId) async {
  final service = ref.read(quizServiceProvider);
  final cache = ref.read(quizCacheProvider.notifier);

  try {
    // Check cache first
    final cachedQuiz = cache.getQuizByLessonId(lessonId);
    if (cachedQuiz != null) {
      return cachedQuiz;
    }

    // Try to generate quiz for lesson
    final quiz = await service.generateQuiz(lessonId: lessonId);
    cache.addQuiz(quiz);
    return quiz;
  } catch (e) {
    // Return null if quiz cannot be generated
    return null;
  }
});

/// Quiz validation provider
final quizValidationProvider = Provider.family<bool, Quiz>((ref, quiz) {
  return quiz.isValid && quiz.questionCount >= 3;
});

/// Quiz difficulty provider
final quizDifficultyProvider = Provider.family<String, Quiz>((ref, quiz) {
  final questionTypes = quiz.questionTypes;

  if (questionTypes.length == 1) {
    return 'Easy';
  } else if (questionTypes.length == 2) {
    return 'Medium';
  } else {
    return 'Hard';
  }
});

/// Request model for quiz generation
class QuizRequest {
  final String lessonId;

  const QuizRequest({
    required this.lessonId,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QuizRequest && other.lessonId == lessonId;
  }

  @override
  int get hashCode => lessonId.hashCode;
}