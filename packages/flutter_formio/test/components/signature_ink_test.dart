// ignore_for_file: depend_on_referenced_packages

import 'dart:ui';

import 'package:formio/src/widgets/components/signature_ink.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SignaturePen', () {
    /// Feeds a stroke of [samples] moves, each covering [step] pixels in the
    /// same 16ms, and returns the width reported for every sample. Timestamps
    /// are explicit, so the widths are a pure function of the input.
    List<double> strokeRadii({
      required double step,
      int samples = 8,
      SignaturePen? pen,
    }) {
      final p = (pen ?? SignaturePen())..beginStroke();
      var at = Duration.zero;
      var x = 0.0;
      return List.generate(samples, (_) {
        final radius = p.radiusAt(Offset(x, 0), at);
        x += step;
        at += const Duration(milliseconds: 16);
        return radius;
      });
    }

    test('the first sample uses the midpoint radius', () {
      final pen = SignaturePen(minWidth: 1, maxWidth: 4)..beginStroke();

      expect(pen.radiusAt(Offset.zero, Duration.zero), 2.5);
    });

    test('a fast pen draws thinner than a slow one', () {
      double average(List<double> widths) =>
          widths.reduce((a, b) => a + b) / widths.length;

      expect(average(strokeRadii(step: 40)),
          lessThan(average(strokeRadii(step: 2))));
    });

    test('the nib never leaves the schema bounds', () {
      final widths = [
        ...strokeRadii(step: 0.01, pen: SignaturePen(minWidth: 1, maxWidth: 4)),
        ...strokeRadii(step: 5000, pen: SignaturePen(minWidth: 1, maxWidth: 4)),
      ];

      expect(widths, everyElement(inInclusiveRange(1, 4)));
      expect(widths, contains(closeTo(1, 0.001)),
          reason: 'a very fast pen should bottom out at minWidth');
    });

    test('swapped bounds are ordered rather than rejected', () {
      final pen = SignaturePen(minWidth: 4, maxWidth: 1);

      expect(pen.minWidth, 1);
      expect(pen.maxWidth, 4);
    });

    test('equal bounds give a constant nib', () {
      expect(strokeRadii(step: 30, pen: SignaturePen(minWidth: 2, maxWidth: 2)),
          everyElement(closeTo(2, 0.001)));
    });

    test('a new stroke does not inherit the last stroke speed', () {
      final pen = SignaturePen(minWidth: 1, maxWidth: 4);
      strokeRadii(step: 5000, pen: pen); // race the pen to its thinnest

      pen.beginStroke();
      expect(pen.radiusAt(Offset.zero, Duration.zero), 2.5,
          reason: 'the stroke should start at the midpoint radius again');
    });

    test('untimed samples still produce widths within bounds', () {
      final pen = SignaturePen(minWidth: 1, maxWidth: 4)..beginStroke();
      final widths = List.generate(
          8, (i) => pen.radiusAt(Offset(i * 10, 0), null)); // no timestamps

      expect(widths, everyElement(inInclusiveRange(1, 4)));
    });

    test('web parity fixture filters moves and keeps the final sample', () {
      final pen = SignaturePen()..beginStroke();

      final samples = [
        pen.sampleAt(Offset.zero, Duration.zero),
        pen.sampleAt(const Offset(3, 0), const Duration(milliseconds: 8)),
        pen.sampleAt(const Offset(8, 0), const Duration(milliseconds: 12)),
        pen.sampleAt(const Offset(10, 0), const Duration(milliseconds: 16)),
        pen.sampleAt(const Offset(18, 0), const Duration(milliseconds: 24)),
        pen.sampleAt(const Offset(20, 0), const Duration(milliseconds: 32)),
        // Pointer-up bypasses the 16ms move throttle, as signature_pad does.
        pen.endAt(const Offset(28, 0), const Duration(milliseconds: 40)),
      ].whereType<StrokePoint>().toList();

      expect(samples.map((point) => point.offset.dx), [0, 10, 20, 28]);
      expect(samples.map((point) => point.radius), [
        1.5,
        closeTo(1.7391304348, 0.0000000001),
        closeTo(1.5936254980, 0.0000000001),
        closeTo(1.3364517207, 0.0000000001),
      ]);
    });
  });

  group('paintStrokes', () {
    /// Records what was asked of the canvas, since the geometry is otherwise
    /// only observable as pixels.
    final recording = _RecordingCanvas();

    setUp(recording.clear);

    StrokePoint point(double x) => StrokePoint(Offset(x, 0), 2);

    test('a lone sample is drawn at its configured radius', () {
      paintStrokes(recording, [point(0)], const Color(0xFF000000));

      expect(recording.dots, 1);
      expect(recording.radii, [2]);
    });

    test('three samples rasterize their circles in one filled path', () {
      paintStrokes(
          recording, [point(0), point(10), point(20)], const Color(0xFF000000));

      expect(recording.dots, 1, reason: 'the stroke starts with one dot');
      expect(recording.paths, 1,
          reason: 'signature_pad fills every curve as a single path');
    });

    test('a null separates strokes instead of joining them', () {
      paintStrokes(
          recording,
          [
            point(0),
            point(10),
            point(20),
            null,
            point(50),
            point(60),
            point(70)
          ],
          const Color(0xFF000000));

      expect(recording.paths, 2);
      expect(recording.pathBounds[0].right, lessThan(20));
      expect(recording.pathBounds[1].left, greaterThan(40),
          reason: 'no filled curve should bridge the separated strokes');
    });

    test('trailing and repeated nulls draw nothing extra', () {
      paintStrokes(recording, [null, point(0), point(10), null, null],
          const Color(0xFF000000));

      expect(recording.dots, 1);
      expect(recording.paths, 0);
    });
  });
}

/// A [Canvas] that records signature_pad-style ink dots and filled curves.
class _RecordingCanvas implements Canvas {
  final centers = <Offset>[];
  final radii = <double>[];
  final pathBounds = <Rect>[];

  int get dots => centers.length;
  int get paths => pathBounds.length;

  void clear() {
    centers.clear();
    radii.clear();
    pathBounds.clear();
  }

  @override
  void drawPath(Path path, Paint paint) => pathBounds.add(path.getBounds());

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    centers.add(c);
    radii.add(radius);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
