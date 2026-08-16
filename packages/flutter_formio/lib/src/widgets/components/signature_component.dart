/// A Flutter widget that renders a signature input field based on
/// a Form.io "signature" component.
///
/// Allows the user to draw a signature on a canvas. The signature
/// is captured as a base64-encoded PNG image string.
library;

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:formio/formio.dart';

import 'css_color.dart';
import 'drawing_canvas_gesture.dart';
import 'signature_ink.dart';

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

class _SignatureComponentState extends State<SignatureComponent> {
  final _points = <StrokePoint?>[];
  final _padKey = GlobalKey();

  /// The pen for the stroke in progress; replaced at the start of each stroke
  /// so none of them inherits the last one's speed.
  SignaturePen _pen = SignaturePen();

  /// The signature PNG currently shown on the pad. External values decode into
  /// it, and locally drawn strokes switch to the same image path after export.
  /// Live points remain in memory so another stroke can resume without losing
  /// the earlier ones.
  Uint8List? _displayImage;

  /// The most recent value emitted by this widget. Its host echo is a no-op so
  /// the retained point model remains available for another local stroke.
  String? _locallySavedValue;

  /// Invalidates an export when the pad changes before PNG encoding finishes.
  int _inkRevision = 0;

  /// Resolution multiplier for the exported PNG.
  static const _exportScale = 3.0;

  /// A pen carrying the schema's nib bounds and web sampling settings.
  SignaturePen get _schemaPen => SignaturePen(
        minWidth: _parseCssLength(widget.component.raw['minWidth']) ??
            SignaturePen.defaultMinWidth,
        maxWidth: _parseCssLength(widget.component.raw['maxWidth']) ??
            SignaturePen.defaultMaxWidth,
        minDistance: _parseCssLength(widget.component.raw['minDistance']) ??
            SignaturePen.defaultMinDistance,
        throttle: Duration(
          milliseconds: (_parseCssLength(widget.component.raw['throttle']) ??
                  SignaturePen.defaultThrottle.inMilliseconds)
              .round(),
        ),
      );

  bool get _isRequired => widget.component.required;

  /// The pad shows nothing: no strokes and no displayed image. Drives both the
  /// required error and whether Clear does anything. Deliberately reads local
  /// state rather than [widget.value] — after [_clear] the pad is empty at once,
  /// without waiting for the host to echo the null value back.
  bool get _isEmpty => _points.isEmpty && _displayImage == null;

  @override
  void initState() {
    super.initState();
    _displayImage = _decodeSignature(widget.value);
  }

  @override
  void didUpdateWidget(covariant SignatureComponent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == oldWidget.value) return;

    // The host normally echoes `_saveSignature` back during its next rebuild.
    // Keep the live points in that one case; every other value change is an
    // external prefill/calculation/reset and must replace the local state.
    if (_locallySavedValue != null && widget.value == _locallySavedValue) {
      _locallySavedValue = null;
      return;
    }

    _inkRevision++;
    _points.clear();
    _displayImage = _decodeSignature(widget.value);
  }

  /// Decodes a Form.io signature value — a `data:image/png;base64,...` URL, or
  /// bare base64 — returning null for anything unreadable.
  static Uint8List? _decodeSignature(String? value) {
    if (value == null || value.isEmpty) return null;
    final comma = value.indexOf(',');
    final payload = value.startsWith('data:') && comma != -1
        ? value.substring(comma + 1)
        : value;
    try {
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }

  /// Pad height from the schema's `height` (Form.io emits `"150px"`), so the
  /// pad — and therefore the aspect ratio of the PNG we export — matches the
  /// web renderer's canvas. Falls back to the historical 200 when the schema
  /// says nothing.
  double get _padHeight =>
      (_parseCssLength(widget.component.raw['height']) ?? 200)
          .clamp(40.0, 1000.0);

  /// Pad width from the schema's `width`. Form.io's default is `"100%"`, which
  /// parses to null and leaves the pad filling its parent, same as on web.
  double? get _padWidth => _parseCssLength(widget.component.raw['width']);

  /// Parses Form.io's CSS-ish lengths — `"150px"`, `"150"`, `150`. Percentages
  /// and anything unreadable return null, which callers read as "fill".
  static double? _parseCssLength(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw is! String) return null;
    final text = raw.trim();
    if (text.isEmpty || text.endsWith('%')) return null;
    return double.tryParse(text.replaceAll(RegExp(r'[a-zA-Z]+$'), ''));
  }

  /// The caption under the pad.
  String get _footer {
    final raw = widget.component.raw['footer'];
    return raw is String ? raw.trim() : '';
  }

  /// Form.io's `penColor`/`backgroundColor`, when the schema sets them.
  Color? get _schemaPenColor => parseCssColor(widget.component.raw['penColor']);
  Color? get _schemaBackgroundColor =>
      parseCssColor(widget.component.raw['backgroundColor']);

  void _clear() {
    setState(() {
      _inkRevision++;
      _points.clear();
      _displayImage = null;
      _locallySavedValue = null;
    });
    widget.onChanged(null);
  }

  /// Adds an accepted web-style sample. The first accepted sample switches the
  /// pad back to live painting; retained points restore every earlier local
  /// stroke while the user continues signing.
  void _addPoint(Offset offset, Duration? timeStamp) {
    final point = _pen.sampleAt(offset, timeStamp);
    if (point == null) return;
    setState(() {
      _inkRevision++;
      _displayImage = null;
      _points.add(point);
    });
  }

  /// Begins a stroke with a fresh schema-configured pen and records its first
  /// point.
  void _startStroke(Offset offset, Duration? timeStamp) {
    _pen = _schemaPen..beginStroke();
    _addPoint(offset, timeStamp);
  }

  /// Records the unthrottled pointer-up sample, separates this stroke from the
  /// next one, then persists the finished ink.
  void _endStroke(Offset offset, Duration? timeStamp) {
    final finalPoint = _pen.endAt(offset, timeStamp);
    setState(() {
      if (finalPoint != null) {
        _inkRevision++;
        _points.add(finalPoint);
      }
      _points.add(null);
    });
    _saveSignature();
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
    final revision = _inkRevision;
    try {
      final box = _padKey.currentContext?.findRenderObject() as RenderBox?;
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
      paintStrokes(canvas, _points, penColor);

      final image = await recorder.endRecording().toImage(
            (size.width * _exportScale).ceil(),
            (size.height * _exportScale).ceil(),
          );
      try {
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final pngBytes = byteData?.buffer.asUint8List();
        if (pngBytes != null && mounted && revision == _inkRevision) {
          final value = 'data:image/png;base64,${base64Encode(pngBytes)}';
          _locallySavedValue = value;
          setState(() => _displayImage = pngBytes);
          widget.onChanged(value);
        }
      } finally {
        image.dispose();
      }
    } catch (e) {
      debugPrint('Error saving signature: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FormioThemeScope.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.component.label, style: theme.resolvedLabelStyle(context)),
        const SizedBox(height: 8),
        _buildPad(context, theme),
        // Form.io's `footer` sits centred under the
        // pad on web; the schema can blank it out to hide it.
        if (_footer.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: SizedBox(
              width: _padWidth ?? double.infinity,
              child: Text(
                _footer,
                textAlign: TextAlign.center,
                style: theme.resolvedDescriptionStyle(context),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              style: theme.resolvedSecondaryActionStyle(context),
              onPressed: _isEmpty ? null : _clear,
              icon: const Icon(Icons.clear),
              label: Text(ComponentFactory.locale.clear),
            ),
          ],
        ),
        if (_isRequired && _isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              ComponentFactory.locale
                  .getRequiredMessage(widget.component.label),
              style: theme.resolvedErrorStyle(context),
            ),
          ),
      ],
    );
  }

  /// The drawing surface. Saved and externally loaded signatures use the same
  /// stretched image path as Form.io web. Retained local strokes stay painted
  /// underneath it so the pad never blanks while the PNG decodes its first
  /// frame.
  Widget _buildPad(BuildContext context, FormioTheme theme) {
    // When the schema states its colours, show exactly what will be exported;
    // otherwise keep the pad theme-native and let the export normalise.
    final inkColor =
        _schemaPenColor ?? Theme.of(context).colorScheme.onSurfaceVariant;
    final decoration = theme.resolvedContainerDecoration(context).copyWith(
          color: _schemaBackgroundColor ??
              theme.inputFillColor ??
              Theme.of(context).colorScheme.surfaceContainerHighest,
        );

    return Container(
      height: _padHeight,
      width: _padWidth ?? double.infinity,
      decoration: decoration,
      child: ClipRRect(
        borderRadius: (decoration.borderRadius as BorderRadius?) ??
            BorderRadius.circular(8),
        child: RepaintBoundary(
          key: _padKey,
          child: DrawingCanvasGestureDetector(
            onPointDown: _startStroke,
            onPointMove: _addPoint,
            onStrokeEnd: _endStroke,
            // StackFit.expand hands both children the pad's full size, so the
            // painter needs no explicit `size`.
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _SignaturePainter(_points, inkColor, _inkRevision),
                ),
                if (_displayImage != null)
                  Image.memory(
                    _displayImage!,
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<StrokePoint?> points;
  final Color color;

  /// Snapshot used for invalidation because [points] is intentionally mutated
  /// in place by the owning state.
  final int revision;

  _SignaturePainter(this.points, this.color, this.revision);

  @override
  void paint(Canvas canvas, Size size) => paintStrokes(canvas, points, color);

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) =>
      revision != oldDelegate.revision || color != oldDelegate.color;
}
