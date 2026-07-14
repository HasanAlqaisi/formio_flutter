/// Public extension point for rendering custom (or overridden) Form.io
/// components with [EngineFormRenderer].
///
/// A host app registers builders on the renderer via its `customComponents`
/// map. Each builder receives a [FormioFieldContext] — a small, stable surface
/// over the renderer's internal state — and returns a widget. The context lets
/// the builder read/write its own value, read any other path, show its
/// validation error, obtain a persistent controller/focus node, render child
/// components, delegate to a built-in builder, or wrap itself in the standard
/// label/description/error chrome.
///
/// This is the seam that keeps domain-specific widgets (file uploads, maps,
/// signature pads, …) OUT of the package: the package renders standard Form.io
/// components; anything bespoke is provided by the host at this boundary.
///
/// Example — provide a brand-new type:
/// ```dart
/// EngineFormRenderer(
///   form: form,
///   engine: engine,
///   customComponents: {
///     'fmsfile': (ctx) => MyFileField(ctx),      // new type
///     'sites':   (ctx) => ctx.builtin('select'), // reuse a built-in
///     'select':  (ctx) => MyBrandedSelect(ctx),  // override a built-in
///   },
/// );
/// ```
library;

import 'package:flutter/widgets.dart';

import '../core/form_logic_engine.dart';

/// A builder for a custom or overridden component type.
typedef FormioFieldBuilder = Widget Function(FormioFieldContext ctx);

/// The per-field context handed to a [FormioFieldBuilder].
///
/// Instances are created by [EngineFormRenderer] for the component being built;
/// host code never constructs one directly. All reads/writes go through the
/// live engine loop, so calling [setValue] triggers a recompute exactly as a
/// built-in field would.
class FormioFieldContext {
  FormioFieldContext({
    required this.context,
    required this.component,
    required this.path,
    required dynamic Function(String path) read,
    required void Function(String path, dynamic value, {bool immediate}) write,
    required FormLogicError? Function(String path) errorFor,
    required TextEditingController Function(String path) controllerFor,
    required FocusNode Function(String path) focusFor,
    required Widget Function(Map<String, dynamic> raw) renderChild,
    required Widget Function(String type) builtin,
    required Widget Function(Widget control, {bool showLabel}) chrome,
  })  : _read = read,
        _write = write,
        _errorFor = errorFor,
        _controllerFor = controllerFor,
        _focusFor = focusFor,
        _renderChild = renderChild,
        _builtin = builtin,
        _chrome = chrome;

  /// The build context of the renderer.
  final BuildContext context;

  /// The raw Form.io JSON for this component (all its properties).
  final Map<String, dynamic> component;

  /// The nested data path of this field, e.g. `incident.attachmentsIds` or
  /// `grid[0].amount`. Use it with [read] to address other fields relative to
  /// nowhere in particular — paths are absolute within the submission.
  final String path;

  final dynamic Function(String path) _read;
  final void Function(String path, dynamic value, {bool immediate}) _write;
  final FormLogicError? Function(String path) _errorFor;
  final TextEditingController Function(String path) _controllerFor;
  final FocusNode Function(String path) _focusFor;
  final Widget Function(Map<String, dynamic> raw) _renderChild;
  final Widget Function(String type) _builtin;
  final Widget Function(Widget control, {bool showLabel}) _chrome;

  /// This field's current value in the (post-engine) submission data.
  dynamic get value => _read(path);

  /// Write this field's value. Marks the field touched and recomputes. Pass
  /// `immediate: true` for discrete controls (a tap/selection) so the value
  /// shows at once; leave false (default) for rapid text input, which debounces.
  void setValue(dynamic value, {bool immediate = false}) =>
      _write(path, value, immediate: immediate);

  /// Read the value at any other absolute [otherPath] in the submission
  /// (list indices supported, e.g. `grid[0].amount`).
  dynamic read(String otherPath) => _read(otherPath);

  /// The validation error to display for this field, or null. Already gated by
  /// the renderer's touched/submitted policy, so you can render it directly.
  FormLogicError? get error => _errorFor(path);

  /// A persistent [TextEditingController] keyed by this field's path. Survives
  /// rebuilds; disposed by the renderer.
  TextEditingController controller() => _controllerFor(path);

  /// A persistent [FocusNode] keyed by this field's path. The renderer
  /// recomputes on blur.
  FocusNode focusNode() => _focusFor(path);

  /// Render a sub-component (from [component]'s `components`) under this
  /// field's path. Use for composite custom components.
  Widget child(Map<String, dynamic> raw) => _renderChild(raw);

  /// Render this component as if it were the given built-in [type] (e.g.
  /// `'select'`), returning the package's default widget for it — including its
  /// standard chrome. Handy for aliasing a domain type to a built-in.
  Widget builtin(String type) => _builtin(type);

  /// Wrap [control] in the standard field chrome (label, description, and inline
  /// error) that built-in fields use. Opt-in: custom builders own their layout
  /// by default and call this only if they want the stock look.
  Widget chrome(Widget control, {bool showLabel = true}) =>
      _chrome(control, showLabel: showLabel);
}
