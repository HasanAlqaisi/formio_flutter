// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:formio/formio.dart';
import 'package:formio/src/widgets/components/drawing_canvas_gesture.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [Canvas] that keeps the radius of every standalone ink dot and ignores
/// filled curve paths.
class _InkRecordingCanvas implements Canvas {
  final radii = <double>[];

  @override
  void drawCircle(Offset c, double radius, Paint paint) => radii.add(radius);

  @override
  void drawPath(Path path, Paint paint) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('SignatureComponent', () {
    /// Puts the canvas inside a tall scroll view, mirroring how the renderer
    /// hosts it, so the gesture-arena competition is reproduced.
    Widget scrollHost(Widget child) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  child,
                  const SizedBox(height: 2000), // guarantee scrollable extent
                ],
              ),
            ),
          ),
        );

    ComponentModel signature() => ComponentModel.fromJson({
          'key': 'sig1',
          'type': 'signature',
          'label': 'Sign here',
        });

    /// The Clear button is enabled only while a stroke exists, so it stands in
    /// for "the canvas received the gesture" without inspecting PNG pixels.
    bool strokeRecorded(WidgetTester tester) =>
        tester
            .widget<TextButton>(find.ancestor(
              of: find.byIcon(Icons.clear),
              matching: find.byType(TextButton),
            ))
            .onPressed !=
        null;

    /// The drawing surface itself — targeted directly so the drag cannot land
    /// on some unrelated Material-internal painter.
    final canvas = find.byType(DrawingCanvasGestureDetector);

    /// The pad box around the canvas — the sized, decorated container whose
    /// dimensions the schema controls (the canvas itself sits inside its
    /// border, so it measures a couple of pixels smaller).
    Size padSize(WidgetTester tester) => tester.getSize(
        find.ancestor(of: canvas, matching: find.byType(Container)).first);

    /// Drags in many small steps, the way a real touchscreen delivers moves.
    /// A single-step `tester.drag` would let both recognizers cross their
    /// thresholds in the same event and hide the arena conflict entirely.
    /// Each move carries an explicit, advancing `timeStamp`: it defaults to
    /// zero, which would tell the pad every sample happened in the same instant
    /// and leave it unable to measure pen speed.
    Future<TestGesture> liveStroke(WidgetTester tester, Offset total,
        {int steps = 24,
        Duration interval = const Duration(milliseconds: 16)}) async {
      final gesture = await tester.startGesture(tester.getCenter(canvas));
      var elapsed = Duration.zero;
      for (var i = 0; i < steps; i++) {
        elapsed += interval;
        await gesture.moveBy(Offset(total.dx / steps, total.dy / steps),
            timeStamp: elapsed);
        await tester.pump(interval);
      }
      return gesture;
    }

    Future<void> stroke(WidgetTester tester, Offset total,
        {int steps = 24,
        Duration interval = const Duration(milliseconds: 16)}) async {
      final gesture =
          await liveStroke(tester, total, steps: steps, interval: interval);
      await gesture.up();
    }

    testWidgets('vertical stroke draws instead of scrolling the form',
        (tester) async {
      await tester.pumpWidget(scrollHost(SignatureComponent(
        component: signature(),
        value: null,
        onChanged: (_) {},
      )));

      final scrollable =
          tester.state<ScrollableState>(find.byType(Scrollable).first);
      expect(scrollable.position.pixels, 0);
      expect(strokeRecorded(tester), isFalse);

      // Stroke straight UP, well past kTouchSlop (~18px) — the distance at
      // which the enclosing Scrollable claims the gesture. The direction
      // matters: a downward stroke at offset 0 clamps to 0 whoever wins, so it
      // could never detect the leak.
      await stroke(tester, const Offset(0, -120));
      await tester.pumpAndSettle();

      expect(scrollable.position.pixels, 0,
          reason: 'vertical stroke leaked to the scroll view');
      expect(strokeRecorded(tester), isTrue,
          reason: 'canvas never received the vertical drag');
    });

    testWidgets('horizontal stroke still draws', (tester) async {
      await tester.pumpWidget(scrollHost(SignatureComponent(
        component: signature(),
        value: null,
        onChanged: (_) {},
      )));

      await stroke(tester, const Offset(120, 0));
      await tester.pumpAndSettle();

      expect(strokeRecorded(tester), isTrue);
    });

    testWidgets('pad honours the schema height, as the web canvas does',
        (tester) async {
      await tester.pumpWidget(scrollHost(SignatureComponent(
        component: ComponentModel.fromJson({
          'key': 'sig1',
          'type': 'signature',
          'label': 'Sign here',
          'width': '100%',
          'height': '150px',
        }),
        value: null,
        onChanged: (_) {},
      )));

      final size = padSize(tester);
      expect(size.height, 150);
      expect(size.width, 800, reason: '100% should still fill the parent');
    });

    testWidgets('pad falls back to 200 when the schema omits height',
        (tester) async {
      await tester.pumpWidget(scrollHost(SignatureComponent(
        component: signature(),
        value: null,
        onChanged: (_) {},
      )));

      expect(padSize(tester).height, 200);
    });

    testWidgets('shows the schema footer under the pad', (tester) async {
      await tester.pumpWidget(scrollHost(SignatureComponent(
        component: ComponentModel.fromJson({
          'key': 'sig1',
          'type': 'signature',
          'label': 'Sign here',
          'footer': 'Sign above',
        }),
        value: null,
        onChanged: (_) {},
      )));

      expect(find.text('Sign above'), findsOneWidget);
      expect(tester.getCenter(find.text('Sign above')).dy,
          greaterThan(tester.getBottomLeft(canvas).dy),
          reason: 'the footer belongs below the pad, as on web');
    });

    testWidgets('renders no footer when the schema blanks it', (tester) async {
      await tester.pumpWidget(scrollHost(SignatureComponent(
        component: ComponentModel.fromJson({
          'key': 'sig1',
          'type': 'signature',
          'label': 'Sign here',
          'footer': '',
        }),
        value: null,
        onChanged: (_) {},
      )));

      // Only the label — no stray caption.
      expect(find.byType(Text), findsNWidgets(2)); // label + Clear
    });

    /// Replays the on-screen painter onto a canvas that records the web-style
    /// ink circles — the only way to observe the nib short of a golden file.
    _InkRecordingCanvas replayPainter(WidgetTester tester) {
      final painter = tester
          .widgetList<CustomPaint>(
              find.descendant(of: canvas, matching: find.byType(CustomPaint)))
          .last
          .painter!;
      final recording = _InkRecordingCanvas();
      painter.paint(recording, const Size(800, 200));
      return recording;
    }

    List<double> paintedRadii(WidgetTester tester) =>
        replayPainter(tester).radii;

    testWidgets('a tap leaves a dot', (tester) async {
      await tester.pumpWidget(scrollHost(SignatureComponent(
        component: signature(),
        value: null,
        onChanged: (_) {},
      )));

      final gesture = await tester.startGesture(tester.getCenter(canvas));
      await tester.pump();

      final painted = replayPainter(tester);
      expect(painted.radii, [1.5],
          reason: 'the default dot radius is the midpoint of 0.5 and 2.5');
      await gesture.up();
    });

    testWidgets('the schema pen widths reach the painter', (tester) async {
      await tester.pumpWidget(scrollHost(SignatureComponent(
        component: ComponentModel.fromJson({
          'key': 'sig1',
          'type': 'signature',
          'label': 'Sign here',
          // Deliberately not signature_pad's 0.5/2.5 defaults: widths inside
          // this range prove the schema was read, not that we got lucky.
          'minWidth': '3',
          'maxWidth': '6',
        }),
        value: null,
        onChanged: (_) {},
      )));

      final gesture = await liveStroke(tester, const Offset(200, -60));

      final radii = paintedRadii(tester);
      expect(radii, isNotEmpty);
      expect(radii, everyElement(inInclusiveRange(3, 6)));
      await gesture.up();
    });

    /// A 1x1 transparent PNG — enough for the widget to decode and mount an
    /// Image; the pixels themselves are irrelevant here.
    const submittedPng =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB'
        'CAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

    testWidgets('renders a submitted signature', (tester) async {
      await tester.pumpWidget(scrollHost(SignatureComponent(
        component: signature(),
        value: submittedPng,
        onChanged: (_) {},
      )));
      await tester.pump();

      expect(find.byType(Image), findsOneWidget,
          reason: 'submitted signature was not rendered');
      expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.fill,
          reason: 'web stretches stored signatures to the current canvas');
      expect(strokeRecorded(tester), isTrue,
          reason: 'clear should be available for a submitted signature');
    });

    testWidgets('drawing replaces the submitted signature', (tester) async {
      await tester.pumpWidget(scrollHost(SignatureComponent(
        component: signature(),
        value: submittedPng,
        onChanged: (_) {},
      )));
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);

      final gesture = await liveStroke(tester, const Offset(0, -80));

      expect(find.byType(Image), findsNothing,
          reason: 'old signature stayed behind the new strokes');
      await gesture.up();
    });

    testWidgets('a locally saved signature returns through the image path',
        (tester) async {
      String? saved;
      await tester.pumpWidget(scrollHost(SignatureComponent(
        component: signature(),
        value: null,
        onChanged: (value) => saved = value,
      )));

      await stroke(tester, const Offset(120, -40));
      await tester.runAsync(() async {
        for (var i = 0; i < 100 && saved == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pump();

      expect(saved, startsWith('data:image/png;base64,'));
      expect(find.byType(Image), findsOneWidget,
          reason: 'local and web signatures must use the same display path');
      expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.fill);
      expect(find.descendant(of: canvas, matching: find.byType(CustomPaint)),
          findsOneWidget,
          reason:
              'live ink must remain behind the PNG during first-frame decode');
    });

    testWidgets('an external reset replaces live strokes', (tester) async {
      final value = ValueNotifier<String?>(submittedPng);
      addTearDown(value.dispose);
      await tester.pumpWidget(scrollHost(ValueListenableBuilder<String?>(
        valueListenable: value,
        builder: (_, currentValue, __) => SignatureComponent(
          component: signature(),
          value: currentValue,
          onChanged: (_) {},
        ),
      )));
      await tester.pump();

      await stroke(tester, const Offset(0, -80));
      await tester.pumpAndSettle();
      expect(strokeRecorded(tester), isTrue);

      value.value = null;
      await tester.pump();

      expect(find.byType(Image), findsNothing);
      expect(strokeRecorded(tester), isFalse,
          reason: 'the external null must clear the local stroke state');
    });

    testWidgets('clear removes a submitted signature', (tester) async {
      String? saved = 'stale';
      await tester.pumpWidget(scrollHost(SignatureComponent(
        component: signature(),
        value: submittedPng,
        onChanged: (v) => saved = v,
      )));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      expect(saved, isNull);
      expect(find.byType(Image), findsNothing);
      expect(strokeRecorded(tester), isFalse);
    });

    testWidgets('clear button resets the signature', (tester) async {
      String? saved = 'stale';
      await tester.pumpWidget(scrollHost(SignatureComponent(
        component: signature(),
        value: null,
        onChanged: (v) => saved = v,
      )));

      await stroke(tester, const Offset(0, -80));
      await tester.pumpAndSettle();
      expect(strokeRecorded(tester), isTrue);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      expect(saved, isNull, reason: 'clear should emit a null value');
      expect(strokeRecorded(tester), isFalse);
    });
  });
}
