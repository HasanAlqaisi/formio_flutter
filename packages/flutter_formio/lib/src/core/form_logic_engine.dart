/// Headless Form.io logic engine.
///
/// Runs Form.io's own `@formio/core` processors (calculate, logic, conditions,
/// clearHidden, validate) inside a persistent QuickJS/JavaScriptCore runtime via
/// `flutter_js`. This gives full Form.io logic fidelity — including custom
/// JavaScript calculations, conditionals, and validations with the real eval
/// context (`data`, `row`, `moment`, lodash, `utils`, …) — without a WebView.
///
/// The JS engine is bundled as a package asset
/// (`assets/formio/formio-core.bundle.js`) and loaded once via [init].
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_js/flutter_js.dart';

/// A single validation error returned by the engine.
///
/// [message] is not localized here — [rule]/[messageKey] identify the failed
/// rule so the renderer can map it to a localized string.
class FormLogicError {
  const FormLogicError({
    required this.path,
    this.key,
    this.rule,
    this.messageKey,
    this.level,
    this.setting,
  });

  /// Full data path of the failing component (e.g. `creatioContainer1.categoryId`).
  final String path;

  /// The component `key`.
  final String? key;

  /// The failed rule name (e.g. `required`, `custom`, `pattern`).
  final String? rule;

  /// Error key or custom message returned by the rule.
  final String? messageKey;

  /// `error` | `warning` | etc.
  final String? level;

  /// The rule's limit/parameter (e.g. `maxLength` → "5", `min` → "10",
  /// `pattern` → the regex), used to build a specific message. May be null.
  final String? setting;

  factory FormLogicError.fromJson(Map<String, dynamic> j) => FormLogicError(
        path: (j['path'] ?? '') as String,
        key: j['key'] as String?,
        rule: j['rule'] as String?,
        messageKey: j['messageKey'] as String?,
        level: j['level'] as String?,
        setting: j['setting'] as String?,
      );

  @override
  String toString() => 'FormLogicError($path, rule: $rule, msg: $messageKey)';
}

/// Result of running the Form.io processors against a form + submission.
class FormLogicResult {
  const FormLogicResult({
    required this.data,
    required this.hidden,
    required this.errors,
  });

  /// Submission data after calculations / logic value-actions / clearHidden.
  final Map<String, dynamic> data;

  /// Data paths that are conditionally hidden (`{path: true}`).
  final Map<String, dynamic> hidden;

  /// Validation errors (empty = valid).
  final List<FormLogicError> errors;

  bool get isValid => errors.isEmpty;

  /// Whether the component at [path] is conditionally hidden.
  bool isHidden(String path) => hidden[path] == true;

  factory FormLogicResult.fromJson(Map<String, dynamic> j) => FormLogicResult(
        data: (j['data'] as Map?)?.cast<String, dynamic>() ?? const {},
        hidden: (j['hidden'] as Map?)?.cast<String, dynamic>() ?? const {},
        errors: ((j['errors'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => FormLogicError.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
}

/// Thrown when the JS engine itself fails (load or execution error).
class FormLogicEngineException implements Exception {
  FormLogicEngineException(this.message);
  final String message;
  @override
  String toString() => 'FormLogicEngineException: $message';
}

/// The minimal engine surface [EngineFormRenderer] depends on.
///
/// Implement this to back the renderer with an alternative engine (e.g. an
/// isolate-hosted one) or a fake in tests. [FormLogicEngine] is the default
/// `flutter_js` implementation.
abstract interface class FormEngine {
  /// Prepare/cache [form] before processing (see [FormLogicEngine.setForm]).
  void setForm(Map<String, dynamic> form);

  /// Run the pipeline against [submissionData]; returns data/hidden/errors.
  /// [validate] defaults to true (live validation).
  FormLogicResult processData(
    Map<String, dynamic> submissionData, {
    bool validate,
  });
}

/// Persistent wrapper around the `@formio/core` bundle running in `flutter_js`.
///
/// Create once, call [init] at startup, [setForm] when the form loads/changes,
/// then [processData] on every change/submit (only the small submission crosses
/// the FFI boundary). [process] remains as a one-shot form+data convenience.
class FormLogicEngine implements FormEngine {
  FormLogicEngine();

  static const _assetPath =
      'packages/formio/assets/formio/formio-core.bundle.js';

  JavascriptRuntime? _runtime;

  bool get isReady => _runtime != null;

  /// Loads the runtime and evaluates the engine bundle once.
  Future<void> init() async {
    if (_runtime != null) return;
    final runtime = getJavascriptRuntime();
    final source = await rootBundle.loadString(_assetPath);
    final loaded = runtime.evaluate(source);
    if (loaded.isError) {
      runtime.dispose();
      throw FormLogicEngineException('Failed to load engine: ${loaded.stringResult}');
    }
    _runtime = runtime;
  }

  JavascriptRuntime _requireRuntime() {
    final runtime = _runtime;
    if (runtime == null) {
      throw FormLogicEngineException(
          'Engine not initialized — call init() first.');
    }
    return runtime;
  }

  /// Evaluates [expr] (which must return a JSON string), decodes it, and throws
  /// if the runtime or the engine reported an error.
  Map<String, dynamic> _evalJson(JavascriptRuntime runtime, String expr) {
    final res = runtime.evaluate(expr);
    if (res.isError) throw FormLogicEngineException(res.stringResult);
    final decoded = jsonDecode(res.stringResult) as Map<String, dynamic>;
    if (decoded['error'] != null) {
      throw FormLogicEngineException(decoded['error'].toString());
    }
    return decoded;
  }

  /// Caches [form] inside the JS runtime (parsed and DOM-stripped once) so
  /// subsequent [processData] calls only marshal the small submission across the
  /// FFI boundary. Call whenever the form definition changes.
  ///
  /// This is the key perf lever: without it, every recompute re-serialized and
  /// re-parsed the entire (often ~1MB) form in QuickJS.
  void setForm(Map<String, dynamic> form) {
    final runtime = _requireRuntime();
    // Double-encode: inner jsonEncode → JSON text; outer → a JS string literal.
    runtime.evaluate('globalThis.__fioForm = ${jsonEncode(jsonEncode(form))};');
    _evalJson(runtime, 'fioSetForm(globalThis.__fioForm)');
  }

  /// Runs the pipeline against the form cached by [setForm], sending only
  /// [submissionData]. [validate] defaults to true (live validation); pass false
  /// only for a fast "draft" pass that skips the validate processor.
  ///
  /// Synchronous (flutter_js runs on the platform thread via FFI) — debounce
  /// calls from the UI.
  FormLogicResult processData(
    Map<String, dynamic> submissionData, {
    bool validate = true,
  }) {
    final runtime = _requireRuntime();
    runtime.evaluate(
        'globalThis.__fioData = ${jsonEncode(jsonEncode(submissionData))};');
    return FormLogicResult.fromJson(
        _evalJson(runtime, 'fioProcessData(globalThis.__fioData, $validate)'));
  }

  /// One-shot: runs the pipeline against [form] + [submissionData], re-parsing
  /// the form each call. Prefer [setForm] + [processData]; kept for callers that
  /// don't hold a stable form or want a single call.
  FormLogicResult process({
    required Map<String, dynamic> form,
    required Map<String, dynamic> submissionData,
  }) {
    final runtime = _requireRuntime();
    final payload = jsonEncode({
      'form': form,
      'submission': {'data': submissionData},
    });
    runtime.evaluate('globalThis.__fioIn = ${jsonEncode(payload)};');
    return FormLogicResult.fromJson(
        _evalJson(runtime, 'fioProcess(globalThis.__fioIn)'));
  }

  void dispose() {
    _runtime?.dispose();
    _runtime = null;
  }
}
