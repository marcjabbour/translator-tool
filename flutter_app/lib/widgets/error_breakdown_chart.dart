import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import '../models/progress_models.dart';

/// Chart widget showing error breakdown by type
class ErrorBreakdownChart extends StatelessWidget {
  final Map<String, int> errorBreakdown;
  final double height;

  const ErrorBreakdownChart({
    Key? key,
    required this.errorBreakdown,
    this.height = 220,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (errorBreakdown.isEmpty) {
      return _buildNoErrorsChart(context);
    }

    final sortedErrors = _getSortedErrors();
    final totalErrors = errorBreakdown.values.fold(0, (sum, count) => sum + count);

    return Container(
      height: height,
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
          _buildHeader(context, totalErrors),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                // Pie chart
                Expanded(
                  flex: 2,
                  child: _buildPieChart(context, sortedErrors, totalErrors),
                ),
                const SizedBox(width: 16),
                // Legend
                Expanded(
                  flex: 3,
                  child: _buildLegend(context, sortedErrors, totalErrors),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int totalErrors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Error Breakdown',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$totalErrors total errors',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ],
        ),
        Icon(
          CupertinoIcons.chart_pie,
          color: CupertinoColors.systemBlue,
          size: 20,
        ),
      ],
    );
  }

  Widget _buildPieChart(BuildContext context, List<MapEntry<String, int>> sortedErrors, int totalErrors) {
    return CustomPaint(
      size: Size.infinite,
      painter: ErrorPieChartPainter(
        errorData: sortedErrors,
        totalErrors: totalErrors,
        colors: _getErrorColors(),
      ),
    );
  }

  Widget _buildLegend(BuildContext context, List<MapEntry<String, int>> sortedErrors, int totalErrors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...sortedErrors.asMap().entries.map((entry) {
          final index = entry.key;
          final errorEntry = entry.value;
          final percentage = (errorEntry.value / totalErrors * 100).toStringAsFixed(1);
          final color = _getErrorColors()[index % _getErrorColors().length];

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildLegendItem(context, errorEntry.key, errorEntry.value, percentage, color),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildLegendItem(BuildContext context, String errorType, int count, String percentage, Color color) {
    final displayName = ErrorTypeHelper.getDisplayName(errorType);

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$count errors',
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 11,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ],
          ),
        ),
        Text(
          '$percentage%',
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildNoErrorsChart(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.systemGreen.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.checkmark_seal_fill,
              size: 48,
              color: CupertinoColors.systemGreen,
            ),
            const SizedBox(height: 12),
            Text(
              'Perfect Performance!',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: CupertinoColors.systemGreen,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No errors detected in this period',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<MapEntry<String, int>> _getSortedErrors() {
    final entries = errorBreakdown.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  List<Color> _getErrorColors() {
    return [
      CupertinoColors.systemRed,
      CupertinoColors.systemOrange,
      CupertinoColors.systemYellow,
      CupertinoColors.systemBlue,
      CupertinoColors.systemPurple,
      CupertinoColors.systemPink,
      CupertinoColors.systemTeal,
      CupertinoColors.systemIndigo,
    ];
  }
}

/// Custom painter for pie chart
class ErrorPieChartPainter extends CustomPainter {
  final List<MapEntry<String, int>> errorData;
  final int totalErrors;
  final List<Color> colors;

  ErrorPieChartPainter({
    required this.errorData,
    required this.totalErrors,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (errorData.isEmpty || totalErrors == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 * 0.8;

    double startAngle = -math.pi / 2; // Start from top

    for (int i = 0; i < errorData.length; i++) {
      final error = errorData[i];
      final sweepAngle = (error.value / totalErrors) * 2 * math.pi;
      final color = colors[i % colors.length];

      // Draw pie slice
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      final path = Path();
      path.moveTo(center.dx, center.dy);
      path.arcTo(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
      );
      path.close();

      canvas.drawPath(path, paint);

      // Draw border
      final borderPaint = Paint()
        ..color = CupertinoColors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      canvas.drawPath(path, borderPaint);

      startAngle += sweepAngle;
    }

    // Draw center circle for donut effect
    final centerPaint = Paint()
      ..color = CupertinoColors.systemBackground
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.4, centerPaint);

    // Draw total count in center
    final textPainter = TextPainter(
      text: TextSpan(
        text: totalErrors.toString(),
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: CupertinoColors.label,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );

    // Draw "errors" label
    final labelPainter = TextPainter(
      text: const TextSpan(
        text: 'errors',
        style: TextStyle(
          fontSize: 10,
          color: CupertinoColors.secondaryLabel,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    labelPainter.layout();
    labelPainter.paint(
      canvas,
      Offset(
        center.dx - labelPainter.width / 2,
        center.dy + textPainter.height / 2 + 2,
      ),
    );
  }

  @override
  bool shouldRepaint(ErrorPieChartPainter oldDelegate) {
    return errorData != oldDelegate.errorData ||
           totalErrors != oldDelegate.totalErrors;
  }
}