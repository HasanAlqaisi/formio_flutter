/// Test ids for form controls, as `Semantics.identifier`.
///
/// Maestro matches `id:` as a **regular expression**, so an id has to be free of
/// metacharacters: `formio_grid[0]_remove` would be read as a character class
/// and match `formio_grid0_remove` instead of itself. Every id built here is
/// `[A-Za-z0-9_]` only, which means itself under regex.
library;

import 'package:flutter/widgets.dart';

/// Test id for a data path: `formio_<path>`.
///
/// Each row index `[i]` becomes `_row<i>`, and everything outside
/// `[A-Za-z0-9_]` — path dots included — becomes `_`. So `grid[0].choice`
/// gives `formio_grid_row0_choice`, unique per row where the component key
/// alone would repeat.
String formioSemanticsId(String path) => 'formio_'
    '${formioIdSegment(path.replaceAllMapped(RegExp(r'\[(\d+)\]'), (m) => '_row${m[1]}'))}';

/// One variable part of an id — an option value, a survey row key — flattened
/// to `[A-Za-z0-9_]`.
///
/// Option values are form-authored and routinely hold spaces, `+`, `(`, `.`:
/// `_option_a+b` would match `ab` under regex, never itself.
String formioIdSegment(Object? value) =>
    '$value'.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');

/// The test-id prefix for the component below, for components rendered through
/// `ComponentFactory`.
///
/// Those receive a `ComponentModel` and no data path, so left to themselves they
/// build ids from the schema key — the same key in every repeat of a datagrid
/// row, editgrid row, container or wizard entry. The engine renderer wraps each
/// one in this scope so the ids carry the path instead.
///
/// A host-registered custom component gets the prefix too, via
/// [FormioSemanticsScope.of], without having to know how paths are spelled.
class FormioSemanticsScope extends InheritedWidget {
  const FormioSemanticsScope({
    super.key,
    required this.prefix,
    required super.child,
  });

  /// `formio_<path>` for the component below.
  final String prefix;

  /// The prefix for the component at [context].
  ///
  /// Falls back to `formio_<key>` for a component built outside the engine
  /// renderer, where there is no path to scope it by.
  static String of(BuildContext context, Object? key) =>
      context
          .dependOnInheritedWidgetOfExactType<FormioSemanticsScope>()
          ?.prefix ??
      formioSemanticsId('$key');

  @override
  bool updateShouldNotify(FormioSemanticsScope oldWidget) =>
      oldWidget.prefix != prefix;
}
