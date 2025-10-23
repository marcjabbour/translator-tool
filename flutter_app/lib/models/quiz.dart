/// Quiz models for test mode functionality
/// Maps to quiz data from backend API (Story 1.3)
class QuizQuestion {
  final String type;
  final String question;
  final dynamic answer; // Can be int (MCQ), String (translation), or List<String> (fill_blank)
  final List<String>? choices;
  final String? rationale;

  const QuizQuestion({
    required this.type,
    required this.question,
    required this.answer,
    this.choices,
    this.rationale,
  });

  /// Create QuizQuestion from API JSON response
  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      type: json['type'] as String,
      question: json['question'] as String,
      answer: json['answer'], // Dynamic type - can be int, String, or List
      choices: json['choices'] != null
          ? List<String>.from(json['choices'] as List)
          : null,
      rationale: json['rationale'] as String?,
    );
  }

  /// Convert QuizQuestion to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'question': question,
      'answer': answer,
      if (choices != null) 'choices': choices,
      if (rationale != null) 'rationale': rationale,
    };
  }

  /// Check if this is a multiple choice question
  bool get isMultipleChoice => type == 'mcq';

  /// Check if this is a translation question
  bool get isTranslation => type == 'translate';

  /// Check if this is a fill-in-blank question
  bool get isFillBlank => type == 'fill_blank';

  /// Get the correct answer as string for display
  String get correctAnswerDisplay {
    switch (type) {
      case 'mcq':
        if (choices != null && answer is int) {
          final index = answer as int;
          return index < choices!.length ? choices![index] : 'Invalid';
        }
        return 'Invalid MCQ';
      case 'translate':
        return answer.toString();
      case 'fill_blank':
        if (answer is List) {
          return (answer as List).join(', ');
        }
        return answer.toString();
      default:
        return answer.toString();
    }
  }

  /// Check if user answer is correct
  bool isCorrectAnswer(dynamic userAnswer) {
    switch (type) {
      case 'mcq':
        return userAnswer == answer;
      case 'translate':
        if (userAnswer is String && answer is String) {
          // Case-insensitive comparison for translation
          return userAnswer.toLowerCase().trim() ==
                 (answer as String).toLowerCase().trim();
        }
        return false;
      case 'fill_blank':
        if (userAnswer is List && answer is List) {
          final userList = userAnswer as List;
          final correctList = answer as List;
          if (userList.length != correctList.length) return false;

          for (int i = 0; i < userList.length; i++) {
            if (userList[i].toString().toLowerCase().trim() !=
                correctList[i].toString().toLowerCase().trim()) {
              return false;
            }
          }
          return true;
        }
        return false;
      default:
        return userAnswer == answer;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QuizQuestion &&
        other.type == type &&
        other.question == question &&
        other.answer == answer;
  }

  @override
  int get hashCode => Object.hash(type, question, answer);

  @override
  String toString() {
    return 'QuizQuestion(type: $type, question: $question)';
  }
}

/// Quiz model representing a complete quiz
class Quiz {
  final String quizId;
  final String lessonId;
  final List<QuizQuestion> questions;
  final Map<String, dynamic> meta;

  const Quiz({
    required this.quizId,
    required this.lessonId,
    required this.questions,
    required this.meta,
  });

  /// Create Quiz from API JSON response
  factory Quiz.fromJson(Map<String, dynamic> json) {
    final questionsList = json['questions'] as List;
    final questions = questionsList
        .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
        .toList();

    return Quiz(
      quizId: json['quiz_id'] as String,
      lessonId: json['lesson_id'] as String,
      questions: questions,
      meta: json['meta'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Convert Quiz to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'quiz_id': quizId,
      'lesson_id': lessonId,
      'questions': questions.map((q) => q.toJson()).toList(),
      'meta': meta,
    };
  }

  /// Get question by index
  QuizQuestion? getQuestion(int index) {
    if (index >= 0 && index < questions.length) {
      return questions[index];
    }
    return null;
  }

  /// Get total number of questions
  int get questionCount => questions.length;

  /// Get questions by type
  List<QuizQuestion> getQuestionsByType(String type) {
    return questions.where((q) => q.type == type).toList();
  }

  /// Check if quiz meets minimum requirements (3+ questions)
  bool get isValid => questions.length >= 3;

  /// Get question types present in quiz
  Set<String> get questionTypes {
    return questions.map((q) => q.type).toSet();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Quiz &&
        other.quizId == quizId &&
        other.lessonId == lessonId;
  }

  @override
  int get hashCode => Object.hash(quizId, lessonId);

  @override
  String toString() {
    return 'Quiz(id: $quizId, lessonId: $lessonId, questions: ${questions.length})';
  }
}

/// User's response to a quiz question
class QuizResponse {
  final int questionIndex;
  final String questionType;
  final dynamic userAnswer;
  final bool isCorrect;
  final DateTime timestamp;

  const QuizResponse({
    required this.questionIndex,
    required this.questionType,
    required this.userAnswer,
    required this.isCorrect,
    required this.timestamp,
  });

  /// Create QuizResponse for a user's answer
  factory QuizResponse.fromAnswer({
    required int questionIndex,
    required QuizQuestion question,
    required dynamic userAnswer,
  }) {
    return QuizResponse(
      questionIndex: questionIndex,
      questionType: question.type,
      userAnswer: userAnswer,
      isCorrect: question.isCorrectAnswer(userAnswer),
      timestamp: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QuizResponse &&
        other.questionIndex == questionIndex &&
        other.userAnswer == userAnswer;
  }

  @override
  int get hashCode => Object.hash(questionIndex, userAnswer);

  @override
  String toString() {
    return 'QuizResponse(question: $questionIndex, correct: $isCorrect)';
  }
}

/// Quiz session state tracking user progress
class QuizSession {
  final Quiz quiz;
  final List<QuizResponse> responses;
  final int currentQuestionIndex;
  final DateTime startTime;
  final bool isCompleted;

  const QuizSession({
    required this.quiz,
    required this.responses,
    required this.currentQuestionIndex,
    required this.startTime,
    required this.isCompleted,
  });

  /// Create initial quiz session
  factory QuizSession.start(Quiz quiz) {
    return QuizSession(
      quiz: quiz,
      responses: [],
      currentQuestionIndex: 0,
      startTime: DateTime.now(),
      isCompleted: false,
    );
  }

  /// Get current question
  QuizQuestion? get currentQuestion {
    return quiz.getQuestion(currentQuestionIndex);
  }

  /// Get user's response for a specific question
  QuizResponse? getResponseFor(int questionIndex) {
    try {
      return responses.firstWhere((r) => r.questionIndex == questionIndex);
    } catch (e) {
      return null; // No response found
    }
  }

  /// Check if user has answered current question
  bool get hasAnsweredCurrent {
    return getResponseFor(currentQuestionIndex) != null;
  }

  /// Check if user can go to next question
  bool get canGoNext {
    return hasAnsweredCurrent && currentQuestionIndex < quiz.questionCount - 1;
  }

  /// Check if user can go to previous question
  bool get canGoPrevious {
    return currentQuestionIndex > 0;
  }

  /// Get progress percentage
  double get progressPercentage {
    if (quiz.questionCount == 0) return 0.0;
    return responses.length / quiz.questionCount;
  }

  /// Get number of correct answers
  int get correctCount {
    return responses.where((r) => r.isCorrect).length;
  }

  /// Get score percentage
  double get scorePercentage {
    if (quiz.questionCount == 0) return 0.0;
    return correctCount / quiz.questionCount;
  }

  /// Get elapsed time
  Duration get elapsedTime {
    return DateTime.now().difference(startTime);
  }

  /// Add or update response for current question
  QuizSession answerCurrentQuestion(dynamic userAnswer) {
    final question = currentQuestion;
    if (question == null) return this;

    final response = QuizResponse.fromAnswer(
      questionIndex: currentQuestionIndex,
      question: question,
      userAnswer: userAnswer,
    );

    // Remove existing response for this question if any
    final updatedResponses = responses
        .where((r) => r.questionIndex != currentQuestionIndex)
        .toList();
    updatedResponses.add(response);
    updatedResponses.sort((a, b) => a.questionIndex.compareTo(b.questionIndex));

    return copyWith(responses: updatedResponses);
  }

  /// Move to next question
  QuizSession goToNext() {
    if (!canGoNext) return this;
    return copyWith(currentQuestionIndex: currentQuestionIndex + 1);
  }

  /// Move to previous question
  QuizSession goToPrevious() {
    if (!canGoPrevious) return this;
    return copyWith(currentQuestionIndex: currentQuestionIndex - 1);
  }

  /// Go to specific question
  QuizSession goToQuestion(int questionIndex) {
    if (questionIndex < 0 || questionIndex >= quiz.questionCount) return this;
    return copyWith(currentQuestionIndex: questionIndex);
  }

  /// Complete the quiz
  QuizSession complete() {
    return copyWith(isCompleted: true);
  }

  /// Copy session with updated properties
  QuizSession copyWith({
    Quiz? quiz,
    List<QuizResponse>? responses,
    int? currentQuestionIndex,
    DateTime? startTime,
    bool? isCompleted,
  }) {
    return QuizSession(
      quiz: quiz ?? this.quiz,
      responses: responses ?? this.responses,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      startTime: startTime ?? this.startTime,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QuizSession &&
        other.quiz == quiz &&
        other.currentQuestionIndex == currentQuestionIndex &&
        other.isCompleted == isCompleted;
  }

  @override
  int get hashCode => Object.hash(quiz, currentQuestionIndex, isCompleted);

  @override
  String toString() {
    return 'QuizSession(quiz: ${quiz.quizId}, question: $currentQuestionIndex/${quiz.questionCount}, completed: $isCompleted)';
  }
}