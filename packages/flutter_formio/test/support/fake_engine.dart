/// A [FormEngine] for widget tests.
///
/// Twenty test files each carried their own copy of this — mostly a bare
/// passthrough, twice with hidden/error injection — so a change to the
/// `FormEngine` interface meant twenty edits.
///
/// The real engine runs `@formio/core` in `flutter_js`, which a widget test
/// cannot start. Tests that need genuine engine behaviour belong in
/// `tools/formio-core/test`, against the shipped bundle.
library;

import 'package:formio/formio.dart';

class FakeEngine implements FormEngine {
  FakeEngine({
    this.hidden = const {},
    this.errors = const [],
    this.errorsFor,
  });

  /// Returned as `FormLogicResult.hidden`.
  final Map<String, dynamic> hidden;

  /// Returned as `FormLogicResult.errors`, but only when `validate` is true —
  /// the renderer calls with `validate: false` for live recomputes.
  final List<FormLogicError> errors;

  /// Errors computed from the submission, for rules that depend on the current
  /// values. Takes precedence over [errors] when given.
  final List<FormLogicError> Function(Map<String, dynamic> data)? errorsFor;

  /// The last form handed to [setForm], for asserting it was re-cached.
  Map<String, dynamic>? lastForm;

  /// How many times [processData] ran, for asserting debounce behaviour.
  int processCount = 0;

  @override
  void setForm(Map<String, dynamic> form) => lastForm = form;

  @override
  FormLogicResult processData(
    Map<String, dynamic> submissionData, {
    bool validate = true,
  }) {
    processCount++;
    return FormLogicResult(
      data: submissionData,
      hidden: hidden,
      errors: validate ? (errorsFor?.call(submissionData) ?? errors) : const [],
    );
  }
}

/// Wraps [components] in the minimal form envelope the renderer expects.
Map<String, dynamic> formOf(List<Map<String, dynamic>> components) => {
      'display': 'form',
      'components': components,
    };

/// A data-bound component with the flags the renderer needs to bind a path.
Map<String, dynamic> field(
  String type,
  String key, {
  String? label,
  Map<String, dynamic> extra = const {},
}) =>
    {
      'type': type,
      'key': key,
      'label': label ?? key,
      'input': true,
      ...extra,
    };
