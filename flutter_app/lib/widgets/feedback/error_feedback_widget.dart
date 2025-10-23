import 'package:flutter/cupertino.dart';
import '../../models/evaluation_models.dart';

/// Widget for displaying categorized error feedback
class ErrorFeedbackWidget extends StatelessWidget {
  final List<ErrorFeedback> errors;
  final String? suggestion;
  final bool isCorrect;
  final bool compact;

  const ErrorFeedbackWidget({
    Key? key,
    required this.errors,
    this.suggestion,
    required this.isCorrect,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isCorrect && errors.isEmpty) {
      return _buildCorrectIndicator(context);
    }

    if (compact) {
      return _buildCompactErrorIndicator(context);
    }

    return _buildDetailedErrorFeedback(context);
  }

  Widget _buildCorrectIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: CupertinoColors.systemGreen.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.checkmark_circle_fill,
            color: CupertinoColors.systemGreen,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            'Correct',
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              color: CupertinoColors.systemGreen,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactErrorIndicator(BuildContext context) {
    if (errors.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: CupertinoColors.systemRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: CupertinoColors.systemRed.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_circle_fill,
            color: CupertinoColors.systemRed,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            '${errors.length} error${errors.length == 1 ? '' : 's'}',
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              color: CupertinoColors.systemRed,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedErrorFeedback(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCorrect
            ? CupertinoColors.systemGreen.withOpacity(0.05)
            : CupertinoColors.systemRed.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect
              ? CupertinoColors.systemGreen.withOpacity(0.2)
              : CupertinoColors.systemRed.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with result indicator
          Row(
            children: [
              Icon(
                isCorrect
                    ? CupertinoIcons.checkmark_circle_fill
                    : CupertinoIcons.exclamationmark_circle_fill,
                color: isCorrect
                    ? CupertinoColors.systemGreen
                    : CupertinoColors.systemRed,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? 'Correct' : 'Needs Improvement',
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  color: isCorrect
                      ? CupertinoColors.systemGreen
                      : CupertinoColors.systemRed,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),

          if (errors.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Issues Found:',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            ...errors.map((error) => _buildErrorItem(context, error)),
          ],

          if (suggestion != null && suggestion!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    CupertinoIcons.lightbulb,
                    color: CupertinoColors.systemBlue,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      suggestion!,
                      style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                        color: CupertinoColors.systemBlue,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorItem(BuildContext context, ErrorFeedback error) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getErrorTypeColor(error.type).withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _getErrorTypeLabel(error.type),
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                color: _getErrorTypeColor(error.type),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (error.token.isNotEmpty)
                  RichText(
                    text: TextSpan(
                      style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                        fontSize: 14,
                      ),
                      children: [
                        const TextSpan(text: 'Issue with: '),
                        TextSpan(
                          text: '"${error.token}"',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.systemRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (error.hint != null && error.hint!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    error.hint!,
                    style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getErrorTypeColor(String errorType) {
    switch (errorType.toUpperCase()) {
      case 'EN_IN_AR':
        return CupertinoColors.systemRed;
      case 'SPELL_T':
        return CupertinoColors.systemOrange;
      case 'GRAMMAR':
        return CupertinoColors.systemPurple;
      case 'VOCAB':
        return CupertinoColors.systemYellow;
      case 'OMISSION':
      case 'EXTRA':
        return CupertinoColors.systemIndigo;
      default:
        return CupertinoColors.systemGray;
    }
  }

  String _getErrorTypeLabel(String errorType) {
    switch (errorType.toUpperCase()) {
      case 'EN_IN_AR':
        return 'English';
      case 'SPELL_T':
        return 'Spelling';
      case 'GRAMMAR':
        return 'Grammar';
      case 'VOCAB':
        return 'Vocabulary';
      case 'OMISSION':
        return 'Missing';
      case 'EXTRA':
        return 'Extra';
      default:
        return 'Other';
    }
  }
}

/// Widget for correction suggestions with visual indicators
class CorrectionSuggestionWidget extends StatelessWidget {
  final String suggestion;
  final String? correctAnswer;
  final bool showCorrectAnswer;

  const CorrectionSuggestionWidget({
    Key? key,
    required this.suggestion,
    this.correctAnswer,
    this.showCorrectAnswer = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.systemGreen.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.checkmark_shield,
                color: CupertinoColors.systemGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Suggested Improvement',
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  color: CupertinoColors.systemGreen,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            suggestion,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 14,
              height: 1.4,
            ),
          ),
          if (showCorrectAnswer && correctAnswer != null && correctAnswer!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.check_mark,
                    color: CupertinoColors.systemGreen,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Correct answer: ',
                    style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    correctAnswer!,
                    style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.systemGreen,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Modal for detailed error information and improvement guidance
class ErrorDetailModal extends StatelessWidget {
  final String errorType;
  final String token;
  final String? hint;
  final VoidCallback? onDismiss;

  const ErrorDetailModal({
    Key? key,
    required this.errorType,
    required this.token,
    this.hint,
    this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CupertinoActionSheet(
      title: Text(
        'Error Details',
        style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      message: Column(
        children: [
          const SizedBox(height: 16),
          _buildErrorTypeSection(context),
          const SizedBox(height: 16),
          _buildTokenSection(context),
          if (hint != null && hint!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildHintSection(context),
          ],
          const SizedBox(height: 16),
          _buildImprovementGuidance(context),
        ],
      ),
      actions: [
        CupertinoActionSheetAction(
          onPressed: onDismiss ?? () => Navigator.of(context).pop(),
          child: const Text('Got it'),
        ),
      ],
    );
  }

  Widget _buildErrorTypeSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getErrorTypeColor(errorType).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            _getErrorTypeIcon(errorType),
            color: _getErrorTypeColor(errorType),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getErrorTypeTitle(errorType),
                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _getErrorTypeDescription(errorType),
                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontSize: 14,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGray6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.quote_bubble,
            color: CupertinoColors.systemGray,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Issue with: ',
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 14,
            ),
          ),
          Text(
            '"$token"',
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.systemRed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHintSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            CupertinoIcons.lightbulb,
            color: CupertinoColors.systemBlue,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hint!,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 14,
                color: CupertinoColors.systemBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImprovementGuidance(BuildContext context) {
    final guidance = _getImprovementGuidance(errorType);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.book,
                color: CupertinoColors.systemGreen,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'How to improve:',
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: CupertinoColors.systemGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            guidance,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Color _getErrorTypeColor(String errorType) {
    switch (errorType.toUpperCase()) {
      case 'EN_IN_AR':
        return CupertinoColors.systemRed;
      case 'SPELL_T':
        return CupertinoColors.systemOrange;
      case 'GRAMMAR':
        return CupertinoColors.systemPurple;
      case 'VOCAB':
        return CupertinoColors.systemYellow;
      case 'OMISSION':
      case 'EXTRA':
        return CupertinoColors.systemIndigo;
      default:
        return CupertinoColors.systemGray;
    }
  }

  IconData _getErrorTypeIcon(String errorType) {
    switch (errorType.toUpperCase()) {
      case 'EN_IN_AR':
        return CupertinoIcons.textformat_abc;
      case 'SPELL_T':
        return CupertinoIcons.pencil;
      case 'GRAMMAR':
        return CupertinoIcons.textformat;
      case 'VOCAB':
        return CupertinoIcons.book;
      case 'OMISSION':
        return CupertinoIcons.minus_circle;
      case 'EXTRA':
        return CupertinoIcons.plus_circle;
      default:
        return CupertinoIcons.exclamationmark_circle;
    }
  }

  String _getErrorTypeTitle(String errorType) {
    switch (errorType.toUpperCase()) {
      case 'EN_IN_AR':
        return 'English in Arabic';
      case 'SPELL_T':
        return 'Transliteration Spelling';
      case 'GRAMMAR':
        return 'Grammar Issue';
      case 'VOCAB':
        return 'Vocabulary Choice';
      case 'OMISSION':
        return 'Missing Word';
      case 'EXTRA':
        return 'Extra Word';
      default:
        return 'Other Issue';
    }
  }

  String _getErrorTypeDescription(String errorType) {
    switch (errorType.toUpperCase()) {
      case 'EN_IN_AR':
        return 'English word used where Arabic transliteration expected';
      case 'SPELL_T':
        return 'Misspelling in Lebanese Arabic transliteration';
      case 'GRAMMAR':
        return 'Word order or grammatical structure issue';
      case 'VOCAB':
        return 'Incorrect word choice';
      case 'OMISSION':
        return 'Missing word that changes meaning';
      case 'EXTRA':
        return 'Added word that changes meaning';
      default:
        return 'General issue with response';
    }
  }

  String _getImprovementGuidance(String errorType) {
    switch (errorType.toUpperCase()) {
      case 'EN_IN_AR':
        return 'Practice using Lebanese Arabic transliteration instead of English words. Remember that Lebanese Arabic uses Latin letters with numbers (2,3,5,7,8,9) for specific sounds.';
      case 'SPELL_T':
        return 'Review Lebanese Arabic transliteration rules. Common patterns include: 7 for ح, 3 for ع, 2 for ء. Practice with consistent spelling patterns.';
      case 'GRAMMAR':
        return 'Study Lebanese Arabic sentence structure and word order. Unlike English, Lebanese Arabic may have different grammatical patterns.';
      case 'VOCAB':
        return 'Expand your Lebanese Arabic vocabulary. Consider the context and choose words that fit the situation appropriately.';
      case 'OMISSION':
        return 'Pay attention to all parts of the sentence. Make sure you include all necessary words to convey the complete meaning.';
      case 'EXTRA':
        return 'Focus on concise expression. Remove unnecessary words that might confuse the meaning or make the sentence unclear.';
      default:
        return 'Keep practicing and reviewing the lesson content. Each mistake is a learning opportunity!';
    }
  }
}