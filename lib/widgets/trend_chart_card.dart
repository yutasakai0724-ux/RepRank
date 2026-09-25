import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../theme.dart';
import '../utils/app_fonts.dart';

/// グラフ表示範囲（画面に一度に表示する日数）。
enum TrendRange {
  week('週', 7),
  month('月', 30),
  quarter('3ヶ月', 90),
  year('年', 365);

  const TrendRange(this.label, this.days);
  final String label;
  final int days;
}

class TrendPoint {
  final DateTime date;
  final double value;
  const TrendPoint(this.date, this.value);
}

/// 1本の推移データ（1RM・体重比・ボリュームなど）。
class TrendSeries {
  final String label;
  final String? subtitle;
  final List<TrendPoint> points;
  final Color color;
  final String Function(double) formatAxis;
  final String Function(double) formatTooltip;

  const TrendSeries({
    required this.label,
    this.subtitle,
    required this.points,
    required this.color,
    required this.formatAxis,
    required this.formatTooltip,
  });
}

// ── 前処理済みデータ ───────────────────────────────────────────────

int _epochDay(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

DateTime _fromEpochDay(int day) =>
    DateTime.utc(1970, 1, 1).add(Duration(days: day));

/// 日付を「1970年からの日数」に変換してソートしたデータ。
/// 入力が変わったときだけ作り直し、スクロール中は一切再計算しない。
class _Data {
  final List<int> days;
  final List<double> values;
  const _Data(this.days, this.values);

  static _Data from(List<TrendPoint> points) {
    final sorted = [...points]..sort((a, b) => a.date.compareTo(b.date));
    return _Data(
      [for (final p in sorted) _epochDay(p.date)],
      [for (final p in sorted) p.value],
    );
  }

  bool get isEmpty => days.isEmpty;
}

int _lowerBound(List<int> a, int x) {
  var lo = 0, hi = a.length;
  while (lo < hi) {
    final m = (lo + hi) >> 1;
    if (a[m] < x) {
      lo = m + 1;
    } else {
      hi = m;
    }
  }
  return lo;
}

int _upperBound(List<int> a, int x) {
  var lo = 0, hi = a.length;
  while (lo < hi) {
    final m = (lo + hi) >> 1;
    if (a[m] <= x) {
      lo = m + 1;
    } else {
      hi = m;
    }
  }
  return lo;
}

/// スクロール位置と日付の対応。表示範囲・幅が変わったときだけ作り直す。
class _Geo {
  final int minStart; // スクロール領域の左端の日
  final int maxEnd; // スクロール領域の右端の日（今日か最新記録日）
  final int rangeDays;
  final double pxPerDay;

  const _Geo(this.minStart, this.maxEnd, this.rangeDays, this.pxPerDay);

  int get totalDays => maxEnd - minStart + 1;
  double get contentWidth => totalDays * pxPerDay;
  double get viewport => rangeDays * pxPerDay;
  double get maxOffset => math.max(0, contentWidth - viewport);

  double startDayAt(double offset) => minStart + offset / pxPerDay;
  double offsetForEnd(int endDay) =>
      ((endDay - rangeDays + 1) - minStart) * pxPerDay;
}

/// Y軸の追従アニメーション用の現在値（描画クラスから更新する）。
class _YAnim {
  double? min;
  double? max;
}

/// 日付ベースの横軸を持つ推移グラフカード。
///
/// 描画は fl_chart を使わず専用の CustomPainter で行い、スクロール位置だけを
/// 再描画のきっかけにする。スクロール中はウィジェットの再構築・レイアウトが走らず、
/// 画面内の数十点を描くだけになる。
/// 右上の「表示範囲」で 週／月（既定）／3ヶ月／年 を切り替え、横スクロールで
/// 任意の期間へ移動できる。Y軸は表示中の範囲に追従する。
class TrendChartCard extends StatefulWidget {
  final String title;
  final List<TrendSeries> series;
  final double height;
  final double leftReserved;
  final String emptyMessage;

  const TrendChartCard({
    super.key,
    required this.title,
    required this.series,
    this.height = 170,
    this.leftReserved = 44,
    this.emptyMessage = 'データが蓄積されるとグラフが表示されます',
  });

  @override
  State<TrendChartCard> createState() => _TrendChartCardState();
}

class _TrendChartCardState extends State<TrendChartCard> {
  TrendRange _range = TrendRange.month;
  int _seriesIdx = 0;

  final ScrollController _ctrl = ScrollController();
  final ValueNotifier<int?> _selected = ValueNotifier<int?>(null);
  final ValueNotifier<int> _yTick = ValueNotifier<int>(0);
  final _YAnim _yAnim = _YAnim();
  final Map<String, TextPainter> _textCache = {};

  late List<_Data> _data;
  _Geo? _lastGeo;

  /// 範囲切替・初回表示のあと、右端をこの日に合わせてスクロール位置を復元する。
  int? _pendingEnd = _epochDay(DateTime.now());

  @override
  void initState() {
    super.initState();
    _data = [for (final s in widget.series) _Data.from(s.points)];
  }

  @override
  void didUpdateWidget(covariant TrendChartCard old) {
    super.didUpdateWidget(old);
    _data = [for (final s in widget.series) _Data.from(s.points)];
    if (_seriesIdx >= widget.series.length) _seriesIdx = 0;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _selected.dispose();
    _yTick.dispose();
    super.dispose();
  }

  _Geo _buildGeo(double plotWidth) {
    final nonEmpty = _data.where((d) => !d.isEmpty).toList();
    final earliest = nonEmpty.map((d) => d.days.first).reduce(math.min);
    final latest = nonEmpty.map((d) => d.days.last).reduce(math.max);
    final today = _epochDay(DateTime.now());
    final maxEnd = math.max(today, latest);
    final minStart = math.min(earliest, maxEnd - _range.days + 1);
    return _Geo(minStart, maxEnd, _range.days, plotWidth / _range.days);
  }

  double _offset(_Geo g) => _ctrl.hasClients ? _ctrl.offset : g.maxOffset;

  void _onTap(Offset local, _Geo g) {
    final data = _data[_seriesIdx];
    if (data.isEmpty) return;
    final dayF = g.startDayAt(_offset(g)) + local.dx / g.pxPerDay;
    final i = _lowerBound(data.days, dayF.round());
    int? best;
    var bestDist = double.infinity;
    for (final c in [i - 1, i, i + 1]) {
      if (c < 0 || c >= data.days.length) continue;
      final dist = (data.days[c] - dayF).abs() * g.pxPerDay;
      if (dist < bestDist) {
        bestDist = dist;
        best = data.days[c];
      }
    }
    _selected.value = (best != null && bestDist <= 24) ? best : null;
  }

  void _animateBy(_Geo g, double delta) {
    if (!_ctrl.hasClients) return;
    final target = (_ctrl.offset + delta).clamp(0.0, g.maxOffset);
    _ctrl.animateTo(target,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  String _md(DateTime d) => '${d.month}/${d.day}';

  @override
  Widget build(BuildContext context) {
    final series = widget.series[_seriesIdx];
    final allEmpty = _data.every((d) => d.isEmpty);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: context.cCardLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: AppFonts.jetBrainsMono(
                          fontSize: 10,
                          color: context.cTextSub,
                          letterSpacing: 1),
                    ),
                    if (series.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        series.subtitle!,
                        style: AppFonts.jetBrainsMono(
                            fontSize: 9,
                            color: context.cTextSub.withValues(alpha: 0.5)),
                      ),
                    ],
                  ],
                ),
              ),
              _buildRangeButton(series.color),
            ],
          ),
          if (widget.series.length > 1) ...[
            const SizedBox(height: 10),
            _buildSeriesChips(),
          ],
          const SizedBox(height: 12),
          if (allEmpty)
            SizedBox(
              height: 80,
              child: Center(
                child: Text(
                  widget.emptyMessage,
                  style: AppFonts.jetBrainsMono(
                      fontSize: 11, color: context.cTextSub),
                ),
              ),
            )
          else
            LayoutBuilder(builder: (context, c) {
              final plotWidth = c.maxWidth - widget.leftReserved;
              final geo = _buildGeo(plotWidth);
              _lastGeo = geo;

              final pending = _pendingEnd;
              if (pending != null) {
                _pendingEnd = null;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || !_ctrl.hasClients) return;
                  final g = _lastGeo ?? geo;
                  _ctrl.jumpTo(
                      g.offsetForEnd(pending).clamp(0.0, g.maxOffset));
                });
              }

              return Column(
                children: [
                  SizedBox(
                    height: widget.height,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: _ChartPainter(
                                data: _data[_seriesIdx],
                                series: series,
                                geo: geo,
                                ctrl: _ctrl,
                                selected: _selected,
                                yAnim: _yAnim,
                                yTick: _yTick,
                                textCache: _textCache,
                                leftReserved: widget.leftReserved,
                                gridColor:
                                    context.cTextSub.withValues(alpha: 0.15),
                                textColor: context.cTextSub,
                                cardColor: context.cCardLow,
                                tooltipColor: context.cCardHigh,
                              ),
                            ),
                          ),
                        ),
                        // 透明なスクロール領域。標準の慣性スクロールにスクロール位置だけ担当させる
                        Positioned(
                          left: widget.leftReserved,
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTapUp: (d) => _onTap(d.localPosition, geo),
                            child: SingleChildScrollView(
                              controller: _ctrl,
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: geo.contentWidth,
                                height: widget.height,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildNavigator(geo, series.color),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSeriesChips() {
    return Row(
      children: [
        for (var i = 0; i < widget.series.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() {
              _seriesIdx = i;
              _selected.value = null;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: i == _seriesIdx
                    ? widget.series[i].color.withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: i == _seriesIdx
                      ? widget.series[i].color
                      : context.cBorderSub,
                ),
              ),
              child: Text(
                widget.series[i].label,
                style: AppFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: i == _seriesIdx
                      ? widget.series[i].color
                      : context.cTextSub,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRangeButton(Color accent) {
    return PopupMenuButton<TrendRange>(
      tooltip: '表示範囲',
      color: context.cCardHigh,
      onSelected: (r) {
        final g = _lastGeo;
        int? end;
        if (g != null) end = g.startDayAt(_offset(g)).round() + g.rangeDays - 1;
        setState(() {
          _range = r;
          _pendingEnd = end ?? _epochDay(DateTime.now());
        });
      },
      itemBuilder: (_) => [
        for (final r in TrendRange.values)
          PopupMenuItem(
            value: r,
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: r == _range
                      ? Icon(Icons.check, size: 16, color: accent)
                      : null,
                ),
                Text(r.label,
                    style: AppFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.cText)),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: context.cCardHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '表示範囲：${_range.label}',
              style: AppFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.cText),
            ),
            Icon(Icons.expand_more, size: 16, color: context.cTextSub),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigator(_Geo geo, Color accent) {
    Widget arrow(IconData icon, bool enabled, VoidCallback onTap) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Icon(
            icon,
            size: 22,
            color:
                enabled ? accent : context.cTextSub.withValues(alpha: 0.25),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final off = _offset(geo);
        final startDay = geo.startDayAt(off).round();
        final endDay = startDay + geo.rangeDays - 1;
        final s = _fromEpochDay(startDay);
        final e = _fromEpochDay(endDay);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            arrow(Icons.chevron_left, off > 0.5,
                () => _animateBy(geo, -geo.viewport)),
            Text(
              '${s.year}/${_md(s)} – ${_md(e)}',
              style:
                  AppFonts.jetBrainsMono(fontSize: 10, color: context.cTextSub),
            ),
            arrow(Icons.chevron_right, off < geo.maxOffset - 0.5,
                () => _animateBy(geo, geo.viewport)),
          ],
        );
      },
    );
  }
}

// ── 描画 ───────────────────────────────────────────────────────────

class _ChartPainter extends CustomPainter {
  final _Data data;
  final TrendSeries series;
  final _Geo geo;
  final ScrollController ctrl;
  final ValueNotifier<int?> selected;
  final _YAnim yAnim;
  final ValueNotifier<int> yTick;
  final Map<String, TextPainter> textCache;
  final double leftReserved;
  final Color gridColor;
  final Color textColor;
  final Color cardColor;
  final Color tooltipColor;

  _ChartPainter({
    required this.data,
    required this.series,
    required this.geo,
    required this.ctrl,
    required this.selected,
    required this.yAnim,
    required this.yTick,
    required this.textCache,
    required this.leftReserved,
    required this.gridColor,
    required this.textColor,
    required this.cardColor,
    required this.tooltipColor,
  }) : super(repaint: Listenable.merge([ctrl, selected, yTick]));

  TextPainter _text(String text,
      {double size = 9, Color? color, FontWeight? weight}) {
    final c = color ?? textColor;
    final key = '$text|$size|${c.toARGB32()}|${weight?.value}';
    if (textCache.length > 300) textCache.clear();
    return textCache.putIfAbsent(
      key,
      () => TextPainter(
        text: TextSpan(
          text: text,
          style: AppFonts.jetBrainsMono(
              fontSize: size, color: c, fontWeight: weight),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
  }

  static double _niceStep(double raw) {
    final exp = (math.log(raw) / math.ln10).floorToDouble();
    final base = math.pow(10, exp).toDouble();
    final f = raw / base;
    final nice = f <= 1 ? 1 : (f <= 2 ? 2 : (f <= 5 ? 5 : 10));
    return nice * base;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final off = ctrl.hasClients ? ctrl.offset : geo.maxOffset;
    final startF = geo.startDayAt(off);
    final endF = startF + geo.rangeDays;
    final px = geo.pxPerDay;
    final plot =
        Rect.fromLTRB(leftReserved, 6, size.width, size.height - 22);
    final days = data.days;
    final values = data.values;

    // ── 表示範囲内の点 ──
    final lo = _lowerBound(days, startF.ceil());
    final hi = _upperBound(days, endF.floor()); // 範囲内は [lo, hi)

    // ── Y軸：表示中の範囲に追従（なめらかに補間） ──
    double tMin, tMax;
    if (days.isEmpty) {
      tMin = 0;
      tMax = 1;
    } else {
      final from = hi > lo ? lo : math.max(0, lo - 1);
      final to = hi > lo ? hi : math.min(days.length, lo + 1);
      tMin = double.infinity;
      tMax = -double.infinity;
      for (var i = from; i < to; i++) {
        tMin = math.min(tMin, values[i]);
        tMax = math.max(tMax, values[i]);
      }
    }
    var pad = (tMax - tMin) * 0.2;
    if (pad < 1e-9) pad = math.max(tMax.abs() * 0.05, 1);
    tMin -= pad;
    tMax += pad;

    if (yAnim.min == null) {
      yAnim.min = tMin;
      yAnim.max = tMax;
    } else {
      final span = math.max(tMax - tMin, 1e-9);
      final dMin = tMin - yAnim.min!;
      final dMax = tMax - yAnim.max!;
      if (dMin.abs() < span * 0.002 && dMax.abs() < span * 0.002) {
        yAnim.min = tMin;
        yAnim.max = tMax;
      } else {
        yAnim.min = yAnim.min! + dMin * 0.25;
        yAnim.max = yAnim.max! + dMax * 0.25;
        SchedulerBinding.instance.addPostFrameCallback((_) => yTick.value++);
      }
    }
    final yMin = yAnim.min!;
    final yMax = yAnim.max!;
    final ySpan = math.max(yMax - yMin, 1e-9);

    double xOf(int day) => plot.left + (day - startF) * px;
    double yOf(double v) => plot.bottom - (v - yMin) / ySpan * plot.height;

    // ── グリッド線とY軸ラベル ──
    final step = _niceStep(ySpan / 4);
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    var v = (yMin / step).ceil() * step;
    while (v <= yMax + 1e-9) {
      final y = yOf(v);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      final tp = _text(series.formatAxis(v));
      tp.paint(canvas, Offset(leftReserved - 6 - tp.width, y - tp.height / 2));
      v += step;
    }

    // ── 折れ線・面・点（クリップ内） ──
    if (days.isNotEmpty) {
      canvas.save();
      canvas.clipRect(plot);

      final first = math.max(0, lo - 1);
      final last = math.min(days.length - 1, hi);
      final line = Path();
      for (var i = first; i <= last; i++) {
        final p = Offset(xOf(days[i]), yOf(values[i]));
        i == first ? line.moveTo(p.dx, p.dy) : line.lineTo(p.dx, p.dy);
      }

      if (last > first) {
        final area = Path.from(line)
          ..lineTo(xOf(days[last]), plot.bottom)
          ..lineTo(xOf(days[first]), plot.bottom)
          ..close();
        canvas.drawPath(
          area,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                series.color.withValues(alpha: 0.18),
                series.color.withValues(alpha: 0.0),
              ],
            ).createShader(plot),
        );
        canvas.drawPath(
          line,
          Paint()
            ..color = series.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round,
        );
      }

      final dotR = (hi - lo) > 60 ? 2.0 : 4.0;
      final fill = Paint()..color = series.color;
      final ring = Paint()
        ..color = cardColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (var i = lo; i < hi; i++) {
        final c = Offset(xOf(days[i]), yOf(values[i]));
        canvas.drawCircle(c, dotR, fill);
        canvas.drawCircle(c, dotR, ring);
      }

      // ── 選択中の点 ──
      final sel = selected.value;
      if (sel != null) {
        final i = _lowerBound(days, sel);
        if (i < days.length && days[i] == sel) {
          final c = Offset(xOf(sel), yOf(values[i]));
          canvas.drawLine(
            Offset(c.dx, plot.top),
            Offset(c.dx, plot.bottom),
            Paint()
              ..color = series.color.withValues(alpha: 0.4)
              ..strokeWidth = 1,
          );
          canvas.drawCircle(c, 6, fill);
          canvas.drawCircle(c, 6, ring);
        }
      }
      canvas.restore();

      if (sel != null) _paintTooltip(canvas, plot, sel, xOf, yOf);
    }

    // ── X軸ラベル ──
    _paintXLabels(canvas, size, plot, startF, endF, xOf);
  }

  void _paintTooltip(Canvas canvas, Rect plot, int sel,
      double Function(int) xOf, double Function(double) yOf) {
    final i = _lowerBound(data.days, sel);
    if (i >= data.days.length || data.days[i] != sel) return;
    final x = xOf(sel);
    if (x < plot.left - 1 || x > plot.right + 1) return;
    final d = _fromEpochDay(sel);
    final tp = _text('${d.month}/${d.day}  ${series.formatTooltip(data.values[i])}',
        size: 11, color: series.color, weight: FontWeight.w700);
    const padH = 8.0, padV = 5.0;
    final w = tp.width + padH * 2;
    final h = tp.height + padV * 2;
    final y = yOf(data.values[i]);
    var left = x - w / 2;
    left = left.clamp(plot.left, math.max(plot.left, plot.right - w));
    var top = y - h - 10;
    if (top < 0) top = y + 10;
    final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, w, h), const Radius.circular(6));
    canvas.drawRRect(rect, Paint()..color = tooltipColor);
    tp.paint(canvas, Offset(left + padH, top + padV));
  }

  void _paintXLabels(Canvas canvas, Size size, Rect plot, double startF,
      double endF, double Function(int) xOf) {
    void label(int day, String text) {
      final x = xOf(day);
      if (x < plot.left - 12 || x > plot.right + 12) return;
      final tp = _text(text);
      tp.paint(canvas, Offset(x - tp.width / 2, plot.bottom + 5));
    }

    if (geo.rangeDays > 100) {
      // 年表示：月初に「yy/M」
      final s = _fromEpochDay(startF.floor());
      var y = s.year, m = s.month;
      while (true) {
        final day = _epochDay(DateTime.utc(y, m, 1));
        if (day > endF) break;
        if (day >= startF) label(day, '${y % 100}/$m');
        m++;
        if (m > 12) {
          m = 1;
          y++;
        }
      }
      return;
    }

    final interval = geo.rangeDays <= 7 ? 1 : (geo.rangeDays <= 31 ? 5 : 15);
    // 今日（右端）を基準に interval 日ごと
    final ceilStart = startF.ceil();
    if (geo.maxEnd < ceilStart) return;
    final kMax = (geo.maxEnd - ceilStart) ~/ interval;
    for (var day = geo.maxEnd - kMax * interval;
        day <= endF;
        day += interval) {
      final d = _fromEpochDay(day);
      label(day, '${d.month}/${d.day}');
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => true;
}
