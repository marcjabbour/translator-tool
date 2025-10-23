import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_progress.dart';
import '../services/progress_service.dart';

/// User dashboard screen showing learning progress and statistics
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardStatsProvider);
    final profileAsync = ref.watch(userProfileProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Dashboard'),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: () async {
                ref.invalidate(dashboardStatsProvider);
                ref.invalidate(userProfileProvider);
              },
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome section
                    _buildWelcomeSection(context, profileAsync),
                    const SizedBox(height: 24),

                    // Stats overview
                    dashboardAsync.when(
                      data: (stats) => _buildStatsOverview(context, stats),
                      loading: () => _buildLoadingStats(context),
                      error: (error, stack) => _buildErrorSection(context, error.toString()),
                    ),
                    const SizedBox(height: 24),

                    // Learning streak
                    _buildStreakSection(context, ref),
                    const SizedBox(height: 24),

                    // Recent activity
                    _buildRecentActivitySection(context, ref),
                    const SizedBox(height: 24),

                    // Topic progress
                    dashboardAsync.when(
                      data: (stats) => _buildTopicProgressSection(context, stats),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 24),

                    // Quick actions
                    _buildQuickActionsSection(context),
                  ],
                ),
              ),
            ),
          ],
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context, AsyncValue<UserProfile> profileAsync) {
    return profileAsync.when(
      data: (profile) => Container(
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
            Text(
              'Welcome back${profile.displayName != null ? ', ${profile.displayName}' : ''}!',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: CupertinoColors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Keep up the great work learning Lebanese Arabic',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 16,
                color: CupertinoColors.white.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildWelcomeStat(
                  context,
                  'Lessons Completed',
                  profile.totalLessonsCompleted.toString(),
                ),
                const SizedBox(width: 20),
                _buildWelcomeStat(
                  context,
                  'Total Time',
                  profile.formattedTotalTime,
                ),
              ],
            ),
          ],
        ),
      ),
      loading: () => _buildLoadingWelcome(context),
      error: (_, __) => _buildErrorWelcome(context),
    );
  }

  Widget _buildWelcomeStat(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            fontSize: 20,
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

  Widget _buildStatsOverview(BuildContext context, DashboardStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                'Lessons',
                stats.totalLessonsCompleted.toString(),
                CupertinoIcons.book,
                CupertinoColors.systemBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context,
                'Quizzes',
                stats.totalQuizzesCompleted.toString(),
                CupertinoIcons.checkmark_circle,
                CupertinoColors.systemGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                'Avg Score',
                stats.averageQuizScorePercentage,
                CupertinoIcons.star,
                CupertinoColors.systemOrange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context,
                'This Week',
                stats.lessonsThisWeek.toString(),
                CupertinoIcons.calendar,
                CupertinoColors.systemPurple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const Spacer(),
              Text(
                value,
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 14,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakSection(BuildContext context, WidgetRef ref) {
    final streakData = ref.watch(streakStatusProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.systemOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: CupertinoColors.systemOrange.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.flame,
                size: 24,
                color: CupertinoColors.systemOrange,
              ),
              const SizedBox(width: 12),
              Text(
                'Learning Streak',
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${streakData['current']} days',
                      style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: CupertinoColors.systemOrange,
                      ),
                    ),
                    Text(
                      'Current streak',
                      style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                        fontSize: 14,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Best: ${streakData['longest']} days',
                    style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    streakData['current'] > 0 ? 'Keep it up!' : 'Start your streak today!',
                    style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      fontSize: 14,
                      color: CupertinoColors.systemOrange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitySection(BuildContext context, WidgetRef ref) {
    final recentActivity = ref.watch(recentActivityProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        if (recentActivity.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'No recent activity. Start learning to see your progress here!',
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  color: CupertinoColors.secondaryLabel,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...recentActivity.take(5).map((progress) => _buildActivityItem(context, progress)),
      ],
    );
  }

  Widget _buildActivityItem(BuildContext context, UserProgress progress) {
    IconData icon;
    Color color;
    String description;

    switch (progress.status) {
      case 'completed':
        icon = CupertinoIcons.checkmark_circle_fill;
        color = CupertinoColors.systemGreen;
        description = 'Completed lesson';
        break;
      case 'in_progress':
        icon = CupertinoIcons.clock;
        color = CupertinoColors.systemOrange;
        description = 'Studied lesson';
        break;
      default:
        icon = CupertinoIcons.book;
        color = CupertinoColors.systemBlue;
        description = 'Viewed lesson';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
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
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatRelativeTime(progress.lastAccessed),
                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontSize: 14,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
          if (progress.timeSpentMinutes > 0)
            Text(
              progress.formattedTimeSpent,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 14,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopicProgressSection(BuildContext context, DashboardStats stats) {
    if (stats.topicProgress.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Topic Progress',
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ...stats.topicProgress.entries.map((entry) => _buildTopicItem(context, entry)),
      ],
    );
  }

  Widget _buildTopicItem(BuildContext context, MapEntry<String, dynamic> topicData) {
    final topic = topicData.key;
    final data = topicData.value as Map<String, dynamic>;
    final completionRate = (data['completion_rate'] as double? ?? 0.0);
    final completed = data['completed'] as int? ?? 0;
    final total = data['total'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                topic.replaceAll('_', ' ').toUpperCase(),
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$completed/$total',
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 14,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey5,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: completionRate,
              child: Container(
                decoration: BoxDecoration(
                  color: completionRate > 0.8
                      ? CupertinoColors.systemGreen
                      : completionRate > 0.5
                          ? CupertinoColors.systemOrange
                          : CupertinoColors.systemBlue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(completionRate * 100).round()}% complete',
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 12,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                context,
                'Continue Learning',
                CupertinoIcons.play_fill,
                CupertinoColors.systemBlue,
                () {
                  // Navigate to lesson selection or continue last lesson
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionButton(
                context,
                'View Analytics',
                CupertinoIcons.chart_bar,
                CupertinoColors.systemGreen,
                () {
                  // Navigate to analytics screen
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Loading states
  Widget _buildLoadingWelcome(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 24,
            width: 200,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey5,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 16,
            width: 300,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey5,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingStats(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildLoadingStatCard(context)),
            const SizedBox(width: 12),
            Expanded(child: _buildLoadingStatCard(context)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildLoadingStatCard(context)),
            const SizedBox(width: 12),
            Expanded(child: _buildLoadingStatCard(context)),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingStatCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 20,
            width: 60,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey5,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 14,
            width: 80,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey5,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  // Error states
  Widget _buildErrorWelcome(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.systemRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'Failed to load profile information',
        style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          color: CupertinoColors.systemRed,
        ),
      ),
    );
  }

  Widget _buildErrorSection(BuildContext context, String error) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.systemRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            CupertinoIcons.exclamationmark_triangle,
            size: 24,
            color: CupertinoColors.systemRed,
          ),
          const SizedBox(height: 8),
          Text(
            'Failed to load dashboard data',
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontWeight: FontWeight.w500,
              color: CupertinoColors.systemRed,
            ),
          ),
        ],
      ),
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}