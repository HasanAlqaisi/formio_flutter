/// Headless Form.io logic engine.
///
/// Runs Form.io's own `@formio/core` processors (calculate, logic, conditions,
/// clearHidden, validate) inside a persistent QuickJS/JavaScriptCore runtime via
/// `flutter_js`. This gives full Form.io logic fidelity — including custom
/// JavaScript calculations, conditionals, and validations with the real eval
/// context (`data`, `row`, `moment`, lodash, `utils`, …) — without a WebView.
///
/// The JS engine is bundled as a package asset
/// (`assets/formio/fms-formio-core.bundle.js`) and loaded once via [init].
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

  factory FormLogicError.fromJson(Map<String, dynamic> j) => FormLogicError(
        path: (j['path'] ?? '') as String,
        key: j['key'] as String?,
        rule: j['rule'] as String?,
        messageKey: j['messageKey'] as String?,
        level: j['level'] as String?,
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

/// Persistent wrapper around the `@formio/core` bundle running in `flutter_js`.
///
/// Create once, call [init] at startup, then [process] on every change/submit.
class FormLogicEngine {
  FormLogicEngine();

  static const _assetPath =
      'packages/formio/assets/formio/fms-formio-core.bundle.js';

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

  /// Runs the Form.io evaluator pipeline against [form] + [submissionData].
  ///
  /// Returns calculated [FormLogicResult.data], the conditional/hidden map, and
  /// validation errors. Synchronous (flutter_js runs on the platform thread via
  /// FFI) — debounce calls from the UI.
  FormLogicResult process({
    required Map<String, dynamic> form,
    required Map<String, dynamic> submissionData,
  }) {
    final runtime = _runtime;
    if (runtime == null) {
      throw FormLogicEngineException('Engine not initialized — call init() first.');
    }

    // Pass the payload as a JS string literal (jsonEncode escapes it safely,
    // incl. unicode/RTL content), then let fmsProcess JSON.parse it.
    final payload = jsonEncode({
      'form': form,
      'submission': {'data': submissionData},
    });
    runtime.evaluate('globalThis.__fmsIn = ${jsonEncode(payload)};');
    final res = runtime.evaluate('fmsProcess(globalThis.__fmsIn)');
    if (res.isError) {
      throw FormLogicEngineException(res.stringResult);
    }

    final decoded = jsonDecode(res.stringResult) as Map<String, dynamic>;
    if (decoded['error'] != null) {
      throw FormLogicEngineException(decoded['error'].toString());
    }
    return FormLogicResult.fromJson(decoded);
  }

  void dispose() {
    _runtime?.dispose();
    _runtime = null;
  }
}
