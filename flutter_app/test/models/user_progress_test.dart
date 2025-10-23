import 'package:flutter_test/flutter_test.dart';
import 'package:translator_tool/models/user_progress.dart';

void main() {
  group('UserProgress', () {
    test('should create UserProgress from JSON', () {
      final json = {
        'progress_id': 'progress-123',
        'user_id': 'user-456',
        'lesson_id': 'lesson-789',
        'status': 'completed',
        'completion_date': '2024-01-15T10:30:00Z',
        'time_spent_minutes': 25,
        'lesson_views': 3,
        'translation_toggles': 5,
        'quiz_taken': true,
        'quiz_score': 0.85,
        'quiz_attempts': 2,
        'best_quiz_score': 0.85,
        'last_accessed': '2024-01-15T10:30:00Z',
      };

      final progress = UserProgress.fromJson(json);

      expect(progress.progressId, 'progress-123');
      expect(progress.userId, 'user-456');
      expect(progress.lessonId, 'lesson-789');
      expect(progress.status, 'completed');
      expect(progress.completionDate, isNotNull);
      expect(progress.timeSpentMinutes, 25);
      expect(progress.lessonViews, 3);
      expect(progress.translationToggles, 5);
      expect(progress.quizTaken, true);
      expect(progress.quizScore, 0.85);
      expect(progress.quizAttempts, 2);
      expect(progress.bestQuizScore, 0.85);
      expect(progress.lastAccessed, isA<DateTime>());
    });

    test('should convert UserProgress to JSON', () {
      final progress = UserProgress(
        progressId: 'progress-123',
        userId: 'user-456',
        lessonId: 'lesson-789',
        status: 'in_progress',
        timeSpentMinutes: 15,
        lessonViews: 2,
        translationToggles: 3,
        quizTaken: false,
        quizAttempts: 0,
        lastAccessed: DateTime.parse('2024-01-15T10:30:00Z'),
      );

      final json = progress.toJson();

      expect(json['progress_id'], 'progress-123');
      expect(json['user_id'], 'user-456');
      expect(json['lesson_id'], 'lesson-789');
      expect(json['status'], 'in_progress');
      expect(json['time_spent_minutes'], 15);
      expect(json['lesson_views'], 2);
      expect(json['translation_toggles'], 3);
      expect(json['quiz_taken'], false);
      expect(json['quiz_attempts'], 0);
    });

    test('should correctly identify status states', () {
      final notStarted = UserProgress(
        progressId: 'progress-1',
        userId: 'user-1',
        lessonId: 'lesson-1',
        status: 'not_started',
        timeSpentMinutes: 0,
        lessonViews: 0,
        translationToggles: 0,
        quizTaken: false,
        quizAttempts: 0,
        lastAccessed: DateTime.now(),
      );

      final inProgress = UserProgress(
        progressId: 'progress-2',
        userId: 'user-1',
        lessonId: 'lesson-2',
        status: 'in_progress',
        timeSpentMinutes: 10,
        lessonViews: 1,
        translationToggles: 2,
        quizTaken: false,
        quizAttempts: 0,
        lastAccessed: DateTime.now(),
      );

      final completed = UserProgress(
        progressId: 'progress-3',
        userId: 'user-1',
        lessonId: 'lesson-3',
        status: 'completed',
        timeSpentMinutes: 30,
        lessonViews: 3,
        translationToggles: 5,
        quizTaken: true,
        quizAttempts: 1,
        lastAccessed: DateTime.now(),
      );

      expect(notStarted.isNotStarted, true);
      expect(notStarted.isInProgress, false);
      expect(notStarted.isCompleted, false);

      expect(inProgress.isNotStarted, false);
      expect(inProgress.isInProgress, true);
      expect(inProgress.isCompleted, false);

      expect(completed.isNotStarted, false);
      expect(completed.isInProgress, false);
      expect(completed.isCompleted, true);
    });

    test('should format time spent correctly', () {
      final shortTime = UserProgress(
        progressId: 'progress-1',
        userId: 'user-1',
        lessonId: 'lesson-1',
        status: 'completed',
        timeSpentMinutes: 45,
        lessonViews: 1,
        translationToggles: 0,
        quizTaken: false,
        quizAttempts: 0,
        lastAccessed: DateTime.now(),
      );

      final longTime = UserProgress(
        progressId: 'progress-2',
        userId: 'user-1',
        lessonId: 'lesson-2',
        status: 'completed',
        timeSpentMinutes: 125, // 2h 5m
        lessonViews: 1,
        translationToggles: 0,
        quizTaken: false,
        quizAttempts: 0,
        lastAccessed: DateTime.now(),
      );

      expect(shortTime.formattedTimeSpent, '45m');
      expect(longTime.formattedTimeSpent, '2h 5m');
    });

    test('should format quiz scores correctly', () {
      final progress = UserProgress(
        progressId: 'progress-1',
        userId: 'user-1',
        lessonId: 'lesson-1',
        status: 'completed',
        timeSpentMinutes: 30,
        lessonViews: 1,
        translationToggles: 0,
        quizTaken: true,
        quizScore: 0.875,
        quizAttempts: 1,
        bestQuizScore: 0.875,
        lastAccessed: DateTime.now(),
      );

      expect(progress.quizScorePercentage, '88%');
      expect(progress.bestQuizScorePercentage, '88%');
    });

    test('should handle null quiz scores', () {
      final progress = UserProgress(
        progressId: 'progress-1',
        userId: 'user-1',
        lessonId: 'lesson-1',
        status: 'in_progress',
        timeSpentMinutes: 15,
        lessonViews: 1,
        translationToggles: 0,
        quizTaken: false,
        quizAttempts: 0,
        lastAccessed: DateTime.now(),
      );

      expect(progress.quizScorePercentage, 'N/A');
      expect(progress.bestQuizScorePercentage, 'N/A');
    });

    test('should handle equality correctly', () {
      final progress1 = UserProgress(
        progressId: 'progress-1',
        userId: 'user-1',
        lessonId: 'lesson-1',
        status: 'completed',
        timeSpentMinutes: 30,
        lessonViews: 1,
        translationToggles: 0,
        quizTaken: false,
        quizAttempts: 0,
        lastAccessed: DateTime.now(),
      );

      final progress2 = UserProgress(
        progressId: 'progress-1',
        userId: 'user-1',
        lessonId: 'lesson-1',
        status: 'completed',
        timeSpentMinutes: 30,
        lessonViews: 1,
        translationToggles: 0,
        quizTaken: false,
        quizAttempts: 0,
        lastAccessed: DateTime.now(),
      );

      final progress3 = UserProgress(
        progressId: 'progress-2',
        userId: 'user-1',
        lessonId: 'lesson-1',
        status: 'completed',
        timeSpentMinutes: 30,
        lessonViews: 1,
        translationToggles: 0,
        quizTaken: false,
        quizAttempts: 0,
        lastAccessed: DateTime.now(),
      );

      expect(progress1 == progress2, true);
      expect(progress1 == progress3, false);
      expect(progress1.hashCode == progress2.hashCode, true);
    });
  });

  group('QuizAttempt', () {
    test('should create QuizAttempt from JSON', () {
      final json = {
        'attempt_id': 'attempt-123',
        'user_id': 'user-456',
        'quiz_id': 'quiz-789',
        'score': 0.75,
        'total_questions': 4,
        'correct_answers': 3,
        'time_taken_seconds': 180,
        'started_at': '2024-01-15T10:00:00Z',
        'completed_at': '2024-01-15T10:03:00Z',
        'mcq_correct': 2,
        'mcq_total': 2,
        'translation_correct': 1,
        'translation_total': 1,
        'fill_blank_correct': 0,
        'fill_blank_total': 1,
      };

      final attempt = QuizAttempt.fromJson(json);

      expect(attempt.attemptId, 'attempt-123');
      expect(attempt.userId, 'user-456');
      expect(attempt.quizId, 'quiz-789');
      expect(attempt.score, 0.75);
      expect(attempt.totalQuestions, 4);
      expect(attempt.correctAnswers, 3);
      expect(attempt.timeSpentSeconds, 180);
      expect(attempt.mcqCorrect, 2);
      expect(attempt.mcqTotal, 2);
      expect(attempt.translationCorrect, 1);
      expect(attempt.translationTotal, 1);
      expect(attempt.fillBlankCorrect, 0);
      expect(attempt.fillBlankTotal, 1);
    });

    test('should format score percentage correctly', () {
      final attempt = QuizAttempt(
        attemptId: 'attempt-1',
        userId: 'user-1',
        quizId: 'quiz-1',
        score: 0.8333,
        totalQuestions: 3,
        correctAnswers: 2,
        timeSpentSeconds: 120,
        startedAt: DateTime.now(),
        completedAt: DateTime.now(),
        mcqCorrect: 2,
        mcqTotal: 2,
        translationCorrect: 0,
        translationTotal: 1,
        fillBlankCorrect: 0,
        fillBlankTotal: 0,
      );

      expect(attempt.scorePercentage, '83%');
    });

    test('should format time taken correctly', () {
      final shortTime = QuizAttempt(
        attemptId: 'attempt-1',
        userId: 'user-1',
        quizId: 'quiz-1',
        score: 1.0,
        totalQuestions: 3,
        correctAnswers: 3,
        timeSpentSeconds: 45,
        startedAt: DateTime.now(),
        completedAt: DateTime.now(),
        mcqCorrect: 3,
        mcqTotal: 3,
        translationCorrect: 0,
        translationTotal: 0,
        fillBlankCorrect: 0,
        fillBlankTotal: 0,
      );

      final longTime = QuizAttempt(
        attemptId: 'attempt-2',
        userId: 'user-1',
        quizId: 'quiz-1',
        score: 0.8,
        totalQuestions: 5,
        correctAnswers: 4,
        timeSpentSeconds: 185, // 3m 5s
        startedAt: DateTime.now(),
        completedAt: DateTime.now(),
        mcqCorrect: 4,
        mcqTotal: 5,
        translationCorrect: 0,
        translationTotal: 0,
        fillBlankCorrect: 0,
        fillBlankTotal: 0,
      );

      expect(shortTime.formattedTimeTaken, '45s');
      expect(longTime.formattedTimeTaken, '3m 5s');
    });

    test('should calculate accuracy by question type', () {
      final attempt = QuizAttempt(
        attemptId: 'attempt-1',
        userId: 'user-1',
        quizId: 'quiz-1',
        score: 0.6,
        totalQuestions: 5,
        correctAnswers: 3,
        timeSpentSeconds: 300,
        startedAt: DateTime.now(),
        completedAt: DateTime.now(),
        mcqCorrect: 2,
        mcqTotal: 2,
        translationCorrect: 1,
        translationTotal: 2,
        fillBlankCorrect: 0,
        fillBlankTotal: 1,
      );

      final accuracy = attempt.accuracyByType;

      expect(accuracy['mcq'], 1.0); // 2/2 = 100%
      expect(accuracy['translate'], 0.5); // 1/2 = 50%
      expect(accuracy['fill_blank'], 0.0); // 0/1 = 0%
    });

    test('should handle zero totals in accuracy calculation', () {
      final attempt = QuizAttempt(
        attemptId: 'attempt-1',
        userId: 'user-1',
        quizId: 'quiz-1',
        score: 1.0,
        totalQuestions: 2,
        correctAnswers: 2,
        timeSpentSeconds: 60,
        startedAt: DateTime.now(),
        completedAt: DateTime.now(),
        mcqCorrect: 2,
        mcqTotal: 2,
        translationCorrect: 0,
        translationTotal: 0,
        fillBlankCorrect: 0,
        fillBlankTotal: 0,
      );

      final accuracy = attempt.accuracyByType;

      expect(accuracy['mcq'], 1.0);
      expect(accuracy['translate'], 0.0); // No questions, should be 0
      expect(accuracy['fill_blank'], 0.0); // No questions, should be 0
    });
  });

  group('UserProfile', () {
    test('should create UserProfile from JSON', () {
      final json = {
        'user_id': 'user-123',
        'display_name': 'John Doe',
        'preferred_level': 'intermediate',
        'total_lessons_completed': 25,
        'total_quizzes_completed': 20,
        'total_time_spent_minutes': 1500,
        'average_quiz_score': 0.82,
        'current_streak_days': 7,
        'longest_streak_days': 15,
        'last_activity_date': '2024-01-15T10:30:00Z',
        'favorite_topics': ['greetings', 'food'],
        'topic_performance': {'greetings': {'accuracy': 0.9}},
        'settings': {'notifications': true},
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.userId, 'user-123');
      expect(profile.displayName, 'John Doe');
      expect(profile.preferredLevel, 'intermediate');
      expect(profile.totalLessonsCompleted, 25);
      expect(profile.totalQuizzesCompleted, 20);
      expect(profile.totalTimeSpentMinutes, 1500);
      expect(profile.averageQuizScore, 0.82);
      expect(profile.currentStreakDays, 7);
      expect(profile.longestStreakDays, 15);
      expect(profile.lastActivityDate, isNotNull);
      expect(profile.favoriteTopics, ['greetings', 'food']);
      expect(profile.topicPerformance['greetings']['accuracy'], 0.9);
      expect(profile.settings['notifications'], true);
    });

    test('should format total time correctly', () {
      final shortTime = UserProfile(
        userId: 'user-1',
        totalLessonsCompleted: 5,
        totalQuizzesCompleted: 3,
        totalTimeSpentMinutes: 45,
        currentStreakDays: 2,
        longestStreakDays: 5,
        favoriteTopics: [],
        topicPerformance: {},
        settings: {},
      );

      final longTime = UserProfile(
        userId: 'user-2',
        totalLessonsCompleted: 50,
        totalQuizzesCompleted: 40,
        totalTimeSpentMinutes: 1825, // 30h 25m
        currentStreakDays: 10,
        longestStreakDays: 20,
        favoriteTopics: [],
        topicPerformance: {},
        settings: {},
      );

      expect(shortTime.formattedTotalTime, '45m');
      expect(longTime.formattedTotalTime, '30h 25m');
    });

    test('should format average quiz score correctly', () {
      final profile = UserProfile(
        userId: 'user-1',
        totalLessonsCompleted: 10,
        totalQuizzesCompleted: 8,
        totalTimeSpentMinutes: 300,
        averageQuizScore: 0.875,
        currentStreakDays: 3,
        longestStreakDays: 7,
        favoriteTopics: [],
        topicPerformance: {},
        settings: {},
      );

      expect(profile.averageQuizScorePercentage, '88%');
    });

    test('should handle null average quiz score', () {
      final profile = UserProfile(
        userId: 'user-1',
        totalLessonsCompleted: 5,
        totalQuizzesCompleted: 0,
        totalTimeSpentMinutes: 150,
        currentStreakDays: 2,
        longestStreakDays: 4,
        favoriteTopics: [],
        topicPerformance: {},
        settings: {},
      );

      expect(profile.averageQuizScorePercentage, 'N/A');
    });
  });

  group('DashboardStats', () {
    test('should create DashboardStats from JSON', () {
      final json = {
        'total_lessons_completed': 15,
        'total_quizzes_completed': 12,
        'total_time_spent_minutes': 750,
        'average_quiz_score': 0.78,
        'current_streak_days': 5,
        'lessons_this_week': 3,
        'recent_activity': [
          {'lesson_id': 'lesson-1', 'status': 'completed', 'timestamp': '2024-01-15T10:00:00Z'}
        ],
        'topic_progress': {
          'greetings': {'total': 5, 'completed': 4, 'completion_rate': 0.8}
        },
      };

      final stats = DashboardStats.fromJson(json);

      expect(stats.totalLessonsCompleted, 15);
      expect(stats.totalQuizzesCompleted, 12);
      expect(stats.totalTimeSpentMinutes, 750);
      expect(stats.averageQuizScore, 0.78);
      expect(stats.currentStreakDays, 5);
      expect(stats.lessonsThisWeek, 3);
      expect(stats.recentActivity.length, 1);
      expect(stats.topicProgress['greetings']['completion_rate'], 0.8);
    });

    test('should format total time and average score correctly', () {
      final stats = DashboardStats(
        totalLessonsCompleted: 20,
        totalQuizzesCompleted: 18,
        totalTimeSpentMinutes: 1290, // 21h 30m
        averageQuizScore: 0.825,
        currentStreakDays: 8,
        lessonsThisWeek: 4,
        recentActivity: [],
        topicProgress: {},
      );

      expect(stats.formattedTotalTime, '21h 30m');
      expect(stats.averageQuizScorePercentage, '83%');
    });
  });

  group('ProgressUpdateRequest', () {
    test('should convert to JSON correctly', () {
      final request = ProgressUpdateRequest(
        status: 'completed',
        timeSpentMinutes: 30,
        lessonViews: 2,
        translationToggles: 5,
      );

      final json = request.toJson();

      expect(json['status'], 'completed');
      expect(json['time_spent_minutes'], 30);
      expect(json['lesson_views'], 2);
      expect(json['translation_toggles'], 5);
    });

    test('should exclude null values from JSON', () {
      final request = ProgressUpdateRequest(
        status: 'in_progress',
        timeSpentMinutes: null,
        lessonViews: 1,
        translationToggles: null,
      );

      final json = request.toJson();

      expect(json['status'], 'in_progress');
      expect(json['lesson_views'], 1);
      expect(json.containsKey('time_spent_minutes'), false);
      expect(json.containsKey('translation_toggles'), false);
    });
  });

  group('QuizAttemptSubmission', () {
    test('should convert to JSON correctly', () {
      final startTime = DateTime.parse('2024-01-15T10:00:00Z');
      final endTime = DateTime.parse('2024-01-15T10:05:00Z');

      final submission = QuizAttemptSubmission(
        quizId: 'quiz-123',
        responses: [
          {'type': 'mcq', 'user_answer': 0, 'is_correct': true},
          {'type': 'translate', 'user_answer': 'marhaba', 'is_correct': true},
        ],
        score: 1.0,
        timeSpentSeconds: 300,
        startedAt: startTime,
        completedAt: endTime,
      );

      final json = submission.toJson();

      expect(json['quiz_id'], 'quiz-123');
      expect(json['responses'].length, 2);
      expect(json['score'], 1.0);
      expect(json['time_taken_seconds'], 300);
      expect(json['started_at'], '2024-01-15T10:00:00.000Z');
      expect(json['completed_at'], '2024-01-15T10:05:00.000Z');
    });
  });
}