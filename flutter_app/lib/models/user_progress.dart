/// User progress tracking models for Flutter
/// Maps to backend progress tracking API responses
class UserProgress {
  final String progressId;
  final String userId;
  final String lessonId;
  final String status;
  final DateTime? completionDate;
  final int timeSpentMinutes;
  final int lessonViews;
  final int translationToggles;
  final bool quizTaken;
  final double? quizScore;
  final int quizAttempts;
  final double? bestQuizScore;
  final DateTime lastAccessed;

  const UserProgress({
    required this.progressId,
    required this.userId,
    required this.lessonId,
    required this.status,
    this.completionDate,
    required this.timeSpentMinutes,
    required this.lessonViews,
    required this.translationToggles,
    required this.quizTaken,
    this.quizScore,
    required this.quizAttempts,
    this.bestQuizScore,
    required this.lastAccessed,
  });

  /// Create UserProgress from API JSON response
  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      progressId: json['progress_id'] as String,
      userId: json['user_id'] as String,
      lessonId: json['lesson_id'] as String,
      status: json['status'] as String,
      completionDate: json['completion_date'] != null
          ? DateTime.parse(json['completion_date'] as String)
          : null,
      timeSpentMinutes: json['time_spent_minutes'] as int,
      lessonViews: json['lesson_views'] as int,
      translationToggles: json['translation_toggles'] as int,
      quizTaken: json['quiz_taken'] as bool,
      quizScore: json['quiz_score'] as double?,
      quizAttempts: json['quiz_attempts'] as int,
      bestQuizScore: json['best_quiz_score'] as double?,
      lastAccessed: DateTime.parse(json['last_accessed'] as String),
    );
  }

  /// Convert UserProgress to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'progress_id': progressId,
      'user_id': userId,
      'lesson_id': lessonId,
      'status': status,
      'completion_date': completionDate?.toIso8601String(),
      'time_spent_minutes': timeSpentMinutes,
      'lesson_views': lessonViews,
      'translation_toggles': translationToggles,
      'quiz_taken': quizTaken,
      'quiz_score': quizScore,
      'quiz_attempts': quizAttempts,
      'best_quiz_score': bestQuizScore,
      'last_accessed': lastAccessed.toIso8601String(),
    };
  }

  /// Check if lesson is completed
  bool get isCompleted => status == 'completed';

  /// Check if lesson is in progress
  bool get isInProgress => status == 'in_progress';

  /// Check if lesson is not started
  bool get isNotStarted => status == 'not_started';

  /// Get formatted time spent
  String get formattedTimeSpent {
    if (timeSpentMinutes < 60) {
      return '${timeSpentMinutes}m';
    } else {
      final hours = timeSpentMinutes ~/ 60;
      final minutes = timeSpentMinutes % 60;
      return '${hours}h ${minutes}m';
    }
  }

  /// Get quiz score as percentage
  String get quizScorePercentage {
    if (quizScore == null) return 'N/A';
    return '${(quizScore! * 100).round()}%';
  }

  /// Get best quiz score as percentage
  String get bestQuizScorePercentage {
    if (bestQuizScore == null) return 'N/A';
    return '${(bestQuizScore! * 100).round()}%';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProgress &&
        other.progressId == progressId &&
        other.userId == userId &&
        other.lessonId == lessonId;
  }

  @override
  int get hashCode => Object.hash(progressId, userId, lessonId);

  @override
  String toString() {
    return 'UserProgress(id: $progressId, lesson: $lessonId, status: $status)';
  }
}

/// Quiz attempt model
class QuizAttempt {
  final String attemptId;
  final String userId;
  final String quizId;
  final double score;
  final int totalQuestions;
  final int correctAnswers;
  final int timeSpentSeconds;
  final DateTime startedAt;
  final DateTime completedAt;
  final int mcqCorrect;
  final int mcqTotal;
  final int translationCorrect;
  final int translationTotal;
  final int fillBlankCorrect;
  final int fillBlankTotal;

  const QuizAttempt({
    required this.attemptId,
    required this.userId,
    required this.quizId,
    required this.score,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.timeSpentSeconds,
    required this.startedAt,
    required this.completedAt,
    required this.mcqCorrect,
    required this.mcqTotal,
    required this.translationCorrect,
    required this.translationTotal,
    required this.fillBlankCorrect,
    required this.fillBlankTotal,
  });

  /// Create QuizAttempt from API JSON response
  factory QuizAttempt.fromJson(Map<String, dynamic> json) {
    return QuizAttempt(
      attemptId: json['attempt_id'] as String,
      userId: json['user_id'] as String,
      quizId: json['quiz_id'] as String,
      score: json['score'] as double,
      totalQuestions: json['total_questions'] as int,
      correctAnswers: json['correct_answers'] as int,
      timeSpentSeconds: json['time_taken_seconds'] as int,
      startedAt: DateTime.parse(json['started_at'] as String),
      completedAt: DateTime.parse(json['completed_at'] as String),
      mcqCorrect: json['mcq_correct'] as int,
      mcqTotal: json['mcq_total'] as int,
      translationCorrect: json['translation_correct'] as int,
      translationTotal: json['translation_total'] as int,
      fillBlankCorrect: json['fill_blank_correct'] as int,
      fillBlankTotal: json['fill_blank_total'] as int,
    );
  }

  /// Get score as percentage
  String get scorePercentage => '${(score * 100).round()}%';

  /// Get formatted time taken
  String get formattedTimeTaken {
    if (timeSpentSeconds < 60) {
      return '${timeSpentSeconds}s';
    } else {
      final minutes = timeSpentSeconds ~/ 60;
      final seconds = timeSpentSeconds % 60;
      return '${minutes}m ${seconds}s';
    }
  }

  /// Get accuracy by question type
  Map<String, double> get accuracyByType {
    return {
      'mcq': mcqTotal > 0 ? mcqCorrect / mcqTotal : 0.0,
      'translate': translationTotal > 0 ? translationCorrect / translationTotal : 0.0,
      'fill_blank': fillBlankTotal > 0 ? fillBlankCorrect / fillBlankTotal : 0.0,
    };
  }

  @override
  String toString() {
    return 'QuizAttempt(id: $attemptId, score: $scorePercentage)';
  }
}

/// User profile model
class UserProfile {
  final String userId;
  final String? displayName;
  final String? preferredLevel;
  final int totalLessonsCompleted;
  final int totalQuizzesCompleted;
  final int totalTimeSpentMinutes;
  final double? averageQuizScore;
  final int currentStreakDays;
  final int longestStreakDays;
  final DateTime? lastActivityDate;
  final List<String> favoriteTopics;
  final Map<String, dynamic> topicPerformance;
  final Map<String, dynamic> settings;

  const UserProfile({
    required this.userId,
    this.displayName,
    this.preferredLevel,
    required this.totalLessonsCompleted,
    required this.totalQuizzesCompleted,
    required this.totalTimeSpentMinutes,
    this.averageQuizScore,
    required this.currentStreakDays,
    required this.longestStreakDays,
    this.lastActivityDate,
    required this.favoriteTopics,
    required this.topicPerformance,
    required this.settings,
  });

  /// Create UserProfile from API JSON response
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String?,
      preferredLevel: json['preferred_level'] as String?,
      totalLessonsCompleted: json['total_lessons_completed'] as int,
      totalQuizzesCompleted: json['total_quizzes_completed'] as int,
      totalTimeSpentMinutes: json['total_time_spent_minutes'] as int,
      averageQuizScore: json['average_quiz_score'] as double?,
      currentStreakDays: json['current_streak_days'] as int,
      longestStreakDays: json['longest_streak_days'] as int,
      lastActivityDate: json['last_activity_date'] != null
          ? DateTime.parse(json['last_activity_date'] as String)
          : null,
      favoriteTopics: List<String>.from(json['favorite_topics'] as List? ?? []),
      topicPerformance: Map<String, dynamic>.from(json['topic_performance'] as Map? ?? {}),
      settings: Map<String, dynamic>.from(json['settings'] as Map? ?? {}),
    );
  }

  /// Get formatted total time spent
  String get formattedTotalTime {
    if (totalTimeSpentMinutes < 60) {
      return '${totalTimeSpentMinutes}m';
    } else {
      final hours = totalTimeSpentMinutes ~/ 60;
      final minutes = totalTimeSpentMinutes % 60;
      return '${hours}h ${minutes}m';
    }
  }

  /// Get average quiz score as percentage
  String get averageQuizScorePercentage {
    if (averageQuizScore == null) return 'N/A';
    return '${(averageQuizScore! * 100).round()}%';
  }

  @override
  String toString() {
    return 'UserProfile(id: $userId, lessons: $totalLessonsCompleted, streak: $currentStreakDays)';
  }
}

/// Dashboard statistics model
class DashboardStats {
  final int totalLessonsCompleted;
  final int totalQuizzesCompleted;
  final int totalTimeSpentMinutes;
  final double? averageQuizScore;
  final int currentStreakDays;
  final int lessonsThisWeek;
  final List<Map<String, dynamic>> recentActivity;
  final Map<String, dynamic> topicProgress;

  const DashboardStats({
    required this.totalLessonsCompleted,
    required this.totalQuizzesCompleted,
    required this.totalTimeSpentMinutes,
    this.averageQuizScore,
    required this.currentStreakDays,
    required this.lessonsThisWeek,
    required this.recentActivity,
    required this.topicProgress,
  });

  /// Create DashboardStats from API JSON response
  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalLessonsCompleted: json['total_lessons_completed'] as int,
      totalQuizzesCompleted: json['total_quizzes_completed'] as int,
      totalTimeSpentMinutes: json['total_time_spent_minutes'] as int,
      averageQuizScore: json['average_quiz_score'] as double?,
      currentStreakDays: json['current_streak_days'] as int,
      lessonsThisWeek: json['lessons_this_week'] as int,
      recentActivity: List<Map<String, dynamic>>.from(json['recent_activity'] as List? ?? []),
      topicProgress: Map<String, dynamic>.from(json['topic_progress'] as Map? ?? {}),
    );
  }

  /// Get formatted total time spent
  String get formattedTotalTime {
    if (totalTimeSpentMinutes < 60) {
      return '${totalTimeSpentMinutes}m';
    } else {
      final hours = totalTimeSpentMinutes ~/ 60;
      final minutes = totalTimeSpentMinutes % 60;
      return '${hours}h ${minutes}m';
    }
  }

  /// Get average quiz score as percentage
  String get averageQuizScorePercentage {
    if (averageQuizScore == null) return 'N/A';
    return '${(averageQuizScore! * 100).round()}%';
  }

  @override
  String toString() {
    return 'DashboardStats(lessons: $totalLessonsCompleted, streak: $currentStreakDays)';
  }
}

/// Progress update request model
class ProgressUpdateRequest {
  final String? status;
  final int? timeSpentMinutes;
  final int? lessonViews;
  final int? translationToggles;

  const ProgressUpdateRequest({
    this.status,
    this.timeSpentMinutes,
    this.lessonViews,
    this.translationToggles,
  });

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (status != null) json['status'] = status;
    if (timeSpentMinutes != null) json['time_spent_minutes'] = timeSpentMinutes;
    if (lessonViews != null) json['lesson_views'] = lessonViews;
    if (translationToggles != null) json['translation_toggles'] = translationToggles;
    return json;
  }
}

/// Quiz attempt submission model
class QuizAttemptSubmission {
  final String quizId;
  final List<Map<String, dynamic>> responses;
  final double score;
  final int timeSpentSeconds;
  final DateTime startedAt;
  final DateTime completedAt;

  const QuizAttemptSubmission({
    required this.quizId,
    required this.responses,
    required this.score,
    required this.timeSpentSeconds,
    required this.startedAt,
    required this.completedAt,
  });

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'quiz_id': quizId,
      'responses': responses,
      'score': score,
      'time_taken_seconds': timeSpentSeconds,
      'started_at': startedAt.toIso8601String(),
      'completed_at': completedAt.toIso8601String(),
    };
  }
}