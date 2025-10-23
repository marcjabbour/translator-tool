import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/quiz.dart';

/// Fill-in-the-blank question widget with interactive blanks
class FillBlankQuestion extends ConsumerStatefulWidget {
  final QuizQuestion question;
  final List<String>? userAnswers;
  final bool showCorrectAnswer;
  final Function(List<String>) onAnswersChanged;
  final bool isEnabled;

  const FillBlankQuestion({
    Key? key,
    required this.question,
    this.userAnswers,
    this.showCorrectAnswer = false,
    required this.onAnswersChanged,
    this.isEnabled = true,
  }) : super(key: key);

  @override
  ConsumerState<FillBlankQuestion> createState() => _FillBlankQuestionState();
}

class _FillBlankQuestionState extends ConsumerState<FillBlankQuestion>
    with TickerProviderStateMixin {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  List<String> _blanks = [];

  @override
  void initState() {
    super.initState();
    _setupBlanks();
    _setupControllers();

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
  }

  void _setupBlanks() {
    if (widget.question.answer is List) {
      _blanks = List<String>.from(widget.question.answer);
    } else {
      _blanks = [widget.question.answer.toString()];
    }
  }

  void _setupControllers() {
    _controllers = List.generate(_blanks.length, (index) {
      final controller = TextEditingController(
        text: widget.userAnswers != null && index < widget.userAnswers!.length
            ? widget.userAnswers![index]
            : '',
      );
      controller.addListener(_onTextChanged);
      return controller;
    });

    _focusNodes = List.generate(_blanks.length, (index) => FocusNode());
  }

  void _onTextChanged() {
    final answers = _controllers.map((c) => c.text).toList();
    widget.onAnswersChanged(answers);
  }

  @override
  void didUpdateWidget(FillBlankQuestion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userAnswers != oldWidget.userAnswers) {
      for (int i = 0; i < _controllers.length; i++) {
        if (widget.userAnswers != null && i < widget.userAnswers!.length) {
          _controllers[i].text = widget.userAnswers![i];
        }
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.question.isFillBlank) {
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

          // Question with interactive blanks
          _buildQuestionWithBlanks(context),
          const SizedBox(height: 24),

          // Instructions
          _buildInstructions(context),

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
                CupertinoIcons.square_fill_line_vertical_square,
                size: 16,
                color: CupertinoTheme.of(context).primaryColor,
              ),
              const SizedBox(width: 6),
              Text(
                'Fill in the Blanks',
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
        if (widget.showCorrectAnswer && widget.userAnswers != null)
          _buildResultIcon(),
      ],
    );
  }

  Widget _buildResultIcon() {
    final isCorrect = widget.question.isCorrectAnswer(widget.userAnswers);
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

  Widget _buildQuestionWithBlanks(BuildContext context) {
    // Parse the question text to identify blanks (marked with _____)
    final questionText = widget.question.question;
    final parts = questionText.split('_____');

    if (parts.length <= 1) {
      // No blanks found, show regular question with input fields below
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            questionText,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(_blanks.length, (index) => _buildBlankInput(context, index)),
        ],
      );
    }

    // Build question with inline blanks
    return Wrap(
      children: _buildInlineQuestion(context, parts),
    );
  }

  List<Widget> _buildInlineQuestion(BuildContext context, List<String> parts) {
    final widgets = <Widget>[];

    for (int i = 0; i < parts.length; i++) {
      // Add text part
      if (parts[i].isNotEmpty) {
        widgets.add(
          Text(
            parts[i],
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        );
      }

      // Add blank input (except after the last part)
      if (i < parts.length - 1 && i < _blanks.length) {
        widgets.add(_buildInlineBlank(context, i));
      }
    }

    return widgets;
  }

  Widget _buildInlineBlank(BuildContext context, int index) {
    final isCorrect = widget.showCorrectAnswer &&
                     widget.userAnswers != null &&
                     index < widget.userAnswers!.length &&
                     widget.userAnswers![index].toLowerCase().trim() ==
                     _blanks[index].toLowerCase().trim();

    final isIncorrect = widget.showCorrectAnswer &&
                       widget.userAnswers != null &&
                       index < widget.userAnswers!.length &&
                       widget.userAnswers![index].isNotEmpty &&
                       !isCorrect;

    Color borderColor;
    if (isCorrect) {
      borderColor = CupertinoColors.systemGreen;
    } else if (isIncorrect) {
      borderColor = CupertinoColors.systemRed;
    } else if (_focusNodes[index].hasFocus) {
      borderColor = CupertinoTheme.of(context).primaryColor;
    } else {
      borderColor = CupertinoColors.systemGrey4;
    }

    return Container(
      width: 120,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
      ),
      child: CupertinoTextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        enabled: widget.isEnabled && !widget.showCorrectAnswer,
        textAlign: TextAlign.center,
        style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: BoxDecoration(
          color: widget.isEnabled && !widget.showCorrectAnswer
              ? CupertinoTheme.of(context).scaffoldBackgroundColor
              : CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        placeholder: '_____',
        placeholderStyle: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          color: CupertinoColors.placeholderText,
          fontSize: 16,
        ),
        onSubmitted: (value) {
          // Move to next field or remove focus
          if (index < _focusNodes.length - 1) {
            _focusNodes[index + 1].requestFocus();
          } else {
            _focusNodes[index].unfocus();
          }
        },
      ),
    );
  }

  Widget _buildBlankInput(BuildContext context, int index) {
    final isCorrect = widget.showCorrectAnswer &&
                     widget.userAnswers != null &&
                     index < widget.userAnswers!.length &&
                     widget.userAnswers![index].toLowerCase().trim() ==
                     _blanks[index].toLowerCase().trim();

    final isIncorrect = widget.showCorrectAnswer &&
                       widget.userAnswers != null &&
                       index < widget.userAnswers!.length &&
                       widget.userAnswers![index].isNotEmpty &&
                       !isCorrect;

    Color borderColor;
    if (isCorrect) {
      borderColor = CupertinoColors.systemGreen;
    } else if (isIncorrect) {
      borderColor = CupertinoColors.systemRed;
    } else if (_focusNodes[index].hasFocus) {
      borderColor = CupertinoTheme.of(context).primaryColor;
    } else {
      borderColor = CupertinoColors.systemGrey4;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Blank ${index + 1}:',
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: borderColor,
                width: 2,
              ),
            ),
            child: CupertinoTextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              enabled: widget.isEnabled && !widget.showCorrectAnswer,
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
              placeholder: 'Enter missing word...',
              placeholderStyle: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                color: CupertinoColors.placeholderText,
                fontSize: 16,
              ),
              onSubmitted: (value) {
                if (index < _focusNodes.length - 1) {
                  _focusNodes[index + 1].requestFocus();
                } else {
                  _focusNodes[index].unfocus();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: CupertinoColors.systemBlue.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.info,
            size: 16,
            color: CupertinoColors.systemBlue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Fill in the missing words using Lebanese Arabic transliteration (Latin alphabet with numbers)',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 12,
                color: CupertinoColors.systemBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedback(BuildContext context) {
    final isCorrect = widget.question.isCorrectAnswer(widget.userAnswers);

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
                isCorrect ? 'All Correct!' : 'Some Incorrect',
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
            // Show correct answers
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
                    'Correct answers:',
                    style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.systemGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(_blanks.length, (index) {
                    final userAnswer = widget.userAnswers != null && index < widget.userAnswers!.length
                        ? widget.userAnswers![index]
                        : '';
                    final correctAnswer = _blanks[index];
                    final isCorrectBlank = userAnswer.toLowerCase().trim() ==
                                          correctAnswer.toLowerCase().trim();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Text(
                            'Blank ${index + 1}:',
                            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isCorrectBlank
                                  ? CupertinoColors.systemGreen.withOpacity(0.2)
                                  : CupertinoColors.systemRed.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              correctAnswer,
                              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isCorrectBlank
                                    ? CupertinoColors.systemGreen
                                    : CupertinoColors.systemRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
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
              'Invalid fill-in-blank question format',
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