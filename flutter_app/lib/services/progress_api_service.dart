import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/progress_models.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';

/// Service for handling progress-related API calls
class ProgressApiService {
  final http.Client _client;
  final String _baseUrl;

  ProgressApiService({
    http.Client? client,
    String? baseUrl,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  /// Get user progress analytics
  Future<ProgressResponse> getUserProgress(String userId, int daysBack) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw ProgressApiException('User not authenticated');
      }

      final uri = Uri.parse('$_baseUrl/api/v1/progress').replace(
        queryParameters: {
          'user_id': userId,
          'days_back': daysBack.toString(),
        },
      );

      final response = await _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw ProgressApiException('Request timeout'),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return ProgressResponse.fromJson(jsonData);
      } else if (response.statusCode == 401) {
        throw ProgressApiException('Authentication failed', isAuthError: true);
      } else if (response.statusCode == 403) {
        throw ProgressApiException('Access denied');
      } else if (response.statusCode == 404) {
        throw ProgressApiException('Progress data not found');
      } else if (response.statusCode == 429) {
        throw ProgressApiException('Too many requests. Please try again later.');
      } else {
        final errorMessage = _parseErrorMessage(response.body);
        throw ProgressApiException(
          'Failed to fetch progress data: $errorMessage',
          statusCode: response.statusCode,
        );
      }
    } on SocketException {
      throw ProgressApiException('No internet connection');
    } on FormatException {
      throw ProgressApiException('Invalid response format');
    } on ProgressApiException {
      rethrow;
    } catch (e) {
      throw ProgressApiException('Unexpected error: ${e.toString()}');
    }
  }

  /// Update progress data (for future use)
  Future<void> updateUserProgress(String userId, ProgressRequest request) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw ProgressApiException('User not authenticated');
      }

      final uri = Uri.parse('$_baseUrl/api/v1/progress');
      final response = await _client.put(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(request.toJson()),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw ProgressApiException('Request timeout'),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      } else if (response.statusCode == 401) {
        throw ProgressApiException('Authentication failed', isAuthError: true);
      } else if (response.statusCode == 403) {
        throw ProgressApiException('Access denied');
      } else {
        final errorMessage = _parseErrorMessage(response.body);
        throw ProgressApiException(
          'Failed to update progress: $errorMessage',
          statusCode: response.statusCode,
        );
      }
    } on SocketException {
      throw ProgressApiException('No internet connection');
    } on ProgressApiException {
      rethrow;
    } catch (e) {
      throw ProgressApiException('Unexpected error: ${e.toString()}');
    }
  }

  /// Check service health
  Future<bool> checkHealth() async {
    try {
      final uri = Uri.parse('$_baseUrl/health');
      final response = await _client.get(uri).timeout(
        const Duration(seconds: 10),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Parse error message from response body
  String _parseErrorMessage(String responseBody) {
    try {
      final jsonData = json.decode(responseBody) as Map<String, dynamic>;
      return jsonData['detail']?.toString() ??
             jsonData['message']?.toString() ??
             'Unknown error';
    } catch (e) {
      return 'Unknown error';
    }
  }

  /// Dispose of resources
  void dispose() {
    _client.close();
  }
}

/// Custom exception for progress API errors
class ProgressApiException implements Exception {
  final String message;
  final int? statusCode;
  final bool isAuthError;
  final bool isNetworkError;

  const ProgressApiException(
    this.message, {
    this.statusCode,
    this.isAuthError = false,
    this.isNetworkError = false,
  });

  @override
  String toString() => 'ProgressApiException: $message';

  /// Check if this is a recoverable error
  bool get isRecoverable {
    if (isAuthError) return false;
    if (statusCode == null) return true;

    // Recoverable status codes
    return [408, 429, 500, 502, 503, 504].contains(statusCode);
  }

  /// Get user-friendly error message
  String get userMessage {
    if (isNetworkError || message.contains('internet') || message.contains('network')) {
      return 'Please check your internet connection and try again.';
    }

    if (isAuthError) {
      return 'Please log in again to continue.';
    }

    switch (statusCode) {
      case 400:
        return 'Invalid request. Please try again.';
      case 403:
        return 'You don\'t have permission to access this data.';
      case 404:
        return 'Progress data not found.';
      case 429:
        return 'Too many requests. Please wait a moment and try again.';
      case 500:
      case 502:
      case 503:
      case 504:
        return 'Server error. Please try again later.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}

/// Mock service for testing and development
class MockProgressApiService implements ProgressApiService {
  @override
  final http.Client _client = http.Client();

  @override
  final String _baseUrl = 'http://localhost:8000';

  /// Mock delay to simulate network latency
  static const Duration _mockDelay = Duration(milliseconds: 800);

  @override
  Future<ProgressResponse> getUserProgress(String userId, int daysBack) async {
    await Future.delayed(_mockDelay);

    // Simulate different scenarios based on userId
    if (userId == 'error_user') {
      throw ProgressApiException('Simulated error');
    }

    if (userId == 'no_data_user') {
      return const ProgressResponse(
        weekly: ProgressMetrics(
          accuracy: 0.0,
          timeMinutes: 0,
          errorBreakdown: {},
          lessonsCompleted: 0,
          streakDays: 0,
          improvementRate: 0.0,
        ),
        trends: [],
        improvementAreas: [],
      );
    }

    // Return mock data
    return _generateMockProgress(daysBack);
  }

  @override
  Future<void> updateUserProgress(String userId, ProgressRequest request) async {
    await Future.delayed(_mockDelay);
    // Mock implementation - no-op
  }

  @override
  Future<bool> checkHealth() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return true;
  }

  @override
  void dispose() {
    _client.close();
  }

  /// Generate mock progress data
  ProgressResponse _generateMockProgress(int daysBack) {
    final now = DateTime.now();
    final trends = List.generate(daysBack, (index) {
      final date = now.subtract(Duration(days: daysBack - index - 1));
      final accuracy = 0.7 + (index / daysBack) * 0.2 + (DateTime.now().millisecond % 100) / 1000;
      final timeMinutes = 20 + (index % 5) * 10;

      return TrendPoint(
        date: date.toIso8601String().split('T')[0],
        accuracy: accuracy.clamp(0.0, 1.0),
        timeMinutes: timeMinutes,
      );
    });

    final errorBreakdown = {
      'SPELL_T': 5,
      'EN_IN_AR': 3,
      'VOCAB': 2,
      'GRAMMAR': 1,
    };

    final improvementAreas = ['SPELL_T', 'EN_IN_AR'];

    return ProgressResponse(
      weekly: ProgressMetrics(
        accuracy: trends.isNotEmpty ? trends.last.accuracy : 0.8,
        timeMinutes: trends.fold(0, (sum, trend) => sum + trend.timeMinutes),
        errorBreakdown: errorBreakdown,
        lessonsCompleted: (daysBack / 2).round(),
        streakDays: 5,
        improvementRate: 0.15,
      ),
      trends: trends,
      improvementAreas: improvementAreas,
    );
  }
}