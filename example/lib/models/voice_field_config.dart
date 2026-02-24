/// VoiceFieldConfig — type-aware configuration for voice-based form filling.
///
/// Classifies Form.io component types into voice-compatible categories
/// and provides per-type AI prompt templates with validation constraints.
/// All prompt text comes from [PromptDictionary] for i18n support.
library;

import 'package:formio_api/formio_api.dart';

import 'prompt_dictionary.dart';

/// The voice input strategy for a component type.
enum VoiceInputStrategy {
  /// Free text input (textfield, textarea, password)
  freeText,

  /// Numeric input (number, currency)
  numeric,

  /// Single option selection (select, radio)
  singleSelect,

  /// Multiple option selection (selectboxes)
  multiSelect,

  /// Boolean yes/no (checkbox)
  boolean,

  /// Email address
  email,

  /// Phone number
  phone,

  /// URL
  url,

  /// Date or date-time (date, datetime, day)
  date,

  /// Time only
  time,

  /// Tags / comma-separated values
  tags,

  /// Not compatible with voice input — should be skipped
  skip,
}

/// Configuration for voice-based interaction with a specific form field.
class VoiceFieldConfig {
  /// Whether this component can be filled via voice.
  final bool isVoiceCompatible;

  /// The input strategy to use.
  final VoiceInputStrategy strategy;

  /// Type-specific AI prompt instructions.
  final String promptTemplate;

  /// Validation constraints extracted from the component.
  final Map<String, dynamic> constraints;

  /// Reason for skipping (only when !isVoiceCompatible).
  final String? skipReason;

  const VoiceFieldConfig({
    required this.isVoiceCompatible,
    required this.strategy,
    required this.promptTemplate,
    this.constraints = const {},
    this.skipReason,
  });

  /// Component types that cannot be filled by voice.
  static const _skipTypes = {
    'signature', 'file', 'captcha', 'sketchpad', 'tagpad',
    'hidden', 'button', 'datasource', 'container', 'datagrid',
    'editgrid', 'nestedform', 'form', 'dynamicwizard',
    'datatable', 'datamap', 'reviewpage', 'custom',
    'alert', 'content', 'htmlelement',
  };

  /// Build a [VoiceFieldConfig] from a Form.io [ComponentModel].
  factory VoiceFieldConfig.fromComponent(ComponentModel component) {
    final type = component.type;
    final d = PromptDictionary.current;

    // Check skip types first
    if (_skipTypes.contains(type)) {
      return VoiceFieldConfig(
        isVoiceCompatible: false,
        strategy: VoiceInputStrategy.skip,
        promptTemplate: '',
        skipReason: d.skipReason(type),
      );
    }

    // Extract validation constraints from raw JSON
    final validate =
        component.raw['validate'] as Map<String, dynamic>? ?? {};
    final constraints = <String, dynamic>{};

    if (validate['maxLength'] != null) {
      constraints['maxLength'] = validate['maxLength'];
    }
    if (validate['minLength'] != null) {
      constraints['minLength'] = validate['minLength'];
    }
    if (validate['min'] != null) constraints['min'] = validate['min'];
    if (validate['max'] != null) constraints['max'] = validate['max'];
    if (validate['pattern'] != null) {
      constraints['pattern'] = validate['pattern'];
    }
    if (component.raw['decimalLimit'] != null) {
      constraints['decimalLimit'] = component.raw['decimalLimit'];
    }
    if (component.raw['currency'] != null) {
      constraints['currency'] = component.raw['currency'];
    }

    switch (type) {
      case 'textfield':
        return VoiceFieldConfig(
          isVoiceCompatible: true,
          strategy: VoiceInputStrategy.freeText,
          promptTemplate: d.textFieldPrompt(
            maxLength: constraints['maxLength'] as int?,
            minLength: constraints['minLength'] as int?,
          ),
          constraints: constraints,
        );

      case 'textarea':
        return VoiceFieldConfig(
          isVoiceCompatible: true,
          strategy: VoiceInputStrategy.freeText,
          promptTemplate: d.textAreaPrompt(
            maxLength: constraints['maxLength'] as int?,
          ),
          constraints: constraints,
        );

      case 'password':
        return VoiceFieldConfig(
          isVoiceCompatible: true,
          strategy: VoiceInputStrategy.freeText,
          promptTemplate: d.passwordPrompt,
          constraints: constraints,
        );

      case 'email':
        return VoiceFieldConfig(
          isVoiceCompatible: true,
          strategy: VoiceInputStrategy.email,
          promptTemplate: d.emailPrompt,
          constraints: constraints,
        );

      case 'phoneNumber':
        return VoiceFieldConfig(
          isVoiceCompatible: true,
          strategy: VoiceInputStrategy.phone,
          promptTemplate: d.phonePrompt,
          constraints: constraints,
        );

      case 'url':
        return VoiceFieldConfig(
          isVoiceCompatible: true,
          strategy: VoiceInputStrategy.url,
          promptTemplate: d.urlPrompt,
          constraints: constraints,
        );

      case 'number':
        return VoiceFieldConfig(
          isVoiceCompatible: true,
          strategy: VoiceInputStrategy.numeric,
          promptTemplate: d.numberPrompt(
            min: constraints['min'],
            max: constraints['max'],
            decimalLimit: constraints['decimalLimit'],
          ),
          constraints: constraints,
        );

      case 'currency':
        return VoiceFieldConfig(
          isVoiceCompatible: true,
          strategy: VoiceInputStrategy.numeric,
          promptTemplate: d.currencyPrompt(
            currency:
                constraints['currency']?.toString() ?? 'TRY',
            decimalLimit:
                (constraints['decimalLimit'] as int?) ?? 2,
          ),
          constraints: constraints,
        );

      case 'select':
        return VoiceFieldConfig(
          isVoiceCompatible: true,
          strategy: VoiceInputStrategy.singleSelect,
          promptTemplate: d.singleSelectPrompt,
          constraints: constraints,
        );

      case 'radio':
        return VoiceFieldConfig(
          isVoiceCompatible: true,
          strategy: VoiceInputStrategy.singleSelect,
          promptTemplate: d.radioPrompt,
          constraints: constraints,
        );

      case 'selectboxes':
        return VoiceFieldConfig(
          isVoiceCompatible: true,
          strategy: VoiceInputStrategy.multiSelect,
          promptTemplate: d.multiSelectPrompt,
          constraints: constraints,
        );

      case 'checkbox':
        return VoiceFieldConfig(
          isVoiceCompatible: true,
          strategy: VoiceInputStrategy.boolean,
          promptTemplate: d.checkboxPrompt,
          constraints: constraints,
        );

      case 'date':
      case 'datetime':
      case 'day':
        return VoiceFieldConfig(
          isVoiceCompatible: true,
          strategy: VoiceInputStrategy.date,
          promptTemplate: d.datePrompt(includeTime: type == 'datetime'),
          constraints: constraints,
        );

      case 'time':
        return VoiceFieldConfig(
          isVoiceCompatible: true,
          strategy: VoiceInputStrategy.time,
          promptTemplate: d.timePrompt,
          constraints: constraints,
        );

      case 'tags':
        return VoiceFieldConfig(
          isVoiceCompatible: true,
          strategy: VoiceInputStrategy.tags,
          promptTemplate: d.tagsPrompt,
          constraints: constraints,
        );

      case 'address':
        return VoiceFieldConfig(
          isVoiceCompatible: true,
          strategy: VoiceInputStrategy.freeText,
          promptTemplate: d.addressPrompt,
          constraints: constraints,
        );

      case 'survey':
        return VoiceFieldConfig(
          isVoiceCompatible: false,
          strategy: VoiceInputStrategy.skip,
          promptTemplate: '',
          skipReason: d.skipSurvey,
        );

      default:
        return VoiceFieldConfig(
          isVoiceCompatible: true,
          strategy: VoiceInputStrategy.freeText,
          promptTemplate: d.textFieldPrompt(),
          constraints: constraints,
        );
    }
  }
}
