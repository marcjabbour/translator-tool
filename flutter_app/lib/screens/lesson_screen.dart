import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lesson.dart';
import '../providers/language_toggle_provider.dart';
import '../services/lesson_service.dart';
import '../widgets/language_toggle_widget.dart';
import '../widgets/lesson_content_widget.dart';

/// Main lesson screen with dual translation toggle functionality
/// Integrates with backend lesson data and provides responsive design
class LessonScreen extends ConsumerStatefulWidget {
  final String? lessonId;
  final StoryRequest? storyRequest;

  const LessonScreen({
    Key? key,
    this.lessonId,
    this.storyRequest,
  }) : super(key: key);

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  bool _showPerformanceMonitor = false;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: _buildNavigationBar(context),
      child: SafeArea(
        child: _buildContent(context),
      ),
    );
  }

  CupertinoNavigationBar _buildNavigationBar(BuildContext context) {
    return CupertinoNavigationBar(
      middle: Text('Lesson'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LanguageModeIndicator(fontSize: 14),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              setState(() {
                _showPerformanceMonitor = !_showPerformanceMonitor;
              });
            },
            child: Icon(
              CupertinoIcons.speedometer,
              size: 20,
              color: _showPerformanceMonitor
                  ? CupertinoTheme.of(context).primaryColor
                  : CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    // Determine lesson source
    if (widget.lessonId != null) {
      return _buildLessonById(context);
    } else if (widget.storyRequest != null) {
      return _buildGeneratedLesson(context);
    } else {
      return _buildLessonSelection(context);
    }
  }

  Widget _buildLessonById(BuildContext context) {
    final cachedLesson = ref.watch(lessonCacheProvider)[widget.lessonId!];

    if (cachedLesson != null) {
      return _buildLessonView(context, cachedLesson);
    } else {
      return _buildLessonLoading(context, 'Loading lesson...');
    }
  }

  Widget _buildGeneratedLesson(BuildContext context) {
    final storyAsync = ref.watch(storyGeneratorProvider(widget.storyRequest!));

    return storyAsync.when(
      data: (lesson) => _buildLessonView(context, lesson),
      loading: () => _buildLessonLoading(context, 'Generating story...'),
      error: (error, stackTrace) => _buildErrorView(context, error),
    );
  }

  Widget _buildLessonView(BuildContext context, Lesson lesson) {
    return ResponsiveLessonContent(
      lesson: lesson,
      builder: (context, isLargeScreen) {
        if (isLargeScreen) {
          return _buildLargeScreenLayout(context, lesson);
        } else {
          return _buildMobileLayout(context, lesson);
        }
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context, Lesson lesson) {
    return Column(
      children: [
        // Performance monitor (development only)
        if (_showPerformanceMonitor) const TogglePerformanceMonitor(),

        // Toggle controls
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoTheme.of(context).scaffoldBackgroundColor,
            border: Border(
              bottom: BorderSide(
                color: CupertinoColors.systemGrey5,
                width: 0.5,
              ),
            ),
          ),
          child: LanguageToggleWidget(
            lesson: lesson,
            onToggle: () {
              // Provide haptic feedback
              HapticFeedback.lightImpact();
            },
            showLabels: false,
            compact: true,
          ),
        ),

        // Lesson content
        Expanded(
          child: PositionPreserver(
            contentId: lesson.lessonId,
            child: LessonContentWidget(
              lesson: lesson,
              padding: const EdgeInsets.all(20),
            ),
          ),
        ),

        // Bottom actions
        _buildBottomActions(context, lesson),
      ],
    );
  }

  Widget _buildLargeScreenLayout(BuildContext context, Lesson lesson) {
    return Row(
      children: [
        // Side panel with controls
        Container(
          width: 300,
          decoration: BoxDecoration(
            color: CupertinoTheme.of(context).scaffoldBackgroundColor,
            border: Border(
              right: BorderSide(
                color: CupertinoColors.systemGrey5,
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            children: [
              // Performance monitor
              if (_showPerformanceMonitor) const TogglePerformanceMonitor(),

              // Toggle controls
              Padding(
                padding: const EdgeInsets.all(16),
                child: LanguageToggleWidget(
                  lesson: lesson,
                  onToggle: () {
                    HapticFeedback.lightImpact();
                  },
                ),
              ),

              // Lesson metadata
              _buildLessonMetadata(context, lesson),

              const Spacer(),

              // Bottom actions
              _buildBottomActions(context, lesson),
            ],
          ),
        ),

        // Main content area
        Expanded(
          child: PositionPreserver(
            contentId: lesson.lessonId,
            child: LessonContentWidget(
              lesson: lesson,
              padding: const EdgeInsets.all(40),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLessonMetadata(BuildContext context, Lesson lesson) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lesson Details',
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildMetadataRow('Topic', lesson.topic),
          _buildMetadataRow('Level', lesson.level),
          _buildMetadataRow('Created', _formatDate(lesson.createdAt)),
          const SizedBox(height: 16),
          _buildContentStats(lesson),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentStats(Lesson lesson) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Content Statistics',
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          const SizedBox(height: 8),
          _buildStatRow('English', '${lesson.enText.length} chars'),
          _buildStatRow('Arabic', '${lesson.laText.length} chars'),
          _buildStatRow('Words (EN)', '${lesson.enText.split(' ').length}'),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 11,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          Text(
            value,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context, Lesson lesson) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: CupertinoColors.systemGrey5,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: CupertinoButton.filled(
              onPressed: () {
                // Implement "Start Quiz" functionality
                _showNotImplemented(context, 'Quiz functionality');
              },
              child: Text('Start Quiz'),
            ),
          ),
          const SizedBox(width: 12),
          CupertinoButton(
            onPressed: () {
              // Implement "Save Lesson" functionality
              _showNotImplemented(context, 'Save functionality');
            },
            child: Icon(CupertinoIcons.bookmark),
          ),
          CupertinoButton(
            onPressed: () {
              // Implement "Share Lesson" functionality
              _showNotImplemented(context, 'Share functionality');
            },
            child: Icon(CupertinoIcons.share),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonSelection(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.book,
              size: 64,
              color: CupertinoColors.systemGrey,
            ),
            const SizedBox(height: 16),
            Text(
              'Select a Lesson',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a topic and level to generate a new lesson',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                color: CupertinoColors.secondaryLabel,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            CupertinoButton.filled(
              onPressed: () {
                _showTopicSelection(context);
              },
              child: Text('Generate Lesson'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonLoading(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CupertinoActivityIndicator(radius: 20),
          const SizedBox(height: 16),
          Text(
            message,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, Object error) {
    String message = 'An error occurred';
    if (error is LessonServiceException) {
      message = error.message;
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 64,
              color: CupertinoColors.systemRed,
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                color: CupertinoColors.secondaryLabel,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            CupertinoButton.filled(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTopicSelection(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => TopicSelectionSheet(),
    );
  }

  void _showNotImplemented(BuildContext context, String feature) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Coming Soon'),
        content: Text('$feature will be available in a future update.'),
        actions: [
          CupertinoDialogAction(
            child: Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Topic selection bottom sheet
class TopicSelectionSheet extends ConsumerWidget {
  const TopicSelectionSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ['coffee_chat', 'restaurant', 'shopping', 'greeting', 'family'];
    final levels = ['beginner', 'intermediate', 'advanced'];

    return CupertinoActionSheet(
      title: Text('Select Topic and Level'),
      message: Text('Choose what you want to practice'),
      actions: [
        for (final topic in topics)
          for (final level in levels)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (context) => LessonScreen(
                      storyRequest: StoryRequest(
                        topic: topic,
                        level: level,
                      ),
                    ),
                  ),
                );
              },
              child: Text('${_capitalize(topic)} - ${_capitalize(level)}'),
            ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDestructiveAction: true,
        onPressed: () => Navigator.of(context).pop(),
        child: Text('Cancel'),
      ),
    );
  }

  String _capitalize(String text) {
    return text.split('_').map((word) =>
      word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : word
    ).join(' ');
  }
}