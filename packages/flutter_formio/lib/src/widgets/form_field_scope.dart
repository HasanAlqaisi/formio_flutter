/// The seam between [EngineFormRenderer] (which owns form state + the logic
/// engine) and the stateless component builders. Builders read/write values and
/// render children through this scope instead of touching renderer internals.
library;

import 'package:flutter/widgets.dart';

import '../core/form_logic_engine.dart';
import 'control_builders.dart';
import 'form_theme.dart';

class FieldScope {
  const FieldScope({
    required this.context,
    required this.theme,
    required this.data,
    required this.getValue,
    required this.setValue,
    required this.errorFor,
    required this.controllerFor,
    required this.focusFor,
    required this.renderChild,
    this.controls = const FormioControlBuilders(),
  });

  final BuildContext context;

  /// Design tokens for the built-in widgets (labels, inputs, errors, panels).
  final FormioTheme theme;

  /// The full current (post-engine) submission data, for widgets that need the
  /// whole context — e.g. `{{data.x}}` interpolation in content/html elements.
  final Map<String, dynamic> data;

  /// Read the nested value at [path].
  final dynamic Function(String path) getValue;

  /// Write [value] at [path] (marks touched + recomputes). Pass
  /// `immediate: true` for discrete taps (select/checkbox/radio/date/add-row)
  /// so the change shows at once; leave false for rapid text input (debounced).
  final void Function(String path, dynamic value, {bool immediate}) setValue;

  /// The validation error to display for [path], or null (gated by touched/submit).
  final FormLogicError? Function(String path) errorFor;

  /// A persistent text controller for [path].
  final TextEditingController Function(String path) controllerFor;

  /// A persistent focus node for [path] (recomputes on blur).
  final FocusNode Function(String path) focusFor;

  /// Render a child component under [parentPath] (recursion for containers).
  final Widget Function(Map<String, dynamic> raw, String parentPath) renderChild;

  /// Host-supplied widgets for built-in controls. The package still resolves the
  /// schema and owns the behaviour; these only change what is rendered.
  final FormioControlBuilders controls;
}
