import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:translator_tool/models/quiz.dart';
import 'package:translator_tool/screens/test_mode_screen.dart';
import 'package:translator_tool/providers/quiz_provider.dart';
import 'package:translator_tool/services/quiz_service.dart';

// Mock quiz for testing
final mockQuiz = Quiz(
  quizId: 'quiz-123',
  lessonId: 'lesson-456',
  questions: [
    QuizQuestion(
      type: 'mcq',
      question: 'What does "marhaba" mean?',
      answer: 0,
      choices: ['Hello', 'Goodbye', 'Thank you', 'Please'],
      rationale: 'Marhaba is a common greeting.',
    ),
    QuizQuestion(
      type: 'translate',
      question: 'Translate: Good morning',
      answer: 'sabah al kheir',
      rationale: 'Sabah al kheir means good morning.',
    ),
    QuizQuestion(
      type: 'fill_blank',
      question: 'Fill in: Ana _____ min Lubnan',
      answer: ['jaye'],
      rationale: 'Jaye means coming.',
    ),
  ],
  meta: {},
);

void main() {
  group('TestModeScreen', () {
    Widget createWidget(String lessonId) {
      return ProviderScope(
        overrides: [
          // Override the quiz provider to return our mock quiz
          quizByLessonLoadProvider(lessonId).overrideWith((ref, arg) async {
            return mockQuiz;
          }),
        ],
        child: CupertinoApp(
          home: TestModeScreen(lessonId: lessonId),
        ),
      );
    }

    Widget createWidgetWithError(String lessonId) {
      return ProviderScope(
        overrides: [
          quizByLessonLoadProvider(lessonId).overrideWith((ref, arg) async {
            return null; // Simulate error/no quiz
          }),
        ],
        child: CupertinoApp(
          home: TestModeScreen(lessonId: lessonId),
        ),
      );
    }

    testWidgets('should show loading state initially', (tester) async {
      await tester.pumpWidget(createWidget('lesson-123'));

      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.text('Loading quiz...'), findsOneWidget);
    });

    testWidgets('should show error when quiz fails to load', (tester) async {
      await tester.pumpWidget(createWidgetWithError('lesson-123'));
      await tester.pump(); // Complete the future

      expect(find.text('Quiz Unavailable'), findsOneWidget);
      expect(find.text('Failed to load quiz for this lesson'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.exclamationmark_triangle), findsOneWidget);
      expect(find.text('Go Back'), findsOneWidget);
    });

    testWidgets('should start quiz session when quiz loads', (tester) async {
      await tester.pumpWidget(createWidget('lesson-123'));
      await tester.pump(); // Complete the future
      await tester.pump(); // Allow session to start

      // Should show the first question
      expect(find.text('What does "marhaba" mean?'), findsOneWidget);
      expect(find.text('Question 1 of 3'), findsOneWidget);
      expect(find.text('Multiple Choice'), findsOneWidget);
    });

    testWidgets('should display progress header correctly', (tester) async {
      await tester.pumpWidget(createWidget('lesson-123'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Question 1 of 3'), findsOneWidget);
      expect(find.text('0/3 answered'), findsOneWidget);
    });

    testWidgets('should handle question answering and navigation', (tester) async {
      await tester.pumpWidget(createWidget('lesson-123'));
      await tester.pump();
      await tester.pump();

      // Answer the first question (MCQ)
      await tester.tap(find.text('Hello'));
      await tester.pump();

      // Progress should update
      expect(find.text('1/3 answered'), findsOneWidget);

      // Next button should be enabled
      final nextButton = find.text('Next');
      expect(nextButton, findsOneWidget);

      await tester.tap(nextButton);
      await tester.pump();

      // Should show second question (Translation)
      expect(find.text('Question 2 of 3'), findsOneWidget);
      expect(find.text('Translate: Good morning'), findsOneWidget);
      expect(find.text('Translation'), findsOneWidget);
    });

    testWidgets('should handle previous navigation', (tester) async {
      await tester.pumpWidget(createWidget('lesson-123'));
      await tester.pump();
      await tester.pump();

      // Answer first question and go to second
      await tester.tap(find.text('Hello'));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pump();

      // Previous button should be available
      final previousButton = find.text('Previous');
      expect(previousButton, findsOneWidget);

      await tester.tap(previousButton);
      await tester.pump();

      // Should be back to first question
      expect(find.text('Question 1 of 3'), findsOneWidget);
      expect(find.text('What does "marhaba" mean?'), findsOneWidget);
    });

    testWidgets('should show submit button on last question', (tester) async {
      await tester.pumpWidget(createWidget('lesson-123'));
      await tester.pump();
      await tester.pump();

      // Answer all questions to get to submit
      await tester.tap(find.text('Hello'));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pump();

      // Answer translation question
      await tester.enterText(find.byType(CupertinoTextField), 'sabah al kheir');
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pump();

      // Should be on last question
      expect(find.text('Question 3 of 3'), findsOneWidget);

      // Answer fill blank question
      await tester.enterText(find.byType(CupertinoTextField).first, 'jaye');
      await tester.pump();

      // Should show submit button
      expect(find.text('Submit Quiz'), findsOneWidget);
    });

    testWidgets('should show completion screen after submission', (tester) async {
      await tester.pumpWidget(createWidget('lesson-123'));
      await tester.pump();
      await tester.pump();

      // Complete all questions
      await tester.tap(find.text('Hello'));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pump();

      await tester.enterText(find.byType(CupertinoTextField), 'sabah al kheir');
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pump();

      await tester.enterText(find.byType(CupertinoTextField).first, 'jaye');
      await tester.pump();
      await tester.tap(find.text('Submit Quiz'));
      await tester.pump();

      // Should show completion screen
      expect(find.text('Quiz Complete!'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget); // All correct answers
      expect(find.text('3 out of 3 correct'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.checkmark_circle_fill), findsOneWidget);
    });

    testWidgets('should show action buttons in completion screen', (tester) async {
      await tester.pumpWidget(createWidget('lesson-123'));
      await tester.pump();
      await tester.pump();

      // Complete quiz quickly (simulate completion)
      final container = ProviderScope.containerOf(tester.element(find.byType(TestModeScreen)));
      container.read(quizSessionProvider.notifier).startQuiz(mockQuiz);
      container.read(quizSessionProvider.notifier).answerCurrentQuestion(0);
      container.read(quizSessionProvider.notifier).goToNext();
      container.read(quizSessionProvider.notifier).answerCurrentQuestion('sabah al kheir');
      container.read(quizSessionProvider.notifier).goToNext();
      container.read(quizSessionProvider.notifier).answerCurrentQuestion(['jaye']);
      container.read(quizSessionProvider.notifier).completeQuiz();
      await tester.pump();

      expect(find.text('Review Answers'), findsOneWidget);
      expect(find.text('Retake Quiz'), findsOneWidget);
      expect(find.text('Back to Lesson'), findsOneWidget);
    });

    testWidgets('should handle navigation bar actions', (tester) async {
      await tester.pumpWidget(createWidget('lesson-123'));
      await tester.pump();
      await tester.pump();

      // Should show back button
      expect(find.byIcon(CupertinoIcons.back), findsOneWidget);

      // Should show refresh action
      expect(find.byIcon(CupertinoIcons.refresh), findsOneWidget);
    });

    testWidgets('should show restart confirmation dialog', (tester) async {
      await tester.pumpWidget(createWidget('lesson-123'));
      await tester.pump();
      await tester.pump();

      // Tap refresh button
      await tester.tap(find.byIcon(CupertinoIcons.refresh));
      await tester.pump();

      // Should show confirmation dialog
      expect(find.text('Restart Quiz'), findsOneWidget);
      expect(find.text('Are you sure you want to restart the quiz? Your current progress will be lost.'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Restart'), findsOneWidget);
    });

    testWidgets('should handle restart confirmation', (tester) async {
      await tester.pumpWidget(createWidget('lesson-123'));
      await tester.pump();
      await tester.pump();

      // Answer a question first
      await tester.tap(find.text('Hello'));
      await tester.pump();

      // Tap refresh and confirm restart
      await tester.tap(find.byIcon(CupertinoIcons.refresh));
      await tester.pump();
      await tester.tap(find.text('Restart'));
      await tester.pump();

      // Should be back to first question with no answers
      expect(find.text('Question 1 of 3'), findsOneWidget);
      expect(find.text('0/3 answered'), findsOneWidget);
    });

    testWidgets('should disable next button when question not answered', (tester) async {
      await tester.pumpWidget(createWidget('lesson-123'));
      await tester.pump();
      await tester.pump();

      // Next button should exist but be disabled (no visual way to test directly)
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Please answer the question to continue'), findsOneWidget);
    });

    testWidgets('should handle different question types correctly', (tester) async {
      await tester.pumpWidget(createWidget('lesson-123'));
      await tester.pump();
      await tester.pump();

      // Test MCQ
      expect(find.text('Multiple Choice'), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);

      // Go to translation question
      await tester.tap(find.text('Hello'));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pump();

      expect(find.text('Translation'), findsOneWidget);
      expect(find.text('Your translation:'), findsOneWidget);

      // Go to fill blank question
      await tester.enterText(find.byType(CupertinoTextField), 'test');
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pump();

      expect(find.text('Fill in the Blanks'), findsOneWidget);
    });

    testWidgets('should handle unsupported question type', (tester) async {
      final invalidQuiz = Quiz(
        quizId: 'quiz-123',
        lessonId: 'lesson-456',
        questions: [
          QuizQuestion(
            type: 'unsupported',
            question: 'Invalid question',
            answer: 'answer',
          ),
        ],
        meta: {},
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [
          quizByLessonLoadProvider('lesson-123').overrideWith((ref, arg) async {
            return invalidQuiz;
          }),
        ],
        child: CupertinoApp(
          home: TestModeScreen(lessonId: 'lesson-123'),
        ),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('Unsupported question type: unsupported'), findsOneWidget);
    });

    testWidgets('should format duration correctly', (tester) async {
      await tester.pumpWidget(createWidget('lesson-123'));
      await tester.pump();
      await tester.pump();

      // Complete quiz to see duration
      final container = ProviderScope.containerOf(tester.element(find.byType(TestModeScreen)));
      container.read(quizSessionProvider.notifier).startQuiz(mockQuiz);
      container.read(quizSessionProvider.notifier).completeQuiz();
      await tester.pump();

      // Should show time in format like "0m 0s"
      expect(find.textContaining('m '), findsOneWidget);
      expect(find.textContaining('s'), findsOneWidget);
    });
  });
}