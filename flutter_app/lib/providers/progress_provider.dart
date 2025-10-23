import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/progress_models.dart';
import '../services/progress_api_service.dart';
import '../services/auth_service.dart';
import '../services/lesson_service.dart'; // For apiConfigProvider

/// Provider for progress API service
final progressApiServiceProvider = Provider<ProgressApiService>((ref) {
  final config = ref.watch(apiConfigProvider);
  return ProgressApiService(
    baseUrl: config['baseUrl'],
  );
});

/// Provider for current user ID (gets from auth service)
final currentUserIdProvider = FutureProvider<String?>((ref) async {
  return await AuthService.getUserId();
});

/// Provider for fetching user progress analytics
final progressProvider = FutureProvider.family<ProgressResponse, int>((ref, daysBack) async {
  final apiService = ref.read(progressApiServiceProvider);
  final userIdAsync = ref.watch(currentUserIdProvider);

  final userId = await userIdAsync.value;
  if (userId == null) {
    throw Exception('User not authenticated');
  }

  return await apiService.getUserProgress(userId, daysBack);
});

/// Provider for progress analytics with automatic refresh
final progressWithRefreshProvider = StateNotifierProvider.family<ProgressNotifier, AsyncValue<ProgressResponse>, int>(
  (ref, daysBack) => ProgressNotifier(ref, daysBack),
);

/// State notifier for managing progress data with refresh capabilities
class ProgressNotifier extends StateNotifier<AsyncValue<ProgressResponse>> {
  final Ref _ref;
  final int _daysBack;

  ProgressNotifier(this._ref, this._daysBack) : super(const AsyncValue.loading()) {
    _loadProgress();
  }

  /// Load progress data
  Future<void> _loadProgress() async {
    try {
      final apiService = _ref.read(progressApiServiceProvider);
      final userIdAsync = _ref.watch(currentUserIdProvider);

      final userId = await userIdAsync.value;
      if (userId == null) {
        state = AsyncValue.error('User not authenticated', StackTrace.current);
        return;
      }

      state = const AsyncValue.loading();
      final progress = await apiService.getUserProgress(userId, _daysBack);
      state = AsyncValue.data(progress);
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  /// Refresh progress data
  Future<void> refresh() async {
    await _loadProgress();
  }

  /// Update the time range and reload data
  Future<void> updateDaysBack(int newDaysBack) async {
    if (newDaysBack != _daysBack) {
      // This will be handled by the family provider creating a new instance
      await _loadProgress();
    }
  }
}

/// Provider for caching progress data to reduce API calls
final progressCacheProvider = StateNotifierProvider<ProgressCacheNotifier, Map<String, ProgressResponse>>(
  (ref) => ProgressCacheNotifier(),
);

/// Cache notifier for progress data
class ProgressCacheNotifier extends StateNotifier<Map<String, ProgressResponse>> {
  ProgressCacheNotifier() : super({});

  /// Get cached progress data
  ProgressResponse? getCachedProgress(String userId, int daysBack) {
    final key = '${userId}_$daysBack';
    return state[key];
  }

  /// Cache progress data
  void cacheProgress(String userId, int daysBack, ProgressResponse progress) {
    final key = '${userId}_$daysBack';
    state = {...state, key: progress};
  }

  /// Clear cache for user
  void clearUserCache(String userId) {
    final newState = Map<String, ProgressResponse>.from(state);
    newState.removeWhere((key, value) => key.startsWith(userId));
    state = newState;
  }

  /// Clear all cache
  void clearAll() {
    state = {};
  }
}

/// Provider for progress summary data (lightweight version)
final progressSummaryProvider = FutureProvider<ProgressMetrics?>((ref) async {
  try {
    final progressAsync = ref.watch(progressProvider(7)); // Last 7 days
    return progressAsync.when(
      data: (progress) => progress.weekly,
      loading: () => null,
      error: (_, __) => null,
    );
  } catch (e) {
    return null;
  }
});

/// Provider for checking if user has recent progress data
final hasRecentProgressProvider = FutureProvider<bool>((ref) async {
  try {
    final progressAsync = ref.watch(progressProvider(7));
    return progressAsync.when(
      data: (progress) => progress.trends.isNotEmpty,
      loading: () => false,
      error: (_, __) => false,
    );
  } catch (e) {
    return false;
  }
});

/// Provider for progress improvement areas
final improvementAreasProvider = FutureProvider<List<String>>((ref) async {
  try {
    final progressAsync = ref.watch(progressProvider(30));
    return progressAsync.when(
      data: (progress) => progress.improvementAreas,
      loading: () => <String>[],
      error: (_, __) => <String>[],
    );
  } catch (e) {
    return <String>[];
  }
});

/// Provider for user's current streak
final currentStreakProvider = FutureProvider<int>((ref) async {
  try {
    final progressAsync = ref.watch(progressProvider(30));
    return progressAsync.when(
      data: (progress) => progress.weekly.streakDays,
      loading: () => 0,
      error: (_, __) => 0,
    );
  } catch (e) {
    return 0;
  }
});

/// Provider for overall progress trend
final progressTrendProvider = FutureProvider<TrendDirection>((ref) async {
  try {
    final progressAsync = ref.watch(progressProvider(30));
    return progressAsync.when(
      data: (progress) => progress.overallTrend,
      loading: () => TrendDirection.stable,
      error: (_, __) => TrendDirection.stable,
    );
  } catch (e) {
    return TrendDirection.stable;
  }
});

/// Provider for progress loading state
final progressLoadingProvider = Provider<bool>((ref) {
  final progressAsync = ref.watch(progressProvider(30));
  return progressAsync.isLoading;
});

/// Provider for progress error state
final progressErrorProvider = Provider<String?>((ref) {
  final progressAsync = ref.watch(progressProvider(30));
  return progressAsync.maybeWhen(
    error: (error, _) => error.toString(),
    orElse: () => null,
  );
});

/// Extension methods for easier progress data access
extension ProgressProviderExtensions on WidgetRef {
  /// Get user progress for specific time range
  AsyncValue<ProgressResponse> watchProgress(int daysBack) {
    return watch(progressProvider(daysBack));
  }

  /// Get progress summary
  AsyncValue<ProgressMetrics?> watchProgressSummary() {
    return watch(progressSummaryProvider);
  }

  /// Get improvement areas
  AsyncValue<List<String>> watchImprovementAreas() {
    return watch(improvementAreasProvider);
  }

  /// Get current streak
  AsyncValue<int> watchCurrentStreak() {
    return watch(currentStreakProvider);
  }

  /// Check if user has recent progress
  AsyncValue<bool> watchHasRecentProgress() {
    return watch(hasRecentProgressProvider);
  }

  /// Get progress trend
  AsyncValue<TrendDirection> watchProgressTrend() {
    return watch(progressTrendProvider);
  }

  /// Refresh progress data
  void refreshProgress(int daysBack) {
    invalidate(progressProvider(daysBack));
  }

  /// Refresh all progress-related providers
  void refreshAllProgress() {
    invalidate(progressProvider);
    invalidate(progressSummaryProvider);
    invalidate(improvementAreasProvider);
    invalidate(currentStreakProvider);
    invalidate(hasRecentProgressProvider);
    invalidate(progressTrendProvider);
  }

  /// Clear progress cache
  void clearProgressCache() {
    read(progressCacheProvider.notifier).clearAll();
  }

  /// Clear progress cache for current user
  void clearUserProgressCache() async {
    final userIdAsync = read(currentUserIdProvider);
    final userId = await userIdAsync.value;
    if (userId != null) {
      read(progressCacheProvider.notifier).clearUserCache(userId);
    }
  }
}

/// Mixin for widgets that need progress data
mixin ProgressDataMixin {
  /// Watch progress with error handling
  AsyncValue<ProgressResponse> watchProgressSafe(WidgetRef ref, int daysBack) {
    try {
      return ref.watch(progressProvider(daysBack));
    } catch (e) {
      return AsyncValue.error('Failed to load progress data', StackTrace.current);
    }
  }

  /// Get progress metrics or null if not available
  ProgressMetrics? getProgressMetrics(WidgetRef ref, int daysBack) {
    final progressAsync = ref.watch(progressProvider(daysBack));
    return progressAsync.maybeWhen(
      data: (progress) => progress.weekly,
      orElse: () => null,
    );
  }

  /// Check if progress data is available
  bool hasProgressData(WidgetRef ref, int daysBack) {
    final progressAsync = ref.watch(progressProvider(daysBack));
    return progressAsync.maybeWhen(
      data: (progress) => progress.trends.isNotEmpty,
      orElse: () => false,
    );
  }

  /// Get formatted accuracy string
  String getFormattedAccuracy(WidgetRef ref, int daysBack) {
    final metrics = getProgressMetrics(ref, daysBack);
    return metrics?.accuracyPercentage ?? 'N/A';
  }

  /// Get formatted time spent string
  String getFormattedTimeSpent(WidgetRef ref, int daysBack) {
    final metrics = getProgressMetrics(ref, daysBack);
    return metrics?.formattedTimeSpent ?? 'N/A';
  }

  /// Check if user is improving
  bool isUserImproving(WidgetRef ref, int daysBack) {
    final metrics = getProgressMetrics(ref, daysBack);
    return metrics?.isImproving ?? false;
  }
}