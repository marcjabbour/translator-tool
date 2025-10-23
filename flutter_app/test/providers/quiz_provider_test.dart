import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:translator_tool/models/quiz.dart';
import 'package:translator_tool/providers/quiz_provider.dart';

void main() {
  group('QuizSessionNotifier', () {
    late ProviderContainer container;
    late Quiz testQuiz;

    setUp(() {
      container = ProviderContainer();

      final questions = [
        QuizQuestion(type: 'mcq', question: 'Q1', answer: 0, choices: ['A', 'B']),
        QuizQuestion(type: 'translate', question: 'Q2', answer: 'answer2'),
        QuizQuestion(type: 'fill_blank', question: 'Q3', answer: ['answer3']),
      ];

      testQuiz = Quiz(
        quizId: 'quiz-123',
        lessonId: 'lesson-456',
        questions: questions,
        meta: {},
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('should start with null state', () {
      final session = container.read(quizSessionProvider);
      expect(session, null);
    });

    test('should start quiz session', () {
      final notifier = container.read(quizSessionProvider.notifier);
      notifier.startQuiz(testQuiz);

      final session = container.read(quizSessionProvider);
      expect(session, isNotNull);
      expect(session!.quiz, testQuiz);
      expect(session.currentQuestionIndex, 0);
      expect(session.responses.length, 0);
      expect(session.isCompleted, false);
    });

    test('should answer current question', () {
      final notifier = container.read(quizSessionProvider.notifier);
      notifier.startQuiz(testQuiz);
      notifier.answerCurrentQuestion(0);

      final session = container.read(quizSessionProvider);
      expect(session!.responses.length, 1);
      expect(session.responses[0].questionIndex, 0);
      expect(session.responses[0].userAnswer, 0);
      expect(session.responses[0].isCorrect, true);
    });

    test('should navigate between questions', () {
      final notifier = container.read(quizSessionProvider.notifier);
      notifier.startQuiz(testQuiz);
      notifier.answerCurrentQuestion(0);
      notifier.goToNext();

      final session = container.read(quizSessionProvider);
      expect(session!.currentQuestionIndex, 1);

      notifier.goToPrevious();
      final updatedSession = container.read(quizSessionProvider);
      expect(updatedSession!.currentQuestionIndex, 0);
    });

    test('should go to specific question', () {
      final notifier = container.read(quizSessionProvider.notifier);
      notifier.startQuiz(testQuiz);
      notifier.goToQuestion(2);

      final session = container.read(quizSessionProvider);
      expect(session!.currentQuestionIndex, 2);
    });

    test('should complete quiz', () {
      final notifier = container.read(quizSessionProvider.notifier);
      notifier.startQuiz(testQuiz);
      notifier.completeQuiz();

      final session = container.read(quizSessionProvider);
      expect(session!.isCompleted, true);
    });

    test('should reset quiz', () {
      final notifier = container.read(quizSessionProvider.notifier);
      notifier.startQuiz(testQuiz);
      notifier.resetQuiz();

      final session = container.read(quizSessionProvider);
      expect(session, null);
    });

    test('should restart quiz', () {
      final notifier = container.read(quizSessionProvider.notifier);
      notifier.startQuiz(testQuiz);
      notifier.answerCurrentQuestion(0);
      notifier.goToNext();
      notifier.restartQuiz();

      final session = container.read(quizSessionProvider);
      expect(session!.currentQuestionIndex, 0);
      expect(session.responses.length, 0);
      expect(session.isCompleted, false);
    });
  });

  group('Quiz Providers', () {
    late ProviderContainer container;
    late Quiz testQuiz;

    setUp(() {
      container = ProviderContainer();

      final questions = [
        QuizQuestion(type: 'mcq', question: 'Q1', answer: 0, choices: ['A', 'B']),
        QuizQuestion(type: 'translate', question: 'Q2', answer: 'answer2'),
        QuizQuestion(type: 'fill_blank', question: 'Q3', answer: ['answer3']),
      ];

      testQuiz = Quiz(
        quizId: 'quiz-123',
        lessonId: 'lesson-456',
        questions: questions,
        meta: {},
      );

      // Start quiz session for testing other providers
      container.read(quizSessionProvider.notifier).startQuiz(testQuiz);
    });

    tearDown(() {
      container.dispose();
    });

    test('quizReadyForSubmissionProvider should work correctly', () {
      // Initially not ready
      bool ready = container.read(quizReadyForSubmissionProvider);
      expect(ready, false);

      // Answer all questions
      final notifier = container.read(quizSessionProvider.notifier);
      notifier.answerCurrentQuestion(0);
      notifier.goToNext();
      notifier.answerCurrentQuestion('answer2');
      notifier.goToNext();
      notifier.answerCurrentQuestion(['answer3']);

      ready = container.read(quizReadyForSubmissionProvider);
      expect(ready, true);
    });

    test('quizCompletionProvider should provide correct data', () {
      final completion = container.read(quizCompletionProvider);

      expect(completion['isCompleted'], false);
      expect(completion['score'], 0.0);
      expect(completion['correctCount'], 0);
      expect(completion['totalQuestions'], 3);
      expect(completion['elapsedTime'], isA<Duration>());
    });

    test('quizCompletionProvider should handle null session', () {
      container.read(quizSessionProvider.notifier).resetQuiz();

      final completion = container.read(quizCompletionProvider);

      expect(completion['isCompleted'], false);
      expect(completion['score'], 0.0);
      expect(completion['correctCount'], 0);
      expect(completion['totalQuestions'], 0);
      expect(completion['elapsedTime'], Duration.zero);
    });

    test('currentQuestionProvider should provide question details', () {
      final currentQuestion = container.read(currentQuestionProvider);

      expect(currentQuestion, isNotNull);
      expect(currentQuestion!['questionIndex'], 0);
      expect(currentQuestion['totalQuestions'], 3);
      expect(currentQuestion['hasAnswered'], false);
      expect(currentQuestion['canGoNext'], false);
      expect(currentQuestion['canGoPrevious'], false);
      expect(currentQuestion['isLastQuestion'], false);
    });

    test('currentQuestionProvider should handle null session', () {
      container.read(quizSessionProvider.notifier).resetQuiz();

      final currentQuestion = container.read(currentQuestionProvider);
      expect(currentQuestion, null);
    });

    test('quizNavigationProvider should provide navigation data', () {
      final navigation = container.read(quizNavigationProvider);

      expect(navigation['currentIndex'], 0);
      expect(navigation['totalQuestions'], 3);
      expect(navigation['progress'], 0.0);
      expect(navigation['canGoNext'], false);
      expect(navigation['canGoPrevious'], false);
      expect(navigation['answeredQuestions'], <int>[]);
    });

    test('quizNavigationProvider should update after answers', () {
      final notifier = container.read(quizSessionProvider.notifier);
      notifier.answerCurrentQuestion(0);

      final navigation = container.read(quizNavigationProvider);

      expect(navigation['progress'], closeTo(0.333, 0.01));
      expect(navigation['canGoNext'], true);
      expect(navigation['answeredQuestions'], [0]);
    });

    test('questionResultsProvider should provide results data', () {
      final notifier = container.read(quizSessionProvider.notifier);
      notifier.answerCurrentQuestion(0); // Correct
      notifier.goToNext();
      notifier.answerCurrentQuestion('wrong'); // Incorrect

      final results = container.read(questionResultsProvider);

      expect(results.length, 3);
      expect(results[0]['questionIndex'], 0);
      expect(results[0]['isCorrect'], true);
      expect(results[0]['hasAnswered'], true);

      expect(results[1]['questionIndex'], 1);
      expect(results[1]['isCorrect'], false);
      expect(results[1]['hasAnswered'], true);

      expect(results[2]['questionIndex'], 2);
      expect(results[2]['hasAnswered'], false);
    });

    test('quizStatisticsProvider should calculate statistics correctly', () {
      final notifier = container.read(quizSessionProvider.notifier);
      notifier.answerCurrentQuestion(0); // Correct MCQ
      notifier.goToNext();
      notifier.answerCurrentQuestion('wrong'); // Incorrect translation

      final stats = container.read(quizStatisticsProvider);

      expect(stats['totalQuestions'], 3);
      expect(stats['answeredQuestions'], 2);
      expect(stats['correctAnswers'], 1);
      expect(stats['incorrectAnswers'], 1);
      expect(stats['accuracy'], 0.5);

      final breakdown = stats['questionTypeBreakdown'] as Map<String, Map<String, int>>;
      expect(breakdown['mcq']?['correct'], 1);
      expect(breakdown['mcq']?['total'], 1);
      expect(breakdown['translate']?['correct'], 0);
      expect(breakdown['translate']?['total'], 1);
    });

    test('quizStatisticsProvider should handle null session', () {
      container.read(quizSessionProvider.notifier).resetQuiz();

      final stats = container.read(quizStatisticsProvider);

      expect(stats['totalQuestions'], 0);
      expect(stats['answeredQuestions'], 0);
      expect(stats['correctAnswers'], 0);
      expect(stats['incorrectAnswers'], 0);
      expect(stats['accuracy'], 0.0);
      expect(stats['questionTypeBreakdown'], <String, Map<String, int>>{});
    });

    test('providers should react to session changes', () {
      // Test that providers update when session changes
      final notifier = container.read(quizSessionProvider.notifier);

      // Initial state
      expect(container.read(quizReadyForSubmissionProvider), false);
      expect(container.read(quizNavigationProvider)['progress'], 0.0);

      // Answer questions and check updates
      notifier.answerCurrentQuestion(0);
      expect(container.read(quizNavigationProvider)['progress'], closeTo(0.333, 0.01));

      notifier.goToNext();
      notifier.answerCurrentQuestion('answer2');
      expect(container.read(quizNavigationProvider)['progress'], closeTo(0.666, 0.01));

      notifier.goToNext();
      notifier.answerCurrentQuestion(['answer3']);
      expect(container.read(quizReadyForSubmissionProvider), true);
      expect(container.read(quizNavigationProvider)['progress'], 1.0);
    });
  });
}