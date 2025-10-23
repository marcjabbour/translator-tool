import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lesson.dart';
import '../providers/language_toggle_provider.dart';

/// Dual language toggle widget with Cupertino design
/// Provides smooth toggle between English and Lebanese Arabic
class LanguageToggleWidget extends ConsumerStatefulWidget {
  final Lesson lesson;
  final VoidCallback? onToggle;
  final bool showLabels;
  final bool compact;

  const LanguageToggleWidget({
    Key? key,
    required this.lesson,
    this.onToggle,
    this.showLabels = true,
    this.compact = false,
  }) : super(key: key);

  @override
  ConsumerState<LanguageToggleWidget> createState() => _LanguageToggleWidgetState();
}

class _LanguageToggleWidgetState extends ConsumerState<LanguageToggleWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150), // Under 200ms requirement
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleToggle() async {
    if (!widget.lesson.hasCompleteTranslation) return;

    // Trigger animation
    await _animationController.forward();

    // Perform toggle
    await ref.read(languageToggleProvider.notifier).toggleLanguage();

    // Complete animation
    await _animationController.reverse();

    // Notify parent widget
    widget.onToggle?.call();
  }

  @override
  Widget build(BuildContext context) {
    final toggleState = ref.watch(languageToggleProvider);
    final currentMode = toggleState.currentMode;
    final isToggling = toggleState.isToggling;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: _buildToggleContent(context, currentMode, isToggling),
          ),
        );
      },
    );
  }

  Widget _buildToggleContent(BuildContext context, LanguageMode currentMode, bool isToggling) {
    if (widget.compact) {
      return _buildCompactToggle(context, currentMode, isToggling);
    } else {
      return _buildFullToggle(context, currentMode, isToggling);
    }
  }

  Widget _buildCompactToggle(BuildContext context, LanguageMode currentMode, bool isToggling) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      onPressed: widget.lesson.hasCompleteTranslation && !isToggling ? _handleToggle : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: CupertinoTheme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: CupertinoTheme.of(context).primaryColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isToggling)
              const CupertinoActivityIndicator(radius: 8)
            else
              Icon(
                currentMode == LanguageMode.english
                    ? CupertinoIcons.textformat_abc
                    : CupertinoIcons.textformat,
                size: 16,
                color: CupertinoTheme.of(context).primaryColor,
              ),
            const SizedBox(width: 4),
            Text(
              currentMode.code.toUpperCase(),
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: CupertinoTheme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullToggle(BuildContext context, LanguageMode currentMode, bool isToggling) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showLabels) ...[
            Text(
              'Language',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 14,
                color: CupertinoColors.secondaryLabel,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLanguageOption(
                context,
                LanguageMode.english,
                currentMode,
                isToggling,
              ),
              const SizedBox(width: 16),
              _buildToggleButton(context, currentMode, isToggling),
              const SizedBox(width: 16),
              _buildLanguageOption(
                context,
                LanguageMode.arabic,
                currentMode,
                isToggling,
              ),
            ],
          ),
          if (!widget.lesson.hasCompleteTranslation) ...[
            const SizedBox(height: 8),
            Text(
              'Translation not available',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 12,
                color: CupertinoColors.systemRed,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    LanguageMode mode,
    LanguageMode currentMode,
    bool isToggling,
  ) {
    final isSelected = currentMode == mode;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? CupertinoTheme.of(context).primaryColor
                : CupertinoColors.systemGrey6,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            mode.code.toUpperCase(),
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? CupertinoColors.white
                  : CupertinoColors.secondaryLabel,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          mode == LanguageMode.english ? 'English' : 'عربي',
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            fontSize: 11,
            color: isSelected
                ? CupertinoTheme.of(context).primaryColor
                : CupertinoColors.secondaryLabel,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButton(BuildContext context, LanguageMode currentMode, bool isToggling) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: widget.lesson.hasCompleteTranslation && !isToggling ? _handleToggle : null,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: widget.lesson.hasCompleteTranslation
              ? CupertinoTheme.of(context).primaryColor
              : CupertinoColors.systemGrey4,
          shape: BoxShape.circle,
          boxShadow: [
            if (widget.lesson.hasCompleteTranslation)
              BoxShadow(
                color: CupertinoTheme.of(context).primaryColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: isToggling
            ? const CupertinoActivityIndicator(
                color: CupertinoColors.white,
                radius: 10,
              )
            : Icon(
                CupertinoIcons.arrow_2_circlepath,
                color: CupertinoColors.white,
                size: 20,
              ),
      ),
    );
  }
}

/// Language mode indicator for showing current language in app bar or headers
class LanguageModeIndicator extends ConsumerWidget {
  final bool showIcon;
  final double? fontSize;

  const LanguageModeIndicator({
    Key? key,
    this.showIcon = true,
    this.fontSize,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(currentLanguageModeProvider);
    final isToggling = ref.watch(isTogglingProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: CupertinoTheme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            if (isToggling)
              const CupertinoActivityIndicator(radius: 6)
            else
              Icon(
                currentMode == LanguageMode.english
                    ? CupertinoIcons.textformat_abc
                    : CupertinoIcons.textformat,
                size: 12,
                color: CupertinoTheme.of(context).primaryColor,
              ),
            const SizedBox(width: 4),
          ],
          Text(
            currentMode.displayName,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: fontSize ?? 12,
              fontWeight: FontWeight.w500,
              color: CupertinoTheme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Performance monitor widget for development/testing
class TogglePerformanceMonitor extends ConsumerWidget {
  const TogglePerformanceMonitor({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final performance = ref.watch(togglePerformanceProvider);
    final withinBudget = performance['is_within_budget'] as bool;
    final timeSinceToggle = performance['time_since_toggle_ms'] as int;

    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: withinBudget ? CupertinoColors.systemGreen.withOpacity(0.1) : CupertinoColors.systemRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: withinBudget ? CupertinoColors.systemGreen : CupertinoColors.systemRed,
          width: 1,
        ),
      ),
      child: Text(
        'Toggle Performance: ${timeSinceToggle}ms ${withinBudget ? "✓" : "✗"}',
        style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          fontSize: 10,
          color: withinBudget ? CupertinoColors.systemGreen : CupertinoColors.systemRed,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}