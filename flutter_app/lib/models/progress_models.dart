/// Progress metrics for a specific time period
class ProgressMetrics {
  final double accuracy;
  final int timeMinutes;
  final Map<String, int> errorBreakdown;
  final int lessonsCompleted;
  final int streakDays;
  final double improvementRate;

  const ProgressMetrics({
    required this.accuracy,
    required this.timeMinutes,
    required this.errorBreakdown,
    required this.lessonsCompleted,
    required this.streakDays,
    required this.improvementRate,
  });

  factory ProgressMetrics.fromJson(Map<String, dynamic> json) {
    return ProgressMetrics(
      accuracy: (json['accuracy'] as num).toDouble(),
      timeMinutes: json['time_minutes'] as int,
      errorBreakdown: Map<String, int>.from(json['error_breakdown'] as Map),
      lessonsCompleted: json['lessons_completed'] as int,
      streakDays: json['streak_days'] as int,
      improvementRate: (json['improvement_rate'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accuracy': accuracy,
      'time_minutes': timeMinutes,
      'error_breakdown': errorBreakdown,
      'lessons_completed': lessonsCompleted,
      'streak_days': streakDays,
      'improvement_rate': improvementRate,
    };
  }
}

/// Single trend data point for charts
class TrendPoint {
  final String date;
  final double accuracy;
  final int timeMinutes;

  const TrendPoint({
    required this.date,
    required this.accuracy,
    required this.timeMinutes,
  });

  factory TrendPoint.fromJson(Map<String, dynamic> json) {
    return TrendPoint(
      date: json['date'] as String,
      accuracy: (json['accuracy'] as num).toDouble(),
      timeMinutes: json['time_minutes'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'accuracy': accuracy,
      'time_minutes': timeMinutes,
    };
  }
}

/// Progress analytics response from API
class ProgressResponse {
  final ProgressMetrics weekly;
  final List<TrendPoint> trends;
  final List<String> improvementAreas;

  const ProgressResponse({
    required this.weekly,
    required this.trends,
    required this.improvementAreas,
  });

  factory ProgressResponse.fromJson(Map<String, dynamic> json) {
    return ProgressResponse(
      weekly: ProgressMetrics.fromJson(json['weekly'] as Map<String, dynamic>),
      trends: (json['trends'] as List)
          .map((item) => TrendPoint.fromJson(item as Map<String, dynamic>))
          .toList(),
      improvementAreas: List<String>.from(json['improvement_areas'] as List),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'weekly': weekly.toJson(),
      'trends': trends.map((trend) => trend.toJson()).toList(),
      'improvement_areas': improvementAreas,
    };
  }
}

/// Request parameters for progress API
class ProgressRequest {
  final String userId;
  final int daysBack;

  const ProgressRequest({
    required this.userId,
    this.daysBack = 30,
  });

  factory ProgressRequest.fromJson(Map<String, dynamic> json) {
    return ProgressRequest(
      userId: json['user_id'] as String,
      daysBack: json['days_back'] as int? ?? 30,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'days_back': daysBack,
    };
  }
}

/// Extension methods for formatting and UI helpers
extension ProgressMetricsX on ProgressMetrics {
  /// Get accuracy as percentage string
  String get accuracyPercentage => '${(accuracy * 100).toStringAsFixed(1)}%';

  /// Get formatted time spent
  String get formattedTimeSpent {
    if (timeMinutes < 60) {
      return '${timeMinutes}m';
    } else {
      final hours = timeMinutes ~/ 60;
      final minutes = timeMinutes % 60;
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
  }

  /// Get improvement rate as percentage string with sign
  String get improvementRatePercentage {
    final percent = (improvementRate * 100).toStringAsFixed(1);
    final sign = improvementRate >= 0 ? '+' : '';
    return '$sign$percent%';
  }

  /// Get most common error type
  String? get topErrorType {
    if (errorBreakdown.isEmpty) return null;
    return errorBreakdown.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// Get total error count
  int get totalErrors => errorBreakdown.values.fold(0, (sum, count) => sum + count);

  /// Check if showing improvement
  bool get isImproving => improvementRate > 0;

  /// Get streak status description
  String get streakDescription {
    if (streakDays == 0) return 'Start your streak today!';
    if (streakDays == 1) return 'Keep it up!';
    if (streakDays < 7) return 'Great progress!';
    if (streakDays < 30) return 'Amazing consistency!';
    return 'Incredible dedication!';
  }
}

extension TrendPointX on TrendPoint {
  /// Get accuracy as percentage
  double get accuracyPercent => accuracy * 100;

  /// Parse date string to DateTime
  DateTime get dateTime => DateTime.parse(date);

  /// Get formatted date for display
  String get formattedDate {
    final dt = dateTime;
    return '${dt.month}/${dt.day}';
  }

  /// Get formatted time
  String get formattedTime {
    if (timeMinutes < 60) {
      return '${timeMinutes}m';
    } else {
      final hours = timeMinutes ~/ 60;
      final minutes = timeMinutes % 60;
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
  }
}

extension ProgressResponseX on ProgressResponse {
  /// Get overall trend direction
  TrendDirection get overallTrend {
    if (trends.length < 2) return TrendDirection.stable;

    final firstAccuracy = trends.first.accuracy;
    final lastAccuracy = trends.last.accuracy;
    final diff = lastAccuracy - firstAccuracy;

    if (diff > 0.05) return TrendDirection.improving;
    if (diff < -0.05) return TrendDirection.declining;
    return TrendDirection.stable;
  }

  /// Get total time spent across all trend points
  int get totalTimeSpent => trends.fold(0, (sum, point) => sum + point.timeMinutes);

  /// Get average accuracy across trend points
  double get averageAccuracy {
    if (trends.isEmpty) return 0.0;
    return trends.fold(0.0, (sum, point) => sum + point.accuracy) / trends.length;
  }

  /// Check if user has any improvement areas
  bool get hasImprovementAreas => improvementAreas.isNotEmpty;

  /// Get primary improvement area
  String? get primaryImprovementArea =>
      improvementAreas.isNotEmpty ? improvementAreas.first : null;
}

/// Enum for trend directions
enum TrendDirection {
  improving,
  declining,
  stable,
}

extension TrendDirectionX on TrendDirection {
  String get description {
    switch (this) {
      case TrendDirection.improving:
        return 'Improving';
      case TrendDirection.declining:
        return 'Needs attention';
      case TrendDirection.stable:
        return 'Stable';
    }
  }

  /// Get appropriate color for trend
  String get colorName {
    switch (this) {
      case TrendDirection.improving:
        return 'green';
      case TrendDirection.declining:
        return 'red';
      case TrendDirection.stable:
        return 'blue';
    }
  }
}

/// Error type display names and descriptions
class ErrorTypeHelper {
  static const Map<String, String> displayNames = {
    'EN_IN_AR': 'English in Arabic',
    'SPELL_T': 'Transliteration Spelling',
    'GRAMMAR': 'Grammar',
    'VOCAB': 'Vocabulary',
    'OMISSION': 'Missing Words',
    'EXTRA': 'Extra Words',
  };

  static const Map<String, String> descriptions = {
    'EN_IN_AR': 'Using English words instead of Arabic transliteration',
    'SPELL_T': 'Misspelling Arabic words in transliteration',
    'GRAMMAR': 'Incorrect grammar or word order',
    'VOCAB': 'Wrong word choice or usage',
    'OMISSION': 'Missing required words',
    'EXTRA': 'Adding unnecessary words',
  };

  static String getDisplayName(String errorType) =>
      displayNames[errorType] ?? errorType;

  static String getDescription(String errorType) =>
      descriptions[errorType] ?? 'Unknown error type';

  static List<String> get allErrorTypes => displayNames.keys.toList();
}