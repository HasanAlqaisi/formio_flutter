/// A Flutter widget that renders a signature input field based on
/// a Form.io "signature" component.
///
/// Allows the user to draw a signature on a canvas. The signature
/// is captured as a base64-encoded PNG image string.
library;

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:formio/formio.dart';

import 'css_color.dart';
import 'drawing_canvas_gesture.dart';

class SignatureComponent extends StatefulWidget {
  /// The Form.io component definition.
  final ComponentModel component;

  /// The current signature value as a base64-encoded PNG.
  final String? value;

  /// Callback triggered when the signature is drawn.
  final ValueChanged<String?> onChanged;

  /// Localization strings

  const SignatureComponent({
    super.key,
    required this.component,
    required this.value,
    required this.onChanged,
  });

  @override
  State<SignatureComponent> createState() => _SignatureComponentState();
}

/// Draws [points] as connected strokes. Shared by the on-screen painter and the
/// export, so the two can never diverge in shape.
void _paintStrokes(Canvas canvas, List<Offset?> points, Color color) {
  final paint = Paint()
    ..color = color
    ..strokeWidth = 3.0
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  for (var i = 0; i < points.length - 1; i++) {
    final a = points[i];
    final b = points[i + 1];
    if (a != null && b != null) canvas.drawLine(a, b, paint);
  }
}

class _SignatureComponentState extends State<SignatureComponent> {
  final _points = <Offset?>[];
  final _globalKey = GlobalKey();

  /// Resolution multiplier for the exported PNG.
  static const _exportScale = 3.0;

  bool get _isRequired => widget.component.required;

  /// Form.io's `penColor`/`backgroundColor`, when the schema sets them.
  Color? get _schemaPenColor => parseCssColor(widget.component.raw['penColor']);
  Color? get _schemaBackgroundColor =>
      parseCssColor(widget.component.raw['backgroundColor']);

  void _clear() {
    setState(() {
      _points.clear();
    });
    widget.onChanged(null);
  }

  /// Renders the signature to an opaque PNG, painting the strokes afresh rather
  /// than screenshotting the on-screen canvas.
  ///
  /// Capturing the widget baked in whatever colours the *app theme* happened to
  /// use, onto a transparent background — so a signature drawn in dark mode
  /// exported as a near-white stroke on nothing, invisible everywhere it is
  /// later shown on white (PDF, admin review, print). The stored artifact must
  /// not depend on the theme that was active while signing.
  Future<void> _saveSignature() async {
    if (_points.isEmpty) return;
    try {
      final box = _globalKey.currentContext?.findRenderObject() as RenderBox?;
      final size = box?.size;
      if (size == null || size.isEmpty) return;

      // Schema colours win when present; otherwise normalise to dark-on-white
      // so the result is legible regardless of the app's brightness.
      final penColor = _schemaPenColor ?? Colors.black;
      final backgroundColor = _schemaBackgroundColor ?? Colors.white;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(_exportScale);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = backgroundColor,
      );
      _paintStrokes(canvas, _points, penColor);

      final image = await recorder.endRecording().toImage(
            (size.width * _exportScale).ceil(),
            (size.height * _exportScale).ceil(),
          );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();
      if (pngBytes != null) {
        widget.onChanged('data:image/png;base64,${base64Encode(pngBytes)}');
      }
    } catch (e) {
      debugPrint('Error saving signature: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _isRequired && (widget.value == null || _points.isEmpty);
    final theme = FormioThemeScope.of(context);
    // When the schema states its colours, show exactly what will be exported;
    // otherwise keep the pad theme-native and let the export normalise.
    final inkColor =
        _schemaPenColor ?? Theme.of(context).colorScheme.onSurfaceVariant;
    final canvasDecoration =
        theme.resolvedContainerDecoration(context).copyWith(
              color: _schemaBackgroundColor ??
                  theme.inputFillColor ??
                  Theme.of(context).colorScheme.surfaceContainerHighest,
            );
    final canvasRadius = (canvasDecoration.borderRadius as BorderRadius?) ??
        BorderRadius.circular(8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.component.label,
            style: FormioThemeScope.of(context).resolvedLabelStyle(context)),
        const SizedBox(height: 8),
        Container(
          height: 200,
          width: double.infinity,
          decoration: canvasDecoration,
          child: ClipRRect(
            borderRadius: canvasRadius,
            child: RepaintBoundary(
              key: _globalKey,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return DrawingCanvasGestureDetector(
                    onPointDown: (offset) {
                      setState(() {
                        _points.add(offset);
                      });
                    },
                    onPointMove: (offset) {
                      setState(() {
                        _points.add(offset);
                      });
                    },
                    onStrokeEnd: () {
                      setState(() {
                        _points.add(null); // Add null to separate strokes
                      });
                      _saveSignature();
                    },
                    child: Container(
                      color: Colors.transparent,
                      child: CustomPaint(
                        painter: _SignaturePainter(_points, inkColor),
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              style: FormioThemeScope.of(context)
                  .resolvedSecondaryActionStyle(context),
              onPressed: _points.isEmpty ? null : _clear,
              icon: const Icon(Icons.clear),
              label: Text(ComponentFactory.locale.clear),
            ),
          ],
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              ComponentFactory.locale
                  .getRequiredMessage(widget.component.label),
              style: FormioThemeScope.of(context).resolvedErrorStyle(context),
            ),
          ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;

  final Color color;
  _SignaturePainter(this.points, this.color);

  @override
  void paint(Canvas canvas, Size size) => _paintStrokes(canvas, points, color);

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) => true;
}
