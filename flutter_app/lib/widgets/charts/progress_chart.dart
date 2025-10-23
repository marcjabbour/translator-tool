import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import '../../models/progress_models.dart';

/// Chart widget showing daily progress activity (time spent)
class ProgressChart extends StatelessWidget {
  final List<TrendPoint> trendPoints;
  final bool showAccuracy;
  final bool showTimeSpent;
  final double height;

  const ProgressChart({
    Key? key,
    required this.trendPoints,
    this.showAccuracy = true,
    this.showTimeSpent = false,
    this.height = 180,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (trendPoints.isEmpty) {
      return _buildEmptyChart(context);
    }

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
        children: [
          _buildChartHeader(context),
          const SizedBox(height: 16),
          Expanded(
            child: _buildChart(context),
          ),
        ],
      ),
    );
  }

  Widget _buildChartHeader(BuildContext context) {
    final totalTime = trendPoints.fold(0, (sum, point) => sum + point.timeMinutes);
    final avgTime = totalTime / trendPoints.length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              showTimeSpent ? 'Daily Activity' : 'Performance',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              showTimeSpent
                ? 'Avg: ${_formatMinutes(avgTime.round())}/day'
                : 'Total: ${_formatMinutes(totalTime)}',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ],
        ),
        if (showTimeSpent)
          Icon(
            CupertinoIcons.clock,
            color: CupertinoColors.systemBlue,
            size: 20,
          ),
      ],
    );
  }

  Widget _buildChart(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: ProgressChartPainter(
        trendPoints: trendPoints,
        showAccuracy: showAccuracy,
        showTimeSpent: showTimeSpent,
        primaryColor: CupertinoTheme.of(context).primaryColor,
        secondaryColor: CupertinoColors.systemBlue,
        backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
        textStyle: CupertinoTheme.of(context).textTheme.textStyle,
      ),
    );
  }

  Widget _buildEmptyChart(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoTheme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.separator,
          width: 0.5,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.chart_bar_square,
              size: 48,
              color: CupertinoColors.systemGrey,
            ),
            const SizedBox(height: 12),
            Text(
              'No activity data',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 16,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Start learning to track your daily progress',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 12,
                color: CupertinoColors.tertiaryLabel,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return remainingMinutes > 0 ? '${hours}h ${remainingMinutes}m' : '${hours}h';
    }
  }
}

/// Custom painter for progress chart
class ProgressChartPainter extends CustomPainter {
  final List<TrendPoint> trendPoints;
  final bool showAccuracy;
  final bool showTimeSpent;
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;
  final TextStyle textStyle;

  ProgressChartPainter({
    required this.trendPoints,
    required this.showAccuracy,
    required this.showTimeSpent,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
    required this.textStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (trendPoints.isEmpty) return;

    final chartArea = Rect.fromLTWH(40, 20, size.width - 80, size.height - 60);

    // Draw background grid
    _drawGrid(canvas, chartArea);

    if (showTimeSpent) {
      // Draw time spent as bars
      _drawTimeSpentBars(canvas, chartArea);
    }

    if (showAccuracy && !showTimeSpent) {
      // Draw accuracy as bars when not showing time spent
      _drawAccuracyBars(canvas, chartArea);
    }

    // Draw labels
    _drawLabels(canvas, chartArea, size);
  }

  void _drawGrid(Canvas canvas, Rect chartArea) {
    final gridPaint = Paint()
      ..color = CupertinoColors.separator.withOpacity(0.2)
      ..strokeWidth = 0.5;

    // Horizontal grid lines
    for (int i = 0; i <= 4; i++) {
      final y = chartArea.top + (chartArea.height / 4) * i;
      canvas.drawLine(
        Offset(chartArea.left, y),
        Offset(chartArea.right, y),
        gridPaint,
      );
    }
  }

  void _drawTimeSpentBars(Canvas canvas, Rect chartArea) {
    final maxTime = trendPoints.map((p) => p.timeMinutes).reduce(math.max);
    if (maxTime == 0) return;

    final barWidth = (chartArea.width / trendPoints.length) * 0.6;
    final barSpacing = chartArea.width / trendPoints.length;

    for (int i = 0; i < trendPoints.length; i++) {
      final point = trendPoints[i];
      final barHeight = (point.timeMinutes / maxTime) * chartArea.height;
      final x = chartArea.left + (barSpacing * i) + (barSpacing - barWidth) / 2;
      final y = chartArea.bottom - barHeight;

      // Create gradient for bar
      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          secondaryColor.withOpacity(0.8),
          secondaryColor.withOpacity(0.4),
        ],
      );

      final rect = Rect.fromLTWH(x, y, barWidth, barHeight);
      final paint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.fill;

      // Draw rounded rectangle for bar
      final roundedRect = RRect.fromRectAndRadius(
        rect,
        const Radius.circular(4),
      );
      canvas.drawRRect(roundedRect, paint);

      // Draw border
      final borderPaint = Paint()
        ..color = secondaryColor
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(roundedRect, borderPaint);
    }
  }

  void _drawAccuracyBars(Canvas canvas, Rect chartArea) {
    final barWidth = (chartArea.width / trendPoints.length) * 0.6;
    final barSpacing = chartArea.width / trendPoints.length;

    for (int i = 0; i < trendPoints.length; i++) {
      final point = trendPoints[i];
      final barHeight = point.accuracy * chartArea.height;
      final x = chartArea.left + (barSpacing * i) + (barSpacing - barWidth) / 2;
      final y = chartArea.bottom - barHeight;

      // Color based on accuracy level
      Color barColor;
      if (point.accuracy >= 0.8) {
        barColor = CupertinoColors.systemGreen;
      } else if (point.accuracy >= 0.6) {
        barColor = CupertinoColors.systemYellow;
      } else {
        barColor = CupertinoColors.systemRed;
      }

      // Create gradient for bar
      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          barColor.withOpacity(0.8),
          barColor.withOpacity(0.4),
        ],
      );

      final rect = Rect.fromLTWH(x, y, barWidth, barHeight);
      final paint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.fill;

      // Draw rounded rectangle for bar
      final roundedRect = RRect.fromRectAndRadius(
        rect,
        const Radius.circular(4),
      );
      canvas.drawRRect(roundedRect, paint);

      // Draw border
      final borderPaint = Paint()
        ..color = barColor
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(roundedRect, borderPaint);
    }
  }

  void _drawLabels(Canvas canvas, Rect chartArea, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Y-axis labels
    if (showTimeSpent) {
      final maxTime = trendPoints.map((p) => p.timeMinutes).reduce(math.max);
      for (int i = 0; i <= 4; i++) {
        final time = (maxTime / 4) * (4 - i);
        final y = chartArea.top + (chartArea.height / 4) * i;

        textPainter.text = TextSpan(
          text: _formatMinutes(time.round()),
          style: textStyle.copyWith(
            fontSize: 10,
            color: CupertinoColors.secondaryLabel,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(5, y - textPainter.height / 2),
        );
      }
    } else {
      // Accuracy labels
      for (int i = 0; i <= 4; i++) {
        final accuracy = (100 / 4) * (4 - i);
        final y = chartArea.top + (chartArea.height / 4) * i;

        textPainter.text = TextSpan(
          text: '${accuracy.toInt()}%',
          style: textStyle.copyWith(
            fontSize: 10,
            color: CupertinoColors.secondaryLabel,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(5, y - textPainter.height / 2),
        );
      }
    }

    // X-axis labels (dates)
    final labelCount = math.min(trendPoints.length, 5);
    for (int i = 0; i < labelCount; i++) {
      final pointIndex = (trendPoints.length - 1) * i ~/ (labelCount - 1);
      final point = trendPoints[pointIndex];
      final barSpacing = chartArea.width / trendPoints.length;
      final x = chartArea.left + (barSpacing * pointIndex) + barSpacing / 2;

      textPainter.text = TextSpan(
        text: point.formattedDate,
        style: textStyle.copyWith(
          fontSize: 10,
          color: CupertinoColors.secondaryLabel,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, chartArea.bottom + 8),
      );
    }
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    } else {
      final hours = minutes ~/ 60;
      return '${hours}h';
    }
  }

  @override
  bool shouldRepaint(ProgressChartPainter oldDelegate) {
    return trendPoints != oldDelegate.trendPoints ||
           showAccuracy != oldDelegate.showAccuracy ||
           showTimeSpent != oldDelegate.showTimeSpent;
  }
}