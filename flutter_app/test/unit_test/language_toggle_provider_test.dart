import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../lib/models/lesson.dart';
import '../../lib/providers/language_toggle_provider.dart';

void main() {
  group('LanguageToggleState Tests', () {
    test('should create initial state correctly', () {
      final state = LanguageToggleState.initial();

      expect(state.currentMode, LanguageMode.english);
      expect(state.position.scrollOffset, 0.0);
      expect(state.isToggling, false);
    });

    test('should copy state with updated properties', () {
      final originalState = LanguageToggleState.initial();

      final updatedState = originalState.copyWith(
        currentMode: LanguageMode.arabic,
        isToggling: true,
      );

      expect(updatedState.currentMode, LanguageMode.arabic);
      expect(updatedState.isToggling, true);
      expect(updatedState.position, originalState.position); // Unchanged
    });

    test('should maintain equality based on content', () {
      final state1 = LanguageToggleState.initial();
      final state2 = LanguageToggleState.initial();

      expect(state1, state2);

      final state3 = state1.copyWith(currentMode: LanguageMode.arabic);
      expect(state1, isNot(state3));
    });
  });

  group('LanguageToggleNotifier Tests', () {
    late ProviderContainer container;
    late LanguageToggleNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(languageToggleProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('should start with initial state', () {
      final state = container.read(languageToggleProvider);

      expect(state.currentMode, LanguageMode.english);
      expect(state.isToggling, false);
      expect(state.position.scrollOffset, 0.0);
    });

    test('should toggle language mode correctly', () async {
      // Initial state should be English
      expect(container.read(languageToggleProvider).currentMode, LanguageMode.english);

      // Toggle to Arabic
      await notifier.toggleLanguage(scrollOffset: 100.0);

      final state = container.read(languageToggleProvider);
      expect(state.currentMode, LanguageMode.arabic);
      expect(state.position.scrollOffset, 100.0);
      expect(state.isToggling, false); // Should complete toggle
    });

    test('should preserve position during toggle', () async {
      await notifier.toggleLanguage(
        scrollOffset: 150.0,
        textCursorPosition: 25,
        selectionStart: 10,
        selectionEnd: 20,
      );

      final state = container.read(languageToggleProvider);
      expect(state.position.scrollOffset, 150.0);
      expect(state.position.textCursorPosition, 25);
      expect(state.position.selectionStart, 10);
      expect(state.position.selectionEnd, 20);
    });

    test('should update position without toggling', () {
      notifier.updatePosition(
        scrollOffset: 200.0,
        textCursorPosition: 50,
      );

      final state = container.read(languageToggleProvider);
      expect(state.currentMode, LanguageMode.english); // Should not change
      expect(state.position.scrollOffset, 200.0);
      expect(state.position.textCursorPosition, 50);
    });

    test('should set specific language mode', () {
      notifier.setLanguageMode(LanguageMode.arabic);

      final state = container.read(languageToggleProvider);
      expect(state.currentMode, LanguageMode.arabic);
    });

    test('should not update if same language mode is set', () {
      final initialTime = container.read(languageToggleProvider).lastToggleTime;

      // Set same mode
      notifier.setLanguageMode(LanguageMode.english);

      final newTime = container.read(languageToggleProvider).lastToggleTime;
      expect(newTime, initialTime); // Should not update timestamp
    });

    test('should reset to initial state', () {
      // Change state first
      notifier.setLanguageMode(LanguageMode.arabic);
      notifier.updatePosition(scrollOffset: 100.0);

      // Reset
      notifier.reset();

      final state = container.read(languageToggleProvider);
      expect(state.currentMode, LanguageMode.english);
      expect(state.position.scrollOffset, 0.0);
      expect(state.isToggling, false);
    });

    test('should track recent toggle correctly', () {
      // Initially not recent
      expect(notifier.isRecentToggle, false);

      // After setting mode, should be recent
      notifier.setLanguageMode(LanguageMode.arabic);
      expect(notifier.isRecentToggle, true);
    });
  });

  group('Provider Convenience Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should provide current language mode correctly', () {
      final currentMode = container.read(currentLanguageModeProvider);
      expect(currentMode, LanguageMode.english);

      // Change mode
      container.read(languageToggleProvider.notifier).setLanguageMode(LanguageMode.arabic);

      final updatedMode = container.read(currentLanguageModeProvider);
      expect(updatedMode, LanguageMode.arabic);
    });

    test('should provide content position correctly', () {
      final position = container.read(contentPositionProvider);
      expect(position.scrollOffset, 0.0);

      // Update position
      container.read(languageToggleProvider.notifier).updatePosition(scrollOffset: 150.0);

      final updatedPosition = container.read(contentPositionProvider);
      expect(updatedPosition.scrollOffset, 150.0);
    });

    test('should provide toggling state correctly', () {
      final isToggling = container.read(isTogglingProvider);
      expect(isToggling, false);
    });

    test('should provide toggle performance metrics', () {
      final performance = container.read(togglePerformanceProvider);

      expect(performance['current_mode'], 'en');
      expect(performance['is_within_budget'], true);
      expect(performance.containsKey('last_toggle_time'), true);
      expect(performance.containsKey('time_since_toggle_ms'), true);
    });

    test('should provide lesson content based on current mode', () {
      final lesson = Lesson(
        lessonId: 'test-id',
        topic: 'test',
        level: 'beginner',
        enText: 'Hello world',
        laText: 'ahlan ya dunya',
        meta: {},
        createdAt: DateTime.now(),
      );

      // Initial mode (English)
      final englishContent = container.read(lessonContentProvider(lesson));
      expect(englishContent, 'Hello world');

      // Switch to Arabic
      container.read(languageToggleProvider.notifier).setLanguageMode(LanguageMode.arabic);

      final arabicContent = container.read(lessonContentProvider(lesson));
      expect(arabicContent, 'ahlan ya dunya');
    });

    test('should check if lesson supports toggle', () {
      final completeLesson = Lesson(
        lessonId: 'test-id',
        topic: 'test',
        level: 'beginner',
        enText: 'Hello',
        laText: 'ahlan',
        meta: {},
        createdAt: DateTime.now(),
      );

      final incompleteLesson = Lesson(
        lessonId: 'test-id-2',
        topic: 'test',
        level: 'beginner',
        enText: 'Hello',
        laText: '',
        meta: {},
        createdAt: DateTime.now(),
      );

      final supportsToggleComplete = container.read(lessonSupportsToggleProvider(completeLesson));
      final supportsToggleIncomplete = container.read(lessonSupportsToggleProvider(incompleteLesson));

      expect(supportsToggleComplete, true);
      expect(supportsToggleIncomplete, false);
    });
  });

  group('Performance Tests', () {
    late ProviderContainer container;
    late LanguageToggleNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(languageToggleProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('should meet toggle latency requirement', () async {
      final stopwatch = Stopwatch()..start();

      await notifier.toggleLanguage();

      stopwatch.stop();

      // Should complete well under 200ms requirement
      expect(stopwatch.elapsedMilliseconds, lessThan(200));
    });

    test('should handle rapid toggles gracefully', () async {
      // Perform multiple rapid toggles
      final futures = <Future<void>>[];
      for (int i = 0; i < 5; i++) {
        futures.add(notifier.toggleLanguage());
      }

      // Wait for all toggles to complete
      await Future.wait(futures);

      final state = container.read(languageToggleProvider);
      expect(state.isToggling, false); // Should not be stuck in toggling state
    });

    test('should track performance metrics accurately', () async {
      // Perform toggle and check metrics
      await notifier.toggleLanguage();

      final performance = container.read(togglePerformanceProvider);
      final timeSinceToggle = performance['time_since_toggle_ms'] as int;

      expect(timeSinceToggle, lessThan(100)); // Should be very recent
      expect(performance['is_within_budget'], true);
    });
  });
}