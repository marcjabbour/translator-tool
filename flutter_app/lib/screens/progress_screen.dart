import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/progress_models.dart';
import '../providers/progress_provider.dart';
import '../widgets/charts/progress_chart.dart';
import '../widgets/charts/accuracy_trend_chart.dart';
import '../widgets/progress_metrics_card.dart';
import '../widgets/improvement_areas_card.dart';
import '../widgets/error_breakdown_chart.dart';

/// Progress dashboard screen showing user learning analytics
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  int _selectedDaysBack = 30;
  final List<int> _dayOptions = [7, 14, 30, 60, 90];

  @override
  Widget build(BuildContext context) {
    final progressAsync = ref.watch(progressProvider(_selectedDaysBack));

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Progress'),
        trailing: _buildTimeRangeSelector(),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: () async {
                ref.invalidate(progressProvider(_selectedDaysBack));
              },
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: progressAsync.when(
                  data: (progress) => _buildProgressContent(context, progress),
                  loading: () => _buildLoadingContent(context),
                  error: (error, stack) => _buildErrorContent(context, error.toString()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => _showTimeRangeActionSheet(),
      child: Text(
        '${_selectedDaysBack}d',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showTimeRangeActionSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Time Range'),
        message: const Text('Select the time period for your progress analysis'),
        actions: _dayOptions.map((days) => CupertinoActionSheetAction(
          onPressed: () {
            setState(() {
              _selectedDaysBack = days;
            });
            Navigator.pop(context);
          },
          child: Text('Last $days days'),
        )).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDefaultAction: true,
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Widget _buildProgressContent(BuildContext context, ProgressResponse progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with overall stats
        _buildProgressHeader(context, progress),
        const SizedBox(height: 24),

        // Accuracy trend chart
        _buildSectionHeader(context, 'Accuracy Trend'),
        const SizedBox(height: 12),
        AccuracyTrendChart(
          trendPoints: progress.trends,
          timeRange: _selectedDaysBack,
        ),
        const SizedBox(height: 24),

        // Weekly metrics summary
        _buildSectionHeader(context, 'Weekly Summary'),
        const SizedBox(height: 12),
        ProgressMetricsCard(metrics: progress.weekly),
        const SizedBox(height: 24),

        // Error breakdown
        if (progress.weekly.errorBreakdown.isNotEmpty) ...[
          _buildSectionHeader(context, 'Error Analysis'),
          const SizedBox(height: 12),
          ErrorBreakdownChart(errorBreakdown: progress.weekly.errorBreakdown),
          const SizedBox(height: 24),
        ],

        // Improvement areas
        if (progress.hasImprovementAreas) ...[
          _buildSectionHeader(context, 'Areas for Improvement'),
          const SizedBox(height: 12),
          ImprovementAreasCard(improvementAreas: progress.improvementAreas),
          const SizedBox(height: 24),
        ],

        // Study streak visualization
        _buildSectionHeader(context, 'Learning Streak'),
        const SizedBox(height: 12),
        _buildStreakCard(context, progress.weekly),
        const SizedBox(height: 24),

        // Daily progress chart
        if (progress.trends.isNotEmpty) ...[
          _buildSectionHeader(context, 'Daily Activity'),
          const SizedBox(height: 12),
          ProgressChart(
            trendPoints: progress.trends,
            showAccuracy: false,
            showTimeSpent: true,
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  Widget _buildProgressHeader(BuildContext context, ProgressResponse progress) {
    final trend = progress.overallTrend;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            CupertinoTheme.of(context).primaryColor,
            CupertinoTheme.of(context).primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Progress',
                      style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: CupertinoColors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Last $_selectedDaysBack days',
                      style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                        fontSize: 16,
                        color: CupertinoColors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              _buildTrendIndicator(context, trend),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  'Accuracy',
                  progress.weekly.accuracyPercentage,
                  CupertinoIcons.chart_bar_fill,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  context,
                  'Time Spent',
                  progress.weekly.formattedTimeSpent,
                  CupertinoIcons.clock_fill,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  context,
                  'Streak',
                  '${progress.weekly.streakDays}d',
                  CupertinoIcons.flame_fill,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendIndicator(BuildContext context, TrendDirection trend) {
    IconData icon;
    Color color;

    switch (trend) {
      case TrendDirection.improving:
        icon = CupertinoIcons.arrow_up_circle_fill;
        color = CupertinoColors.systemGreen;
        break;
      case TrendDirection.declining:
        icon = CupertinoIcons.arrow_down_circle_fill;
        color = CupertinoColors.systemRed;
        break;
      case TrendDirection.stable:
        icon = CupertinoIcons.minus_circle_fill;
        color = CupertinoColors.systemBlue;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: CupertinoColors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            trend.description,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: CupertinoColors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: CupertinoColors.white,
          ),
        ),
        Text(
          label,
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            fontSize: 12,
            color: CupertinoColors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildStreakCard(BuildContext context, ProgressMetrics metrics) {
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CupertinoColors.systemOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              CupertinoIcons.flame_fill,
              color: CupertinoColors.systemOrange,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${metrics.streakDays} Day Streak',
                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  metrics.streakDescription,
                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontSize: 14,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
          if (metrics.isImproving)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                metrics.improvementRatePercentage,
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: CupertinoColors.systemGreen,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingContent(BuildContext context) {
    return Column(
      children: [
        // Loading header
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        const SizedBox(height: 24),

        // Loading charts
        ...List.generate(3, (index) => Column(
          children: [
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 24),
          ],
        )),
      ],
    );
  }

  Widget _buildErrorContent(BuildContext context, String error) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.systemRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle,
            color: CupertinoColors.systemRed,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Unable to load progress data',
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please check your connection and try again',
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 14,
              color: CupertinoColors.secondaryLabel,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          CupertinoButton.filled(
            onPressed: () {
              ref.invalidate(progressProvider(_selectedDaysBack));
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}