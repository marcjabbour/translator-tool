import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_progress.dart';
import '../services/progress_service.dart';

/// Widget for tracking user progress during lesson viewing
class ProgressTracker extends ConsumerStatefulWidget {
  final String lessonId;
  final Widget child;
  final Function(UserProgress)? onProgressUpdate;

  const ProgressTracker({
    Key? key,
    required this.lessonId,
    required this.child,
    this.onProgressUpdate,
  }) : super(key: key);

  @override
  ConsumerState<ProgressTracker> createState() => _ProgressTrackerState();
}

class _ProgressTrackerState extends ConsumerState<ProgressTracker> {
  DateTime? _sessionStart;
  int _translationToggles = 0;
  bool _hasTrackedView = false;

  @override
  void initState() {
    super.initState();
    _sessionStart = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackLessonView();
    });
  }

  @override
  void dispose() {
    _updateTimeSpent();
    super.dispose();
  }

  Future<void> _trackLessonView() async {
    if (_hasTrackedView) return;

    try {
      final service = ref.read(progressServiceProvider);
      final progress = await service.trackLessonView(widget.lessonId);
      _hasTrackedView = true;

      if (widget.onProgressUpdate != null) {
        widget.onProgressUpdate!(progress);
      }
    } catch (e) {
      // Silently handle errors to not disrupt user experience
      debugPrint('Failed to track lesson view: $e');
    }
  }

  Future<void> _trackTranslationToggle() async {
    try {
      final service = ref.read(progressServiceProvider);
      final progress = await service.trackTranslationToggle(widget.lessonId);
      _translationToggles++;

      if (widget.onProgressUpdate != null) {
        widget.onProgressUpdate!(progress);
      }
    } catch (e) {
      debugPrint('Failed to track translation toggle: $e');
    }
  }

  Future<void> _updateTimeSpent() async {
    if (_sessionStart == null) return;

    final timeSpent = DateTime.now().difference(_sessionStart!).inMinutes;
    if (timeSpent < 1) return; // Only track if at least 1 minute

    try {
      final service = ref.read(progressServiceProvider);
      final updateRequest = ProgressUpdateRequest(
        timeSpentMinutes: timeSpent,
      );

      final progress = await service.updateLessonProgress(widget.lessonId, updateRequest);

      if (widget.onProgressUpdate != null) {
        widget.onProgressUpdate!(progress);
      }
    } catch (e) {
      debugPrint('Failed to update time spent: $e');
    }
  }

  Future<void> _markLessonCompleted() async {
    try {
      final service = ref.read(progressServiceProvider);
      final updateRequest = ProgressUpdateRequest(
        status: 'completed',
      );

      final progress = await service.updateLessonProgress(widget.lessonId, updateRequest);

      if (widget.onProgressUpdate != null) {
        widget.onProgressUpdate!(progress);
      }

      // Invalidate related providers to refresh UI
      ref.invalidate(userProgressProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(userProfileProvider);
    } catch (e) {
      debugPrint('Failed to mark lesson completed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProgressTrackerScope(
      tracker: this,
      child: widget.child,
    );
  }
}

/// Inherited widget to provide progress tracking methods to descendants
class ProgressTrackerScope extends InheritedWidget {
  final _ProgressTrackerState tracker;

  const ProgressTrackerScope({
    Key? key,
    required this.tracker,
    required Widget child,
  }) : super(key: key, child: child);

  static _ProgressTrackerState? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ProgressTrackerScope>()?.tracker;
  }

  @override
  bool updateShouldNotify(ProgressTrackerScope oldWidget) {
    return tracker != oldWidget.tracker;
  }
}

/// Extension methods for easy access to progress tracking
extension ProgressTrackingContext on BuildContext {
  /// Track a translation toggle
  Future<void> trackTranslationToggle() async {
    final tracker = ProgressTrackerScope.of(this);
    if (tracker != null) {
      await tracker._trackTranslationToggle();
    }
  }

  /// Mark the lesson as completed
  Future<void> markLessonCompleted() async {
    final tracker = ProgressTrackerScope.of(this);
    if (tracker != null) {
      await tracker._markLessonCompleted();
    }
  }

  /// Update time spent (called automatically on dispose)
  Future<void> updateTimeSpent() async {
    final tracker = ProgressTrackerScope.of(this);
    if (tracker != null) {
      await tracker._updateTimeSpent();
    }
  }
}

/// Widget to show progress status for a lesson
class LessonProgressIndicator extends ConsumerWidget {
  final String lessonId;
  final bool compact;

  const LessonProgressIndicator({
    Key? key,
    required this.lessonId,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(lessonProgressProvider(lessonId));

    return progressAsync.when(
      data: (progress) => _buildProgressIndicator(context, progress),
      loading: () => _buildLoadingIndicator(context),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildProgressIndicator(BuildContext context, UserProgress? progress) {
    if (progress == null) {
      return _buildStatusBadge(context, 'Not Started', CupertinoColors.systemGrey);
    }

    Color color;
    String status;
    IconData icon;

    switch (progress.status) {
      case 'completed':
        color = CupertinoColors.systemGreen;
        status = 'Completed';
        icon = CupertinoIcons.checkmark_circle_fill;
        break;
      case 'in_progress':
        color = CupertinoColors.systemOrange;
        status = 'In Progress';
        icon = CupertinoIcons.clock_fill;
        break;
      default:
        color = CupertinoColors.systemBlue;
        status = 'Started';
        icon = CupertinoIcons.play_circle_fill;
    }

    if (compact) {
      return Icon(icon, size: 16, color: color);
    }

    return _buildStatusBadge(context, status, color, icon: icon, progress: progress);
  }

  Widget _buildStatusBadge(
    BuildContext context,
    String status,
    Color color, {
    IconData? icon,
    UserProgress? progress,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            status,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          if (progress != null && progress.timeSpentMinutes > 0) ...[
            const SizedBox(width: 4),
            Text(
              '• ${progress.formattedTimeSpent}',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 10,
                color: color.withOpacity(0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator(BuildContext context) {
    return Container(
      width: 60,
      height: 20,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

/// Widget for quiz completion celebration and progress update
class QuizCompletionHandler extends ConsumerWidget {
  final String quizId;
  final String lessonId;
  final List<Map<String, dynamic>> responses;
  final double score;
  final DateTime startTime;
  final DateTime completionTime;
  final Widget child;

  const QuizCompletionHandler({
    Key? key,
    required this.quizId,
    required this.lessonId,
    required this.responses,
    required this.score,
    required this.startTime,
    required this.completionTime,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Automatically submit quiz attempt when widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _submitQuizAttempt(ref);
    });

    return child;
  }

  Future<void> _submitQuizAttempt(WidgetRef ref) async {
    try {
      final service = ref.read(progressServiceProvider);
      final attemptData = QuizAttemptSubmission(
        quizId: quizId,
        responses: responses,
        score: score,
        timeSpentSeconds: completionTime.difference(startTime).inSeconds,
        startedAt: startTime,
        completedAt: completionTime,
      );

      await service.recordQuizAttempt(attemptData);

      // Invalidate providers to refresh UI
      ref.invalidate(userProgressProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(userProfileProvider);
      ref.invalidate(quizAttemptsProvider);

    } catch (e) {
      debugPrint('Failed to submit quiz attempt: $e');
    }
  }
}

/// Stats summary widget for quick progress overview
class ProgressStatsSummary extends ConsumerWidget {
  final bool showDetails;

  const ProgressStatsSummary({
    Key? key,
    this.showDetails = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return profileAsync.when(
      data: (profile) => _buildStatsSummary(context, profile),
      loading: () => _buildLoadingSummary(context),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildStatsSummary(BuildContext context, UserProfile profile) {
    final stats = [
      {'label': 'Lessons', 'value': profile.totalLessonsCompleted.toString()},
      {'label': 'Streak', 'value': '${profile.currentStreakDays}d'},
      {'label': 'Avg Score', 'value': profile.averageQuizScorePercentage},
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoTheme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: CupertinoColors.separator,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: stats.map((stat) => _buildStatItem(context, stat)).toList(),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, Map<String, String> stat) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          stat['value']!,
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          stat['label']!,
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            fontSize: 12,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingSummary(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(3, (index) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 16,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey5,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 40,
              height: 12,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey5,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        )),
      ),
    );
  }
}