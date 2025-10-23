import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/quiz.dart';
import '../services/quiz_service.dart';

/// State provider for current quiz session
final quizSessionProvider = StateNotifierProvider<QuizSessionNotifier, QuizSession?>((ref) {
  return QuizSessionNotifier();
});

/// Notifier for managing quiz session state
class QuizSessionNotifier extends StateNotifier<QuizSession?> {
  QuizSessionNotifier() : super(null);

  /// Start a new quiz session
  void startQuiz(Quiz quiz) {
    state = QuizSession.start(quiz);
  }

  /// Answer the current question
  void answerCurrentQuestion(dynamic userAnswer) {
    if (state == null) return;
    state = state!.answerCurrentQuestion(userAnswer);
  }

  /// Move to next question
  void goToNext() {
    if (state == null) return;
    state = state!.goToNext();
  }

  /// Move to previous question
  void goToPrevious() {
    if (state == null) return;
    state = state!.goToPrevious();
  }

  /// Go to specific question by index
  void goToQuestion(int questionIndex) {
    if (state == null) return;
    state = state!.goToQuestion(questionIndex);
  }

  /// Complete the quiz
  void completeQuiz() {
    if (state == null) return;
    state = state!.complete();
  }

  /// Reset the quiz session
  void resetQuiz() {
    state = null;
  }

  /// Restart current quiz
  void restartQuiz() {
    if (state == null) return;
    state = QuizSession.start(state!.quiz);
  }
}

/// Provider for checking if quiz is ready for submission
final quizReadyForSubmissionProvider = Provider<bool>((ref) {
  final session = ref.watch(quizSessionProvider);
  if (session == null) return false;

  return session.responses.length == session.quiz.questionCount;
});

/// Provider for quiz completion status
final quizCompletionProvider = Provider<Map<String, dynamic>>((ref) {
  final session = ref.watch(quizSessionProvider);
  if (session == null) {
    return {
      'isCompleted': false,
      'score': 0.0,
      'correctCount': 0,
      'totalQuestions': 0,
      'elapsedTime': Duration.zero,
    };
  }

  return {
    'isCompleted': session.isCompleted,
    'score': session.scorePercentage,
    'correctCount': session.correctCount,
    'totalQuestions': session.quiz.questionCount,
    'elapsedTime': session.elapsedTime,
  };
});

/// Provider for current question details
final currentQuestionProvider = Provider<Map<String, dynamic>?>((ref) {
  final session = ref.watch(quizSessionProvider);
  if (session == null) return null;

  final currentQuestion = session.currentQuestion;
  if (currentQuestion == null) return null;

  final userResponse = session.getResponseFor(session.currentQuestionIndex);

  return {
    'question': currentQuestion,
    'questionIndex': session.currentQuestionIndex,
    'totalQuestions': session.quiz.questionCount,
    'userAnswer': userResponse?.userAnswer,
    'hasAnswered': session.hasAnsweredCurrent,
    'canGoNext': session.canGoNext,
    'canGoPrevious': session.canGoPrevious,
    'isLastQuestion': session.currentQuestionIndex == session.quiz.questionCount - 1,
  };
});

/// Provider for quiz navigation state
final quizNavigationProvider = Provider<Map<String, dynamic>>((ref) {
  final session = ref.watch(quizSessionProvider);
  if (session == null) {
    return {
      'currentIndex': 0,
      'totalQuestions': 0,
      'progress': 0.0,
      'canGoNext': false,
      'canGoPrevious': false,
      'answeredQuestions': <int>[],
    };
  }

  final answeredQuestions = session.responses
      .map((r) => r.questionIndex)
      .toList()
      ..sort();

  return {
    'currentIndex': session.currentQuestionIndex,
    'totalQuestions': session.quiz.questionCount,
    'progress': session.progressPercentage,
    'canGoNext': session.canGoNext,
    'canGoPrevious': session.canGoPrevious,
    'answeredQuestions': answeredQuestions,
  };
});

/// Provider for question results (used in review mode)
final questionResultsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final session = ref.watch(quizSessionProvider);
  if (session == null) return [];

  return session.quiz.questions.asMap().entries.map((entry) {
    final index = entry.key;
    final question = entry.value;
    final response = session.getResponseFor(index);

    return {
      'questionIndex': index,
      'question': question,
      'userAnswer': response?.userAnswer,
      'isCorrect': response?.isCorrect ?? false,
      'hasAnswered': response != null,
      'correctAnswer': question.correctAnswerDisplay,
    };
  }).toList();
});

/// Provider for quiz statistics
final quizStatisticsProvider = Provider<Map<String, dynamic>>((ref) {
  final session = ref.watch(quizSessionProvider);
  if (session == null) {
    return {
      'totalQuestions': 0,
      'answeredQuestions': 0,
      'correctAnswers': 0,
      'incorrectAnswers': 0,
      'accuracy': 0.0,
      'questionTypeBreakdown': <String, Map<String, int>>{},
    };
  }

  final questionTypeBreakdown = <String, Map<String, int>>{};

  for (final response in session.responses) {
    final questionType = response.questionType;
    questionTypeBreakdown[questionType] ??= {'correct': 0, 'total': 0};
    questionTypeBreakdown[questionType]!['total'] =
        questionTypeBreakdown[questionType]!['total']! + 1;

    if (response.isCorrect) {
      questionTypeBreakdown[questionType]!['correct'] =
          questionTypeBreakdown[questionType]!['correct']! + 1;
    }
  }

  return {
    'totalQuestions': session.quiz.questionCount,
    'answeredQuestions': session.responses.length,
    'correctAnswers': session.correctCount,
    'incorrectAnswers': session.responses.length - session.correctCount,
    'accuracy': session.scorePercentage,
    'questionTypeBreakdown': questionTypeBreakdown,
  };
});

/// Provider for loading quiz by lesson ID
final quizByLessonLoadProvider = FutureProvider.family<Quiz?, String>((ref, lessonId) async {
  final service = ref.read(quizServiceProvider);
  try {
    return await service.generateQuiz(lessonId: lessonId);
  } catch (e) {
    // Return null if quiz generation fails
    return null;
  }
});