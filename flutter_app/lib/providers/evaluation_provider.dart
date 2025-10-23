import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/evaluation_models.dart';
import 'auth_provider.dart';

/// Exception thrown when evaluation service encounters an error
class EvaluationException implements Exception {
  final String message;
  final int? statusCode;
  final String? details;

  const EvaluationException(this.message, {this.statusCode, this.details});

  @override
  String toString() => 'EvaluationException: $message${details != null ? ' - $details' : ''}';
}

/// Service for handling quiz evaluation API calls
class EvaluationService {
  final String baseUrl;
  final http.Client httpClient;

  EvaluationService({
    required this.baseUrl,
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();

  /// Evaluate quiz responses
  Future<EvaluationResponse> evaluateQuizResponses({
    required String token,
    required EvaluationRequest request,
  }) async {
    try {
      final response = await httpClient.post(
        Uri.parse('$baseUrl/api/v1/evaluate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return EvaluationResponse.fromJson(data);
      } else if (response.statusCode == 401) {
        throw const EvaluationException(
          'Authentication failed',
          statusCode: 401,
          details: 'Please check your login status',
        );
      } else if (response.statusCode == 403) {
        throw const EvaluationException(
          'Access denied',
          statusCode: 403,
          details: 'User ID mismatch or insufficient permissions',
        );
      } else if (response.statusCode == 404) {
        throw const EvaluationException(
          'Quiz or lesson not found',
          statusCode: 404,
          details: 'Please check that the quiz and lesson exist',
        );
      } else if (response.statusCode == 429) {
        throw const EvaluationException(
          'Rate limit exceeded',
          statusCode: 429,
          details: 'Please wait before making another request',
        );
      } else {
        final errorData = response.body.isNotEmpty
            ? jsonDecode(response.body) as Map<String, dynamic>?
            : null;
        throw EvaluationException(
          'Failed to evaluate quiz responses',
          statusCode: response.statusCode,
          details: errorData?['detail']?.toString() ?? 'Unknown error occurred',
        );
      }
    } catch (e) {
      if (e is EvaluationException) rethrow;
      throw EvaluationException('Network error: ${e.toString()}');
    }
  }

  /// Get evaluation attempts for a user
  Future<List<AttemptRecord>> getUserAttempts({
    required String token,
    int limit = 50,
  }) async {
    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/api/v1/evaluation/attempts?limit=$limit'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map((item) => AttemptRecord.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw EvaluationException(
          'Failed to get user attempts',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is EvaluationException) rethrow;
      throw EvaluationException('Network error: ${e.toString()}');
    }
  }

  /// Get error statistics for a user
  Future<Map<String, int>> getUserErrorStats({
    required String token,
  }) async {
    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/api/v1/evaluation/errors/stats'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return Map<String, int>.from(data);
      } else {
        throw EvaluationException(
          'Failed to get error statistics',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is EvaluationException) rethrow;
      throw EvaluationException('Network error: ${e.toString()}');
    }
  }

  void dispose() {
    httpClient.close();
  }
}

/// Provider for evaluation service
final evaluationServiceProvider = Provider<EvaluationService>((ref) {
  const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  final service = EvaluationService(baseUrl: baseUrl);

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Provider for quiz evaluation
final quizEvaluationProvider = FutureProvider.family<EvaluationResponse, EvaluationRequest>(
  (ref, request) async {
    final authState = ref.watch(authStateProvider);
    final evaluationService = ref.watch(evaluationServiceProvider);

    return authState.when(
      data: (auth) {
        if (auth.token == null) {
          throw const EvaluationException('User not authenticated');
        }
        return evaluationService.evaluateQuizResponses(
          token: auth.token!,
          request: request,
        );
      },
      loading: () => throw const EvaluationException('Authentication loading'),
      error: (error, _) => throw EvaluationException('Authentication error: $error'),
    );
  },
);

/// Provider for user evaluation attempts
final userAttemptsProvider = FutureProvider.family<List<AttemptRecord>, int>(
  (ref, limit) async {
    final authState = ref.watch(authStateProvider);
    final evaluationService = ref.watch(evaluationServiceProvider);

    return authState.when(
      data: (auth) {
        if (auth.token == null) {
          throw const EvaluationException('User not authenticated');
        }
        return evaluationService.getUserAttempts(
          token: auth.token!,
          limit: limit,
        );
      },
      loading: () => throw const EvaluationException('Authentication loading'),
      error: (error, _) => throw EvaluationException('Authentication error: $error'),
    );
  },
);

/// Provider for user error statistics
final userErrorStatsProvider = FutureProvider<Map<String, int>>(
  (ref) async {
    final authState = ref.watch(authStateProvider);
    final evaluationService = ref.watch(evaluationServiceProvider);

    return authState.when(
      data: (auth) {
        if (auth.token == null) {
          throw const EvaluationException('User not authenticated');
        }
        return evaluationService.getUserErrorStats(token: auth.token!);
      },
      loading: () => throw const EvaluationException('Authentication loading'),
      error: (error, _) => throw EvaluationException('Authentication error: $error'),
    );
  },
);

/// State notifier for managing evaluation state
class EvaluationStateNotifier extends StateNotifier<EvaluationState> {
  final EvaluationService _evaluationService;
  final Ref _ref;

  EvaluationStateNotifier(this._evaluationService, this._ref)
      : super(const EvaluationState.initial());

  /// Submit quiz for evaluation
  Future<EvaluationResponse> submitQuizEvaluation(EvaluationRequest request) async {
    state = const EvaluationState.loading();

    try {
      final authState = _ref.read(authStateProvider).value;
      if (authState?.token == null) {
        throw const EvaluationException('User not authenticated');
      }

      final result = await _evaluationService.evaluateQuizResponses(
        token: authState!.token!,
        request: request,
      );

      state = EvaluationState.success(result);
      return result;
    } catch (e) {
      final error = e is EvaluationException ? e : EvaluationException(e.toString());
      state = EvaluationState.error(error);
      rethrow;
    }
  }

  /// Reset evaluation state
  void reset() {
    state = const EvaluationState.initial();
  }
}

/// Provider for evaluation state notifier
final evaluationStateProvider = StateNotifierProvider<EvaluationStateNotifier, EvaluationState>(
  (ref) {
    final evaluationService = ref.watch(evaluationServiceProvider);
    return EvaluationStateNotifier(evaluationService, ref);
  },
);

/// State class for evaluation operations
class EvaluationState {
  final bool isLoading;
  final EvaluationResponse? result;
  final EvaluationException? error;

  const EvaluationState({
    required this.isLoading,
    this.result,
    this.error,
  });

  const EvaluationState.initial() : this(isLoading: false);
  const EvaluationState.loading() : this(isLoading: true);
  const EvaluationState.success(EvaluationResponse result)
      : this(isLoading: false, result: result);
  const EvaluationState.error(EvaluationException error)
      : this(isLoading: false, error: error);

  bool get hasResult => result != null;
  bool get hasError => error != null;
  bool get isSuccess => !isLoading && hasResult && !hasError;

  @override
  String toString() {
    if (isLoading) return 'EvaluationState.loading';
    if (hasError) return 'EvaluationState.error($error)';
    if (hasResult) return 'EvaluationState.success(score: ${result!.score})';
    return 'EvaluationState.initial';
  }
}

/// Extension methods for evaluation error handling
extension EvaluationErrorExtension on EvaluationException {
  /// Get user-friendly error message
  String get userFriendlyMessage {
    switch (statusCode) {
      case 401:
        return 'Please sign in to continue';
      case 403:
        return 'You don\'t have permission to access this quiz';
      case 404:
        return 'Quiz not found. Please check the quiz exists';
      case 429:
        return 'Too many requests. Please wait a moment';
      case 500:
        return 'Server error. Please try again later';
      default:
        return message;
    }
  }

  /// Check if error is retryable
  bool get isRetryable {
    return statusCode != 403 && statusCode != 404;
  }
}

/// Utility functions for evaluation
class EvaluationUtils {
  /// Create evaluation request from quiz responses
  static EvaluationRequest createRequest({
    required String userId,
    required String lessonId,
    required String quizId,
    required List<Map<String, dynamic>> responses,
  }) {
    return EvaluationRequest(
      userId: userId,
      lessonId: lessonId,
      quizId: quizId,
      responses: responses,
    );
  }

  /// Format score as percentage string
  static String formatScore(double score) {
    return '${(score * 100).round()}%';
  }

  /// Get performance level from score
  static String getPerformanceLevel(double score) {
    if (score >= 0.9) return 'Excellent';
    if (score >= 0.8) return 'Good';
    if (score >= 0.7) return 'Fair';
    if (score >= 0.6) return 'Needs Improvement';
    return 'Poor';
  }

  /// Check if score is passing (≥70%)
  static bool isPassing(double score) => score >= 0.7;

  /// Group errors by type
  static Map<String, List<ErrorFeedback>> groupErrorsByType(List<ErrorFeedback> errors) {
    final groups = <String, List<ErrorFeedback>>{};
    for (final error in errors) {
      groups.putIfAbsent(error.type, () => []).add(error);
    }
    return groups;
  }

  /// Get most common error type
  static String? getMostCommonErrorType(List<ErrorFeedback> errors) {
    if (errors.isEmpty) return null;

    final counts = <String, int>{};
    for (final error in errors) {
      counts[error.type] = (counts[error.type] ?? 0) + 1;
    }

    return counts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }
}