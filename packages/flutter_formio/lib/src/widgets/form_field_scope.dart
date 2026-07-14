/// The seam between [EngineFormRenderer] (which owns form state + the logic
/// engine) and the stateless component builders. Builders read/write values and
/// render children through this scope instead of touching renderer internals.
library;

import 'package:flutter/widgets.dart';

import '../core/form_logic_engine.dart';

class FieldScope {
  const FieldScope({
    required this.context,
    required this.getValue,
    required this.setValue,
    required this.errorFor,
    required this.controllerFor,
    required this.focusFor,
    required this.renderChild,
  });

  final BuildContext context;

  /// Read the nested value at [path].
  final dynamic Function(String path) getValue;

  /// Write [value] at [path] (marks touched + schedules a recompute).
  final void Function(String path, dynamic value) setValue;

  /// The validation error to display for [path], or null (gated by touched/submit).
  final FormLogicError? Function(String path) errorFor;

  /// A persistent text controller for [path].
  final TextEditingController Function(String path) controllerFor;

  /// A persistent focus node for [path] (recomputes on blur).
  final FocusNode Function(String path) focusFor;

  /// Render a child component under [parentPath] (recursion for containers).
  final Widget Function(Map<String, dynamic> raw, String parentPath) renderChild;
}
