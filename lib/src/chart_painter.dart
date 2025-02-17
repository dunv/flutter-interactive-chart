import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:interactive_chart/interactive_chart.dart';

import 'candle_data.dart';
import 'painter_params.dart';

typedef TimeLabelGetter = String Function(int timestamp, int visibleDataCount);
typedef PriceLabelGetter = String Function(double price);
typedef OverlayInfoGetter = Map<String, String> Function(CandleData candle);

class ChartPainter extends CustomPainter {
  final PainterParams params;
  final TimeLabelGetter getTimeLabel;
  final PriceLabelGetter getPriceLabel;
  final OverlayInfoGetter getOverlayInfo;

  ChartPainter({
    required this.params,
    required this.getTimeLabel,
    required this.getPriceLabel,
    required this.getOverlayInfo,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw time labels (dates) & price labels
    _drawTimeLabels(canvas, params);
    _drawPriceGridAndLabels(canvas, params);

    // Draw prices, volumes & trend line
    canvas.save();
    canvas.clipRect(Offset.zero & Size(params.chartWidth, params.chartHeight));
    // canvas.drawRect(
    //   // apply yellow tint to clipped area (for debugging)
    //   Offset.zero & Size(params.chartWidth, params.chartHeight),
    //   Paint()..color = Colors.yellow[100]!,
    // );
    canvas.translate(params.xShift, 0);
    for (int i = 0; i < params.candles.length; i++) {
      _drawSingleDay(canvas, params, i);
    }
    canvas.restore();

    // leftOffset
    // - translates xShift into seconds
    // - the chart displays the center of the first candle with this offset to the left end of the chart
    double leftOffset = -(params.xShift / params.candleWidth) * params.candleTimeInterval.inMilliseconds;
    // the timestamp all the way to the left of the chart
    int minTime = params.candles[0].timestamp + leftOffset.toInt();
    // rightOffset
    // - calculates the "xShift" on the right side and translates into seconds
    // - sometimes an extra candle is rendered if we are "in-between-candles" -> subtract this one in the calculation
    // - the chart display the center of the last candle widh this offset to the right end of the chart
    // - TODO: always assume one extra candle
    double rightOffset = ((params.chartWidth - params.candleWidth * (params.candles.length.toDouble() - 1.0) - params.xShift) / params.candleWidth) * params.candleTimeInterval.inMilliseconds;
    // the timestamp all the way to the right of the chart
    int maxTime = params.candles[params.candles.length - 1].timestamp + rightOffset.toInt();
    // the timeframe displayed in the chart
    int totalTime = maxTime - minTime;
    // for easier rendering: how many chart-pixels make up a second in "real-time"
    double pxPerMilliSecond = params.chartWidth.toDouble() / totalTime.toDouble();

    // debugPrint('extraCandles:${params.extraCandles}');
    // debugPrint(
    //     'xShift:${params.xShift} candleWidth:${params.candleWidth} candles:${params.candles.length} candles*width:${params.candleWidth * params.candles.length} chartWidth:${params.chartWidth}');

    // debugPrint(
    //     'pxPerMillisecond:$pxPerMilliSecond leftOffsetDays:${(leftOffset / 1000 / 60 / 60 / 24 * 100).round() / 100} rightOffsetDays:${(rightOffset / 1000 / 60 / 60 / 24 * 100).round() / 100} candles:${params.candles.length} minTime:${DateTime.fromMillisecondsSinceEpoch(minTime, isUtc: true)} maxTime:${DateTime.fromMillisecondsSinceEpoch(maxTime, isUtc: true)}');

    if (params.trendlines != null && params.showTrendlines) {
      canvas.save();
      canvas.clipRect(Offset.zero & Size(params.chartWidth, params.chartHeight));
      for (int i = 0; i < params.trendlines!.length; i++) {
        _drawSingleTrendline(canvas, params, i, minTime, pxPerMilliSecond);
      }
      canvas.restore();
    }

    if (params.zones != null && params.showZones) {
      canvas.save();
      canvas.clipRect(Offset.zero & Size(params.chartWidth, params.chartHeight));
      for (int i = 0; i < params.zones!.length; i++) {
        _drawSingleZone(canvas, params, i, minTime, maxTime, pxPerMilliSecond);
      }
      canvas.restore();
    }

    // Draw tap highlight & overlay
    if (params.tapPosition != null) {
      if (params.tapPosition!.dx < params.chartWidth) {
        _drawTapHighlightAndOverlay(canvas, params);
      }
    }
  }

  void _drawSingleTrendline(Canvas canvas, PainterParams params, int i, int minTime, double pxPerMilliSecond) {
    final trendline = params.trendlines![i];

    double startX = (trendline.start - minTime.toDouble()) * pxPerMilliSecond;
    double endX = (trendline.end - minTime.toDouble()) * pxPerMilliSecond;

    // debugPrint('trendline i:$i start:${DateTime.fromMillisecondsSinceEpoch(trendline.start.toInt(), isUtc: true)} end:${DateTime.fromMillisecondsSinceEpoch(trendline.end.toInt(), isUtc: true)}');
    canvas.drawLine(
      Offset(startX, params.fitPrice(trendline.y1)),
      Offset(endX, params.fitPrice(trendline.y2)),
      Paint()
        ..strokeWidth = params.candleWidth > 30 ? 1 : 0.5
        ..color = trendline.type == 'support' ? params.style.trendlineSupportColor : params.style.trendlineResistanceColor,
    );
  }

  void _drawSingleZone(Canvas canvas, PainterParams params, int i, int minTime, int maxTime, double pxPerMilliSecond) {
    final zone = params.zones![i];
    double startX = (zone.start - minTime.toDouble()) * pxPerMilliSecond;
    double endX = (zone.end - minTime.toDouble()) * pxPerMilliSecond;

    // debugPrint('zone i:$i start:${DateTime.fromMillisecondsSinceEpoch(zone.start.toInt(), isUtc: true)} end:${DateTime.fromMillisecondsSinceEpoch(zone.end.toInt(), isUtc: true)}');
    canvas.drawRect(
      Rect.fromPoints(
        Offset(startX, params.fitPrice(zone.low)),
        Offset(endX, params.fitPrice(zone.high)),
      ),
      Paint()..color = zone.type == 'buy' ? params.style.zoneBuyColor : params.style.zoneSellColor,
    );
  }

  void _drawTimeLabels(canvas, PainterParams params) {
    // We draw one time label per 90 pixels of screen width
    final lineCount = params.chartWidth ~/ 90;
    final gap = 1 / (lineCount + 1);
    for (int i = 1; i <= lineCount; i++) {
      double x = i * gap * params.chartWidth;
      final index = params.getCandleIndexFromOffset(x);
      if (index < params.candles.length) {
        final candle = params.candles[index];
        final visibleDataCount = params.candles.length;
        final timeTp = TextPainter(
          text: TextSpan(
            text: getTimeLabel(candle.timestamp, visibleDataCount),
            style: params.style.timeLabelStyle,
          ),
        )
          ..textDirection = TextDirection.ltr
          ..layout();

        // Align texts towards vertical bottom
        final topPadding = params.style.timeLabelHeight - timeTp.height;
        timeTp.paint(
          canvas,
          Offset(x - timeTp.width / 2, params.chartHeight + topPadding),
        );
      }
    }
  }

  void _drawPriceGridAndLabels(canvas, PainterParams params) {
    [0.0, 0.25, 0.5, 0.75, 1.0].map((v) => ((params.maxPrice - params.minPrice) * v) + params.minPrice).forEach((y) {
      // debugPrint('drawing priceAndGridAndLabels Offset(0, ${params.fitPrice(y)}) to Offset(${params.chartWidth}, ${params.fitPrice(y)})');

      canvas.drawLine(
        Offset(0, params.fitPrice(y)),
        Offset(params.chartWidth, params.fitPrice(y)),
        Paint()
          ..strokeWidth = 0.5
          ..color = params.style.priceGridLineColor,
      );
      final priceTp = TextPainter(
        text: TextSpan(
          text: getPriceLabel(y),
          style: params.style.priceLabelStyle,
        ),
      )
        ..textDirection = TextDirection.ltr
        ..layout();
      priceTp.paint(
          canvas,
          Offset(
            params.chartWidth + 4,
            params.fitPrice(y) - priceTp.height / 2,
          ));
    });
  }

  void _drawSingleDay(canvas, PainterParams params, int i) {
    final candle = params.candles[i];
    final x = i * params.candleWidth;
    final thickWidth = max(params.candleWidth * 0.8, 0.8);
    final thinWidth = max(params.candleWidth * 0.2, 0.2);
    // Draw price bar
    final open = candle.open;
    final close = candle.close;
    final high = candle.high;
    final low = candle.low;
    if (open != null && close != null) {
      final color = open > close ? params.style.priceLossColor : params.style.priceGainColor;

      // debugPrint('drawing $i (time: ${candle.timestamp}) candle Offset($x, ${params.fitPrice(open)}) to Offset($x, ${params.fitPrice(close)})');
      canvas.drawLine(
        Offset(x, params.fitPrice(open)),
        Offset(x, params.fitPrice(close)),
        Paint()
          ..strokeWidth = thickWidth
          ..color = color,
      );
      if (high != null && low != null) {
        canvas.drawLine(
          Offset(x, params.fitPrice(high)),
          Offset(x, params.fitPrice(low)),
          Paint()
            ..strokeWidth = thinWidth
            ..color = color,
        );
      }
    }
    // Draw volume bar
    final volume = candle.volume;
    if (volume != null) {
      canvas.drawLine(
        Offset(x, params.chartHeight),
        Offset(x, params.fitVolume(volume)),
        Paint()
          ..strokeWidth = thickWidth
          ..color = params.style.volumeColor,
      );
    }
    // Draw trend line
    for (int j = 0; j < candle.trends.length; j++) {
      final trendLinePaint = params.style.trendLineStyles.at(j) ??
          (Paint()
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round
            ..color = Colors.blue);

      final pt = candle.trends.at(j); // current data point
      final prevPt = params.candles.at(i - 1)?.trends.at(j);
      if (pt != null && prevPt != null) {
        canvas.drawLine(
          Offset(x - params.candleWidth, params.fitPrice(prevPt)),
          Offset(x, params.fitPrice(pt)),
          trendLinePaint,
        );
      }
      if (i == 0) {
        // In the front, draw an extra line connecting to out-of-window data
        if (pt != null && params.leadingTrends?.at(j) != null) {
          canvas.drawLine(
            Offset(x - params.candleWidth, params.fitPrice(params.leadingTrends!.at(j)!)),
            Offset(x, params.fitPrice(pt)),
            trendLinePaint,
          );
        }
      } else if (i == params.candles.length - 1) {
        // At the end, draw an extra line connecting to out-of-window data
        if (pt != null && params.trailingTrends?.at(j) != null) {
          canvas.drawLine(
            Offset(x, params.fitPrice(pt)),
            Offset(
              x + params.candleWidth,
              params.fitPrice(params.trailingTrends!.at(j)!),
            ),
            trendLinePaint,
          );
        }
      }
    }
  }

  void _drawTapHighlightAndOverlay(canvas, PainterParams params) {
    final pos = params.tapPosition!;
    final i = params.getCandleIndexFromOffset(pos.dx);
    final candle = params.candles[i];
    canvas.save();
    canvas.translate(params.xShift, 0.0);
    // Draw highlight bar (selection box)
    canvas.drawLine(
        Offset(i * params.candleWidth, 0.0),
        Offset(i * params.candleWidth, params.chartHeight),
        Paint()
          ..strokeWidth = max(params.candleWidth * 0.88, 1.0)
          ..color = params.style.selectionHighlightColor);
    canvas.restore();
    // Draw info pane
    _drawTapInfoOverlay(canvas, params, candle);
  }

  void _drawTapInfoOverlay(canvas, PainterParams params, CandleData candle) {
    final xGap = 8.0;
    final yGap = 4.0;

    TextPainter makeTP(String text) => TextPainter(
          text: TextSpan(
            text: text,
            style: params.style.overlayTextStyle,
          ),
        )
          ..textDirection = TextDirection.ltr
          ..layout();

    final info = getOverlayInfo(candle);
    if (params.trendlines != null && params.showTrendlines) {
      for (int i = 0; i < params.trendlines!.length; i++) {
        final trendline = params.trendlines![i];
        if (trendline.start == candle.timestamp.toDouble() || trendline.end == candle.timestamp.toDouble()) {
          final start = intl.DateFormat.yMd('de_DE').format(DateTime.fromMillisecondsSinceEpoch(trendline.start.toInt(), isUtc: true));
          final end = intl.DateFormat.yMd('de_DE').format(DateTime.fromMillisecondsSinceEpoch(trendline.end.toInt(), isUtc: true));
          debugPrint('starting trendline i:$i start:$start y1:${trendline.y1.toStringAsFixed(2)} end:$end y2:${trendline.y2.toStringAsFixed(2)}');
          info.addAll({'Trendline ${i + 1}': '$start - $end'});
          info.addAll({'                ${i + 1}': '${trendline.y1.toStringAsFixed(2)} - ${trendline.y2.toStringAsFixed(2)}'});
        }
      }
    }

    if (info.isEmpty) return;
    final labels = info.keys.map((text) => makeTP(text)).toList();
    final values = info.values.map((text) => makeTP(text)).toList();

    final labelsMaxWidth = labels.map((tp) => tp.width).reduce(max);
    final valuesMaxWidth = values.map((tp) => tp.width).reduce(max);
    final panelWidth = labelsMaxWidth + valuesMaxWidth + xGap * 3;
    final panelHeight = max(
          labels.map((tp) => tp.height).reduce((a, b) => a + b),
          values.map((tp) => tp.height).reduce((a, b) => a + b),
        ) +
        yGap * (values.length + 1);

    // Shift the canvas, so the overlay panel can appear near touch position.
    canvas.save();
    final pos = params.tapPosition!;
    final fingerSize = 32.0; // leave some margin around user's finger
    double dx, dy;
    assert(params.size.width >= panelWidth, "Overlay panel is too wide.");
    if (pos.dx <= params.size.width / 2) {
      // If user touches the left-half of the screen,
      // we show the overlay panel near finger touch position, on the right.
      dx = pos.dx + fingerSize;
    } else {
      // Otherwise we show panel on the left of the finger touch position.
      dx = pos.dx - panelWidth - fingerSize;
    }
    dx = dx.clamp(0, params.size.width - panelWidth);
    dy = pos.dy - panelHeight - fingerSize;
    if (dy < 0) dy = 0.0;
    canvas.translate(dx, dy);

    // Draw the background for overlay panel
    canvas.drawRect(
      Offset.zero & Size(panelWidth, panelHeight),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 1.0
        ..style = PaintingStyle.fill,
    );

    final border = Path();
    border.lineTo(panelWidth, 0);
    border.lineTo(panelWidth, panelHeight);
    border.lineTo(0, panelHeight);
    border.lineTo(0, 0);
    canvas.drawPath(
        border,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.grey
          ..strokeWidth = .8);
    canvas.drawPath(
        border,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.black
          ..strokeWidth = .3);

    // Draw texts
    var y = 0.0;
    for (int i = 0; i < labels.length; i++) {
      y += yGap;
      final rowHeight = max(labels[i].height, values[i].height);
      // Draw labels (left align, vertical center)
      final labelY = y + (rowHeight - labels[i].height) / 2; // vertical center
      labels[i].paint(canvas, Offset(xGap, labelY));

      // Draw values (right align, vertical center)
      final leading = valuesMaxWidth - values[i].width; // right align
      final valueY = y + (rowHeight - values[i].height) / 2; // vertical center
      values[i].paint(
        canvas,
        Offset(labelsMaxWidth + xGap * 2 + leading, valueY),
      );
      y += rowHeight;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(ChartPainter oldDelegate) => params.shouldRepaint(oldDelegate.params);
}

extension ElementAtOrNull<E> on List<E> {
  E? at(int index) {
    if (index < 0 || index >= length) return null;
    return elementAt(index);
  }
}
