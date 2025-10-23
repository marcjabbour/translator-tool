import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:translator_tool/models/user_progress.dart';
import 'package:translator_tool/widgets/progress_tracker.dart';
import 'package:translator_tool/services/progress_service.dart';

// Mock progress service for testing
class MockProgressService extends ProgressService {
  final Map<String, UserProgress> _progressData = {};
  int _viewCount = 0;
  int _toggleCount = 0;

  MockProgressService() : super(baseUrl: 'http://test.com');

  @override
  Future<UserProgress> trackLessonView(String lessonId) async {
    _viewCount++;
    final progress = UserProgress(
      progressId: 'progress-$lessonId',
      userId: 'test-user',
      lessonId: lessonId,
      status: 'in_progress',
      timeSpentMinutes: 0,
      lessonViews: _viewCount,
      translationToggles: _toggleCount,
      quizTaken: false,
      quizAttempts: 0,
      lastAccessed: DateTime.now(),
    );
    _progressData[lessonId] = progress;
    return progress;
  }

  @override
  Future<UserProgress> trackTranslationToggle(String lessonId) async {
    _toggleCount++;
    final existing = _progressData[lessonId];
    final progress = UserProgress(
      progressId: existing?.progressId ?? 'progress-$lessonId',
      userId: 'test-user',
      lessonId: lessonId,
      status: existing?.status ?? 'in_progress',
      timeSpentMinutes: existing?.timeSpentMinutes ?? 0,
      lessonViews: existing?.lessonViews ?? 1,
      translationToggles: _toggleCount,
      quizTaken: false,
      quizAttempts: 0,
      lastAccessed: DateTime.now(),
    );
    _progressData[lessonId] = progress;
    return progress;
  }

  @override
  Future<UserProgress> updateLessonProgress(
    String lessonId,
    ProgressUpdateRequest updateData,
  ) async {
    final existing = _progressData[lessonId];
    final progress = UserProgress(
      progressId: existing?.progressId ?? 'progress-$lessonId',
      userId: 'test-user',
      lessonId: lessonId,
      status: updateData.status ?? existing?.status ?? 'not_started',
      timeSpentMinutes: updateData.timeSpentMinutes ?? existing?.timeSpentMinutes ?? 0,
      lessonViews: updateData.lessonViews ?? existing?.lessonViews ?? 0,
      translationToggles: updateData.translationToggles ?? existing?.translationToggles ?? 0,
      quizTaken: existing?.quizTaken ?? false,
      quizAttempts: existing?.quizAttempts ?? 0,
      lastAccessed: DateTime.now(),
    );
    _progressData[lessonId] = progress;
    return progress;
  }
}

void main() {
  group('ProgressTracker Widget', () {
    late MockProgressService mockService;

    setUp(() {
      mockService = MockProgressService();
    });

    Widget createWidget(String lessonId, {Function(UserProgress)? onProgressUpdate}) {
      return ProviderScope(
        overrides: [
          progressServiceProvider.overrideWithValue(mockService),
        ],
        child: CupertinoApp(
          home: ProgressTracker(
            lessonId: lessonId,
            onProgressUpdate: onProgressUpdate,
            child: CupertinoPageScaffold(
              child: Container(
                child: Text('Test Child'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('should track lesson view on init', (tester) async {
      bool progressUpdateCalled = false;
      UserProgress? receivedProgress;

      await tester.pumpWidget(createWidget(
        'lesson-123',
        onProgressUpdate: (progress) {
          progressUpdateCalled = true;
          receivedProgress = progress;
        },
      ));

      // Wait for the post frame callback
      await tester.pump();

      expect(progressUpdateCalled, true);
      expect(receivedProgress, isNotNull);
      expect(receivedProgress!.lessonId, 'lesson-123');
      expect(receivedProgress!.lessonViews, 1);
      expect(receivedProgress!.status, 'in_progress');
    });

    testWidgets('should display child content', (tester) async {
      await tester.pumpWidget(createWidget('lesson-123'));
      await tester.pump();

      expect(find.text('Test Child'), findsOneWidget);
    });

    testWidgets('should provide progress tracking scope', (tester) async {
      Widget testChild() {
        return Builder(
          builder: (context) {
            final tracker = ProgressTrackerScope.of(context);
            return Text(tracker != null ? 'Tracker Found' : 'No Tracker');
          },
        );
      }

      await tester.pumpWidget(ProviderScope(
        overrides: [
          progressServiceProvider.overrideWithValue(mockService),
        ],
        child: CupertinoApp(
          home: ProgressTracker(
            lessonId: 'lesson-123',
            child: testChild(),
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('Tracker Found'), findsOneWidget);
    });
  });

  group('LessonProgressIndicator Widget', () {
    late MockProgressService mockService;

    setUp(() {
      mockService = MockProgressService();
    });

    Widget createWidget(String lessonId, {bool compact = false}) {
      return ProviderScope(
        overrides: [
          progressServiceProvider.overrideWithValue(mockService),
          lessonProgressProvider(lessonId).overrideWith((ref, arg) async {
            // Mock progress data
            return UserProgress(
              progressId: 'progress-$lessonId',
              userId: 'test-user',
              lessonId: lessonId,
              status: 'completed',
              timeSpentMinutes: 25,
              lessonViews: 3,
              translationToggles: 5,
              quizTaken: true,
              quizAttempts: 1,
              lastAccessed: DateTime.now(),
            );
          }),
        ],
        child: CupertinoApp(
          home: CupertinoPageScaffold(
            child: LessonProgressIndicator(
              lessonId: lessonId,
              compact: compact,
            ),
          ),
        ),
      );
    }

    Widget createWidgetWithNoProgress(String lessonId) {
      return ProviderScope(
        overrides: [
          progressServiceProvider.overrideWithValue(mockService),
          lessonProgressProvider(lessonId).overrideWith((ref, arg) async {
            return null; // No progress
          }),
        ],
        child: CupertinoApp(
          home: CupertinoPageScaffold(
            child: LessonProgressIndicator(lessonId: lessonId),
          ),
        ),
      );
    }

    testWidgets('should show completed status', (tester) async {
      await tester.pumpWidget(createWidget('lesson-123'));
      await tester.pump(); // Complete the future

      expect(find.text('Completed'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.checkmark_circle_fill), findsOneWidget);
    });

    testWidgets('should show not started status when no progress', (tester) async {
      await tester.pumpWidget(createWidgetWithNoProgress('lesson-123'));
      await tester.pump();

      expect(find.text('Not Started'), findsOneWidget);
    });

    testWidgets('should show compact view when requested', (tester) async {
      await tester.pumpWidget(createWidget('lesson-123', compact: true));
      await tester.pump();

      // In compact mode, should only show icon, not text
      expect(find.byIcon(CupertinoIcons.checkmark_circle_fill), findsOneWidget);
      expect(find.text('Completed'), findsNothing);
    });

    testWidgets('should show loading state initially', (tester) async {
      await tester.pumpWidget(createWidget('lesson-123'));

      // Before the future completes
      expect(find.byType(Container), findsAtLeastOneWidget); // Loading indicator
    });

    testWidgets('should handle different progress states', (tester) async {
      Widget createWidgetWithStatus(String status) {
        return ProviderScope(
          overrides: [
            progressServiceProvider.overrideWithValue(mockService),
            lessonProgressProvider('lesson-123').overrideWith((ref, arg) async {
              return UserProgress(
                progressId: 'progress-123',
                userId: 'test-user',
                lessonId: 'lesson-123',
                status: status,
                timeSpentMinutes: 15,
                lessonViews: 2,
                translationToggles: 3,
                quizTaken: false,
                quizAttempts: 0,
                lastAccessed: DateTime.now(),
              );
            }),
          ],
          child: CupertinoApp(
            home: CupertinoPageScaffold(
              child: LessonProgressIndicator(lessonId: 'lesson-123'),
            ),
          ),
        );
      }

      // Test in_progress status
      await tester.pumpWidget(createWidgetWithStatus('in_progress'));
      await tester.pump();
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.clock_fill), findsOneWidget);

      // Test not_started status (but with some data)
      await tester.pumpWidget(createWidgetWithStatus('not_started'));
      await tester.pump();
      expect(find.text('Started'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.play_circle_fill), findsOneWidget);
    });
  });

  group('ProgressStatsSummary Widget', () {
    late MockProgressService mockService;

    setUp(() {
      mockService = MockProgressService();
    });

    Widget createWidget({bool showDetails = false}) {
      return ProviderScope(
        overrides: [
          progressServiceProvider.overrideWithValue(mockService),
          userProfileProvider.overrideWith((ref) async {
            return UserProfile(
              userId: 'test-user',
              displayName: 'Test User',
              totalLessonsCompleted: 15,
              totalQuizzesCompleted: 12,
              totalTimeSpentMinutes: 450,
              averageQuizScore: 0.85,
              currentStreakDays: 7,
              longestStreakDays: 14,
              favoriteTopics: ['greetings', 'food'],
              topicPerformance: {},
              settings: {},
            );
          }),
        ],
        child: CupertinoApp(
          home: CupertinoPageScaffold(
            child: ProgressStatsSummary(showDetails: showDetails),
          ),
        ),
      );
    }

    Widget createLoadingWidget() {
      return ProviderScope(
        overrides: [
          progressServiceProvider.overrideWithValue(mockService),
          userProfileProvider.overrideWith((ref) async {
            // Simulate loading by never completing
            await Future.delayed(Duration(seconds: 10));
            return UserProfile(
              userId: 'test-user',
              totalLessonsCompleted: 0,
              totalQuizzesCompleted: 0,
              totalTimeSpentMinutes: 0,
              currentStreakDays: 0,
              longestStreakDays: 0,
              favoriteTopics: [],
              topicPerformance: {},
              settings: {},
            );
          }),
        ],
        child: CupertinoApp(
          home: CupertinoPageScaffold(
            child: ProgressStatsSummary(),
          ),
        ),
      );
    }

    testWidgets('should display user stats summary', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump(); // Complete the future

      expect(find.text('15'), findsOneWidget); // Lessons
      expect(find.text('Lessons'), findsOneWidget);
      expect(find.text('7d'), findsOneWidget); // Streak
      expect(find.text('Streak'), findsOneWidget);
      expect(find.text('85%'), findsOneWidget); // Avg Score
      expect(find.text('Avg Score'), findsOneWidget);
    });

    testWidgets('should show loading state', (tester) async {
      await tester.pumpWidget(createLoadingWidget());

      // Should show loading summary with placeholder containers
      expect(find.byType(Container), findsAtLeastOneWidget);
    });

    testWidgets('should handle stats formatting correctly', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump();

      // Verify that the stats are properly formatted
      expect(find.text('15'), findsOneWidget); // Lessons count
      expect(find.text('7d'), findsOneWidget); // Streak with 'd' suffix
      expect(find.text('85%'), findsOneWidget); // Score with '%' suffix
    });
  });

  group('Progress Tracking Context Extensions', () {
    testWidgets('should provide context extensions', (tester) async {
      final mockService = MockProgressService();
      bool toggleCalled = false;
      bool completedCalled = false;

      Widget testWidget() {
        return Builder(
          builder: (context) {
            return Column(
              children: [
                CupertinoButton(
                  onPressed: () async {
                    await context.trackTranslationToggle();
                    toggleCalled = true;
                  },
                  child: Text('Toggle'),
                ),
                CupertinoButton(
                  onPressed: () async {
                    await context.markLessonCompleted();
                    completedCalled = true;
                  },
                  child: Text('Complete'),
                ),
              ],
            );
          },
        );
      }

      await tester.pumpWidget(ProviderScope(
        overrides: [
          progressServiceProvider.overrideWithValue(mockService),
        ],
        child: CupertinoApp(
          home: ProgressTracker(
            lessonId: 'lesson-123',
            child: testWidget(),
          ),
        ),
      ));
      await tester.pump();

      // Test translation toggle
      await tester.tap(find.text('Toggle'));
      await tester.pump();
      expect(toggleCalled, true);

      // Test lesson completion
      await tester.tap(find.text('Complete'));
      await tester.pump();
      expect(completedCalled, true);
    });

    testWidgets('should handle missing tracker gracefully', (tester) async {
      Widget testWidget() {
        return Builder(
          builder: (context) {
            return CupertinoButton(
              onPressed: () async {
                // This should not throw even without ProgressTracker
                await context.trackTranslationToggle();
              },
              child: Text('Toggle Without Tracker'),
            );
          },
        );
      }

      await tester.pumpWidget(CupertinoApp(
        home: CupertinoPageScaffold(
          child: testWidget(),
        ),
      ));

      // Should not throw when tapping without tracker
      await tester.tap(find.text('Toggle Without Tracker'));
      await tester.pump();
      // Test passes if no exception is thrown
    });
  });
}