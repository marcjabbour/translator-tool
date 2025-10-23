import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lesson.dart';
import '../providers/language_toggle_provider.dart';

/// Content display widget with position preservation during language toggle
/// Maintains scroll position, cursor location, and text selection
class LessonContentWidget extends ConsumerStatefulWidget {
  final Lesson lesson;
  final bool isEditable;
  final TextStyle? textStyle;
  final EdgeInsets? padding;
  final VoidCallback? onContentChanged;

  const LessonContentWidget({
    Key? key,
    required this.lesson,
    this.isEditable = false,
    this.textStyle,
    this.padding,
    this.onContentChanged,
  }) : super(key: key);

  @override
  ConsumerState<LessonContentWidget> createState() => _LessonContentWidgetState();
}

class _LessonContentWidgetState extends ConsumerState<LessonContentWidget> {
  late ScrollController _scrollController;
  late TextEditingController _textController;
  late FocusNode _focusNode;

  // Position tracking variables
  double _lastScrollOffset = 0.0;
  int? _lastCursorPosition;
  int? _lastSelectionStart;
  int? _lastSelectionEnd;
  LanguageMode? _lastLanguageMode;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _textController = TextEditingController();
    _focusNode = FocusNode();

    // Listen to scroll changes
    _scrollController.addListener(_onScrollChanged);

    // Listen to text selection changes
    _textController.addListener(_onTextSelectionChanged);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollChanged);
    _textController.removeListener(_onTextSelectionChanged);
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScrollChanged() {
    if (_scrollController.hasClients) {
      _lastScrollOffset = _scrollController.offset;
      _updatePositionInProvider();
    }
  }

  void _onTextSelectionChanged() {
    final selection = _textController.selection;
    _lastCursorPosition = selection.baseOffset;

    if (selection.isValid && !selection.isCollapsed) {
      _lastSelectionStart = selection.start;
      _lastSelectionEnd = selection.end;
    } else {
      _lastSelectionStart = null;
      _lastSelectionEnd = null;
    }

    _updatePositionInProvider();
  }

  void _updatePositionInProvider() {
    ref.read(languageToggleProvider.notifier).updatePosition(
      scrollOffset: _lastScrollOffset,
      textCursorPosition: _lastCursorPosition,
      selectionStart: _lastSelectionStart,
      selectionEnd: _lastSelectionEnd,
    );
  }

  /// Calculate approximate position mapping between different language texts
  /// This handles cases where text lengths differ between languages
  double _calculateProportionalPosition(String fromText, String toText, double position) {
    if (fromText.isEmpty || toText.isEmpty) return 0.0;

    // Calculate proportional position based on character count
    final fromLength = fromText.length;
    final toLength = toText.length;

    if (fromLength == 0) return 0.0;

    final ratio = position / fromLength;
    return (ratio * toLength).clamp(0.0, toLength.toDouble());
  }

  /// Restore position after language toggle
  Future<void> _restorePosition(ContentPosition savedPosition, String newText) async {
    // Wait for widget rebuild
    await Future.delayed(const Duration(milliseconds: 16));

    // Restore scroll position
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final targetScroll = savedPosition.scrollOffset.clamp(0.0, maxScroll);

      await _scrollController.animateTo(
        targetScroll,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }

    // Restore text cursor/selection if in editable mode
    if (widget.isEditable && _focusNode.hasFocus) {
      final savedCursor = savedPosition.textCursorPosition;
      final savedStart = savedPosition.selectionStart;
      final savedEnd = savedPosition.selectionEnd;

      if (savedCursor != null || (savedStart != null && savedEnd != null)) {
        // Calculate new positions based on text length differences
        final currentText = _textController.text;
        final previousText = _lastLanguageMode == LanguageMode.english
            ? widget.lesson.enText
            : widget.lesson.laText;

        if (savedStart != null && savedEnd != null) {
          // Restore text selection
          final newStart = _calculateProportionalPosition(
            previousText,
            currentText,
            savedStart.toDouble()
          ).round().clamp(0, currentText.length);

          final newEnd = _calculateProportionalPosition(
            previousText,
            currentText,
            savedEnd.toDouble()
          ).round().clamp(newStart, currentText.length);

          _textController.selection = TextSelection(
            baseOffset: newStart,
            extentOffset: newEnd,
          );
        } else if (savedCursor != null) {
          // Restore cursor position
          final newCursor = _calculateProportionalPosition(
            previousText,
            currentText,
            savedCursor.toDouble()
          ).round().clamp(0, currentText.length);

          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: newCursor),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final toggleState = ref.watch(languageToggleProvider);
    final currentMode = toggleState.currentMode;
    final isToggling = toggleState.isToggling;

    // Detect language mode change
    if (_lastLanguageMode != null && _lastLanguageMode != currentMode) {
      // Language has changed, restore position
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restorePosition(toggleState.position, widget.lesson.getTextForLanguage(currentMode));
      });
    }
    _lastLanguageMode = currentMode;

    // Update text controller with current language content
    final currentText = widget.lesson.getTextForLanguage(currentMode);
    if (_textController.text != currentText) {
      _textController.text = currentText;
    }

    return AnimatedOpacity(
      opacity: isToggling ? 0.7 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: _buildContent(context, currentText, currentMode, isToggling),
    );
  }

  Widget _buildContent(BuildContext context, String text, LanguageMode mode, bool isToggling) {
    final textStyle = widget.textStyle ?? _getDefaultTextStyle(context, mode);

    if (widget.isEditable) {
      return _buildEditableContent(context, text, textStyle, isToggling);
    } else {
      return _buildReadOnlyContent(context, text, textStyle, isToggling);
    }
  }

  Widget _buildEditableContent(BuildContext context, String text, TextStyle textStyle, bool isToggling) {
    return Padding(
      padding: widget.padding ?? const EdgeInsets.all(16),
      child: CupertinoTextField(
        controller: _textController,
        focusNode: _focusNode,
        enabled: !isToggling,
        maxLines: null,
        style: textStyle,
        decoration: BoxDecoration(
          color: CupertinoTheme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: CupertinoColors.systemGrey4,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(12),
        placeholder: 'Start typing your translation...',
        placeholderStyle: textStyle.copyWith(
          color: CupertinoColors.placeholderText,
        ),
        onChanged: (value) {
          widget.onContentChanged?.call();
        },
      ),
    );
  }

  Widget _buildReadOnlyContent(BuildContext context, String text, TextStyle textStyle, bool isToggling) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: widget.padding ?? const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Language indicator
          _buildLanguageHeader(context),
          const SizedBox(height: 12),

          // Content with smooth transition
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.1, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: SelectableText(
              text,
              key: ValueKey('${text.hashCode}_${DateTime.now().millisecondsSinceEpoch}'),
              style: textStyle,
              onSelectionChanged: (selection, cause) {
                if (selection != null) {
                  _lastSelectionStart = selection.start;
                  _lastSelectionEnd = selection.end;
                  _updatePositionInProvider();
                }
              },
            ),
          ),

          // Bottom spacing
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildLanguageHeader(BuildContext context) {
    final currentMode = ref.watch(currentLanguageModeProvider);

    return Row(
      children: [
        Icon(
          currentMode == LanguageMode.english
              ? CupertinoIcons.textformat_abc
              : CupertinoIcons.textformat,
          size: 16,
          color: CupertinoColors.secondaryLabel,
        ),
        const SizedBox(width: 6),
        Text(
          currentMode.displayName,
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
        const Spacer(),
        _buildCharacterCount(),
      ],
    );
  }

  Widget _buildCharacterCount() {
    final currentMode = ref.watch(currentLanguageModeProvider);
    final characterCount = widget.lesson.getCharacterCount(currentMode);

    return Text(
      '$characterCount chars',
      style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
        fontSize: 12,
        color: CupertinoColors.tertiaryLabel,
      ),
    );
  }

  TextStyle _getDefaultTextStyle(BuildContext context, LanguageMode mode) {
    final baseStyle = CupertinoTheme.of(context).textTheme.textStyle;

    return baseStyle.copyWith(
      fontSize: 16,
      height: 1.5,
      color: CupertinoTheme.of(context).textTheme.textStyle.color,
      // Adjust font for Arabic text if needed
      fontFamily: mode == LanguageMode.arabic ? null : baseStyle.fontFamily,
    );
  }
}

/// Responsive layout wrapper for lesson content
class ResponsiveLessonContent extends ConsumerWidget {
  final Lesson lesson;
  final Widget Function(BuildContext context, bool isLargeScreen) builder;

  const ResponsiveLessonContent({
    Key? key,
    required this.lesson,
    required this.builder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth > 768;

        return builder(context, isLargeScreen);
      },
    );
  }
}

/// Position preservation utility widget
class PositionPreserver extends ConsumerStatefulWidget {
  final Widget child;
  final String contentId;

  const PositionPreserver({
    Key? key,
    required this.child,
    required this.contentId,
  }) : super(key: key);

  @override
  ConsumerState<PositionPreserver> createState() => _PositionPreserverState();
}

class _PositionPreserverState extends ConsumerState<PositionPreserver> {
  final Map<String, ContentPosition> _savedPositions = {};

  @override
  Widget build(BuildContext context) {
    final toggleState = ref.watch(languageToggleProvider);

    // Save position when language changes
    ref.listen(currentLanguageModeProvider, (previous, current) {
      if (previous != null && previous != current) {
        _savedPositions[widget.contentId] = toggleState.position;
      }
    });

    return widget.child;
  }
}