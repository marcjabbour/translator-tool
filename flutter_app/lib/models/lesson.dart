/// Lesson model representing story content with dual language support
/// Maps to lesson data from backend API (Story 1.1)
class Lesson {
  final String lessonId;
  final String topic;
  final String level;
  final String enText;
  final String laText; // transliterated Lebanese Arabic
  final Map<String, dynamic> meta;
  final DateTime createdAt;

  const Lesson({
    required this.lessonId,
    required this.topic,
    required this.level,
    required this.enText,
    required this.laText,
    required this.meta,
    required this.createdAt,
  });

  /// Create Lesson from API JSON response
  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      lessonId: json['lesson_id'] as String,
      topic: json['topic'] as String? ?? '',
      level: json['level'] as String? ?? '',
      enText: json['en_text'] as String,
      laText: json['la_text'] as String,
      meta: json['meta'] as Map<String, dynamic>? ?? {},
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Convert Lesson to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'lesson_id': lessonId,
      'topic': topic,
      'level': level,
      'en_text': enText,
      'la_text': laText,
      'meta': meta,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Get text content based on language mode
  String getTextForLanguage(LanguageMode mode) {
    switch (mode) {
      case LanguageMode.english:
        return enText;
      case LanguageMode.arabic:
        return laText;
    }
  }

  /// Get character count for the specified language
  int getCharacterCount(LanguageMode mode) {
    return getTextForLanguage(mode).length;
  }

  /// Check if lesson has content in both languages
  bool get hasCompleteTranslation => enText.isNotEmpty && laText.isNotEmpty;

  /// Copy lesson with updated properties
  Lesson copyWith({
    String? lessonId,
    String? topic,
    String? level,
    String? enText,
    String? laText,
    Map<String, dynamic>? meta,
    DateTime? createdAt,
  }) {
    return Lesson(
      lessonId: lessonId ?? this.lessonId,
      topic: topic ?? this.topic,
      level: level ?? this.level,
      enText: enText ?? this.enText,
      laText: laText ?? this.laText,
      meta: meta ?? this.meta,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Lesson &&
        other.lessonId == lessonId &&
        other.topic == topic &&
        other.level == level &&
        other.enText == enText &&
        other.laText == laText;
  }

  @override
  int get hashCode {
    return Object.hash(lessonId, topic, level, enText, laText);
  }

  @override
  String toString() {
    return 'Lesson(id: $lessonId, topic: $topic, level: $level)';
  }
}

/// Language mode enum for dual translation toggle
enum LanguageMode {
  english('English', 'en'),
  arabic('اللبنانية', 'la'); // Lebanese Arabic

  const LanguageMode(this.displayName, this.code);

  final String displayName;
  final String code;

  /// Toggle between English and Arabic modes
  LanguageMode get toggle {
    switch (this) {
      case LanguageMode.english:
        return LanguageMode.arabic;
      case LanguageMode.arabic:
        return LanguageMode.english;
    }
  }

  /// Get language mode from string code
  static LanguageMode fromCode(String code) {
    switch (code) {
      case 'en':
        return LanguageMode.english;
      case 'la':
        return LanguageMode.arabic;
      default:
        return LanguageMode.english; // Default fallback
    }
  }
}

/// Position tracking model for maintaining user position during toggle
class ContentPosition {
  final double scrollOffset;
  final int? textCursorPosition;
  final int? selectionStart;
  final int? selectionEnd;
  final DateTime timestamp;

  const ContentPosition({
    required this.scrollOffset,
    this.textCursorPosition,
    this.selectionStart,
    this.selectionEnd,
    required this.timestamp,
  });

  /// Create default position (top of content)
  factory ContentPosition.initial() {
    return ContentPosition(
      scrollOffset: 0.0,
      timestamp: DateTime.now(),
    );
  }

  /// Check if position has text selection
  bool get hasSelection =>
      selectionStart != null && selectionEnd != null && selectionStart != selectionEnd;

  /// Copy position with updated properties
  ContentPosition copyWith({
    double? scrollOffset,
    int? textCursorPosition,
    int? selectionStart,
    int? selectionEnd,
    DateTime? timestamp,
  }) {
    return ContentPosition(
      scrollOffset: scrollOffset ?? this.scrollOffset,
      textCursorPosition: textCursorPosition ?? this.textCursorPosition,
      selectionStart: selectionStart ?? this.selectionStart,
      selectionEnd: selectionEnd ?? this.selectionEnd,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContentPosition &&
        other.scrollOffset == scrollOffset &&
        other.textCursorPosition == textCursorPosition &&
        other.selectionStart == selectionStart &&
        other.selectionEnd == selectionEnd;
  }

  @override
  int get hashCode {
    return Object.hash(scrollOffset, textCursorPosition, selectionStart, selectionEnd);
  }

  @override
  String toString() {
    return 'ContentPosition(scroll: $scrollOffset, cursor: $textCursorPosition, selection: $selectionStart-$selectionEnd)';
  }
}