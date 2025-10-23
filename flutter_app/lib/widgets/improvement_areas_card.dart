import 'package:flutter/cupertino.dart';
import '../models/progress_models.dart';

/// Card widget showing areas that need improvement
class ImprovementAreasCard extends StatelessWidget {
  final List<String> improvementAreas;

  const ImprovementAreasCard({
    Key? key,
    required this.improvementAreas,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (improvementAreas.isEmpty) {
      return _buildNoImprovementNeeded(context);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoTheme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.separator,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          ..._buildImprovementItems(context),
          const SizedBox(height: 16),
          _buildActionButton(context),
        ],
      ),
    );
  }

  Widget _buildHeader(Context context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            CupertinoIcons.lightbulb,
            color: CupertinoColors.systemBlue,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Focus Areas',
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Based on your recent performance',
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildImprovementItems(BuildContext context) {
    return improvementAreas.asMap().entries.map((entry) {
      final index = entry.key;
      final area = entry.value;
      final priority = _getPriorityLevel(index);

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildImprovementItem(context, area, priority),
      );
    }).toList();
  }

  Widget _buildImprovementItem(BuildContext context, String area, ImprovementPriority priority) {
    final errorDisplayName = ErrorTypeHelper.getDisplayName(area);
    final errorDescription = ErrorTypeHelper.getDescription(area);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: priority.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: priority.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 40,
            decoration: BoxDecoration(
              color: priority.color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        errorDisplayName,
                        style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _buildPriorityBadge(context, priority),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  errorDescription,
                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
                const SizedBox(height: 8),
                _buildImprovementTips(context, area),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(BuildContext context, ImprovementPriority priority) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: priority.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        priority.label,
        style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: CupertinoColors.white,
        ),
      ),
    );
  }

  Widget _buildImprovementTips(BuildContext context, String errorType) {
    final tips = _getImprovementTips(errorType);

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: tips.map((tip) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          tip,
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            fontSize: 10,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        color: CupertinoColors.systemBlue,
        borderRadius: BorderRadius.circular(8),
        padding: const EdgeInsets.symmetric(vertical: 12),
        onPressed: () {
          // TODO: Navigate to practice screen focused on improvement areas
          _showPracticeModal(context);
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.book,
              size: 16,
              color: CupertinoColors.white,
            ),
            const SizedBox(width: 8),
            Text(
              'Practice These Areas',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoImprovementNeeded(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.systemGreen.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            CupertinoIcons.checkmark_seal_fill,
            size: 48,
            color: CupertinoColors.systemGreen,
          ),
          const SizedBox(height: 16),
          Text(
            'Excellent Work!',
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: CupertinoColors.systemGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re performing well across all areas. Keep up the great work!',
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 14,
              color: CupertinoColors.secondaryLabel,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showPracticeModal(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Practice Options'),
        message: const Text('Choose how you\'d like to practice these areas'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to targeted lesson
            },
            child: const Text('Start Targeted Lesson'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to quiz focused on improvement areas
            },
            child: const Text('Take Practice Quiz'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Show study guide
            },
            child: const Text('View Study Guide'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDefaultAction: true,
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  ImprovementPriority _getPriorityLevel(int index) {
    switch (index) {
      case 0:
        return ImprovementPriority.high;
      case 1:
        return ImprovementPriority.medium;
      default:
        return ImprovementPriority.low;
    }
  }

  List<String> _getImprovementTips(String errorType) {
    switch (errorType) {
      case 'EN_IN_AR':
        return ['Practice transliteration', 'Use Arabic script', 'Review vocabulary'];
      case 'SPELL_T':
        return ['Practice spelling', 'Review phonetics', 'Use audio guides'];
      case 'GRAMMAR':
        return ['Study grammar rules', 'Practice sentence structure', 'Review examples'];
      case 'VOCAB':
        return ['Expand vocabulary', 'Practice context', 'Use flashcards'];
      case 'OMISSION':
        return ['Read carefully', 'Check completeness', 'Practice listening'];
      case 'EXTRA':
        return ['Be concise', 'Focus on meaning', 'Practice editing'];
      default:
        return ['Practice regularly', 'Review lessons', 'Ask for help'];
    }
  }
}

/// Priority levels for improvement areas
enum ImprovementPriority {
  high,
  medium,
  low,
}

extension ImprovementPriorityX on ImprovementPriority {
  String get label {
    switch (this) {
      case ImprovementPriority.high:
        return 'High';
      case ImprovementPriority.medium:
        return 'Medium';
      case ImprovementPriority.low:
        return 'Low';
    }
  }

  Color get color {
    switch (this) {
      case ImprovementPriority.high:
        return CupertinoColors.systemRed;
      case ImprovementPriority.medium:
        return CupertinoColors.systemOrange;
      case ImprovementPriority.low:
        return CupertinoColors.systemYellow;
    }
  }
}