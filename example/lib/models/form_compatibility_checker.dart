/// FormCompatibilityChecker — validates that a form can be fully
/// completed via voice input before starting a session.
///
/// Recursively scans all components and reports any required fields
/// that are not voice-compatible. Used to show a blocking screen
/// if the form cannot be filled entirely by voice.
library;

import 'package:formio_api/formio_api.dart';

import 'voice_field_config.dart';

/// A single unsupported required field found during the check.
class UnsupportedField {
  final String key;
  final String label;
  final String type;
  final String reason;

  const UnsupportedField({
    required this.key,
    required this.label,
    required this.type,
    required this.reason,
  });
}

/// Result of a form compatibility check.
class FormCompatibilityResult {
  /// Whether the form is fully compatible with voice input.
  bool get isCompatible => unsupportedRequiredFields.isEmpty;

  /// List of required fields that cannot be filled by voice.
  final List<UnsupportedField> unsupportedRequiredFields;

  const FormCompatibilityResult({
    required this.unsupportedRequiredFields,
  });
}

class FormCompatibilityChecker {
  FormCompatibilityChecker._();

  /// Check if all required fields in the form can be filled by voice.
  ///
  /// Returns a [FormCompatibilityResult] with the list of
  /// unsupported required fields (if any).
  static FormCompatibilityResult check(FormModel form) {
    final unsupported = <UnsupportedField>[];
    _scanComponents(form.components, unsupported);
    return FormCompatibilityResult(unsupportedRequiredFields: unsupported);
  }

  static void _scanComponents(
    List<ComponentModel> components,
    List<UnsupportedField> unsupported,
  ) {
    for (final component in components) {
      final config = VoiceFieldConfig.fromComponent(component);

      // If the component is required but not voice-compatible, flag it
      if (component.required && !config.isVoiceCompatible) {
        unsupported.add(UnsupportedField(
          key: component.key,
          label: component.label.isNotEmpty ? component.label : component.key,
          type: component.type,
          reason: config.skipReason ?? '',
        ));
      }

      // Recurse into children (panels, columns, tabs, etc.)
      _scanChildren(component, unsupported);
    }
  }

  static void _scanChildren(
    ComponentModel component,
    List<UnsupportedField> unsupported,
  ) {
    // Handle components with 'components' array
    final children = component.raw['components'] as List?;
    if (children != null) {
      final childModels = children
          .map((c) => ComponentModel.fromJson(c as Map<String, dynamic>))
          .toList();
      _scanComponents(childModels, unsupported);
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
        _scanComponents(childModels, unsupported);
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
        _scanComponents(childModels, unsupported);
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
          _scanComponents(childModels, unsupported);
        }
      }
    }
  }
}
