import 'package:flutter/cupertino.dart';
import '../models/progress_models.dart';

/// Card widget displaying key progress metrics
class ProgressMetricsCard extends StatelessWidget {
  final ProgressMetrics metrics;

  const ProgressMetricsCard({
    Key? key,
    required this.metrics,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 20),
          _buildMetricsGrid(context),
          const SizedBox(height: 16),
          _buildProgressIndicators(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Weekly Summary',
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (metrics.isImproving)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.arrow_up,
                  size: 12,
                  color: CupertinoColors.systemGreen,
                ),
                const SizedBox(width: 4),
                Text(
                  metrics.improvementRatePercentage,
                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: CupertinoColors.systemGreen,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMetricsGrid(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricItem(
            context,
            'Accuracy',
            metrics.accuracyPercentage,
            CupertinoIcons.target,
            _getAccuracyColor(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricItem(
            context,
            'Time Spent',
            metrics.formattedTimeSpent,
            CupertinoIcons.clock,
            CupertinoColors.systemBlue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricItem(
            context,
            'Lessons',
            metrics.lessonsCompleted.toString(),
            CupertinoIcons.book,
            CupertinoColors.systemPurple,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 12,
              color: CupertinoColors.secondaryLabel,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicators(BuildContext context) {
    return Column(
      children: [
        // Accuracy progress bar
        _buildProgressBar(
          context,
          'Accuracy Level',
          metrics.accuracy,
          _getAccuracyColor(),
        ),
        const SizedBox(height: 12),

        // Error rate indicator
        if (metrics.totalErrors > 0) ...[
          _buildErrorSummary(context),
          const SizedBox(height: 12),
        ],

        // Streak indicator
        if (metrics.streakDays > 0)
          _buildStreakIndicator(context),
      ],
    );
  }

  Widget _buildProgressBar(
    BuildContext context,
    String label,
    double progress,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey5,
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorSummary(BuildContext context) {
    final topError = metrics.topErrorType;
    if (topError == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemYellow.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: CupertinoColors.systemYellow.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle,
            color: CupertinoColors.systemYellow,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Most Common Error',
                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  ErrorTypeHelper.getDisplayName(topError),
                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontSize: 11,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${metrics.errorBreakdown[topError]}x',
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: CupertinoColors.systemYellow,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.flame_fill,
            color: CupertinoColors.systemOrange,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${metrics.streakDays} Day Streak',
                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  metrics.streakDescription,
                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
          if (metrics.streakDays >= 7)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: CupertinoColors.systemOrange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Hot!',
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getAccuracyColor() {
    if (metrics.accuracy >= 0.8) return CupertinoColors.systemGreen;
    if (metrics.accuracy >= 0.6) return CupertinoColors.systemYellow;
    return CupertinoColors.systemRed;
  }
}