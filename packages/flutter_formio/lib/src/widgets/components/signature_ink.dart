/// The ink model behind the signature pad: the nib radius at each sample and
/// how the samples are painted.
///
/// Kept apart from the widget because it is the part that has to match
/// signature_pad's output on web — a signature drawn on a phone and one drawn
/// in a browser should look like the same pen — and because none of it needs a
/// [BuildContext] to be exercised.
library;

import 'dart:math' as math;
import 'dart:ui';

/// One sample of a stroke: where the pen was, and the nib radius there.
///
/// The radius travels with the point rather than being decided at paint time,
/// because it depends on how fast the pen was moving when the point arrived —
/// information the painter no longer has.
class StrokePoint {
  final Offset offset;
  final double radius;

  const StrokePoint(this.offset, this.radius);
}

/// Tracks pen speed across a stroke and reports the nib radius for each sample.
///
/// signature_pad's model: `max(maxWidth / (velocity + 1), minWidth)`, over a
/// velocity smoothed against the previous sample, so a fast stroke thins and a
/// slow one fills out.
///
/// One instance spans one stroke; call [beginStroke] before the first sample of
/// each, or the new stroke inherits the old one's speed.
class SignaturePen {
  /// signature_pad's own defaults, for schemas that omit the properties.
  static const defaultMinWidth = 0.5;
  static const defaultMaxWidth = 2.5;
  static const defaultMinDistance = 5.0;
  static const defaultThrottle = Duration(milliseconds: 16);

  /// How much of the new velocity feeds into the smoothed one, matching
  /// signature_pad's `velocityFilterWeight`. Lower would lag behind the pen,
  /// higher would make the nib jitter sample to sample.
  static const _velocitySmoothing = 0.7;

  /// The thinnest and thickest the nib gets. Ordered on the way in, so bounds
  /// that arrive swapped still draw.
  final double minWidth;
  final double maxWidth;
  final double minDistance;
  final Duration throttle;

  /// Fallback clock for samples that arrive without a pointer timestamp.
  final _clock = Stopwatch();

  Offset? _lastOffset;
  Duration _lastSampleAt = Duration.zero;
  bool _lastSampleWasTimed = false;
  double _lastVelocity = 0;

  SignaturePen({
    double minWidth = defaultMinWidth,
    double maxWidth = defaultMaxWidth,
    double minDistance = defaultMinDistance,
    Duration throttle = defaultThrottle,
  })  : minWidth = math.min(minWidth, maxWidth),
        maxWidth = math.max(minWidth, maxWidth),
        minDistance = math.max(0, minDistance),
        throttle = throttle.isNegative ? Duration.zero : throttle;

  /// Starts a stroke, dropping the previous stroke's pen state.
  void beginStroke() {
    _lastOffset = null;
    _lastVelocity = 0;
    _lastSampleAt = Duration.zero;
    _clock
      ..reset()
      ..start();
  }

  /// The nib radius at [offset], reached at [timeStamp] — the pointer event's
  /// own time, which is not the time we got round to handling it, so a dropped
  /// frame does not register as a burst of speed. Pass null when the platform
  /// supplied none and the pen will time the sample itself.
  ///
  /// The first sample of a stroke has no velocity yet and uses the midpoint of
  /// the configured bounds, matching signature_pad's initial width and dot.
  double radiusAt(Offset offset, Duration? timeStamp) {
    final now = timeStamp ?? _clock.elapsed;
    final last = _lastOffset;
    final previousSampleAt = _lastSampleAt;
    // A delta is only meaningful between two samples off the same clock, and
    // the pointer's and ours count from different origins.
    final sameClock = _lastSampleWasTimed == (timeStamp != null);

    _lastOffset = offset;
    _lastSampleAt = now;
    _lastSampleWasTimed = timeStamp != null;

    if (last == null) {
      _lastVelocity = 0;
      return (minWidth + maxWidth) / 2;
    }

    final elapsedMs =
        sameClock ? (now - previousSampleAt).inMicroseconds / 1000 : 0.0;
    // Samples in the same instant carry no speed information; keep the previous
    // velocity rather than dividing by zero.
    final velocity =
        elapsedMs > 0 ? (offset - last).distance / elapsedMs : _lastVelocity;
    _lastVelocity = _velocitySmoothing * velocity +
        (1 - _velocitySmoothing) * _lastVelocity;

    return math.max(maxWidth / (_lastVelocity + 1), minWidth);
  }

  /// Applies signature_pad's input filters and returns an accepted sample.
  ///
  /// Move events are accepted at most once per [throttle] interval and only
  /// after travelling more than [minDistance] logical pixels from the last
  /// accepted sample. Flutter logical pixels are the mobile equivalent of the
  /// CSS pixels used by signature_pad.
  StrokePoint? sampleAt(Offset offset, Duration? timeStamp) {
    final last = _lastOffset;
    if (last != null) {
      if ((offset - last).distance <= minDistance) return null;

      final now = timeStamp ?? _clock.elapsed;
      final sameClock = _lastSampleWasTimed == (timeStamp != null);
      if (sameClock && now - _lastSampleAt < throttle) return null;
    }

    return StrokePoint(offset, radiusAt(offset, timeStamp));
  }

  /// Accepts the pointer-up sample without throttling, while retaining the web
  /// renderer's minimum-distance rule. signature_pad calls `_strokeUpdate`
  /// directly when a stroke ends, bypassing its throttled move callback.
  StrokePoint? endAt(Offset offset, Duration? timeStamp) {
    final last = _lastOffset;
    if (last != null && (offset - last).distance <= minDistance) return null;
    return StrokePoint(offset, radiusAt(offset, timeStamp));
  }
}

/// Draws [points] — strokes separated by nulls — in [color].
///
/// This follows signature_pad's raster model: each segment is a cubic Bézier
/// derived from four samples, then filled with overlapping circles whose radius
/// changes along the curve. In signature_pad, `minWidth` and `maxWidth` are
/// passed to `arc` as radii rather than used as a canvas stroke width.
void paintStrokes(Canvas canvas, List<StrokePoint?> points, Color color) {
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.fill;

  for (final stroke in _strokesIn(points)) {
    // signature_pad paints the first sample immediately as a dot. Subsequent
    // samples add curves once there is a third point to provide look-ahead.
    canvas.drawCircle(stroke.first.offset, stroke.first.radius, paint);
    if (stroke.length == 1) {
      continue;
    }

    for (var i = 0; i < stroke.length - 2; i++) {
      final previous = i == 0 ? stroke.first : stroke[i - 1];
      final start = stroke[i];
      final end = stroke[i + 1];
      final next = stroke[i + 2];
      final control1 =
          _controlPoints(previous.offset, start.offset, end.offset).$2;
      final control2 = _controlPoints(start.offset, end.offset, next.offset).$1;

      _drawCurve(
        canvas,
        paint,
        start: start.offset,
        control1: control1,
        control2: control2,
        end: end.offset,
        startRadius: start.radius,
        endRadius: end.radius,
      );
    }
  }
}

void _drawCurve(
  Canvas canvas,
  Paint paint, {
  required Offset start,
  required Offset control1,
  required Offset control2,
  required Offset end,
  required double startRadius,
  required double endRadius,
}) {
  final steps =
      (_curveLength(start, control1, control2, end).ceil() * 2).clamp(1, 10000);
  final radiusDelta = endRadius - startRadius;

  final path = Path();
  for (var i = 0; i < steps; i++) {
    final t = i / steps;
    final point = _cubicPoint(start, control1, control2, end, t);
    final radius = startRadius + t * t * t * radiusDelta;
    path.addOval(Rect.fromCircle(center: point, radius: radius));
  }
  canvas.drawPath(path, paint);
}

double _curveLength(
    Offset start, Offset control1, Offset control2, Offset end) {
  const samples = 10;
  var length = 0.0;
  var previous = start;
  for (var i = 1; i <= samples; i++) {
    final point = _cubicPoint(start, control1, control2, end, i / samples);
    length += (point - previous).distance;
    previous = point;
  }
  return length;
}

Offset _cubicPoint(
    Offset start, Offset control1, Offset control2, Offset end, double t) {
  final u = 1 - t;
  final uu = u * u;
  final tt = t * t;
  return start * (uu * u) +
      control1 * (3 * uu * t) +
      control2 * (3 * u * tt) +
      end * (tt * t);
}

/// The outgoing/incoming control points around [middle], ported from
/// signature_pad's `Bezier.calculateControlPoints`.
(Offset, Offset) _controlPoints(Offset first, Offset middle, Offset last) {
  final midpoint1 = _midpoint(first, middle);
  final midpoint2 = _midpoint(middle, last);
  final length1 = (first - middle).distance;
  final length2 = (middle - last).distance;
  final total = length1 + length2;
  final ratio = total == 0 ? 0.0 : length2 / total;
  final center = midpoint2 + (midpoint1 - midpoint2) * ratio;
  final translation = middle - center;
  return (midpoint1 + translation, midpoint2 + translation);
}

/// Splits the flat sample list into one list per stroke, dropping empty runs.
Iterable<List<StrokePoint>> _strokesIn(List<StrokePoint?> points) sync* {
  var stroke = <StrokePoint>[];
  for (final point in points) {
    if (point == null) {
      if (stroke.isNotEmpty) yield stroke;
      stroke = <StrokePoint>[];
    } else {
      stroke.add(point);
    }
  }
  if (stroke.isNotEmpty) yield stroke;
}

Offset _midpoint(Offset a, Offset b) =>
    Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
