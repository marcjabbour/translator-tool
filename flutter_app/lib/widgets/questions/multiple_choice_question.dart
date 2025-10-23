import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/quiz.dart';

/// Multiple choice question widget with Cupertino design
class MultipleChoiceQuestion extends ConsumerStatefulWidget {
  final QuizQuestion question;
  final int? selectedChoice;
  final bool showCorrectAnswer;
  final Function(int) onChoiceSelected;
  final bool isEnabled;

  const MultipleChoiceQuestion({
    Key? key,
    required this.question,
    this.selectedChoice,
    this.showCorrectAnswer = false,
    required this.onChoiceSelected,
    this.isEnabled = true,
  }) : super(key: key);

  @override
  ConsumerState<MultipleChoiceQuestion> createState() => _MultipleChoiceQuestionState();
}

class _MultipleChoiceQuestionState extends ConsumerState<MultipleChoiceQuestion>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.question.isMultipleChoice || widget.question.choices == null) {
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

          // Answer choices
          _buildChoices(context),

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
                CupertinoIcons.list_bullet,
                size: 16,
                color: CupertinoTheme.of(context).primaryColor,
              ),
              const SizedBox(width: 6),
              Text(
                'Multiple Choice',
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
        if (widget.showCorrectAnswer && widget.selectedChoice != null)
          _buildResultIcon(),
      ],
    );
  }

  Widget _buildResultIcon() {
    final isCorrect = widget.selectedChoice == widget.question.answer;
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

  Widget _buildChoices(BuildContext context) {
    final choices = widget.question.choices!;
    return Column(
      children: choices.asMap().entries.map((entry) {
        final index = entry.key;
        final choice = entry.value;
        return _buildChoiceOption(context, index, choice);
      }).toList(),
    );
  }

  Widget _buildChoiceOption(BuildContext context, int index, String choice) {
    final isSelected = widget.selectedChoice == index;
    final isCorrect = widget.question.answer == index;
    final showAsCorrect = widget.showCorrectAnswer && isCorrect;
    final showAsWrong = widget.showCorrectAnswer && isSelected && !isCorrect;

    Color backgroundColor;
    Color borderColor;
    Color textColor;

    if (showAsCorrect) {
      backgroundColor = CupertinoColors.systemGreen.withOpacity(0.1);
      borderColor = CupertinoColors.systemGreen;
      textColor = CupertinoColors.systemGreen;
    } else if (showAsWrong) {
      backgroundColor = CupertinoColors.systemRed.withOpacity(0.1);
      borderColor = CupertinoColors.systemRed;
      textColor = CupertinoColors.systemRed;
    } else if (isSelected) {
      backgroundColor = CupertinoTheme.of(context).primaryColor.withOpacity(0.1);
      borderColor = CupertinoTheme.of(context).primaryColor;
      textColor = CupertinoTheme.of(context).primaryColor;
    } else {
      backgroundColor = CupertinoColors.systemGrey6;
      borderColor = CupertinoColors.systemGrey4;
      textColor = CupertinoTheme.of(context).textTheme.textStyle.color ?? CupertinoColors.label;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: widget.isEnabled && !widget.showCorrectAnswer
            ? () => widget.onChoiceSelected(index)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: isSelected || showAsCorrect || showAsWrong ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Choice indicator
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected || showAsCorrect || showAsWrong
                      ? borderColor
                      : CupertinoColors.systemGrey3,
                ),
                child: Center(
                  child: Text(
                    String.fromCharCode(65 + index), // A, B, C, D
                    style: TextStyle(
                      color: isSelected || showAsCorrect || showAsWrong
                          ? CupertinoColors.white
                          : CupertinoColors.systemGrey,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Choice text
              Expanded(
                child: Text(
                  choice,
                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),

              // Result indicator
              if (showAsCorrect || showAsWrong)
                Icon(
                  showAsCorrect ? CupertinoIcons.check_mark : CupertinoIcons.xmark,
                  size: 20,
                  color: borderColor,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedback(BuildContext context) {
    if (widget.question.rationale == null || widget.question.rationale!.isEmpty) {
      return const SizedBox.shrink();
    }

    final isCorrect = widget.selectedChoice == widget.question.answer;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCorrect
            ? CupertinoColors.systemGreen.withOpacity(0.1)
            : CupertinoColors.systemOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCorrect
              ? CupertinoColors.systemGreen.withOpacity(0.3)
              : CupertinoColors.systemOrange.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.lightbulb,
                size: 16,
                color: isCorrect ? CupertinoColors.systemGreen : CupertinoColors.systemOrange,
              ),
              const SizedBox(width: 8),
              Text(
                'Explanation',
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isCorrect ? CupertinoColors.systemGreen : CupertinoColors.systemOrange,
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
              'Invalid multiple choice question format',
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