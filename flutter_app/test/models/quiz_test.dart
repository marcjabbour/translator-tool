import 'package:flutter_test/flutter_test.dart';
import 'package:translator_tool/models/quiz.dart';

void main() {
  group('QuizQuestion', () {
    test('should create QuizQuestion from JSON - MCQ', () {
      final json = {
        'type': 'mcq',
        'question': 'What does "marhaba" mean?',
        'answer': 0,
        'choices': ['Hello', 'Goodbye', 'Thank you', 'Please'],
        'rationale': 'Marhaba is a common greeting in Arabic.',
      };

      final question = QuizQuestion.fromJson(json);

      expect(question.type, 'mcq');
      expect(question.question, 'What does "marhaba" mean?');
      expect(question.answer, 0);
      expect(question.choices, ['Hello', 'Goodbye', 'Thank you', 'Please']);
      expect(question.rationale, 'Marhaba is a common greeting in Arabic.');
      expect(question.isMultipleChoice, true);
      expect(question.isTranslation, false);
      expect(question.isFillBlank, false);
    });

    test('should create QuizQuestion from JSON - Translation', () {
      final json = {
        'type': 'translate',
        'question': 'Translate: Good morning',
        'answer': 'sabah al kheir',
        'rationale': 'Sabah al kheir is good morning in Lebanese Arabic.',
      };

      final question = QuizQuestion.fromJson(json);

      expect(question.type, 'translate');
      expect(question.question, 'Translate: Good morning');
      expect(question.answer, 'sabah al kheir');
      expect(question.isTranslation, true);
      expect(question.isMultipleChoice, false);
      expect(question.isFillBlank, false);
    });

    test('should create QuizQuestion from JSON - Fill Blank', () {
      final json = {
        'type': 'fill_blank',
        'question': 'Fill in: Ana _____ min Lubnan (I am _____ from Lebanon)',
        'answer': ['jaye', 'coming'],
        'rationale': 'Jaye means coming in Lebanese Arabic.',
      };

      final question = QuizQuestion.fromJson(json);

      expect(question.type, 'fill_blank');
      expect(question.answer, ['jaye', 'coming']);
      expect(question.isFillBlank, true);
    });

    test('should convert QuizQuestion to JSON', () {
      final question = QuizQuestion(
        type: 'mcq',
        question: 'Test question',
        answer: 1,
        choices: ['A', 'B', 'C', 'D'],
        rationale: 'Test rationale',
      );

      final json = question.toJson();

      expect(json['type'], 'mcq');
      expect(json['question'], 'Test question');
      expect(json['answer'], 1);
      expect(json['choices'], ['A', 'B', 'C', 'D']);
      expect(json['rationale'], 'Test rationale');
    });

    test('should return correct answer display for MCQ', () {
      final question = QuizQuestion(
        type: 'mcq',
        question: 'Test',
        answer: 1,
        choices: ['A', 'B', 'C', 'D'],
      );

      expect(question.correctAnswerDisplay, 'B');
    });

    test('should return correct answer display for translation', () {
      final question = QuizQuestion(
        type: 'translate',
        question: 'Test',
        answer: 'marhaba',
      );

      expect(question.correctAnswerDisplay, 'marhaba');
    });

    test('should return correct answer display for fill blank', () {
      final question = QuizQuestion(
        type: 'fill_blank',
        question: 'Test',
        answer: ['word1', 'word2'],
      );

      expect(question.correctAnswerDisplay, 'word1, word2');
    });

    group('isCorrectAnswer', () {
      test('should validate MCQ answers correctly', () {
        final question = QuizQuestion(
          type: 'mcq',
          question: 'Test',
          answer: 2,
          choices: ['A', 'B', 'C', 'D'],
        );

        expect(question.isCorrectAnswer(2), true);
        expect(question.isCorrectAnswer(1), false);
        expect(question.isCorrectAnswer('2'), false);
      });

      test('should validate translation answers case-insensitively', () {
        final question = QuizQuestion(
          type: 'translate',
          question: 'Test',
          answer: 'Marhaba',
        );

        expect(question.isCorrectAnswer('marhaba'), true);
        expect(question.isCorrectAnswer('MARHABA'), true);
        expect(question.isCorrectAnswer('  marhaba  '), true);
        expect(question.isCorrectAnswer('hello'), false);
        expect(question.isCorrectAnswer(123), false);
      });

      test('should validate fill blank answers correctly', () {
        final question = QuizQuestion(
          type: 'fill_blank',
          question: 'Test',
          answer: ['word1', 'word2'],
        );

        expect(question.isCorrectAnswer(['word1', 'word2']), true);
        expect(question.isCorrectAnswer(['WORD1', 'WORD2']), true);
        expect(question.isCorrectAnswer(['  word1  ', '  word2  ']), true);
        expect(question.isCorrectAnswer(['word1']), false);
        expect(question.isCorrectAnswer(['word1', 'word2', 'word3']), false);
        expect(question.isCorrectAnswer(['wrong1', 'wrong2']), false);
        expect(question.isCorrectAnswer('string'), false);
      });
    });

    test('should handle equality correctly', () {
      final question1 = QuizQuestion(
        type: 'mcq',
        question: 'Test',
        answer: 1,
      );

      final question2 = QuizQuestion(
        type: 'mcq',
        question: 'Test',
        answer: 1,
      );

      final question3 = QuizQuestion(
        type: 'mcq',
        question: 'Different',
        answer: 1,
      );

      expect(question1 == question2, true);
      expect(question1 == question3, false);
      expect(question1.hashCode == question2.hashCode, true);
    });
  });

  group('Quiz', () {
    test('should create Quiz from JSON', () {
      final json = {
        'quiz_id': 'quiz-123',
        'lesson_id': 'lesson-456',
        'questions': [
          {
            'type': 'mcq',
            'question': 'Test question 1',
            'answer': 0,
            'choices': ['A', 'B', 'C', 'D'],
          },
          {
            'type': 'translate',
            'question': 'Test question 2',
            'answer': 'answer',
          },
        ],
        'meta': {'difficulty': 'easy'},
      };

      final quiz = Quiz.fromJson(json);

      expect(quiz.quizId, 'quiz-123');
      expect(quiz.lessonId, 'lesson-456');
      expect(quiz.questions.length, 2);
      expect(quiz.meta['difficulty'], 'easy');
      expect(quiz.questionCount, 2);
      expect(quiz.isValid, false); // Less than 3 questions
    });

    test('should convert Quiz to JSON', () {
      final questions = [
        QuizQuestion(type: 'mcq', question: 'Q1', answer: 0),
        QuizQuestion(type: 'translate', question: 'Q2', answer: 'A2'),
        QuizQuestion(type: 'fill_blank', question: 'Q3', answer: ['A3']),
      ];

      final quiz = Quiz(
        quizId: 'quiz-123',
        lessonId: 'lesson-456',
        questions: questions,
        meta: {'test': 'value'},
      );

      final json = quiz.toJson();

      expect(json['quiz_id'], 'quiz-123');
      expect(json['lesson_id'], 'lesson-456');
      expect(json['questions'].length, 3);
      expect(json['meta']['test'], 'value');
    });

    test('should get question by index', () {
      final questions = [
        QuizQuestion(type: 'mcq', question: 'Q1', answer: 0),
        QuizQuestion(type: 'translate', question: 'Q2', answer: 'A2'),
      ];

      final quiz = Quiz(
        quizId: 'quiz-123',
        lessonId: 'lesson-456',
        questions: questions,
        meta: {},
      );

      expect(quiz.getQuestion(0)?.question, 'Q1');
      expect(quiz.getQuestion(1)?.question, 'Q2');
      expect(quiz.getQuestion(2), null);
      expect(quiz.getQuestion(-1), null);
    });

    test('should get questions by type', () {
      final questions = [
        QuizQuestion(type: 'mcq', question: 'Q1', answer: 0),
        QuizQuestion(type: 'translate', question: 'Q2', answer: 'A2'),
        QuizQuestion(type: 'mcq', question: 'Q3', answer: 1),
      ];

      final quiz = Quiz(
        quizId: 'quiz-123',
        lessonId: 'lesson-456',
        questions: questions,
        meta: {},
      );

      final mcqQuestions = quiz.getQuestionsByType('mcq');
      final translateQuestions = quiz.getQuestionsByType('translate');

      expect(mcqQuestions.length, 2);
      expect(translateQuestions.length, 1);
      expect(mcqQuestions[0].question, 'Q1');
      expect(mcqQuestions[1].question, 'Q3');
      expect(translateQuestions[0].question, 'Q2');
    });

    test('should validate quiz correctly', () {
      final validQuiz = Quiz(
        quizId: 'quiz-123',
        lessonId: 'lesson-456',
        questions: [
          QuizQuestion(type: 'mcq', question: 'Q1', answer: 0),
          QuizQuestion(type: 'translate', question: 'Q2', answer: 'A2'),
          QuizQuestion(type: 'fill_blank', question: 'Q3', answer: ['A3']),
        ],
        meta: {},
      );

      final invalidQuiz = Quiz(
        quizId: 'quiz-123',
        lessonId: 'lesson-456',
        questions: [
          QuizQuestion(type: 'mcq', question: 'Q1', answer: 0),
        ],
        meta: {},
      );

      expect(validQuiz.isValid, true);
      expect(invalidQuiz.isValid, false);
    });

    test('should get question types', () {
      final questions = [
        QuizQuestion(type: 'mcq', question: 'Q1', answer: 0),
        QuizQuestion(type: 'translate', question: 'Q2', answer: 'A2'),
        QuizQuestion(type: 'mcq', question: 'Q3', answer: 1),
        QuizQuestion(type: 'fill_blank', question: 'Q4', answer: ['A4']),
      ];

      final quiz = Quiz(
        quizId: 'quiz-123',
        lessonId: 'lesson-456',
        questions: questions,
        meta: {},
      );

      final questionTypes = quiz.questionTypes;

      expect(questionTypes.length, 3);
      expect(questionTypes.contains('mcq'), true);
      expect(questionTypes.contains('translate'), true);
      expect(questionTypes.contains('fill_blank'), true);
    });

    test('should handle equality correctly', () {
      final quiz1 = Quiz(
        quizId: 'quiz-123',
        lessonId: 'lesson-456',
        questions: [],
        meta: {},
      );

      final quiz2 = Quiz(
        quizId: 'quiz-123',
        lessonId: 'lesson-456',
        questions: [],
        meta: {},
      );

      final quiz3 = Quiz(
        quizId: 'quiz-different',
        lessonId: 'lesson-456',
        questions: [],
        meta: {},
      );

      expect(quiz1 == quiz2, true);
      expect(quiz1 == quiz3, false);
      expect(quiz1.hashCode == quiz2.hashCode, true);
    });
  });

  group('QuizResponse', () {
    test('should create QuizResponse from answer', () {
      final question = QuizQuestion(
        type: 'mcq',
        question: 'Test',
        answer: 1,
        choices: ['A', 'B', 'C', 'D'],
      );

      final response = QuizResponse.fromAnswer(
        questionIndex: 0,
        question: question,
        userAnswer: 1,
      );

      expect(response.questionIndex, 0);
      expect(response.questionType, 'mcq');
      expect(response.userAnswer, 1);
      expect(response.isCorrect, true);
      expect(response.timestamp, isA<DateTime>());
    });

    test('should handle incorrect answers', () {
      final question = QuizQuestion(
        type: 'translate',
        question: 'Test',
        answer: 'correct',
      );

      final response = QuizResponse.fromAnswer(
        questionIndex: 0,
        question: question,
        userAnswer: 'wrong',
      );

      expect(response.isCorrect, false);
    });

    test('should handle equality correctly', () {
      final response1 = QuizResponse(
        questionIndex: 0,
        questionType: 'mcq',
        userAnswer: 1,
        isCorrect: true,
        timestamp: DateTime.now(),
      );

      final response2 = QuizResponse(
        questionIndex: 0,
        questionType: 'mcq',
        userAnswer: 1,
        isCorrect: true,
        timestamp: DateTime.now(),
      );

      final response3 = QuizResponse(
        questionIndex: 1,
        questionType: 'mcq',
        userAnswer: 1,
        isCorrect: true,
        timestamp: DateTime.now(),
      );

      expect(response1 == response2, true);
      expect(response1 == response3, false);
      expect(response1.hashCode == response2.hashCode, true);
    });
  });

  group('QuizSession', () {
    late Quiz testQuiz;

    setUp(() {
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

    test('should start quiz session', () {
      final session = QuizSession.start(testQuiz);

      expect(session.quiz, testQuiz);
      expect(session.responses.length, 0);
      expect(session.currentQuestionIndex, 0);
      expect(session.isCompleted, false);
      expect(session.startTime, isA<DateTime>());
      expect(session.currentQuestion?.question, 'Q1');
    });

    test('should answer current question', () {
      var session = QuizSession.start(testQuiz);

      session = session.answerCurrentQuestion(0);

      expect(session.responses.length, 1);
      expect(session.responses[0].questionIndex, 0);
      expect(session.responses[0].userAnswer, 0);
      expect(session.responses[0].isCorrect, true);
      expect(session.hasAnsweredCurrent, true);
    });

    test('should update existing answer', () {
      var session = QuizSession.start(testQuiz);

      session = session.answerCurrentQuestion(0);
      session = session.answerCurrentQuestion(1);

      expect(session.responses.length, 1);
      expect(session.responses[0].userAnswer, 1);
      expect(session.responses[0].isCorrect, false);
    });

    test('should navigate between questions', () {
      var session = QuizSession.start(testQuiz);

      // Answer first question
      session = session.answerCurrentQuestion(0);
      expect(session.canGoNext, true);
      expect(session.canGoPrevious, false);

      // Go to next question
      session = session.goToNext();
      expect(session.currentQuestionIndex, 1);
      expect(session.canGoPrevious, true);

      // Go back
      session = session.goToPrevious();
      expect(session.currentQuestionIndex, 0);
    });

    test('should calculate progress correctly', () {
      var session = QuizSession.start(testQuiz);

      expect(session.progressPercentage, 0.0);

      session = session.answerCurrentQuestion(0);
      expect(session.progressPercentage, closeTo(0.333, 0.01));

      session = session.goToNext().answerCurrentQuestion('answer2');
      expect(session.progressPercentage, closeTo(0.666, 0.01));

      session = session.goToNext().answerCurrentQuestion(['answer3']);
      expect(session.progressPercentage, 1.0);
    });

    test('should calculate score correctly', () {
      var session = QuizSession.start(testQuiz);

      // Answer all questions (2 correct, 1 incorrect)
      session = session.answerCurrentQuestion(0); // Correct
      session = session.goToNext().answerCurrentQuestion('wrong'); // Incorrect
      session = session.goToNext().answerCurrentQuestion(['answer3']); // Correct

      expect(session.correctCount, 2);
      expect(session.scorePercentage, closeTo(0.666, 0.01));
    });

    test('should go to specific question', () {
      var session = QuizSession.start(testQuiz);

      session = session.goToQuestion(2);
      expect(session.currentQuestionIndex, 2);

      // Invalid indices should be ignored
      session = session.goToQuestion(-1);
      expect(session.currentQuestionIndex, 2);

      session = session.goToQuestion(10);
      expect(session.currentQuestionIndex, 2);
    });

    test('should complete quiz', () {
      var session = QuizSession.start(testQuiz);

      session = session.complete();
      expect(session.isCompleted, true);
    });

    test('should handle elapsed time', () {
      final session = QuizSession.start(testQuiz);

      expect(session.elapsedTime, isA<Duration>());
      expect(session.elapsedTime.inMilliseconds, greaterThanOrEqualTo(0));
    });

    test('should get response for specific question', () {
      var session = QuizSession.start(testQuiz);

      session = session.answerCurrentQuestion(0);
      session = session.goToNext().answerCurrentQuestion('answer2');

      final response0 = session.getResponseFor(0);
      final response1 = session.getResponseFor(1);
      final response2 = session.getResponseFor(2);

      expect(response0?.userAnswer, 0);
      expect(response1?.userAnswer, 'answer2');
      expect(response2, null);
    });

    test('should handle copyWith correctly', () {
      final session = QuizSession.start(testQuiz);

      final newSession = session.copyWith(
        currentQuestionIndex: 1,
        isCompleted: true,
      );

      expect(newSession.currentQuestionIndex, 1);
      expect(newSession.isCompleted, true);
      expect(newSession.quiz, session.quiz);
      expect(newSession.responses, session.responses);
    });

    test('should handle equality correctly', () {
      final session1 = QuizSession.start(testQuiz);
      final session2 = QuizSession.start(testQuiz);

      expect(session1 == session2, true);
      expect(session1.hashCode == session2.hashCode, true);

      final session3 = session1.goToNext();
      expect(session1 == session3, false);
    });
  });
}