// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:formio/formio.dart';
import 'package:formio/src/widgets/components/drawing_canvas_gesture.dart';
import 'package:flutter_test/flutter_test.dart';

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
    /// for "the canvas received the gesture" without needing PNG encoding
    /// (`toImage`/`toByteData` require `runAsync`, out of scope here).
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

    /// Drags in many small steps, the way a real touchscreen delivers moves.
    /// A single-step `tester.drag` would let both recognizers cross their
    /// thresholds in the same event and hide the arena conflict entirely.
    Future<void> stroke(WidgetTester tester, Offset total,
        {int steps = 24}) async {
      final gesture = await tester.startGesture(tester.getCenter(canvas));
      for (var i = 0; i < steps; i++) {
        await gesture.moveBy(Offset(total.dx / steps, total.dy / steps));
        await tester.pump(const Duration(milliseconds: 16));
      }
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
