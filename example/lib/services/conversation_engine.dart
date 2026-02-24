/// ConversationEngine — core orchestrator for voice-based form filling.
///
/// Flattens Form.io components, tracks answered fields, evaluates
/// conditional logic after each answer, and determines the next question.
library;

import 'package:flutter/foundation.dart';
import 'package:formio_api/formio_api.dart';

import '../models/prompt_dictionary.dart';

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
    'datagrid',
    'editgrid',
    'nestedform',
    'form',
    'dynamicwizard',
    'datatable',
    'datamap',
    'reviewpage',
    'custom',
    'survey',
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

      default:
        return label;
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
}
