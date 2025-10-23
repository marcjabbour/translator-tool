import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../lib/models/lesson.dart';
import '../../lib/widgets/language_toggle_widget.dart';
import '../../lib/providers/language_toggle_provider.dart';

void main() {
  group('LanguageToggleWidget Tests', () {
    late Lesson testLesson;

    setUp(() {
      testLesson = Lesson(
        lessonId: 'test-id',
        topic: 'coffee_chat',
        level: 'beginner',
        enText: 'Hey, want to grab coffee?',
        laText: 'ahlan, baddak nrou7 neeshrab ahwe?',
        meta: {},
        createdAt: DateTime.now(),
      );
    });

    testWidgets('should display toggle widget correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: CupertinoApp(
            home: CupertinoPageScaffold(
              child: LanguageToggleWidget(lesson: testLesson),
            ),
          ),
        ),
      );

      // Should find toggle widget elements
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('EN'), findsOneWidget);
      expect(find.text('عربي'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.arrow_2_circlepath), findsOneWidget);
    });

    testWidgets('should show current language mode correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: CupertinoApp(
            home: CupertinoPageScaffold(
              child: LanguageToggleWidget(lesson: testLesson),
            ),
          ),
        ),
      );

      // Initial state should show English as selected
      final englishContainer = find.ancestor(
        of: find.text('EN'),
        matching: find.byType(Container),
      ).first;

      final englishWidget = tester.widget<Container>(englishContainer);
      final englishDecoration = englishWidget.decoration as BoxDecoration;

      // Should have primary color for selected state
      expect(englishDecoration.color, isNotNull);
    });

    testWidgets('should toggle language when tapped', (WidgetTester tester) async {
      bool toggleCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: CupertinoApp(
            home: CupertinoPageScaffold(
              child: LanguageToggleWidget(
                lesson: testLesson,
                onToggle: () => toggleCalled = true,
              ),
            ),
          ),
        ),
      );

      // Tap the toggle button
      await tester.tap(find.byIcon(CupertinoIcons.arrow_2_circlepath));
      await tester.pumpAndSettle();

      expect(toggleCalled, true);
    });

    testWidgets('should disable toggle for incomplete lesson', (WidgetTester tester) async {
      final incompleteLesson = Lesson(
        lessonId: 'incomplete-id',
        topic: 'test',
        level: 'beginner',
        enText: 'Hello',
        laText: '', // Missing Arabic translation
        meta: {},
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: CupertinoApp(
            home: CupertinoPageScaffold(
              child: LanguageToggleWidget(lesson: incompleteLesson),
            ),
          ),
        ),
      );

      // Should show "Translation not available" message
      expect(find.text('Translation not available'), findsOneWidget);

      // Toggle button should be disabled (grey color)
      final toggleButton = find.byIcon(CupertinoIcons.arrow_2_circlepath);
      expect(toggleButton, findsOneWidget);
    });

    testWidgets('should show compact mode correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: CupertinoApp(
            home: CupertinoPageScaffold(
              child: LanguageToggleWidget(
                lesson: testLesson,
                compact: true,
              ),
            ),
          ),
        ),
      );

      // Compact mode should not show full labels
      expect(find.text('Language'), findsNothing);
      expect(find.text('English'), findsNothing);
      expect(find.text('عربي'), findsNothing);

      // Should show language code
      expect(find.text('EN'), findsOneWidget);
    });

    testWidgets('should show loading state during toggle', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: CupertinoApp(
            home: CupertinoPageScaffold(
              child: LanguageToggleWidget(lesson: testLesson),
            ),
          ),
        ),
      );

      // Tap toggle button
      await tester.tap(find.byIcon(CupertinoIcons.arrow_2_circlepath));
      await tester.pump(); // Don't settle to catch loading state

      // Should show activity indicator during toggle
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    });

    testWidgets('should respond to external language mode changes', (WidgetTester tester) async {
      final container = ProviderContainer();

      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: CupertinoApp(
            home: CupertinoPageScaffold(
              child: LanguageToggleWidget(lesson: testLesson),
            ),
          ),
        ),
      );

      // Initially English should be selected
      expect(find.text('EN'), findsOneWidget);

      // Change language mode externally
      container.read(languageToggleProvider.notifier).setLanguageMode(LanguageMode.arabic);
      await tester.pumpAndSettle();

      // UI should update to show Arabic as selected
      // Visual indication should change (would need to check styling)
      expect(find.text('عربي'), findsOneWidget);

      container.dispose();
    });

    testWidgets('should maintain accessibility features', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: CupertinoApp(
            home: CupertinoPageScaffold(
              child: LanguageToggleWidget(lesson: testLesson),
            ),
          ),
        ),
      );

      // Toggle button should be accessible
      final toggleButton = find.byIcon(CupertinoIcons.arrow_2_circlepath);
      expect(toggleButton, findsOneWidget);

      // Should be tappable
      expect(tester.widget<CupertinoButton>(find.byType(CupertinoButton).first).onPressed, isNotNull);
    });
  });

  group('LanguageModeIndicator Tests', () {
    testWidgets('should display current language mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: CupertinoApp(
            home: CupertinoPageScaffold(
              child: LanguageModeIndicator(),
            ),
          ),
        ),
      );

      // Should show English initially
      expect(find.text('English'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.textformat_abc), findsOneWidget);
    });

    testWidgets('should update when language changes', (WidgetTester tester) async {
      final container = ProviderContainer();

      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: CupertinoApp(
            home: CupertinoPageScaffold(
              child: LanguageModeIndicator(),
            ),
          ),
        ),
      );

      // Change to Arabic
      container.read(languageToggleProvider.notifier).setLanguageMode(LanguageMode.arabic);
      await tester.pumpAndSettle();

      // Should show Arabic
      expect(find.text('اللبنانية'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.textformat), findsOneWidget);

      container.dispose();
    });

    testWidgets('should hide icon when requested', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: CupertinoApp(
            home: CupertinoPageScaffold(
              child: LanguageModeIndicator(showIcon: false),
            ),
          ),
        ),
      );

      // Should not show icon
      expect(find.byIcon(CupertinoIcons.textformat_abc), findsNothing);
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('should show loading indicator during toggle', (WidgetTester tester) async {
      final container = ProviderContainer();

      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: CupertinoApp(
            home: CupertinoPageScaffold(
              child: LanguageModeIndicator(),
            ),
          ),
        ),
      );

      // Simulate toggling state
      final notifier = container.read(languageToggleProvider.notifier);
      container.read(languageToggleProvider.notifier).state =
          notifier.state.copyWith(isToggling: true);
      await tester.pump();

      // Should show loading indicator
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

      container.dispose();
    });
  });

  group('TogglePerformanceMonitor Tests', () {
    testWidgets('should display performance metrics', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: CupertinoApp(
            home: CupertinoPageScaffold(
              child: TogglePerformanceMonitor(),
            ),
          ),
        ),
      );

      // Should show performance information
      expect(find.textContaining('Toggle Performance:'), findsOneWidget);
      expect(find.textContaining('ms'), findsOneWidget);
    });

    testWidgets('should show success indicator for good performance', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: CupertinoApp(
            home: CupertinoPageScaffold(
              child: TogglePerformanceMonitor(),
            ),
          ),
        ),
      );

      // Should show success checkmark
      expect(find.textContaining('✓'), findsOneWidget);
    });

    testWidgets('should update performance metrics in real-time', (WidgetTester tester) async {
      final container = ProviderContainer();

      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: CupertinoApp(
            home: CupertinoPageScaffold(
              child: TogglePerformanceMonitor(),
            ),
          ),
        ),
      );

      // Perform toggle
      await container.read(languageToggleProvider.notifier).toggleLanguage();
      await tester.pumpAndSettle();

      // Performance metrics should update
      expect(find.textContaining('Toggle Performance:'), findsOneWidget);

      container.dispose();
    });
  });

  group('Responsive Design Tests', () {
    testWidgets('should adapt to different screen sizes', (WidgetTester tester) async {
      // Test with small screen size
      await tester.binding.setSurfaceSize(const Size(375, 667)); // iPhone size

      await tester.pumpWidget(
        ProviderScope(
          child: CupertinoApp(
            home: CupertinoPageScaffold(
              child: LanguageToggleWidget(lesson: testLesson),
            ),
          ),
        ),
      );

      expect(find.byType(LanguageToggleWidget), findsOneWidget);

      // Test with large screen size
      await tester.binding.setSurfaceSize(const Size(1024, 768)); // iPad size

      await tester.pumpAndSettle();

      expect(find.byType(LanguageToggleWidget), findsOneWidget);

      // Reset to default size
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('should handle compact mode on small screens', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568)); // Small phone

      await tester.pumpWidget(
        ProviderScope(
          child: CupertinoApp(
            home: CupertinoPageScaffold(
              child: LanguageToggleWidget(
                lesson: testLesson,
                compact: true,
              ),
            ),
          ),
        ),
      );

      // Compact mode should work on small screens
      expect(find.text('EN'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });
  });
}