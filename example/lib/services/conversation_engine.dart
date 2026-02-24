/// ConversationEngine — core orchestrator for voice-based form filling.
///
/// Flattens Form.io components, tracks answered fields, evaluates
/// conditional logic after each answer, and determines the next question.
library;

import 'package:flutter/foundation.dart';
import 'package:formio_api/formio_api.dart';

import '../models/turkish_prompts.dart';

/// Callback when all visible questions have been answered.
typedef OnFormComplete = void Function(Map<String, dynamic> formData);

class ConversationEngine extends ChangeNotifier {
  final FormModel form;
  final OnFormComplete? onComplete;

  /// Current live form data — updated after each answer.
  final Map<String, dynamic> _formData = {};

  /// Set of component keys that have been answered.
  final Set<String> _answeredKeys = {};

  /// Ordered history of answered keys for undo support.
  final List<String> _answerHistory = [];

  /// All flattened components (excluding layout containers and buttons).
  late final List<ComponentModel> _allQuestions;

  /// Public read-only access to all askable questions.
  List<ComponentModel> get allQuestions => List.unmodifiable(_allQuestions);

  /// Layout component types that are containers, not questions.
  static const _layoutTypes = {
    'panel',
    'columns',
    'well',
    'fieldset',
    'table',
    'tabs',
    'container',
    'content',
    'htmlelement',
  };

  /// Component types that are not askable questions.
  static const _nonQuestionTypes = {
    'button',
    'hidden',
    'datasource',
    // Non-voice-compatible types
    'signature',
    'file',
    'captcha',
    'sketchpad',
    'tagpad',
    'container',
    'editgrid',
    'nestedform',
    'form',
    'dynamicwizard',
    'datatable',
    'datamap',
    'reviewpage',
    'custom',
  };

  ConversationEngine({required this.form, this.onComplete}) {
    _allQuestions = _flattenQuestions(form.components);
    if (kDebugMode) {
      print(
          '🎙️ ConversationEngine: ${_allQuestions.length} questions extracted');
      for (final q in _allQuestions) {
        print('   - [${q.type}] ${q.key}: "${q.label}"');
      }
    }
  }

  // ─── Public API ──────────────────────────────────────────

  /// Current form data (read-only copy).
  Map<String, dynamic> get formData => Map.unmodifiable(_formData);

  /// Progress ratio (0.0 to 1.0).
  double get progress {
    final visible = _visibleQuestions;
    if (visible.isEmpty) return 1.0;
    final answered = visible.where((q) => _answeredKeys.contains(q.key)).length;
    return answered / visible.length;
  }

  /// Whether all visible required questions have been answered.
  bool get isComplete {
    final visible = _visibleQuestions;
    return visible.every((q) => _answeredKeys.contains(q.key));
  }

  /// Total number of visible questions.
  int get totalVisibleQuestions => _visibleQuestions.length;

  /// Number of answered questions.
  int get answeredCount =>
      _visibleQuestions.where((q) => _answeredKeys.contains(q.key)).length;

  /// Whether undo is available.
  bool get canUndo => _answerHistory.isNotEmpty;

  /// The key of the last answered question (for display purposes).
  String? get lastAnsweredKey =>
      _answerHistory.isNotEmpty ? _answerHistory.last : null;

  /// Get the next unanswered visible question, or null if complete.
  ComponentModel? getNextQuestion() {
    for (final question in _allQuestions) {
      if (_answeredKeys.contains(question.key)) continue;
      if (!_isVisible(question)) continue;
      return question;
    }
    return null;
  }

  /// Update form data with a processed answer.
  void updateAnswer(String key, dynamic value) {
    _formData[key] = value;
    _answeredKeys.add(key);
    _answerHistory.add(key);
    notifyListeners();

    if (kDebugMode) {
      print('📝 Answer recorded: $key = $value');
      print('📊 Progress: ${(progress * 100).toStringAsFixed(0)}%');
    }

    // Check if form is now complete
    if (isComplete) {
      onComplete?.call(Map.from(_formData));
    }
  }

  /// Clear a specific answer so it can be re-asked.
  void clearAnswer(String key) {
    _answeredKeys.remove(key);
    _formData.remove(key);
    _answerHistory.remove(key);
    notifyListeners();
  }

  /// Restore answers from a previous session.
  void restoreAnswers(Map<String, dynamic> savedData) {
    for (final entry in savedData.entries) {
      _formData[entry.key] = entry.value;
      _answeredKeys.add(entry.key);
      _answerHistory.add(entry.key);
    }
    notifyListeners();
  }

  /// Get a snapshot of all current form data (for persistence).
  Map<String, dynamic> get formDataSnapshot => Map.from(_formData);

  /// Reset all answers and start from scratch.
  void resetAll() {
    _formData.clear();
    _answeredKeys.clear();
    _answerHistory.clear();
    notifyListeners();
  }

  /// Undo the last answered question.
  ///
  /// Returns the undone component key, or null if nothing to undo.
  String? undoLastAnswer() {
    if (_answerHistory.isEmpty) return null;

    final lastKey = _answerHistory.removeLast();
    _answeredKeys.remove(lastKey);
    _formData.remove(lastKey);

    // Also remove any answers that depended on this answer
    // (i.e., conditional fields that are no longer visible)
    final toRemove = <String>[];
    for (final key in _answeredKeys) {
      final question = _allQuestions.where((q) => q.key == key).firstOrNull;
      if (question != null && !_isVisible(question)) {
        toRemove.add(key);
      }
    }
    for (final key in toRemove) {
      _answeredKeys.remove(key);
      _formData.remove(key);
      _answerHistory.remove(key);
    }

    notifyListeners();

    if (kDebugMode) {
      print('↩️ Undone: $lastKey (+ ${toRemove.length} dependent fields)');
    }

    return lastKey;
  }

  /// Build a human-readable question text for TTS.
  String buildQuestionText(ComponentModel component) {
    final label = component.label.isNotEmpty ? component.label : component.key;

    switch (component.type) {
      case 'textfield':
      case 'textarea':
      case 'email':
      case 'phoneNumber':
      case 'url':
        return label;

      case 'number':
      case 'currency':
        return PromptDictionary.current.questionNumber(label);

      case 'select':
        final options = _getSelectOptions(component);
        if (options.isNotEmpty) {
          return PromptDictionary.current.questionSelectOne(label, options);
        }
        return label;

      case 'radio':
        final options = _getRadioOptions(component);
        if (options.isNotEmpty) {
          return PromptDictionary.current.questionSelectOne(label, options);
        }
        return label;

      case 'checkbox':
        return PromptDictionary.current.questionCheckbox(label);

      case 'selectboxes':
        final options = _getSelectBoxOptions(component);
        if (options.isNotEmpty) {
          return PromptDictionary.current.questionSelectMulti(label, options);
        }
        return label;

      case 'datetime':
      case 'date':
      case 'day':
        return PromptDictionary.current.questionDate(label);

      case 'time':
        return PromptDictionary.current.questionTime(label);

      case 'address':
        return label;

      case 'survey':
        // Survey sub-questions have synthetic keys like surveyKey__qValue
        // They carry the question label and survey values in raw JSON
        final surveyValues = _getSurveyValues(component);
        if (surveyValues.isNotEmpty) {
          return PromptDictionary.current
              .surveyQuestionPrompt(label, surveyValues);
        }
        return label;

      case 'datagrid':
        // DataGrid uses sub-questions expanded from columns
        return label;

      default:
        return label;
    }
  }

  /// Build TTS-specific question text.
  ///
  /// For list-based components (select, radio, selectboxes, survey) with
  /// more than [PromptDictionary.ttsListThreshold] options, returns a
  /// short instruction without the full option list. The full list is
  /// still shown in the chat bubble via [buildQuestionText].
  ///
  /// For all other types, returns the same text as [buildQuestionText].
  String buildTtsText(ComponentModel component) {
    final label = component.label.isNotEmpty ? component.label : component.key;

    switch (component.type) {
      case 'select':
        final options = _getSelectOptions(component);
        if (options.isNotEmpty) {
          return PromptDictionary.current
              .questionSelectOneTts(label, options);
        }
        return label;

      case 'radio':
        final options = _getRadioOptions(component);
        if (options.isNotEmpty) {
          return PromptDictionary.current
              .questionSelectOneTts(label, options);
        }
        return label;

      case 'selectboxes':
        final options = _getSelectBoxOptions(component);
        if (options.isNotEmpty) {
          return PromptDictionary.current
              .questionSelectMultiTts(label, options);
        }
        return label;

      case 'survey':
        final surveyValues = _getSurveyValues(component);
        if (surveyValues.isNotEmpty) {
          return PromptDictionary.current
              .surveyQuestionPromptTts(label, surveyValues);
        }
        return label;

      default:
        return buildQuestionText(component);
    }
  }

  /// Parse a raw text answer into the appropriate value for a component type.
  dynamic parseAnswer(ComponentModel component, String rawText) {
    final text = rawText.trim();

    switch (component.type) {
      case 'number':
      case 'currency':
        return num.tryParse(text.replaceAll(RegExp(r'[^\d.,\-]'), '')) ?? text;

      case 'checkbox':
        final lower = text.toLowerCase();
        return lower.contains('evet') ||
            lower.contains('yes') ||
            lower.contains('doğru') ||
            lower == 'true';

      case 'select':
        return _matchSelectOption(component, text);

      case 'radio':
        return _matchRadioOption(component, text);

      default:
        return text;
    }
  }

  // ─── Private Helpers ─────────────────────────────────────

  /// Flatten all components recursively, filtering out layout containers.
  List<ComponentModel> _flattenQuestions(List<ComponentModel> components) {
    final result = <ComponentModel>[];
    for (final component in components) {
      final type = component.type;

      // Expand survey into sub-questions
      if (type == 'survey') {
        result.addAll(_expandSurvey(component));
        continue;
      }

      // Expand datagrid into row/column sub-questions
      if (type == 'datagrid') {
        result.addAll(_expandDatagrid(component));
        continue;
      }

      // Skip layout containers and non-question types
      if (_layoutTypes.contains(type) || _nonQuestionTypes.contains(type)) {
        // But recurse into their children
        _addChildQuestions(component, result);
        continue;
      }

      result.add(component);
    }
    return result;
  }

  /// Extract child questions from layout components.
  void _addChildQuestions(ComponentModel component, List<ComponentModel> result) {
    // Handle components with 'components' array
    final children = component.raw['components'] as List?;
    if (children != null) {
      final childModels = children
          .map((c) => ComponentModel.fromJson(c as Map<String, dynamic>))
          .toList();
      result.addAll(_flattenQuestions(childModels));
    }

    // Handle columns
    final columns = component.raw['columns'] as List?;
    if (columns != null) {
      for (final col in columns) {
        final colComponents =
            (col as Map<String, dynamic>)['components'] as List? ?? [];
        final childModels = colComponents
            .map((c) => ComponentModel.fromJson(c as Map<String, dynamic>))
            .toList();
        result.addAll(_flattenQuestions(childModels));
      }
    }

    // Handle tabs
    final tabs = component.raw['tabs'] as List?;
    if (tabs != null) {
      for (final tab in tabs) {
        final tabComponents =
            (tab as Map<String, dynamic>)['components'] as List? ?? [];
        final childModels = tabComponents
            .map((c) => ComponentModel.fromJson(c as Map<String, dynamic>))
            .toList();
        result.addAll(_flattenQuestions(childModels));
      }
    }

    // Handle table rows
    final rows = component.raw['rows'] as List?;
    if (rows != null) {
      for (final row in rows) {
        for (final cell in (row as List)) {
          final cellComponents =
              (cell as Map<String, dynamic>)['components'] as List? ?? [];
          final childModels = cellComponents
              .map((c) => ComponentModel.fromJson(c as Map<String, dynamic>))
              .toList();
          result.addAll(_flattenQuestions(childModels));
        }
      }
    }
  }

  /// Check if a component should be visible based on current form data.
  bool _isVisible(ComponentModel component) {
    final conditional =
        component.raw['conditional'] as Map<String, dynamic>?;
    return ConditionalEvaluator.shouldShow(conditional, _formData);
  }

  /// Get currently visible questions.
  List<ComponentModel> get _visibleQuestions =>
      _allQuestions.where(_isVisible).toList();

  /// Extract options from a select component.
  List<String> _getSelectOptions(ComponentModel component) {
    final data = component.raw['data'] as Map<String, dynamic>?;
    final values = data?['values'] as List?;
    if (values == null) return [];
    return values
        .map((v) => (v as Map<String, dynamic>)['label']?.toString() ?? '')
        .where((l) => l.isNotEmpty)
        .toList();
  }

  /// Extract options from a radio component.
  List<String> _getRadioOptions(ComponentModel component) {
    final values = component.raw['values'] as List?;
    if (values == null) return [];
    return values
        .map((v) => (v as Map<String, dynamic>)['label']?.toString() ?? '')
        .where((l) => l.isNotEmpty)
        .toList();
  }

  /// Extract options from a selectboxes component.
  List<String> _getSelectBoxOptions(ComponentModel component) {
    final values = component.raw['values'] as List?;
    if (values == null) return [];
    return values
        .map((v) => (v as Map<String, dynamic>)['label']?.toString() ?? '')
        .where((l) => l.isNotEmpty)
        .toList();
  }

  /// Match a spoken text to a select option value.
  dynamic _matchSelectOption(ComponentModel component, String text) {
    final data = component.raw['data'] as Map<String, dynamic>?;
    final values = data?['values'] as List?;
    if (values == null) return text;

    final lower = text.toLowerCase();
    for (final v in values) {
      final opt = v as Map<String, dynamic>;
      final label = (opt['label']?.toString() ?? '').toLowerCase();
      final value = opt['value']?.toString() ?? '';
      if (lower == label || lower == value.toLowerCase() || lower.contains(label)) {
        return value;
      }
    }
    // Fallback: return raw text
    return text;
  }

  /// Match a spoken text to a radio option value.
  dynamic _matchRadioOption(ComponentModel component, String text) {
    final values = component.raw['values'] as List?;
    if (values == null) return text;

    final lower = text.toLowerCase();
    for (final v in values) {
      final opt = v as Map<String, dynamic>;
      final label = (opt['label']?.toString() ?? '').toLowerCase();
      final value = opt['value']?.toString() ?? '';
      if (lower == label || lower == value.toLowerCase() || lower.contains(label)) {
        return value;
      }
    }
    return text;
  }

  // ─── Survey Expansion ───────────────────────────────────

  /// Extract survey value labels for TTS.
  List<String> _getSurveyValues(ComponentModel component) {
    final values = component.raw['values'] as List?;
    if (values == null) return [];
    return values
        .map((v) => (v as Map<String, dynamic>)['label']?.toString() ?? '')
        .where((l) => l.isNotEmpty)
        .toList();
  }

  /// Expand a survey component into one synthetic question per row.
  ///
  /// Each synthetic question uses key: `surveyKey__questionValue`
  /// so answers can be merged back into `{q1: rating, q2: rating}`.
  List<ComponentModel> _expandSurvey(ComponentModel survey) {
    final questions = survey.raw['questions'] as List?;
    final values = survey.raw['values'] as List?;
    if (questions == null || values == null) return [];

    final result = <ComponentModel>[];
    for (final q in questions) {
      final qMap = q as Map<String, dynamic>;
      final qLabel = qMap['label']?.toString() ?? '';
      final qValue = qMap['value']?.toString() ?? '';

      result.add(ComponentModel.fromJson({
        'type': 'survey',
        'key': '${survey.key}__$qValue',
        'label': qLabel,
        'required': survey.required,
        'values': values,
        '_surveyParentKey': survey.key,
        '_surveyQuestionValue': qValue,
      }));
    }
    return result;
  }

  // ─── DataGrid Expansion ─────────────────────────────────

  /// Expand a datagrid into sub-questions for the first row.
  ///
  /// Each column becomes a question with key: `gridKey__row0__colKey`.
  /// A sentinel "add row?" question is appended with key: `gridKey__addrow`.
  List<ComponentModel> _expandDatagrid(ComponentModel datagrid) {
    final columns = datagrid.raw['components'] as List?;
    if (columns == null || columns.isEmpty) return [];

    final result = <ComponentModel>[];
    final columnLabels =
        columns.map((c) => (c as Map<String, dynamic>)['label']?.toString() ?? '').toList();

    // Notify the user about the table
    // (This info is available via buildQuestionText for the first sub-question)
    // Add first row columns
    for (final col in columns) {
      final colMap = col as Map<String, dynamic>;
      result.add(ComponentModel.fromJson({
        ...colMap,
        'key': '${datagrid.key}__row0__${colMap['key']}',
        'label': '${datagrid.label} — '
            '${PromptDictionary.current.datagridRowPrompt(1)}: ${colMap['label']}',
        'required': datagrid.required,
        '_datagridParentKey': datagrid.key,
        '_datagridRow': 0,
        '_datagridColumn': colMap['key'],
        '_datagridColumnLabels': columnLabels,
      }));
    }

    // Add sentinel "add more rows?" question
    result.add(ComponentModel.fromJson({
      'type': 'checkbox',
      'key': '${datagrid.key}__addrow',
      'label': PromptDictionary.current.datagridAddMorePrompt,
      'required': false,
      '_datagridParentKey': datagrid.key,
      '_datagridSentinel': true,
      '_datagridColumns': columns.map((c) => c as Map<String, dynamic>).toList(),
      '_datagridColumnLabels': columnLabels,
      '_datagridNextRow': 1,
    }));

    return result;
  }

  /// After a datagrid "add row?" answer of true, insert more row questions.
  void expandDatagridRow(String addRowKey) {
    final sentinel = _allQuestions.where((q) => q.key == addRowKey).firstOrNull;
    if (sentinel == null) return;

    final parentKey = sentinel.raw['_datagridParentKey']?.toString() ?? '';
    final nextRow = sentinel.raw['_datagridNextRow'] as int? ?? 1;
    final columns = sentinel.raw['_datagridColumns'] as List? ?? [];
    final columnLabels = (sentinel.raw['_datagridColumnLabels'] as List?)?.cast<String>() ?? [];

    final sentinelIndex = _allQuestions.indexOf(sentinel);
    if (sentinelIndex < 0) return;

    // Insert new row columns before the sentinel
    final newQuestions = <ComponentModel>[];
    for (final col in columns) {
      final colMap = col as Map<String, dynamic>;
      newQuestions.add(ComponentModel.fromJson({
        ...colMap,
        'key': '${parentKey}__row${nextRow}__${colMap['key']}',
        'label': '${sentinel.label.split(' — ').first} — '
            '${PromptDictionary.current.datagridRowPrompt(nextRow + 1)}: ${colMap['label']}',
        'required': false,
        '_datagridParentKey': parentKey,
        '_datagridRow': nextRow,
        '_datagridColumn': colMap['key'],
        '_datagridColumnLabels': columnLabels,
      }));
    }

    // Update sentinel for next potential row
    _allQuestions[sentinelIndex] = ComponentModel.fromJson({
      ...sentinel.raw,
      '_datagridNextRow': nextRow + 1,
    });

    // Remove "add row" answer so it can be re-asked
    _answeredKeys.remove(addRowKey);
    _formData.remove(addRowKey);
    _answerHistory.remove(addRowKey);

    // Insert new questions before the sentinel
    _allQuestions.insertAll(sentinelIndex, newQuestions);
    notifyListeners();
  }

  /// Merge datagrid sub-answers into the final `[{col1: val, col2: val}, ...]` format.
  Map<String, dynamic> get mergedFormData {
    final merged = Map<String, dynamic>.from(_formData);

    // Group survey sub-answers
    final surveyGroups = <String, Map<String, dynamic>>{};
    // Group datagrid sub-answers
    final datagridGroups = <String, List<Map<String, dynamic>>>{};

    for (final entry in _formData.entries) {
      final key = entry.key;

      // Survey: parentKey__questionValue
      if (key.contains('__') && !key.contains('__row') && !key.contains('__addrow')) {
        // Check if this is a survey key by looking up the component
        final component = _allQuestions.where((q) => q.key == key).firstOrNull;
        if (component != null && component.raw['_surveyParentKey'] != null) {
          final parentKey = component.raw['_surveyParentKey'].toString();
          final qValue = component.raw['_surveyQuestionValue'].toString();
          surveyGroups.putIfAbsent(parentKey, () => {});
          surveyGroups[parentKey]![qValue] = entry.value;
          merged.remove(key);
        }
      }

      // DataGrid: parentKey__rowN__colKey
      final dgMatch = RegExp(r'^(.+)__row(\d+)__(.+)$').firstMatch(key);
      if (dgMatch != null) {
        final parentKey = dgMatch.group(1)!;
        final rowNum = int.parse(dgMatch.group(2)!);
        final colKey = dgMatch.group(3)!;
        datagridGroups.putIfAbsent(parentKey, () => []);
        while (datagridGroups[parentKey]!.length <= rowNum) {
          datagridGroups[parentKey]!.add({});
        }
        datagridGroups[parentKey]![rowNum][colKey] = entry.value;
        merged.remove(key);
      }

      // Remove sentinel keys
      if (key.endsWith('__addrow')) {
        merged.remove(key);
      }
    }

    // Merge grouped data
    for (final entry in surveyGroups.entries) {
      merged[entry.key] = entry.value;
    }
    for (final entry in datagridGroups.entries) {
      merged[entry.key] = entry.value;
    }

    return merged;
  }
}
