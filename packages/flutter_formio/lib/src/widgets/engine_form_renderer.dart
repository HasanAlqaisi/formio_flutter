/// Engine-driven, path-aware Form.io renderer.
///
/// Maintains a **nested** submission and delegates ALL logic (calculations,
/// conditionals, Logic-tab actions, validation — incl. custom JavaScript) to
/// [FormLogicEngine] (Form.io's own `@formio/core` running in flutter_js).
///
/// This widget owns state + the engine loop and dispatches by component type;
/// the actual widgets are built by the stateless functions in
/// `component_builders.dart` via a [FieldScope]. Layout/array recursion goes
/// back through `_render`.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/form_logic_engine.dart';
import 'component_builders.dart' as cb;
import 'form_field_context.dart';
import 'form_field_scope.dart';

export 'form_field_context.dart' show FormioFieldContext, FormioFieldBuilder;

typedef EngineFormSubmit = void Function(Map<String, dynamic> data);

class EngineFormRenderer extends StatefulWidget {
  const EngineFormRenderer({
    super.key,
    required this.form,
    required this.engine,
    this.initialData,
    this.onSubmit,
    this.onChanged,
    this.customComponents,
    this.debounce = const Duration(milliseconds: 450),
  });

  final Map<String, dynamic> form;
  final FormLogicEngine engine;
  final Map<String, dynamic>? initialData;
  final EngineFormSubmit? onSubmit;
  final ValueChanged<Map<String, dynamic>>? onChanged;

  /// Host-registered builders for custom component types (or overrides of
  /// built-in types), keyed by the Form.io component `type`.
  final Map<String, FormioFieldBuilder>? customComponents;

  final Duration debounce;

  @override
  State<EngineFormRenderer> createState() => _EngineFormRendererState();
}

class _EngineFormRendererState extends State<EngineFormRenderer> {
  static const _layoutTypes = {
    'columns',
    'table',
    'panel',
    'well',
    'fieldset',
    'tabs',
  };
  static const _nestingTypes = {'container', 'creatioContainer'};
  static const _arrayTypes = {'datagrid', 'editgrid'};

  Map<String, dynamic> _data = {};
  Map<String, dynamic> _hidden = {};
  final Map<String, FormLogicError> _errors = {};

  bool _submitted = false;
  final Set<String> _touched = {};

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};

  bool _ready = false;
  bool _submitting = false;
  String? _fatal;
  Timer? _debounce;
  late FieldScope _scope;

  List<dynamic> get _components =>
      (widget.form['components'] as List?) ?? const [];

  @override
  void initState() {
    super.initState();
    _data = _deepCopy(widget.initialData ?? const {});
    _recompute();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  // ---- engine loop ------------------------------------------------------

  void _applyResult(FormLogicResult result) {
    _data = result.data;
    _hidden = result.hidden;
    _errors
      ..clear()
      ..addEntries(result.errors.map((e) => MapEntry(e.path, e)));
  }

  void _recompute() {
    try {
      final result =
          widget.engine.process(form: widget.form, submissionData: _data);
      setState(() {
        _applyResult(result);
        _ready = true;
      });
      widget.onChanged?.call(_data);
    } catch (e) {
      setState(() {
        _fatal = e.toString();
        _ready = true;
      });
    }
  }

  void _scheduleRecompute() {
    _debounce?.cancel();
    _debounce = Timer(widget.debounce, _recompute);
  }

  // ---- scope wiring -----------------------------------------------------

  FieldScope _makeScope(BuildContext context) => FieldScope(
        context: context,
        data: _data,
        getValue: _getPath,
        setValue: _setPath,
        errorFor: (path) =>
            (_submitted || _touched.contains(path)) ? _errors[path] : null,
        controllerFor: (path) =>
            _controllers.putIfAbsent(path, () => TextEditingController()),
        focusFor: (path) => _focusNodes.putIfAbsent(path, () {
          final f = FocusNode();
          f.addListener(() {
            if (!f.hasFocus) _scheduleRecompute();
          });
          return f;
        }),
        renderChild: _render,
      );

  // ---- nested data access (supports list indices: a.b[0].c) -------------

  static final _pathToken = RegExp(r'([^.\[\]]+)|\[(\d+)\]');

  List<Object> _parsePath(String path) {
    final tokens = <Object>[];
    for (final m in _pathToken.allMatches(path)) {
      final key = m.group(1);
      tokens.add(key != null ? key : int.parse(m.group(2)!));
    }
    return tokens;
  }

  dynamic _getPath(String path) {
    if (path.isEmpty) return null;
    dynamic cur = _data;
    for (final t in _parsePath(path)) {
      if (t is int) {
        if (cur is List && t >= 0 && t < cur.length) {
          cur = cur[t];
        } else {
          return null;
        }
      } else if (cur is Map && cur.containsKey(t)) {
        cur = cur[t];
      } else {
        return null;
      }
    }
    return cur;
  }

  void _setPath(String path, dynamic value) {
    final tokens = _parsePath(path);
    dynamic cur = _data;
    for (var i = 0; i < tokens.length - 1; i++) {
      final t = tokens[i];
      final nextIsIndex = tokens[i + 1] is int;
      if (t is int) {
        cur = cur[t] ??= (nextIsIndex ? <dynamic>[] : <String, dynamic>{});
      } else {
        final key = t as String;
        final map = cur as Map<String, dynamic>;
        var child = map[key];
        if (nextIsIndex ? child is! List : child is! Map) {
          child = nextIsIndex ? <dynamic>[] : <String, dynamic>{};
          map[key] = child;
        }
        cur = child;
      }
    }
    final last = tokens.last;
    if (last is int) {
      (cur as List)[last] = value;
    } else {
      (cur as Map<String, dynamic>)[last as String] = value;
    }
    _touched.add(path);
    _scheduleRecompute();
  }

  // ---- dispatch ---------------------------------------------------------

  String _childPath(String parent, String key) =>
      parent.isEmpty ? key : '$parent.$key';

  Widget _renderList(List<dynamic> comps, String parentPath) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in comps)
            if (c is Map<String, dynamic>) _render(c, parentPath),
        ],
      );

  Widget _render(Map<String, dynamic> raw, String parentPath) {
    final type = raw['type'] as String?;
    final key = raw['key'] as String?;
    final isLayout = _layoutTypes.contains(type);
    final input = raw['input'] == true;
    final path = (isLayout || !input || key == null)
        ? parentPath
        : _childPath(parentPath, key);

    // Hide anything the engine marked hidden. Input components are keyed by
    // their data path; layout/structural components (panels, columns, …) are
    // keyed by their `key`. Only checking the input/path case left
    // conditionally-hidden panels on screen as dead, engine-reverted shells.
    final hiddenByPath = path.isNotEmpty && _hidden[path] == true;
    final hiddenByKey =
        !input && key != null && key.isNotEmpty && _hidden[key] == true;
    if (hiddenByPath || hiddenByKey) {
      return const SizedBox.shrink();
    }

    // A host-registered builder takes precedence over both the native builders
    // and the stock fallback
    final builders = widget.customComponents;
    final custom = (type != null && builders != null) ? builders[type] : null;
    if (custom != null) {
      return custom(_fieldContext(raw, path));
    }

    // Layout containers (structural recursion stays here).
    switch (type) {
      case 'columns':
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final col in (raw['columns'] as List?) ?? const [])
              if (col is Map<String, dynamic>)
                Expanded(
                  flex: (col['width'] as num?)?.toInt() ?? 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _renderList(
                        (col['components'] as List?) ?? const [], parentPath),
                  ),
                ),
          ],
        );
      case 'table':
        return Column(
          children: [
            for (final row in (raw['rows'] as List?) ?? const [])
              if (row is List)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final cell in row)
                      if (cell is Map<String, dynamic>)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: _renderList(
                                (cell['components'] as List?) ?? const [],
                                parentPath),
                          ),
                        ),
                  ],
                ),
          ],
        );
      case 'panel':
      case 'well':
      case 'fieldset':
        // Form.io puts the header in `title` (panels/wells) or `legend`
        // (fieldsets); `label` is the default component name ("Panel"), not a
        // header. Fall back across the three, then to a non-default label.
        final rawLabel = raw['label'] as String?;
        final header = <String?>[
          raw['title'] as String?,
          raw['legend'] as String?,
          (rawLabel == 'Panel' || rawLabel == 'Field Set') ? null : rawLabel,
        ].firstWhere((h) => h != null && h.isNotEmpty, orElse: () => null);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (header != null && raw['hideLabel'] != true)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(header,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                _renderList(
                    (raw['components'] as List?) ?? const [], parentPath),
              ],
            ),
          ),
        );
      case 'tabs':
        return _renderList(
          [
            for (final t in (raw['components'] as List?) ?? const [])
              if (t is Map<String, dynamic>) ...[
                if ((t['label'] as String?)?.isNotEmpty == true)
                  <String, dynamic>{
                    'type': 'htmlelement',
                    'input': false,
                    'content': '<b>${t['label']}</b>',
                  },
                ...((t['components'] as List?) ?? const []),
              ],
          ],
          parentPath,
        );
      case 'button':
        return const SizedBox.shrink();
    }

    if (_nestingTypes.contains(type)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in (raw['components'] as List?) ?? const [])
            if (c is Map<String, dynamic>) _render(c, path),
        ],
      );
    }

    return _renderControl(raw, path, type);
  }

  /// Renders control-level components (leaf inputs, arrays, and the stock
  /// fallback). Split out from [_render] so [FormioFieldContext.builtin] can
  /// re-enter it to render a component as a given built-in type.
  Widget _renderControl(Map<String, dynamic> raw, String path, String? type) {
    // Control components (delegated to stateless builders).
    switch (type) {
      case 'select':
        return cb.buildField(
            _scope, raw, path, cb.buildSelect(_scope, raw, path));
      case 'selectboxes':
        return cb.buildField(
            _scope, raw, path, cb.buildSelectBoxes(_scope, raw, path));
      case 'checkbox':
        return cb.buildField(
            _scope, raw, path, cb.buildCheckbox(_scope, raw, path),
            showLabel: false);
      case 'radio':
        return cb.buildField(
            _scope, raw, path, cb.buildRadio(_scope, raw, path));
      case 'date':
      case 'datetime':
      case 'time':
        return cb.buildField(
            _scope, raw, path, cb.buildDateTime(_scope, raw, path, type!));
    }

    if (cb.kTextTypes.contains(type)) {
      return cb.buildField(
          _scope, raw, path, cb.buildTextLeaf(_scope, raw, path, type!));
    }
    if (_arrayTypes.contains(type)) {
      return cb.buildDataGrid(_scope, raw, path);
    }

    // Stock / custom-registered components render their own label; show only
    // the inline error around them.
    return _wrapError(cb.buildFallback(_scope, raw, path, type), path);
  }

  /// Builds the public [FormioFieldContext] handed to a custom builder for the
  /// component [raw] at [path]. Curated surface over the internal [_scope].
  FormioFieldContext _fieldContext(Map<String, dynamic> raw, String path) =>
      FormioFieldContext(
        context: context,
        component: raw,
        path: path,
        read: _scope.getValue,
        write: _scope.setValue,
        errorFor: _scope.errorFor,
        controllerFor: _scope.controllerFor,
        focusFor: _scope.focusFor,
        renderChild: (childRaw) => _render(childRaw, path),
        builtin: (t) => _renderControl({...raw, 'type': t}, path, t),
        chrome: (control, {bool showLabel = true}) =>
            cb.buildField(_scope, raw, path, control, showLabel: showLabel),
      );

  Widget _wrapError(Widget field, String path) {
    final error =
        (_submitted || _touched.contains(path)) ? _errors[path] : null;
    if (error == null) {
      return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6), child: field);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          field,
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(cb.messageForError(error),
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ---- submit -----------------------------------------------------------

  void _submit() {
    setState(() {
      _submitting = true;
      _submitted = true;
    });
    _debounce?.cancel();
    try {
      final result =
          widget.engine.process(form: widget.form, submissionData: _data);
      setState(() {
        _applyResult(result);
        _submitting = false;
      });
      if (result.isValid) {
        widget.onSubmit?.call(_data);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${result.errors.length} validation error(s)')),
        );
      }
    } catch (e) {
      setState(() {
        _submitting = false;
        _fatal = e.toString();
      });
    }
  }

  // ---- build ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_fatal != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Engine error:\n$_fatal',
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      );
    }
    if (!_ready) {
      return const Center(child: CircularProgressIndicator());
    }
    _scope = _makeScope(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: _renderList(_components, ''),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Submit'),
            ),
          ),
        ),
      ],
    );
  }

  // ---- utils ------------------------------------------------------------

  static Map<String, dynamic> _deepCopy(Map source) =>
      source.map((k, v) => MapEntry(k.toString(), _deepCopyValue(v)));

  static dynamic _deepCopyValue(dynamic v) {
    if (v is Map) return _deepCopy(v);
    if (v is List) return v.map(_deepCopyValue).toList();
    return v;
  }
}
