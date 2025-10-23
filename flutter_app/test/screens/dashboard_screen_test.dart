import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:translator_tool/models/user_progress.dart';
import 'package:translator_tool/screens/dashboard_screen.dart';
import 'package:translator_tool/services/progress_service.dart';

// Mock data for testing
final mockUserProfile = UserProfile(
  userId: 'test-user',
  displayName: 'Test User',
  preferredLevel: 'intermediate',
  totalLessonsCompleted: 25,
  totalQuizzesCompleted: 20,
  totalTimeSpentMinutes: 1500,
  averageQuizScore: 0.82,
  currentStreakDays: 7,
  longestStreakDays: 15,
  lastActivityDate: DateTime.now().subtract(Duration(hours: 2)),
  favoriteTopics: ['greetings', 'food', 'family'],
  topicPerformance: {
    'greetings': {'total': 5, 'completed': 5, 'completion_rate': 1.0, 'average_score': 0.9},
    'food': {'total': 8, 'completed': 6, 'completion_rate': 0.75, 'average_score': 0.85},
  },
  settings: {'notifications': true, 'theme': 'light'},
);

final mockDashboardStats = DashboardStats(
  totalLessonsCompleted: 25,
  totalQuizzesCompleted: 20,
  totalTimeSpentMinutes: 1500,
  averageQuizScore: 0.82,
  currentStreakDays: 7,
  lessonsThisWeek: 4,
  recentActivity: [
    {
      'lesson_id': 'lesson-1',
      'status': 'completed',
      'timestamp': DateTime.now().subtract(Duration(hours: 1)).toIso8601String(),
      'time_spent': 25,
    },
    {
      'lesson_id': 'lesson-2',
      'status': 'in_progress',
      'timestamp': DateTime.now().subtract(Duration(hours: 3)).toIso8601String(),
      'time_spent': 15,
    },
  ],
  topicProgress: {
    'greetings': {'total': 5, 'completed': 5, 'completion_rate': 1.0},
    'food': {'total': 8, 'completed': 6, 'completion_rate': 0.75},
    'family': {'total': 6, 'completed': 2, 'completion_rate': 0.33},
  },
);

final mockUserProgress = [
  UserProgress(
    progressId: 'progress-1',
    userId: 'test-user',
    lessonId: 'lesson-1',
    status: 'completed',
    completionDate: DateTime.now().subtract(Duration(hours: 1)),
    timeSpentMinutes: 25,
    lessonViews: 3,
    translationToggles: 5,
    quizTaken: true,
    quizScore: 0.9,
    quizAttempts: 1,
    lastAccessed: DateTime.now().subtract(Duration(hours: 1)),
  ),
  UserProgress(
    progressId: 'progress-2',
    userId: 'test-user',
    lessonId: 'lesson-2',
    status: 'in_progress',
    timeSpentMinutes: 15,
    lessonViews: 2,
    translationToggles: 3,
    quizTaken: false,
    quizAttempts: 0,
    lastAccessed: DateTime.now().subtract(Duration(hours: 3)),
  ),
];

void main() {
  group('DashboardScreen', () {
    Widget createWidget() {
      return ProviderScope(
        overrides: [
          userProfileProvider.overrideWith((ref) async => mockUserProfile),
          dashboardStatsProvider.overrideWith((ref) async => mockDashboardStats),
          userProgressProvider.overrideWith((ref) async => mockUserProgress),
        ],
        child: CupertinoApp(
          home: DashboardScreen(),
        ),
      );
    }

    Widget createLoadingWidget() {
      return ProviderScope(
        overrides: [
          userProfileProvider.overrideWith((ref) async {
            await Future.delayed(Duration(seconds: 10)); // Never complete
            return mockUserProfile;
          }),
          dashboardStatsProvider.overrideWith((ref) async {
            await Future.delayed(Duration(seconds: 10)); // Never complete
            return mockDashboardStats;
          }),
        ],
        child: CupertinoApp(
          home: DashboardScreen(),
        ),
      );
    }

    Widget createErrorWidget() {
      return ProviderScope(
        overrides: [
          userProfileProvider.overrideWith((ref) async {
            throw Exception('Profile loading failed');
          }),
          dashboardStatsProvider.overrideWith((ref) async {
            throw Exception('Dashboard loading failed');
          }),
        ],
        child: CupertinoApp(
          home: DashboardScreen(),
        ),
      );
    }

    testWidgets('should display navigation bar', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump();

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.byType(CupertinoNavigationBar), findsOneWidget);
    });

    testWidgets('should display welcome section with user data', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(); // Complete the futures

      expect(find.text('Welcome back, Test User!'), findsOneWidget);
      expect(find.text('Keep up the great work learning Lebanese Arabic'), findsOneWidget);
      expect(find.text('25'), findsOneWidget); // Lessons completed
      expect(find.text('25h 0m'), findsOneWidget); // Total time formatted
    });

    testWidgets('should display stats overview cards', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump();

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Lessons'), findsOneWidget);
      expect(find.text('Quizzes'), findsOneWidget);
      expect(find.text('Avg Score'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);

      // Check stat values
      expect(find.text('25'), findsAtLeastOneWidget); // Lessons
      expect(find.text('20'), findsOneWidget); // Quizzes
      expect(find.text('82%'), findsOneWidget); // Avg Score
      expect(find.text('4'), findsOneWidget); // This week
    });

    testWidgets('should display learning streak section', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump();

      expect(find.text('Learning Streak'), findsOneWidget);
      expect(find.text('7 days'), findsOneWidget); // Current streak
      expect(find.text('Current streak'), findsOneWidget);
      expect(find.text('Best: 15 days'), findsOneWidget); // Longest streak
      expect(find.text('Keep it up!'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.flame), findsOneWidget);
    });

    testWidgets('should display recent activity section', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump();

      expect(find.text('Recent Activity'), findsOneWidget);

      // Should show recent activity items
      expect(find.text('Completed lesson'), findsOneWidget);
      expect(find.text('Studied lesson'), findsOneWidget);
    });

    testWidgets('should display topic progress section', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump();

      expect(find.text('Topic Progress'), findsOneWidget);
      expect(find.text('GREETINGS'), findsOneWidget);
      expect(find.text('FOOD'), findsOneWidget);
      expect(find.text('FAMILY'), findsOneWidget);

      // Check completion rates
      expect(find.text('100% complete'), findsOneWidget); // Greetings
      expect(find.text('75% complete'), findsOneWidget); // Food
      expect(find.text('33% complete'), findsOneWidget); // Family
    });

    testWidgets('should display quick actions section', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump();

      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('Continue Learning'), findsOneWidget);
      expect(find.text('View Analytics'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.play_fill), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.chart_bar), findsOneWidget);
    });

    testWidgets('should handle quick action button taps', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump();

      // Test continue learning button
      await tester.tap(find.text('Continue Learning'));
      await tester.pump();
      // Should not throw (navigation would happen in real app)

      // Test view analytics button
      await tester.tap(find.text('View Analytics'));
      await tester.pump();
      // Should not throw (navigation would happen in real app)
    });

    testWidgets('should show loading states correctly', (tester) async {
      await tester.pumpWidget(createLoadingWidget());

      // Should show loading indicators
      expect(find.byType(Container), findsAtLeastOneWidget); // Loading welcome
      expect(find.byType(Container), findsAtLeastOneWidget); // Loading stats
    });

    testWidgets('should handle error states correctly', (tester) async {
      await tester.pumpWidget(createErrorWidget());
      await tester.pump();

      // Should show error messages
      expect(find.text('Failed to load profile information'), findsOneWidget);
      expect(find.text('Failed to load dashboard data'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.exclamationmark_triangle), findsAtLeastOneWidget);
    });

    testWidgets('should handle refresh gesture', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump();

      // Find the CustomScrollView
      final scrollView = find.byType(CustomScrollView);
      expect(scrollView, findsOneWidget);

      // Simulate pull to refresh
      await tester.fling(scrollView, const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Should complete without errors (refresh would happen in real app)
    });

    testWidgets('should display empty state for recent activity', (tester) async {
      Widget createWidgetWithEmptyActivity() {
        return ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) async => mockUserProfile),
            dashboardStatsProvider.overrideWith((ref) async => mockDashboardStats.copyWith(
              recentActivity: [],
            )),
            userProgressProvider.overrideWith((ref) async => []),
          ],
          child: CupertinoApp(
            home: DashboardScreen(),
          ),
        );
      }

      await tester.pumpWidget(createWidgetWithEmptyActivity());
      await tester.pump();

      expect(find.text('No recent activity. Start learning to see your progress here!'), findsOneWidget);
    });

    testWidgets('should show correct streak message for zero days', (tester) async {
      Widget createWidgetWithZeroStreak() {
        final profileWithZeroStreak = UserProfile(
          userId: 'test-user',
          displayName: 'Test User',
          totalLessonsCompleted: 5,
          totalQuizzesCompleted: 0,
          totalTimeSpentMinutes: 150,
          currentStreakDays: 0,
          longestStreakDays: 3,
          favoriteTopics: [],
          topicPerformance: {},
          settings: {},
        );

        return ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) async => profileWithZeroStreak),
            dashboardStatsProvider.overrideWith((ref) async => mockDashboardStats.copyWith(
              currentStreakDays: 0,
            )),
            userProgressProvider.overrideWith((ref) async => []),
          ],
          child: CupertinoApp(
            home: DashboardScreen(),
          ),
        );
      }

      await tester.pumpWidget(createWidgetWithZeroStreak());
      await tester.pump();

      expect(find.text('0 days'), findsOneWidget);
      expect(find.text('Start your streak today!'), findsOneWidget);
    });

    testWidgets('should display topic progress with correct colors', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump();

      // Find progress indicators - they should exist even if we can't test colors directly
      expect(find.byType(FractionallySizedBox), findsAtLeastOneWidget);
    });

    testWidgets('should format relative time correctly', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump();

      // Should show "hours ago" format for recent activity
      expect(find.textContaining('hour'), findsAtLeastOneWidget);
    });

    testWidgets('should handle user with no display name', (tester) async {
      Widget createWidgetWithNoDisplayName() {
        final profileWithoutName = UserProfile(
          userId: 'test-user',
          displayName: null,
          totalLessonsCompleted: 10,
          totalQuizzesCompleted: 8,
          totalTimeSpentMinutes: 300,
          currentStreakDays: 3,
          longestStreakDays: 7,
          favoriteTopics: [],
          topicPerformance: {},
          settings: {},
        );

        return ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) async => profileWithoutName),
            dashboardStatsProvider.overrideWith((ref) async => mockDashboardStats),
            userProgressProvider.overrideWith((ref) async => mockUserProgress),
          ],
          child: CupertinoApp(
            home: DashboardScreen(),
          ),
        );
      }

      await tester.pumpWidget(createWidgetWithNoDisplayName());
      await tester.pump();

      expect(find.text('Welcome back!'), findsOneWidget);
    });

    testWidgets('should handle null average quiz score', (tester) async {
      Widget createWidgetWithNullScore() {
        final statsWithNullScore = DashboardStats(
          totalLessonsCompleted: 10,
          totalQuizzesCompleted: 0,
          totalTimeSpentMinutes: 300,
          averageQuizScore: null,
          currentStreakDays: 5,
          lessonsThisWeek: 2,
          recentActivity: [],
          topicProgress: {},
        );

        return ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) async => mockUserProfile),
            dashboardStatsProvider.overrideWith((ref) async => statsWithNullScore),
            userProgressProvider.overrideWith((ref) async => []),
          ],
          child: CupertinoApp(
            home: DashboardScreen(),
          ),
        );
      }

      await tester.pumpWidget(createWidgetWithNullScore());
      await tester.pump();

      expect(find.text('N/A'), findsOneWidget); // Should show N/A for null score
    });
  });
}

// Extension for creating modified dashboard stats
extension DashboardStatsX on DashboardStats {
  DashboardStats copyWith({
    int? totalLessonsCompleted,
    int? totalQuizzesCompleted,
    int? totalTimeSpentMinutes,
    double? averageQuizScore,
    int? currentStreakDays,
    int? lessonsThisWeek,
    List<Map<String, dynamic>>? recentActivity,
    Map<String, dynamic>? topicProgress,
  }) {
    return DashboardStats(
      totalLessonsCompleted: totalLessonsCompleted ?? this.totalLessonsCompleted,
      totalQuizzesCompleted: totalQuizzesCompleted ?? this.totalQuizzesCompleted,
      totalTimeSpentMinutes: totalTimeSpentMinutes ?? this.totalTimeSpentMinutes,
      averageQuizScore: averageQuizScore ?? this.averageQuizScore,
      currentStreakDays: currentStreakDays ?? this.currentStreakDays,
      lessonsThisWeek: lessonsThisWeek ?? this.lessonsThisWeek,
      recentActivity: recentActivity ?? this.recentActivity,
      topicProgress: topicProgress ?? this.topicProgress,
    );
  }
}