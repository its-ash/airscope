import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../core/models.dart';
import '../core/wifi_math.dart';

/// Visible frequency range of the chart, in MHz.
(double, double) chartRange(WifiBand band, List<AccessPoint> aps) {
  if (band == WifiBand.ghz24) return (2397, 2487);
  if (aps.isEmpty) {
    return band == WifiBand.ghz5 ? (5160, 5340) : (5925, 6105);
  }
  var lo = double.infinity;
  var hi = double.negativeInfinity;
  for (final ap in aps) {
    final r = occupiedRange(ap.centerMhz, ap.widthMhz);
    if (r.$1 < lo) lo = r.$1;
    if (r.$2 > hi) hi = r.$2;
  }
  lo -= 10;
  hi += 10;
  if (hi - lo < 100) {
    final mid = (lo + hi) / 2;
    lo = mid - 50;
    hi = mid + 50;
  }
  return (lo, hi);
}

/// Channels (number, center MHz) to label on the x axis.
List<(int, int)> labelChannels(WifiBand band, double lo, double hi) {
  final channels = switch (band) {
    WifiBand.ghz24 => [for (var c = 1; c <= 13; c++) c],
    WifiBand.ghz5 => channels5,
    WifiBand.ghz6 => [for (var c = 1; c <= 233; c += 4) c],
  };
  return [
    for (final ch in channels)
      if (centerFreqOf(band, ch) >= lo && centerFreqOf(band, ch) <= hi) (ch, centerFreqOf(band, ch)),
  ];
}

/// Channel graph: each access point is a parabola over the spectrum it occupies, as
/// high as its signal is strong.
class ChannelChart extends StatelessWidget {
  const ChannelChart({super.key, required this.band, required this.aps, this.height = 240});

  final WifiBand band;
  final List<AccessPoint> aps;
  final double height;

  /// Colors in the same order as [aps] (legend uses the same function).
  static Color colorOf(BuildContext context, int index) => context.colors.chartColor(index);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _ChannelPainter(
          band: band,
          aps: aps,
          palette: [for (var i = 0; i < aps.length; i++) colors.chartColor(i)],
          grid: colors.border,
          labelStyle: (context.text.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: colors.textMuted),
        ),
      ),
    );
  }
}

class _ChannelPainter extends CustomPainter {
  _ChannelPainter({
    required this.band,
    required this.aps,
    required this.palette,
    required this.grid,
    required this.labelStyle,
  });

  final WifiBand band;
  final List<AccessPoint> aps;
  final List<Color> palette;
  final Color grid;
  final TextStyle labelStyle;

  static const _left = 34.0;
  static const _bottom = 22.0;
  static const _top = 6.0;
  static const _minDbm = -100;
  static const _maxDbm = -30;

  void _text(Canvas canvas, String s, Offset at, {bool center = false, bool rightAlign = false}) {
    final tp = TextPainter(text: TextSpan(text: s, style: labelStyle), textDirection: TextDirection.ltr)..layout();
    var dx = at.dx;
    if (center) dx -= tp.width / 2;
    if (rightAlign) dx -= tp.width;
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(_left, _top, size.width - 4, size.height - _bottom);
    final range = chartRange(band, aps);
    final lo = range.$1;
    final hi = range.$2;
    double xOf(double f) => plot.left + (f - lo) / (hi - lo) * plot.width;
    double yOf(double dbm) => plot.bottom - (dbm - _minDbm) / (_maxDbm - _minDbm) * plot.height;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final dbm in [-90, -70, -50, -30]) {
      final y = yOf(dbm.toDouble());
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      _text(canvas, '$dbm', Offset(plot.left - 6, y), rightAlign: true);
    }
    canvas.drawLine(Offset(plot.left, plot.bottom), Offset(plot.right, plot.bottom), gridPaint);

    // x labels, thinned out so they never touch.
    var lastRight = -1000.0;
    for (final (ch, f) in labelChannels(band, lo, hi)) {
      final x = xOf(f.toDouble());
      canvas.drawLine(Offset(x, plot.bottom), Offset(x, plot.bottom + 3), gridPaint);
      final label = '$ch';
      final w = label.length * 7.0;
      if (x - w / 2 > lastRight + 4) {
        _text(canvas, label, Offset(x, plot.bottom + 12), center: true);
        lastRight = x + w / 2;
      }
    }

    // Weak first so strong networks are drawn on top.
    final order = List.generate(aps.length, (i) => i)..sort((a, b) => aps[a].rssi.compareTo(aps[b].rssi));
    for (final i in order) {
      final ap = aps[i];
      final r = occupiedRange(ap.centerMhz, ap.widthMhz);
      final peak = ((ap.rssi - _minDbm) / (_maxDbm - _minDbm)).clamp(0.02, 1.0);
      final path = Path()..moveTo(xOf(r.$1), plot.bottom);
      const steps = 28;
      for (var s = 0; s <= steps; s++) {
        final f = r.$1 + (r.$2 - r.$1) * s / steps;
        final h = parabola(f, ap.centerMhz, ap.widthMhz, peak);
        path.lineTo(xOf(f), plot.bottom - h * plot.height);
      }
      path.lineTo(xOf(r.$2), plot.bottom);
      final color = palette[i];
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.16));
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_ChannelPainter old) =>
      old.band != band || old.aps != aps || old.grid != grid || old.palette.length != palette.length;
}
