import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lesson.dart';

/// State class for managing dual language toggle functionality
class LanguageToggleState {
  final LanguageMode currentMode;
  final ContentPosition position;
  final bool isToggling;
  final DateTime lastToggleTime;

  const LanguageToggleState({
    required this.currentMode,
    required this.position,
    this.isToggling = false,
    required this.lastToggleTime,
  });

  /// Create initial state
  factory LanguageToggleState.initial() {
    return LanguageToggleState(
      currentMode: LanguageMode.english,
      position: ContentPosition.initial(),
      isToggling: false,
      lastToggleTime: DateTime.now(),
    );
  }

  /// Copy state with updated properties
  LanguageToggleState copyWith({
    LanguageMode? currentMode,
    ContentPosition? position,
    bool? isToggling,
    DateTime? lastToggleTime,
  }) {
    return LanguageToggleState(
      currentMode: currentMode ?? this.currentMode,
      position: position ?? this.position,
      isToggling: isToggling ?? this.isToggling,
      lastToggleTime: lastToggleTime ?? this.lastToggleTime,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LanguageToggleState &&
        other.currentMode == currentMode &&
        other.position == position &&
        other.isToggling == isToggling;
  }

  @override
  int get hashCode => Object.hash(currentMode, position, isToggling);

  @override
  String toString() {
    return 'LanguageToggleState(mode: $currentMode, toggling: $isToggling, position: $position)';
  }
}

/// Notifier for managing language toggle state and operations
class LanguageToggleNotifier extends StateNotifier<LanguageToggleState> {
  LanguageToggleNotifier() : super(LanguageToggleState.initial());

  /// Toggle between English and Arabic with position preservation
  Future<void> toggleLanguage({
    double? scrollOffset,
    int? textCursorPosition,
    int? selectionStart,
    int? selectionEnd,
  }) async {
    // Start toggle animation
    state = state.copyWith(isToggling: true);

    // Capture current position
    final currentPosition = ContentPosition(
      scrollOffset: scrollOffset ?? state.position.scrollOffset,
      textCursorPosition: textCursorPosition,
      selectionStart: selectionStart,
      selectionEnd: selectionEnd,
      timestamp: DateTime.now(),
    );

    // Small delay to ensure smooth UI transition (under 200ms requirement)
    await Future.delayed(const Duration(milliseconds: 50));

    // Toggle to new language mode
    final newMode = state.currentMode.toggle;

    // Update state with new mode and preserved position
    state = state.copyWith(
      currentMode: newMode,
      position: currentPosition,
      isToggling: false,
      lastToggleTime: DateTime.now(),
    );
  }

  /// Update content position without toggling language
  void updatePosition({
    double? scrollOffset,
    int? textCursorPosition,
    int? selectionStart,
    int? selectionEnd,
  }) {
    final updatedPosition = state.position.copyWith(
      scrollOffset: scrollOffset,
      textCursorPosition: textCursorPosition,
      selectionStart: selectionStart,
      selectionEnd: selectionEnd,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(position: updatedPosition);
  }

  /// Set specific language mode
  void setLanguageMode(LanguageMode mode) {
    if (state.currentMode != mode) {
      state = state.copyWith(
        currentMode: mode,
        lastToggleTime: DateTime.now(),
      );
    }
  }

  /// Reset to initial state
  void reset() {
    state = LanguageToggleState.initial();
  }

  /// Check if toggle operation is recent (within performance budget)
  bool get isRecentToggle {
    final timeSinceToggle = DateTime.now().difference(state.lastToggleTime);
    return timeSinceToggle.inMilliseconds < 200; // Performance requirement
  }
}

/// Provider for language toggle state management
final languageToggleProvider = StateNotifierProvider<LanguageToggleNotifier, LanguageToggleState>(
  (ref) => LanguageToggleNotifier(),
);

/// Provider for current language mode (convenience)
final currentLanguageModeProvider = Provider<LanguageMode>((ref) {
  return ref.watch(languageToggleProvider).currentMode;
});

/// Provider for current content position (convenience)
final contentPositionProvider = Provider<ContentPosition>((ref) {
  return ref.watch(languageToggleProvider).position;
});

/// Provider for toggle loading state (convenience)
final isTogglingProvider = Provider<bool>((ref) {
  return ref.watch(languageToggleProvider).isToggling;
});

/// Provider for toggle performance tracking
final togglePerformanceProvider = Provider<Map<String, dynamic>>((ref) {
  final state = ref.watch(languageToggleProvider);
  final timeSinceLastToggle = DateTime.now().difference(state.lastToggleTime);

  return {
    'last_toggle_time': state.lastToggleTime,
    'time_since_toggle_ms': timeSinceLastToggle.inMilliseconds,
    'is_within_budget': timeSinceLastToggle.inMilliseconds < 200,
    'current_mode': state.currentMode.code,
  };
});

/// Lesson content provider that integrates with toggle state
final lessonContentProvider = Provider.family<String, Lesson>((ref, lesson) {
  final currentMode = ref.watch(currentLanguageModeProvider);
  return lesson.getTextForLanguage(currentMode);
});

/// Provider for checking if lesson supports toggle (has both languages)
final lessonSupportsToggleProvider = Provider.family<bool, Lesson>((ref, lesson) {
  return lesson.hasCompleteTranslation;
});