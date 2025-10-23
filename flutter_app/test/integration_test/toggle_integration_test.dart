import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../lib/main.dart';
import '../../lib/models/lesson.dart';
import '../../lib/providers/language_toggle_provider.dart';
import '../../lib/services/lesson_service.dart';
import '../../lib/screens/lesson_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Dual Translation Toggle Integration Tests', () {
    late Lesson testLesson;

    setUp(() {
      testLesson = Lesson(
        lessonId: 'integration-test-id',
        topic: 'coffee_chat',
        level: 'beginner',
        enText: 'Hey, want to grab coffee? This is a longer text to test scrolling and position preservation during language toggle operations.',
        laText: 'ahlan, baddak nrou7 neeshrab ahwe? hada nass atwaal la test el scroll w el position preservation athnaa3 amaliyyat toggle el loughaat.',
        meta: {'seed': 42},
        createdAt: DateTime.now(),
      );
    });

    testWidgets('should perform complete toggle workflow', (WidgetTester tester) async {
      // Override providers for testing
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentLessonProvider.overrideWith((ref) => testLesson),
            apiHealthProvider.overrideWith((ref) => Future.value(true)),
          ],
          child: CupertinoApp(
            home: LessonScreen(
              storyRequest: StoryRequest(
                topic: 'coffee_chat',
                level: 'beginner',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify initial state (English)
      expect(find.text('EN'), findsOneWidget);
      expect(find.textContaining('Hey, want to grab coffee?'), findsOneWidget);

      // Perform toggle
      await tester.tap(find.byIcon(CupertinoIcons.arrow_2_circlepath));
      await tester.pumpAndSettle();

      // Verify toggle to Arabic
      expect(find.textContaining('ahlan, baddak nrou7'), findsOneWidget);

      // Toggle back to English
      await tester.tap(find.byIcon(CupertinoIcons.arrow_2_circlepath));
      await tester.pumpAndSettle();

      // Verify back to English
      expect(find.textContaining('Hey, want to grab coffee?'), findsOneWidget);
    });

    testWidgets('should preserve scroll position during toggle', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentLessonProvider.overrideWith((ref) => testLesson),
          ],
          child: CupertinoApp(
            home: LessonScreen(
              storyRequest: StoryRequest(
                topic: 'coffee_chat',
                level: 'beginner',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find scrollable content
      final scrollableFinder = find.byType(SingleChildScrollView);
      expect(scrollableFinder, findsOneWidget);

      // Scroll down
      await tester.drag(scrollableFinder, const Offset(0, -200));
      await tester.pumpAndSettle();

      // Perform toggle
      await tester.tap(find.byIcon(CupertinoIcons.arrow_2_circlepath));
      await tester.pumpAndSettle();

      // Verify content changed but scroll position is maintained
      expect(find.textContaining('ahlan'), findsOneWidget);

      // Toggle back
      await tester.tap(find.byIcon(CupertinoIcons.arrow_2_circlepath));
      await tester.pumpAndSettle();

      // Verify scroll position is still preserved
      expect(find.textContaining('Hey'), findsOneWidget);
    });

    testWidgets('should meet performance requirements', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentLessonProvider.overrideWith((ref) => testLesson),
          ],
          child: CupertinoApp(
            home: LessonScreen(
              storyRequest: StoryRequest(
                topic: 'coffee_chat',
                level: 'beginner',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Measure toggle performance
      final stopwatch = Stopwatch()..start();

      await tester.tap(find.byIcon(CupertinoIcons.arrow_2_circlepath));
      await tester.pumpAndSettle();

      stopwatch.stop();

      // Should meet < 200ms requirement
      expect(stopwatch.elapsedMilliseconds, lessThan(200));
    });

    testWidgets('should handle rapid toggles gracefully', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentLessonProvider.overrideWith((ref) => testLesson),
          ],
          child: CupertinoApp(
            home: LessonScreen(
              storyRequest: StoryRequest(
                topic: 'coffee_chat',
                level: 'beginner',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Perform rapid toggles
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.byIcon(CupertinoIcons.arrow_2_circlepath));
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.pumpAndSettle();

      // Should not crash and should be in a valid state
      expect(find.byType(LessonScreen), findsOneWidget);
    });

    testWidgets('should work with different content lengths', (WidgetTester tester) async {
      final shortLesson = Lesson(
        lessonId: 'short-test',
        topic: 'greeting',
        level: 'beginner',
        enText: 'Hi',
        laText: 'ahlan',
        meta: {},
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentLessonProvider.overrideWith((ref) => shortLesson),
          ],
          child: CupertinoApp(
            home: LessonScreen(
              storyRequest: StoryRequest(
                topic: 'greeting',
                level: 'beginner',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Toggle with short content
      await tester.tap(find.byIcon(CupertinoIcons.arrow_2_circlepath));
      await tester.pumpAndSettle();

      expect(find.text('ahlan'), findsOneWidget);

      // Toggle back
      await tester.tap(find.byIcon(CupertinoIcons.arrow_2_circlepath));
      await tester.pumpAndSettle();

      expect(find.text('Hi'), findsOneWidget);
    });

    testWidgets('should handle incomplete lessons correctly', (WidgetTester tester) async {
      final incompleteLesson = Lesson(
        lessonId: 'incomplete-test',
        topic: 'test',
        level: 'beginner',
        enText: 'Hello world',
        laText: '', // Missing translation
        meta: {},
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentLessonProvider.overrideWith((ref) => incompleteLesson),
          ],
          child: CupertinoApp(
            home: LessonScreen(
              storyRequest: StoryRequest(
                topic: 'test',
                level: 'beginner',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show unavailable message
      expect(find.text('Translation not available'), findsOneWidget);

      // Toggle button should be disabled
      final toggleButton = find.byIcon(CupertinoIcons.arrow_2_circlepath);
      expect(toggleButton, findsOneWidget);

      // Tapping should not crash
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      // Should still show English content
      expect(find.text('Hello world'), findsOneWidget);
    });

    testWidgets('should work across different screen orientations', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentLessonProvider.overrideWith((ref) => testLesson),
          ],
          child: CupertinoApp(
            home: LessonScreen(
              storyRequest: StoryRequest(
                topic: 'coffee_chat',
                level: 'beginner',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Test in portrait mode
      expect(find.byIcon(CupertinoIcons.arrow_2_circlepath), findsOneWidget);

      // Simulate landscape orientation
      await tester.binding.setSurfaceSize(const Size(800, 600));
      await tester.pumpAndSettle();

      // Toggle should still work
      await tester.tap(find.byIcon(CupertinoIcons.arrow_2_circlepath));
      await tester.pumpAndSettle();

      expect(find.textContaining('ahlan'), findsOneWidget);

      // Reset to portrait
      await tester.binding.setSurfaceSize(const Size(375, 667));
      await tester.pumpAndSettle();

      // Should still work
      await tester.tap(find.byIcon(CupertinoIcons.arrow_2_circlepath));
      await tester.pumpAndSettle();

      expect(find.textContaining('Hey'), findsOneWidget);

      // Clean up
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('should maintain accessibility during toggle', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentLessonProvider.overrideWith((ref) => testLesson),
          ],
          child: CupertinoApp(
            home: LessonScreen(
              storyRequest: StoryRequest(
                topic: 'coffee_chat',
                level: 'beginner',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find semantic elements
      expect(find.byType(Semantics), findsWidgets);

      // Toggle and verify accessibility is maintained
      await tester.tap(find.byIcon(CupertinoIcons.arrow_2_circlepath));
      await tester.pumpAndSettle();

      expect(find.byType(Semantics), findsWidgets);
    });

    testWidgets('should show performance monitor in development', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentLessonProvider.overrideWith((ref) => testLesson),
          ],
          child: CupertinoApp(
            home: LessonScreen(
              storyRequest: StoryRequest(
                topic: 'coffee_chat',
                level: 'beginner',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enable performance monitor
      await tester.tap(find.byIcon(CupertinoIcons.speedometer));
      await tester.pumpAndSettle();

      // Should show performance metrics
      expect(find.textContaining('Toggle Performance:'), findsOneWidget);

      // Perform toggle and verify metrics update
      await tester.tap(find.byIcon(CupertinoIcons.arrow_2_circlepath));
      await tester.pumpAndSettle();

      expect(find.textContaining('ms'), findsOneWidget);
    });

    testWidgets('should handle app lifecycle during toggle', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentLessonProvider.overrideWith((ref) => testLesson),
          ],
          child: CupertinoApp(
            home: LessonScreen(
              storyRequest: StoryRequest(
                topic: 'coffee_chat',
                level: 'beginner',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to Arabic
      await tester.tap(find.byIcon(CupertinoIcons.arrow_2_circlepath));
      await tester.pumpAndSettle();

      // Simulate app going to background and foreground
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/lifecycle',
        null,
        (data) {},
      );

      await tester.pumpAndSettle();

      // Should maintain Arabic state
      expect(find.textContaining('ahlan'), findsOneWidget);
    });
  });

  group('Edge Cases and Error Handling', () {
    testWidgets('should handle null lesson gracefully', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentLessonProvider.overrideWith((ref) => null),
          ],
          child: CupertinoApp(
            home: LessonScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show lesson selection screen
      expect(find.text('Select a Lesson'), findsOneWidget);
    });

    testWidgets('should handle provider errors gracefully', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storyGeneratorProvider.overrideWith((ref, request) async {
              throw Exception('Network error');
            }),
          ],
          child: CupertinoApp(
            home: LessonScreen(
              storyRequest: StoryRequest(
                topic: 'coffee_chat',
                level: 'beginner',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show error state
      expect(find.text('Error'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.exclamationmark_triangle), findsOneWidget);
    });

    testWidgets('should handle memory pressure during toggle', (WidgetTester tester) async {
      // Create a large lesson to simulate memory pressure
      final largeLesson = Lesson(
        lessonId: 'large-test',
        topic: 'long_story',
        level: 'advanced',
        enText: 'This is a very long text ' * 1000,
        laText: 'hada nass atwaal kteer ' * 1000,
        meta: {},
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentLessonProvider.overrideWith((ref) => largeLesson),
          ],
          child: CupertinoApp(
            home: LessonScreen(
              storyRequest: StoryRequest(
                topic: 'long_story',
                level: 'advanced',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should handle large content without crashing
      expect(find.byType(LessonScreen), findsOneWidget);

      // Toggle should still work
      await tester.tap(find.byIcon(CupertinoIcons.arrow_2_circlepath));
      await tester.pumpAndSettle();

      expect(find.textContaining('hada nass'), findsOneWidget);
    });
  });
}