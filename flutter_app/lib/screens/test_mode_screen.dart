import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/quiz.dart';
import '../providers/quiz_provider.dart';
import '../widgets/questions/multiple_choice_question.dart';
import '../widgets/questions/translation_question.dart';
import '../widgets/questions/fill_blank_question.dart';
import '../services/lesson_service.dart';

/// Test mode screen that displays quiz questions
class TestModeScreen extends ConsumerStatefulWidget {
  final String lessonId;

  const TestModeScreen({
    Key? key,
    required this.lessonId,
  }) : super(key: key);

  @override
  ConsumerState<TestModeScreen> createState() => _TestModeScreenState();
}

class _TestModeScreenState extends ConsumerState<TestModeScreen> {
  bool _showReviewMode = false;

  @override
  Widget build(BuildContext context) {
    final quizAsyncValue = ref.watch(quizByLessonLoadProvider(widget.lessonId));
    final session = ref.watch(quizSessionProvider);
    final completion = ref.watch(quizCompletionProvider);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Test Mode'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: Icon(CupertinoIcons.back),
        ),
        trailing: session != null ? _buildQuizActions() : null,
      ),
      child: SafeArea(
        child: quizAsyncValue.when(
          data: (quiz) {
            if (quiz == null) {
              return _buildErrorView('Failed to load quiz for this lesson');
            }

            // Initialize quiz session if not started
            if (session == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(quizSessionProvider.notifier).startQuiz(quiz);
              });
              return _buildLoadingView();
            }

            // Show completion screen if quiz is completed
            if (completion['isCompleted']) {
              return _buildCompletionView();
            }

            // Show quiz content
            return _showReviewMode
                ? _buildReviewMode()
                : _buildQuizContent();
          },
          loading: () => _buildLoadingView(),
          error: (error, stack) => _buildErrorView('Error: $error'),
        ),
      ),
    );
  }

  Widget _buildQuizActions() {
    final session = ref.watch(quizSessionProvider);
    if (session == null) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (session.isCompleted)
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: () {
              setState(() {
                _showReviewMode = !_showReviewMode;
              });
            },
            child: Icon(
              _showReviewMode ? CupertinoIcons.list_bullet : CupertinoIcons.checkmark_circle,
              size: 20,
            ),
          ),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          onPressed: _showRestartDialog,
          child: Icon(CupertinoIcons.refresh, size: 20),
        ),
      ],
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CupertinoActivityIndicator(radius: 20),
          const SizedBox(height: 16),
          Text(
            'Loading quiz...',
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 16,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 48,
              color: CupertinoColors.systemRed,
            ),
            const SizedBox(height: 16),
            Text(
              'Quiz Unavailable',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 16,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizContent() {
    final currentQuestionData = ref.watch(currentQuestionProvider);
    final navigation = ref.watch(quizNavigationProvider);

    if (currentQuestionData == null) {
      return _buildErrorView('Invalid quiz state');
    }

    final question = currentQuestionData['question'] as QuizQuestion;
    final questionIndex = currentQuestionData['questionIndex'] as int;
    final userAnswer = currentQuestionData['userAnswer'];
    final hasAnswered = currentQuestionData['hasAnswered'] as bool;

    return Column(
      children: [
        // Progress header
        _buildProgressHeader(navigation),

        // Question content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Question widget based on type
                _buildQuestionWidget(question, questionIndex, userAnswer),

                const SizedBox(height: 24),

                // Navigation controls
                _buildNavigationControls(currentQuestionData, navigation),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressHeader(Map<String, dynamic> navigation) {
    final currentIndex = navigation['currentIndex'] as int;
    final totalQuestions = navigation['totalQuestions'] as int;
    final progress = navigation['progress'] as double;
    final answeredQuestions = navigation['answeredQuestions'] as List<int>;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoTheme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${currentIndex + 1} of $totalQuestions',
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${answeredQuestions.length}/$totalQuestions answered',
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 14,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey5,
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: CupertinoTheme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionWidget(QuizQuestion question, int questionIndex, dynamic userAnswer) {
    switch (question.type) {
      case 'mcq':
        return MultipleChoiceQuestion(
          question: question,
          selectedChoice: userAnswer as int?,
          onChoiceSelected: (choice) {
            ref.read(quizSessionProvider.notifier).answerCurrentQuestion(choice);
          },
          isEnabled: true,
        );
      case 'translate':
        return TranslationQuestion(
          question: question,
          userAnswer: userAnswer as String?,
          onAnswerChanged: (answer) {
            ref.read(quizSessionProvider.notifier).answerCurrentQuestion(answer);
          },
          isEnabled: true,
        );
      case 'fill_blank':
        return FillBlankQuestion(
          question: question,
          userAnswers: userAnswer as List<String>?,
          onAnswersChanged: (answers) {
            ref.read(quizSessionProvider.notifier).answerCurrentQuestion(answers);
          },
          isEnabled: true,
        );
      default:
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: CupertinoColors.systemRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Unsupported question type: ${question.type}',
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              color: CupertinoColors.systemRed,
            ),
          ),
        );
    }
  }

  Widget _buildNavigationControls(Map<String, dynamic> currentQuestionData, Map<String, dynamic> navigation) {
    final hasAnswered = currentQuestionData['hasAnswered'] as bool;
    final canGoNext = currentQuestionData['canGoNext'] as bool;
    final canGoPrevious = currentQuestionData['canGoPrevious'] as bool;
    final isLastQuestion = currentQuestionData['isLastQuestion'] as bool;
    final readyForSubmission = ref.watch(quizReadyForSubmissionProvider);

    return Column(
      children: [
        Row(
          children: [
            // Previous button
            Expanded(
              child: CupertinoButton(
                onPressed: canGoPrevious
                    ? () => ref.read(quizSessionProvider.notifier).goToPrevious()
                    : null,
                child: Text(
                  'Previous',
                  style: TextStyle(
                    color: canGoPrevious
                        ? CupertinoTheme.of(context).primaryColor
                        : CupertinoColors.inactiveGray,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Next/Submit button
            Expanded(
              child: CupertinoButton.filled(
                onPressed: hasAnswered
                    ? () {
                        if (isLastQuestion && readyForSubmission) {
                          ref.read(quizSessionProvider.notifier).completeQuiz();
                        } else if (canGoNext) {
                          ref.read(quizSessionProvider.notifier).goToNext();
                        }
                      }
                    : null,
                child: Text(
                  isLastQuestion && readyForSubmission
                      ? 'Submit Quiz'
                      : 'Next',
                ),
              ),
            ),
          ],
        ),

        if (!hasAnswered) ...[
          const SizedBox(height: 12),
          Text(
            'Please answer the question to continue',
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 14,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompletionView() {
    final completion = ref.watch(quizCompletionProvider);
    final statistics = ref.watch(quizStatisticsProvider);

    final score = (completion['score'] as double * 100).round();
    final correctCount = completion['correctCount'] as int;
    final totalQuestions = completion['totalQuestions'] as int;
    final elapsedTime = completion['elapsedTime'] as Duration;

    String getGradeText(double scorePercentage) {
      if (scorePercentage >= 0.9) return 'Excellent!';
      if (scorePercentage >= 0.8) return 'Great Job!';
      if (scorePercentage >= 0.7) return 'Good Work!';
      if (scorePercentage >= 0.6) return 'Keep Practicing!';
      return 'Need More Practice';
    }

    Color getGradeColor(double scorePercentage) {
      if (scorePercentage >= 0.8) return CupertinoColors.systemGreen;
      if (scorePercentage >= 0.6) return CupertinoColors.systemOrange;
      return CupertinoColors.systemRed;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Completion celebration
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: getGradeColor(completion['score'] as double).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(
                  CupertinoIcons.checkmark_circle_fill,
                  size: 64,
                  color: getGradeColor(completion['score'] as double),
                ),
                const SizedBox(height: 16),
                Text(
                  'Quiz Complete!',
                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  getGradeText(completion['score'] as double),
                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontSize: 18,
                    color: getGradeColor(completion['score'] as double),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Score summary
          _buildScoreCard(score, correctCount, totalQuestions, elapsedTime),

          const SizedBox(height: 24),

          // Action buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildScoreCard(int score, int correctCount, int totalQuestions, Duration elapsedTime) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoTheme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '$score%',
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: CupertinoTheme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$correctCount out of $totalQuestions correct',
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 16,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: CupertinoColors.separator),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.time,
                size: 16,
                color: CupertinoColors.secondaryLabel,
              ),
              const SizedBox(width: 8),
              Text(
                _formatDuration(elapsedTime),
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 14,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: CupertinoButton.filled(
            onPressed: () {
              setState(() {
                _showReviewMode = true;
              });
            },
            child: Text('Review Answers'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            onPressed: _showRestartDialog,
            child: Text('Retake Quiz'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Back to Lesson'),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewMode() {
    final results = ref.watch(questionResultsProvider);

    return Column(
      children: [
        // Review header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoTheme.of(context).scaffoldBackgroundColor,
            border: Border(
              bottom: BorderSide(
                color: CupertinoColors.separator,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  setState(() {
                    _showReviewMode = false;
                  });
                },
                child: Icon(CupertinoIcons.back),
              ),
              const SizedBox(width: 12),
              Text(
                'Review Answers',
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // Review content
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: results.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final result = results[index];
              final question = result['question'] as QuizQuestion;
              final userAnswer = result['userAnswer'];
              final isCorrect = result['isCorrect'] as bool;

              return _buildReviewQuestionCard(
                question,
                index,
                userAnswer,
                isCorrect,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReviewQuestionCard(QuizQuestion question, int index, dynamic userAnswer, bool isCorrect) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoTheme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect ? CupertinoColors.systemGreen : CupertinoColors.systemRed,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCorrect ? CupertinoColors.systemGreen : CupertinoColors.systemRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Q${index + 1}',
                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                isCorrect ? CupertinoIcons.check_mark : CupertinoIcons.xmark,
                size: 16,
                color: isCorrect ? CupertinoColors.systemGreen : CupertinoColors.systemRed,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? 'Correct' : 'Incorrect',
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isCorrect ? CupertinoColors.systemGreen : CupertinoColors.systemRed,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Question content in review mode
          _buildQuestionWidget(question, index, userAnswer),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }

  void _showRestartDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Restart Quiz'),
        content: Text('Are you sure you want to restart the quiz? Your current progress will be lost.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(quizSessionProvider.notifier).restartQuiz();
              setState(() {
                _showReviewMode = false;
              });
            },
            child: Text('Restart'),
          ),
        ],
      ),
    );
  }
}