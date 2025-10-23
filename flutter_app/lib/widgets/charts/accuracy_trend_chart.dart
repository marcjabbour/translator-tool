import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import '../../models/progress_models.dart';

/// Chart widget showing accuracy trend over time
class AccuracyTrendChart extends StatelessWidget {
  final List<TrendPoint> trendPoints;
  final int timeRange;
  final double height;

  const AccuracyTrendChart({
    Key? key,
    required this.trendPoints,
    required this.timeRange,
    this.height = 200,
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
    final avgAccuracy = trendPoints.fold(0.0, (sum, point) => sum + point.accuracy) / trendPoints.length;
    final trend = _calculateTrend();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Average: ${(avgAccuracy * 100).toStringAsFixed(1)}%',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              _getTrendDescription(trend),
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 12,
                color: _getTrendColor(trend),
              ),
            ),
          ],
        ),
        _buildTrendIcon(trend),
      ],
    );
  }

  Widget _buildChart(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: AccuracyTrendPainter(
        trendPoints: trendPoints,
        primaryColor: CupertinoTheme.of(context).primaryColor,
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
              CupertinoIcons.chart_bar,
              size: 48,
              color: CupertinoColors.systemGrey,
            ),
            const SizedBox(height: 12),
            Text(
              'No data available',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 16,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Complete some lessons to see your progress',
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

  double _calculateTrend() {
    if (trendPoints.length < 2) return 0.0;

    final firstAccuracy = trendPoints.first.accuracy;
    final lastAccuracy = trendPoints.last.accuracy;
    return lastAccuracy - firstAccuracy;
  }

  String _getTrendDescription(double trend) {
    if (trend > 0.05) return 'Improving';
    if (trend < -0.05) return 'Declining';
    return 'Stable';
  }

  Color _getTrendColor(double trend) {
    if (trend > 0.05) return CupertinoColors.systemGreen;
    if (trend < -0.05) return CupertinoColors.systemRed;
    return CupertinoColors.systemBlue;
  }

  Widget _buildTrendIcon(double trend) {
    IconData icon;
    Color color;

    if (trend > 0.05) {
      icon = CupertinoIcons.arrow_up_circle_fill;
      color = CupertinoColors.systemGreen;
    } else if (trend < -0.05) {
      icon = CupertinoIcons.arrow_down_circle_fill;
      color = CupertinoColors.systemRed;
    } else {
      icon = CupertinoIcons.minus_circle_fill;
      color = CupertinoColors.systemBlue;
    }

    return Icon(icon, color: color, size: 24);
  }
}

/// Custom painter for accuracy trend chart
class AccuracyTrendPainter extends CustomPainter {
  final List<TrendPoint> trendPoints;
  final Color primaryColor;
  final Color backgroundColor;
  final TextStyle textStyle;

  AccuracyTrendPainter({
    required this.trendPoints,
    required this.primaryColor,
    required this.backgroundColor,
    required this.textStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (trendPoints.isEmpty) return;

    final chartArea = Rect.fromLTWH(40, 20, size.width - 80, size.height - 60);

    // Draw grid lines
    _drawGrid(canvas, chartArea);

    // Draw accuracy line
    _drawAccuracyLine(canvas, chartArea);

    // Draw data points
    _drawDataPoints(canvas, chartArea);

    // Draw labels
    _drawLabels(canvas, chartArea, size);
  }

  void _drawGrid(Canvas canvas, Rect chartArea) {
    final gridPaint = Paint()
      ..color = CupertinoColors.separator.withOpacity(0.3)
      ..strokeWidth = 0.5;

    // Horizontal grid lines (accuracy levels)
    for (int i = 0; i <= 4; i++) {
      final y = chartArea.top + (chartArea.height / 4) * i;
      canvas.drawLine(
        Offset(chartArea.left, y),
        Offset(chartArea.right, y),
        gridPaint,
      );
    }

    // Vertical grid lines (time intervals)
    final intervals = math.min(trendPoints.length, 7);
    for (int i = 0; i <= intervals; i++) {
      final x = chartArea.left + (chartArea.width / intervals) * i;
      canvas.drawLine(
        Offset(x, chartArea.top),
        Offset(x, chartArea.bottom),
        gridPaint,
      );
    }
  }

  void _drawAccuracyLine(Canvas canvas, Rect chartArea) {
    if (trendPoints.length < 2) return;

    final linePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryColor.withOpacity(0.3),
          primaryColor.withOpacity(0.0),
        ],
      ).createShader(chartArea);

    final path = Path();
    final gradientPath = Path();

    final minAccuracy = trendPoints.map((p) => p.accuracy).reduce(math.min);
    final maxAccuracy = trendPoints.map((p) => p.accuracy).reduce(math.max);
    final accuracyRange = math.max(maxAccuracy - minAccuracy, 0.2); // Minimum range for visibility

    for (int i = 0; i < trendPoints.length; i++) {
      final point = trendPoints[i];
      final x = chartArea.left + (chartArea.width / (trendPoints.length - 1)) * i;
      final normalizedAccuracy = (point.accuracy - minAccuracy) / accuracyRange;
      final y = chartArea.bottom - (chartArea.height * normalizedAccuracy);

      if (i == 0) {
        path.moveTo(x, y);
        gradientPath.moveTo(x, chartArea.bottom);
        gradientPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        gradientPath.lineTo(x, y);
      }
    }

    // Complete gradient path
    gradientPath.lineTo(chartArea.right, chartArea.bottom);
    gradientPath.close();

    // Draw gradient fill
    canvas.drawPath(gradientPath, gradientPaint);

    // Draw line
    canvas.drawPath(path, linePaint);
  }

  void _drawDataPoints(Canvas canvas, Rect chartArea) {
    final pointPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final minAccuracy = trendPoints.map((p) => p.accuracy).reduce(math.min);
    final maxAccuracy = trendPoints.map((p) => p.accuracy).reduce(math.max);
    final accuracyRange = math.max(maxAccuracy - minAccuracy, 0.2);

    for (int i = 0; i < trendPoints.length; i++) {
      final point = trendPoints[i];
      final x = chartArea.left + (chartArea.width / (trendPoints.length - 1)) * i;
      final normalizedAccuracy = (point.accuracy - minAccuracy) / accuracyRange;
      final y = chartArea.bottom - (chartArea.height * normalizedAccuracy);

      // Draw point
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
      canvas.drawCircle(Offset(x, y), 4, borderPaint);
    }
  }

  void _drawLabels(Canvas canvas, Rect chartArea, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Y-axis labels (accuracy percentages)
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

    // X-axis labels (dates)
    final labelCount = math.min(trendPoints.length, 5);
    for (int i = 0; i < labelCount; i++) {
      final pointIndex = (trendPoints.length - 1) * i ~/ (labelCount - 1);
      final point = trendPoints[pointIndex];
      final x = chartArea.left + (chartArea.width / (trendPoints.length - 1)) * pointIndex;

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

  @override
  bool shouldRepaint(AccuracyTrendPainter oldDelegate) {
    return trendPoints != oldDelegate.trendPoints ||
           primaryColor != oldDelegate.primaryColor;
  }
}