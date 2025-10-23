import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/lesson.dart';

void main() {
  group('Lesson Model Tests', () {
    test('should create lesson from JSON correctly', () {
      final json = {
        'lesson_id': '550e8400-e29b-41d4-a716-446655440000',
        'topic': 'coffee_chat',
        'level': 'beginner',
        'en_text': 'Hey, want to grab coffee?',
        'la_text': 'ahlan, baddak nrou7 neeshrab ahwe?',
        'meta': {'seed': 42},
        'created_at': '2024-01-01T10:00:00Z',
      };

      final lesson = Lesson.fromJson(json);

      expect(lesson.lessonId, '550e8400-e29b-41d4-a716-446655440000');
      expect(lesson.topic, 'coffee_chat');
      expect(lesson.level, 'beginner');
      expect(lesson.enText, 'Hey, want to grab coffee?');
      expect(lesson.laText, 'ahlan, baddak nrou7 neeshrab ahwe?');
      expect(lesson.meta['seed'], 42);
    });

    test('should handle missing optional fields in JSON', () {
      final json = {
        'lesson_id': '550e8400-e29b-41d4-a716-446655440000',
        'en_text': 'Hello',
        'la_text': 'ahlan',
      };

      final lesson = Lesson.fromJson(json);

      expect(lesson.lessonId, '550e8400-e29b-41d4-a716-446655440000');
      expect(lesson.topic, '');
      expect(lesson.level, '');
      expect(lesson.meta, {});
    });

    test('should get correct text for language mode', () {
      final lesson = Lesson(
        lessonId: 'test-id',
        topic: 'test',
        level: 'beginner',
        enText: 'Hello world',
        laText: 'ahlan ya dunya',
        meta: {},
        createdAt: DateTime.now(),
      );

      expect(lesson.getTextForLanguage(LanguageMode.english), 'Hello world');
      expect(lesson.getTextForLanguage(LanguageMode.arabic), 'ahlan ya dunya');
    });

    test('should calculate character count correctly', () {
      final lesson = Lesson(
        lessonId: 'test-id',
        topic: 'test',
        level: 'beginner',
        enText: 'Hello',
        laText: 'ahlan',
        meta: {},
        createdAt: DateTime.now(),
      );

      expect(lesson.getCharacterCount(LanguageMode.english), 5);
      expect(lesson.getCharacterCount(LanguageMode.arabic), 5);
    });

    test('should detect complete translation correctly', () {
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
        lessonId: 'test-id',
        topic: 'test',
        level: 'beginner',
        enText: 'Hello',
        laText: '',
        meta: {},
        createdAt: DateTime.now(),
      );

      expect(completeLesson.hasCompleteTranslation, true);
      expect(incompleteLesson.hasCompleteTranslation, false);
    });

    test('should copy lesson with updated properties', () {
      final originalLesson = Lesson(
        lessonId: 'test-id',
        topic: 'original',
        level: 'beginner',
        enText: 'Hello',
        laText: 'ahlan',
        meta: {},
        createdAt: DateTime.now(),
      );

      final copiedLesson = originalLesson.copyWith(
        topic: 'updated',
        level: 'intermediate',
      );

      expect(copiedLesson.lessonId, originalLesson.lessonId);
      expect(copiedLesson.topic, 'updated');
      expect(copiedLesson.level, 'intermediate');
      expect(copiedLesson.enText, originalLesson.enText);
      expect(copiedLesson.laText, originalLesson.laText);
    });
  });

  group('LanguageMode Tests', () {
    test('should toggle between modes correctly', () {
      expect(LanguageMode.english.toggle, LanguageMode.arabic);
      expect(LanguageMode.arabic.toggle, LanguageMode.english);
    });

    test('should create from code correctly', () {
      expect(LanguageMode.fromCode('en'), LanguageMode.english);
      expect(LanguageMode.fromCode('la'), LanguageMode.arabic);
      expect(LanguageMode.fromCode('invalid'), LanguageMode.english); // Default fallback
    });

    test('should have correct display names and codes', () {
      expect(LanguageMode.english.displayName, 'English');
      expect(LanguageMode.english.code, 'en');
      expect(LanguageMode.arabic.displayName, 'اللبنانية');
      expect(LanguageMode.arabic.code, 'la');
    });
  });

  group('ContentPosition Tests', () {
    test('should create initial position correctly', () {
      final position = ContentPosition.initial();

      expect(position.scrollOffset, 0.0);
      expect(position.textCursorPosition, null);
      expect(position.selectionStart, null);
      expect(position.selectionEnd, null);
    });

    test('should detect text selection correctly', () {
      final noSelection = ContentPosition(
        scrollOffset: 0.0,
        timestamp: DateTime.now(),
      );

      final withSelection = ContentPosition(
        scrollOffset: 0.0,
        selectionStart: 5,
        selectionEnd: 10,
        timestamp: DateTime.now(),
      );

      final collapsedSelection = ContentPosition(
        scrollOffset: 0.0,
        selectionStart: 5,
        selectionEnd: 5,
        timestamp: DateTime.now(),
      );

      expect(noSelection.hasSelection, false);
      expect(withSelection.hasSelection, true);
      expect(collapsedSelection.hasSelection, false);
    });

    test('should copy position with updated properties', () {
      final originalPosition = ContentPosition(
        scrollOffset: 100.0,
        textCursorPosition: 50,
        timestamp: DateTime.now(),
      );

      final copiedPosition = originalPosition.copyWith(
        scrollOffset: 200.0,
        selectionStart: 10,
        selectionEnd: 20,
      );

      expect(copiedPosition.scrollOffset, 200.0);
      expect(copiedPosition.textCursorPosition, 50); // Unchanged
      expect(copiedPosition.selectionStart, 10);
      expect(copiedPosition.selectionEnd, 20);
    });

    test('should maintain equality based on position data', () {
      final position1 = ContentPosition(
        scrollOffset: 100.0,
        textCursorPosition: 50,
        timestamp: DateTime.now(),
      );

      final position2 = ContentPosition(
        scrollOffset: 100.0,
        textCursorPosition: 50,
        timestamp: DateTime.now().add(Duration(seconds: 1)), // Different timestamp
      );

      final position3 = ContentPosition(
        scrollOffset: 200.0,
        textCursorPosition: 50,
        timestamp: DateTime.now(),
      );

      expect(position1, position2); // Should be equal despite different timestamps
      expect(position1, isNot(position3)); // Should not be equal due to different scroll offset
    });
  });

  group('Lesson JSON Serialization Tests', () {
    test('should serialize lesson to JSON correctly', () {
      final lesson = Lesson(
        lessonId: 'test-id',
        topic: 'coffee_chat',
        level: 'beginner',
        enText: 'Hello',
        laText: 'ahlan',
        meta: {'seed': 42},
        createdAt: DateTime.parse('2024-01-01T10:00:00Z'),
      );

      final json = lesson.toJson();

      expect(json['lesson_id'], 'test-id');
      expect(json['topic'], 'coffee_chat');
      expect(json['level'], 'beginner');
      expect(json['en_text'], 'Hello');
      expect(json['la_text'], 'ahlan');
      expect(json['meta']['seed'], 42);
      expect(json['created_at'], '2024-01-01T10:00:00.000Z');
    });

    test('should round-trip serialize and deserialize correctly', () {
      final originalLesson = Lesson(
        lessonId: 'test-id',
        topic: 'coffee_chat',
        level: 'beginner',
        enText: 'Hello world',
        laText: 'ahlan ya dunya',
        meta: {'seed': 42, 'custom': 'value'},
        createdAt: DateTime.parse('2024-01-01T10:00:00Z'),
      );

      final json = originalLesson.toJson();
      final deserializedLesson = Lesson.fromJson(json);

      expect(deserializedLesson.lessonId, originalLesson.lessonId);
      expect(deserializedLesson.topic, originalLesson.topic);
      expect(deserializedLesson.level, originalLesson.level);
      expect(deserializedLesson.enText, originalLesson.enText);
      expect(deserializedLesson.laText, originalLesson.laText);
      expect(deserializedLesson.meta, originalLesson.meta);
      expect(deserializedLesson.createdAt, originalLesson.createdAt);
    });
  });
}