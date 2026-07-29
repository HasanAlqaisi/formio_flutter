/// Gesture plumbing shared by the drawing surfaces (signature, sketchpad).
///
/// A plain [GestureDetector] with `onPanUpdate` cannot be used for a drawing
/// canvas that lives inside a scroll view: its [PanGestureRecognizer] needs
/// `kPanSlop` (~36px) of travel to claim the gesture arena, while the enclosing
/// [Scrollable]'s [VerticalDragGestureRecognizer] only needs `kTouchSlop`
/// (~18px). On a vertical stroke the scrollable therefore reaches its threshold
/// first, wins the arena, and the canvas' pan recognizer is rejected — vertical
/// lines scroll the form instead of drawing.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// A [PanGestureRecognizer] that claims the gesture arena as soon as a pointer
/// lands on it, so an enclosing [Scrollable] can never steal a stroke.
///
/// Declaring victory eagerly (rather than after `kPanSlop`) also means a simple
/// tap registers as a dot, which is what a drawing surface should do.
class _EagerPanGestureRecognizer extends PanGestureRecognizer {
  _EagerPanGestureRecognizer({super.debugOwner});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    // Win the arena immediately instead of waiting to out-travel the scrollable.
    resolve(GestureDisposition.accepted);
  }

  @override
  String get debugDescription => 'eager pan (drawing canvas)';
}

/// Wraps a drawing surface so pan gestures always reach [onPointDown] /
/// [onPointMove] / [onStrokeEnd], never the surrounding scroll view.
///
/// Offsets handed to the callbacks are local to this widget, matching the
/// `details.localPosition` the callers previously read from [GestureDetector].
class DrawingCanvasGestureDetector extends StatelessWidget {
  /// A pointer touched down at [Offset]; begin a stroke.
  final ValueChanged<Offset> onPointDown;

  /// The pointer moved to [Offset]; extend the current stroke.
  final ValueChanged<Offset> onPointMove;

  /// The pointer lifted; finish the stroke.
  final VoidCallback onStrokeEnd;

  /// The canvas to draw on.
  final Widget child;

  const DrawingCanvasGestureDetector({
    super.key,
    required this.onPointDown,
    required this.onPointMove,
    required this.onStrokeEnd,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        _EagerPanGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<_EagerPanGestureRecognizer>(
          () => _EagerPanGestureRecognizer(debugOwner: this),
          (recognizer) {
            recognizer
              ..onStart = (details) {
                onPointDown(details.localPosition);
              }
              ..onUpdate = (details) {
                onPointMove(details.localPosition);
              }
              ..onEnd = (_) {
                onStrokeEnd();
              }
              // Fires when the gesture is interrupted (e.g. a system overlay);
              // close the stroke so it does not join the next one.
              ..onCancel = onStrokeEnd;
          },
        ),
      },
      child: child,
    );
  }
}
