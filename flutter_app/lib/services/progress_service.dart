import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_progress.dart';
import 'lesson_service.dart';

/// Service for user progress tracking and dashboard data
class ProgressService {
  final Dio _dio;
  final String _baseUrl;
  final String? _authToken;

  ProgressService({
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
        print('Progress API Error: ${error.response?.statusCode} - ${error.message}');
        handler.next(error);
      },
    ));
  }

  /// Track when a user views a lesson
  Future<UserProgress> trackLessonView(String lessonId) async {
    try {
      final response = await _dio.post('/api/v1/progress/lesson/$lessonId/view');

      if (response.statusCode == 200) {
        return UserProgress.fromJson(response.data);
      } else {
        throw ProgressServiceException(
          'Failed to track lesson view: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Track when a user toggles translation view
  Future<UserProgress> trackTranslationToggle(String lessonId) async {
    try {
      final response = await _dio.post('/api/v1/progress/lesson/$lessonId/toggle');

      if (response.statusCode == 200) {
        return UserProgress.fromJson(response.data);
      } else {
        throw ProgressServiceException(
          'Failed to track translation toggle: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Update lesson progress with custom data
  Future<UserProgress> updateLessonProgress(
    String lessonId,
    ProgressUpdateRequest updateData,
  ) async {
    try {
      final response = await _dio.put(
        '/api/v1/progress/lesson/$lessonId',
        data: updateData.toJson(),
      );

      if (response.statusCode == 200) {
        return UserProgress.fromJson(response.data);
      } else {
        throw ProgressServiceException(
          'Failed to update lesson progress: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Record a quiz attempt
  Future<QuizAttempt> recordQuizAttempt(QuizAttemptSubmission attemptData) async {
    try {
      final response = await _dio.post(
        '/api/v1/progress/quiz-attempt',
        data: attemptData.toJson(),
      );

      if (response.statusCode == 200) {
        return QuizAttempt.fromJson(response.data);
      } else {
        throw ProgressServiceException(
          'Failed to record quiz attempt: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Get progress records for the current user
  Future<List<UserProgress>> getUserProgress({String? lessonId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (lessonId != null) {
        queryParams['lesson_id'] = lessonId;
      }

      final response = await _dio.get(
        '/api/v1/progress/lessons',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> progressList = response.data;
        return progressList.map((data) => UserProgress.fromJson(data)).toList();
      } else {
        throw ProgressServiceException(
          'Failed to get user progress: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Get quiz attempts for the current user
  Future<List<QuizAttempt>> getQuizAttempts({String? quizId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (quizId != null) {
        queryParams['quiz_id'] = quizId;
      }

      final response = await _dio.get(
        '/api/v1/progress/quiz-attempts',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> attemptsList = response.data;
        return attemptsList.map((data) => QuizAttempt.fromJson(data)).toList();
      } else {
        throw ProgressServiceException(
          'Failed to get quiz attempts: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Get user profile with aggregated stats
  Future<UserProfile> getUserProfile() async {
    try {
      final response = await _dio.get('/api/v1/profile');

      if (response.statusCode == 200) {
        return UserProfile.fromJson(response.data);
      } else {
        throw ProgressServiceException(
          'Failed to get user profile: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Get dashboard statistics
  Future<DashboardStats> getDashboardStats() async {
    try {
      final response = await _dio.get('/api/v1/dashboard');

      if (response.statusCode == 200) {
        return DashboardStats.fromJson(response.data);
      } else {
        throw ProgressServiceException(
          'Failed to get dashboard stats: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Get learning analytics
  Future<Map<String, dynamic>> getLearningAnalytics({int days = 30}) async {
    try {
      final response = await _dio.get(
        '/api/v1/analytics',
        queryParameters: {'days': days},
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      } else {
        throw ProgressServiceException(
          'Failed to get learning analytics: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  ProgressServiceException _handleDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ProgressServiceException(
          'Connection timeout. Please check your internet connection.',
          isNetworkError: true,
        );
      case DioExceptionType.connectionError:
        return ProgressServiceException(
          'Unable to connect to server. Please try again later.',
          isNetworkError: true,
        );
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = e.response?.data?['detail'] ?? 'Server error occurred';

        if (statusCode == 401) {
          return ProgressServiceException(
            'Authentication failed. Please log in again.',
            statusCode: statusCode,
            isAuthError: true,
          );
        } else if (statusCode == 404) {
          return ProgressServiceException(
            'Resource not found.',
            statusCode: statusCode,
          );
        } else {
          return ProgressServiceException(
            message,
            statusCode: statusCode,
          );
        }
      default:
        return ProgressServiceException(
          'An unexpected error occurred: ${e.message}',
        );
    }
  }
}

/// Exception thrown by ProgressService
class ProgressServiceException implements Exception {
  final String message;
  final int? statusCode;
  final bool isNetworkError;
  final bool isAuthError;

  const ProgressServiceException(
    this.message, {
    this.statusCode,
    this.isNetworkError = false,
    this.isAuthError = false,
  });

  @override
  String toString() => 'ProgressServiceException: $message';
}

/// Riverpod providers for progress service and data

// Progress service provider
final progressServiceProvider = Provider<ProgressService>((ref) {
  final config = ref.watch(apiConfigProvider);
  return ProgressService(
    baseUrl: config['baseUrl']!,
    authToken: config['authToken'],
  );
});

// User profile provider
final userProfileProvider = FutureProvider<UserProfile>((ref) async {
  final service = ref.read(progressServiceProvider);
  return await service.getUserProfile();
});

// Dashboard stats provider
final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final service = ref.read(progressServiceProvider);
  return await service.getDashboardStats();
});

// User progress provider
final userProgressProvider = FutureProvider<List<UserProgress>>((ref) async {
  final service = ref.read(progressServiceProvider);
  return await service.getUserProgress();
});

// Quiz attempts provider
final quizAttemptsProvider = FutureProvider<List<QuizAttempt>>((ref) async {
  final service = ref.read(progressServiceProvider);
  return await service.getQuizAttempts();
});

// Learning analytics provider
final learningAnalyticsProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, days) async {
  final service = ref.read(progressServiceProvider);
  return await service.getLearningAnalytics(days: days);
});

// Progress for specific lesson provider
final lessonProgressProvider = FutureProvider.family<UserProgress?, String>((ref, lessonId) async {
  final service = ref.read(progressServiceProvider);
  final allProgress = await service.getUserProgress(lessonId: lessonId);
  return allProgress.isNotEmpty ? allProgress.first : null;
});

// Completion rate provider
final completionRateProvider = Provider<double>((ref) {
  final progressAsync = ref.watch(userProgressProvider);

  return progressAsync.when(
    data: (progressList) {
      if (progressList.isEmpty) return 0.0;
      final completed = progressList.where((p) => p.isCompleted).length;
      return completed / progressList.length;
    },
    loading: () => 0.0,
    error: (_, __) => 0.0,
  );
});

// Recent activity provider (last 7 days)
final recentActivityProvider = Provider<List<UserProgress>>((ref) {
  final progressAsync = ref.watch(userProgressProvider);

  return progressAsync.when(
    data: (progressList) {
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      return progressList
          .where((p) => p.lastAccessed.isAfter(weekAgo))
          .toList()
        ..sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

// Streak status provider
final streakStatusProvider = Provider<Map<String, dynamic>>((ref) {
  final profileAsync = ref.watch(userProfileProvider);

  return profileAsync.when(
    data: (profile) => {
      'current': profile.currentStreakDays,
      'longest': profile.longestStreakDays,
      'lastActivity': profile.lastActivityDate,
    },
    loading: () => {'current': 0, 'longest': 0, 'lastActivity': null},
    error: (_, __) => {'current': 0, 'longest': 0, 'lastActivity': null},
  );
});