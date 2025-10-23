/// Error feedback for a specific token or phrase
class ErrorFeedback {
  final String type;
  final String token;
  final String? hint;

  const ErrorFeedback({
    required this.type,
    required this.token,
    this.hint,
  });

  factory ErrorFeedback.fromJson(Map<String, dynamic> json) {
    return ErrorFeedback(
      type: json['type'] as String,
      token: json['token'] as String,
      hint: json['hint'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'token': token,
      'hint': hint,
    };
  }

  @override
  String toString() => 'ErrorFeedback(type: $type, token: $token, hint: $hint)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ErrorFeedback &&
        other.type == type &&
        other.token == token &&
        other.hint == hint;
  }

  @override
  int get hashCode => Object.hash(type, token, hint);
}

/// Feedback for a single quiz question
class QuestionFeedback {
  final int qIndex;
  final bool isCorrect;
  final List<ErrorFeedback> errors;
  final String? suggestion;

  const QuestionFeedback({
    required this.qIndex,
    required this.isCorrect,
    required this.errors,
    this.suggestion,
  });

  factory QuestionFeedback.fromJson(Map<String, dynamic> json) {
    return QuestionFeedback(
      qIndex: json['q_index'] as int,
      isCorrect: json['ok'] as bool,
      errors: (json['errors'] as List<dynamic>)
          .map((e) => ErrorFeedback.fromJson(e as Map<String, dynamic>))
          .toList(),
      suggestion: json['suggestion'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'q_index': qIndex,
      'ok': isCorrect,
      'errors': errors.map((e) => e.toJson()).toList(),
      'suggestion': suggestion,
    };
  }

  /// Get the most severe error type for prioritization
  String? get mostSevereErrorType {
    if (errors.isEmpty) return null;

    // Priority order: EN_IN_AR > SPELL_T > GRAMMAR > VOCAB > OMISSION/EXTRA
    const priorityOrder = [
      'EN_IN_AR',
      'SPELL_T',
      'GRAMMAR',
      'VOCAB',
      'OMISSION',
      'EXTRA'
    ];

    for (final type in priorityOrder) {
      if (errors.any((error) => error.type.toUpperCase() == type)) {
        return type;
      }
    }

    return errors.first.type;
  }

  /// Get count of errors by type
  Map<String, int> get errorCounts {
    final counts = <String, int>{};
    for (final error in errors) {
      counts[error.type] = (counts[error.type] ?? 0) + 1;
    }
    return counts;
  }

  @override
  String toString() =>
      'QuestionFeedback(qIndex: $qIndex, isCorrect: $isCorrect, errors: $errors, suggestion: $suggestion)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QuestionFeedback &&
        other.qIndex == qIndex &&
        other.isCorrect == isCorrect &&
        _listEquals(other.errors, errors) &&
        other.suggestion == suggestion;
  }

  @override
  int get hashCode => Object.hash(qIndex, isCorrect, errors, suggestion);
}

/// Request for quiz evaluation
class EvaluationRequest {
  final String userId;
  final String lessonId;
  final String quizId;
  final List<Map<String, dynamic>> responses;

  const EvaluationRequest({
    required this.userId,
    required this.lessonId,
    required this.quizId,
    required this.responses,
  });

  factory EvaluationRequest.fromJson(Map<String, dynamic> json) {
    return EvaluationRequest(
      userId: json['user_id'] as String,
      lessonId: json['lesson_id'] as String,
      quizId: json['quiz_id'] as String,
      responses: (json['responses'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'lesson_id': lessonId,
      'quiz_id': quizId,
      'responses': responses,
    };
  }

  @override
  String toString() =>
      'EvaluationRequest(userId: $userId, lessonId: $lessonId, quizId: $quizId, responses: $responses)';
}

/// Response from quiz evaluation
class EvaluationResponse {
  final String attemptId;
  final double score;
  final List<QuestionFeedback> feedback;

  const EvaluationResponse({
    required this.attemptId,
    required this.score,
    required this.feedback,
  });

  factory EvaluationResponse.fromJson(Map<String, dynamic> json) {
    return EvaluationResponse(
      attemptId: json['attempt_id'] as String,
      score: (json['score'] as num).toDouble(),
      feedback: (json['feedback'] as List<dynamic>)
          .map((e) => QuestionFeedback.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'attempt_id': attemptId,
      'score': score,
      'feedback': feedback.map((f) => f.toJson()).toList(),
    };
  }

  /// Get percentage score (0-100)
  int get percentageScore => (score * 100).round();

  /// Get total number of questions
  int get totalQuestions => feedback.length;

  /// Get number of correct answers
  int get correctAnswers => feedback.where((f) => f.isCorrect).length;

  /// Get number of incorrect answers
  int get incorrectAnswers => feedback.where((f) => !f.isCorrect).length;

  /// Get all errors across all questions
  List<ErrorFeedback> get allErrors =>
      feedback.expand((f) => f.errors).toList();

  /// Get error statistics by type
  Map<String, int> get errorStatsByType {
    final stats = <String, int>{};
    for (final error in allErrors) {
      stats[error.type] = (stats[error.type] ?? 0) + 1;
    }
    return stats;
  }

  /// Get performance grade based on score
  String get performanceGrade {
    if (score >= 0.9) return 'A';
    if (score >= 0.8) return 'B';
    if (score >= 0.7) return 'C';
    if (score >= 0.6) return 'D';
    return 'F';
  }

  /// Check if this is a passing score
  bool get isPassing => score >= 0.7;

  /// Get encouraging message based on performance
  String get encouragementMessage {
    if (score >= 0.9) {
      return 'Excellent work! Your Lebanese Arabic skills are really developing.';
    } else if (score >= 0.8) {
      return 'Great job! You\'re making good progress.';
    } else if (score >= 0.7) {
      return 'Good effort! Keep practicing to improve further.';
    } else if (score >= 0.5) {
      return 'You\'re learning! Review the feedback and try again.';
    } else {
      return 'Keep going! Every mistake is a step toward improvement.';
    }
  }

  @override
  String toString() =>
      'EvaluationResponse(attemptId: $attemptId, score: $score, feedback: $feedback)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EvaluationResponse &&
        other.attemptId == attemptId &&
        other.score == score &&
        _listEquals(other.feedback, feedback);
  }

  @override
  int get hashCode => Object.hash(attemptId, score, feedback);
}

/// Attempt record for tracking evaluation history
class AttemptRecord {
  final String attemptId;
  final String userId;
  final String lessonId;
  final String quizId;
  final double score;
  final DateTime createdAt;

  const AttemptRecord({
    required this.attemptId,
    required this.userId,
    required this.lessonId,
    required this.quizId,
    required this.score,
    required this.createdAt,
  });

  factory AttemptRecord.fromJson(Map<String, dynamic> json) {
    return AttemptRecord(
      attemptId: json['attempt_id'] as String,
      userId: json['user_id'] as String,
      lessonId: json['lesson_id'] as String,
      quizId: json['quiz_id'] as String,
      score: (json['score'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'attempt_id': attemptId,
      'user_id': userId,
      'lesson_id': lessonId,
      'quiz_id': quizId,
      'score': score,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Get formatted score as percentage
  String get formattedScore => '${(score * 100).round()}%';

  /// Get relative time string
  String get relativeTimeString {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  String toString() =>
      'AttemptRecord(attemptId: $attemptId, userId: $userId, score: $score, createdAt: $createdAt)';
}

/// Error record for tracking user error patterns
class ErrorRecord {
  final String errorId;
  final String userId;
  final String errorType;
  final String? token;
  final Map<String, dynamic>? details;
  final DateTime createdAt;

  const ErrorRecord({
    required this.errorId,
    required this.userId,
    required this.errorType,
    this.token,
    this.details,
    required this.createdAt,
  });

  factory ErrorRecord.fromJson(Map<String, dynamic> json) {
    return ErrorRecord(
      errorId: json['error_id'] as String,
      userId: json['user_id'] as String,
      errorType: json['error_type'] as String,
      token: json['token'] as String?,
      details: json['details'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'error_id': errorId,
      'user_id': userId,
      'error_type': errorType,
      'token': token,
      'details': details,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Get severity from details
  String get severity => details?['severity'] ?? 'medium';

  /// Get hint from details
  String? get hint => details?['hint'];

  @override
  String toString() =>
      'ErrorRecord(errorId: $errorId, errorType: $errorType, token: $token, createdAt: $createdAt)';
}

/// Helper function for list equality comparison
bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (a == null) return b == null;
  if (b == null || a.length != b.length) return false;
  if (identical(a, b)) return true;
  for (int index = 0; index < a.length; index += 1) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

/// Extension for error type categorization
extension ErrorTypeExtension on String {
  /// Check if this is a critical error type
  bool get isCriticalError {
    switch (toUpperCase()) {
      case 'EN_IN_AR':
      case 'SPELL_T':
        return true;
      default:
        return false;
    }
  }

  /// Get user-friendly error type name
  String get friendlyName {
    switch (toUpperCase()) {
      case 'EN_IN_AR':
        return 'English in Arabic';
      case 'SPELL_T':
        return 'Spelling';
      case 'GRAMMAR':
        return 'Grammar';
      case 'VOCAB':
        return 'Vocabulary';
      case 'OMISSION':
        return 'Missing Word';
      case 'EXTRA':
        return 'Extra Word';
      default:
        return 'Other';
    }
  }

  /// Get color for error type
  String get colorName {
    switch (toUpperCase()) {
      case 'EN_IN_AR':
        return 'red';
      case 'SPELL_T':
        return 'orange';
      case 'GRAMMAR':
        return 'purple';
      case 'VOCAB':
        return 'yellow';
      case 'OMISSION':
      case 'EXTRA':
        return 'indigo';
      default:
        return 'gray';
    }
  }
}