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

/// A stroke sample: where the pointer was, and when the *device* reported it.
///
/// The timestamp is the pointer event's own, not the time we got round to
/// handling it, so a canvas can derive pen speed without a dropped frame
/// showing up as a burst of speed. It is null when the platform did not supply
/// one (some synthesized events).
typedef DrawingPointCallback = void Function(
    Offset offset, Duration? timeStamp);

/// Wraps a drawing surface so pan gestures always reach [onPointDown] /
/// [onPointMove] / [onStrokeEnd], never the surrounding scroll view.
///
/// Offsets handed to the callbacks are local to this widget, matching the
/// `details.localPosition` the callers previously read from [GestureDetector].
class DrawingCanvasGestureDetector extends StatefulWidget {
  /// A pointer touched down at [Offset]; begin a stroke.
  final DrawingPointCallback onPointDown;

  /// The pointer moved to [Offset]; extend the current stroke.
  final DrawingPointCallback onPointMove;

  /// The pointer lifted or was cancelled; finish the stroke at its final
  /// reported position.
  final DrawingPointCallback onStrokeEnd;

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
  State<DrawingCanvasGestureDetector> createState() =>
      _DrawingCanvasGestureDetectorState();
}

class _DrawingCanvasGestureDetectorState
    extends State<DrawingCanvasGestureDetector> {
  int? _activePointer;

  void _finishStroke(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    widget.onStrokeEnd(event.localPosition, event.timeStamp);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) => _activePointer ??= event.pointer,
      onPointerUp: _finishStroke,
      // Close interrupted strokes so the next pointer cannot join them.
      onPointerCancel: _finishStroke,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          _EagerPanGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<_EagerPanGestureRecognizer>(
            () => _EagerPanGestureRecognizer(debugOwner: widget),
            (recognizer) {
              recognizer
                ..onStart = (details) {
                  widget.onPointDown(
                      details.localPosition, details.sourceTimeStamp);
                }
                ..onUpdate = (details) {
                  widget.onPointMove(
                      details.localPosition, details.sourceTimeStamp);
                };
            },
          ),
        },
        child: widget.child,
      ),
    );
  }
}
