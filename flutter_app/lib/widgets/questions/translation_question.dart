import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/quiz.dart';

/// Translation question widget with input validation
class TranslationQuestion extends ConsumerStatefulWidget {
  final QuizQuestion question;
  final String? userAnswer;
  final bool showCorrectAnswer;
  final Function(String) onAnswerChanged;
  final bool isEnabled;

  const TranslationQuestion({
    Key? key,
    required this.question,
    this.userAnswer,
    this.showCorrectAnswer = false,
    required this.onAnswerChanged,
    this.isEnabled = true,
  }) : super(key: key);

  @override
  ConsumerState<TranslationQuestion> createState() => _TranslationQuestionState();
}

class _TranslationQuestionState extends ConsumerState<TranslationQuestion>
    with TickerProviderStateMixin {
  late TextEditingController _textController;
  late FocusNode _focusNode;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.userAnswer ?? '');
    _focusNode = FocusNode();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();

    // Listen to text changes
    _textController.addListener(() {
      widget.onAnswerChanged(_textController.text);
    });
  }

  @override
  void didUpdateWidget(TranslationQuestion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userAnswer != oldWidget.userAnswer) {
      _textController.text = widget.userAnswer ?? '';
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.question.isTranslation) {
      return _buildErrorWidget(context);
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: _buildQuestionContent(context),
    );
  }

  Widget _buildQuestionContent(BuildContext context) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header
          _buildQuestionHeader(context),
          const SizedBox(height: 20),

          // Question text
          _buildQuestionText(context),
          const SizedBox(height: 24),

          // Input field
          _buildInputField(context),

          // Feedback section
          if (widget.showCorrectAnswer) ...[
            const SizedBox(height: 20),
            _buildFeedback(context),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: CupertinoTheme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.textformat,
                size: 16,
                color: CupertinoTheme.of(context).primaryColor,
              ),
              const SizedBox(width: 6),
              Text(
                'Translation',
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: CupertinoTheme.of(context).primaryColor,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        if (widget.showCorrectAnswer && widget.userAnswer != null)
          _buildResultIcon(),
      ],
    );
  }

  Widget _buildResultIcon() {
    final isCorrect = widget.question.isCorrectAnswer(widget.userAnswer);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isCorrect ? CupertinoColors.systemGreen : CupertinoColors.systemRed,
        shape: BoxShape.circle,
      ),
      child: Icon(
        isCorrect ? CupertinoIcons.check_mark : CupertinoIcons.xmark,
        size: 16,
        color: CupertinoColors.white,
      ),
    );
  }

  Widget _buildQuestionText(BuildContext context) {
    return Text(
      widget.question.question,
      style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        height: 1.4,
      ),
    );
  }

  Widget _buildInputField(BuildContext context) {
    final isCorrect = widget.showCorrectAnswer &&
                     widget.userAnswer != null &&
                     widget.question.isCorrectAnswer(widget.userAnswer);
    final isIncorrect = widget.showCorrectAnswer &&
                       widget.userAnswer != null &&
                       !widget.question.isCorrectAnswer(widget.userAnswer);

    Color borderColor;
    if (isCorrect) {
      borderColor = CupertinoColors.systemGreen;
    } else if (isIncorrect) {
      borderColor = CupertinoColors.systemRed;
    } else if (_focusNode.hasFocus) {
      borderColor = CupertinoTheme.of(context).primaryColor;
    } else {
      borderColor = CupertinoColors.systemGrey4;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your translation:',
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: borderColor,
              width: 2,
            ),
          ),
          child: CupertinoTextField(
            controller: _textController,
            focusNode: _focusNode,
            enabled: widget.isEnabled && !widget.showCorrectAnswer,
            maxLines: 3,
            minLines: 1,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 16,
            ),
            decoration: BoxDecoration(
              color: widget.isEnabled && !widget.showCorrectAnswer
                  ? CupertinoTheme.of(context).scaffoldBackgroundColor
                  : CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.all(12),
            placeholder: 'Type your translation here...',
            placeholderStyle: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              color: CupertinoColors.placeholderText,
              fontSize: 16,
            ),
            onSubmitted: (value) {
              // Remove focus when user presses enter
              _focusNode.unfocus();
            },
          ),
        ),

        // Character count and hints
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '${_textController.text.length} characters',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 12,
                color: CupertinoColors.tertiaryLabel,
              ),
            ),
            const Spacer(),
            if (widget.isEnabled && !widget.showCorrectAnswer)
              Text(
                'Use Latin alphabet only',
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 12,
                  color: CupertinoColors.tertiaryLabel,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeedback(BuildContext context) {
    final isCorrect = widget.userAnswer != null &&
                     widget.question.isCorrectAnswer(widget.userAnswer);
    final correctAnswer = widget.question.correctAnswerDisplay;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCorrect
            ? CupertinoColors.systemGreen.withOpacity(0.1)
            : CupertinoColors.systemRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCorrect
              ? CupertinoColors.systemGreen.withOpacity(0.3)
              : CupertinoColors.systemRed.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Result header
          Row(
            children: [
              Icon(
                isCorrect ? CupertinoIcons.check_mark : CupertinoIcons.xmark,
                size: 16,
                color: isCorrect ? CupertinoColors.systemGreen : CupertinoColors.systemRed,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? 'Correct!' : 'Incorrect',
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isCorrect ? CupertinoColors.systemGreen : CupertinoColors.systemRed,
                ),
              ),
            ],
          ),

          if (!isCorrect) ...[
            const SizedBox(height: 12),
            // Show correct answer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: CupertinoColors.systemGreen.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Correct answer:',
                    style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.systemGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    correctAnswer,
                    style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Explanation
          if (widget.question.rationale != null && widget.question.rationale!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  CupertinoIcons.lightbulb,
                  size: 16,
                  color: CupertinoColors.systemOrange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Explanation',
                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.systemOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.question.rationale!,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.systemRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.systemRed.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.exclamationmark_triangle,
            color: CupertinoColors.systemRed,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Invalid translation question format',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                color: CupertinoColors.systemRed,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}