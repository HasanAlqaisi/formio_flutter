/// Fallback + host-registration mechanism for the engine renderer.
///
/// [EngineFormRenderer] renders basic inputs and layout NATIVELY. This factory
/// is only reached (via `buildFallback`) for premium / less-common component
/// types, and for host-registered custom builders (see [register]). Basic and
/// layout cases are intentionally absent — they never reach here.
library;

import 'package:flutter/material.dart';
import 'package:formio/formio.dart';

class ComponentFactory {
  /// Global locale configuration for all components
  static FormioLocalizations _locale = const DefaultFormioLocalizations();

  /// Registry of custom component builders
  static final Map<String, FormioComponentBuilder> _customComponents = {};

  /// Get current locale
  static FormioLocalizations get locale => _locale;

  /// Set global locale for all components
  static void setLocale(FormioLocalizations newLocale) {
    _locale = newLocale;
  }

  /// Registers custom component builders (type → builder).
  static void initialize(Map<String, FormioComponentBuilder> componentBuilders) {
    _customComponents.addAll(componentBuilders);
  }

  /// Registers a single custom component builder.
  ///
  /// ```dart
  /// ComponentFactory.register('mytype', MyBuilder());
  /// ```
  static void register(String type, FormioComponentBuilder builder) {
    _customComponents[type] = builder;
  }

  /// Removes a custom component builder registration.
  static void unregister(String type) {
    _customComponents.remove(type);
  }

  /// Whether a custom builder is registered for [type].
  static bool isRegistered(String type) {
    return _customComponents.containsKey(type);
  }

  /// Creates the appropriate widget for a given component.
  static Widget build({
    required ComponentModel component,
    dynamic value,
    required ValueChanged<dynamic> onChanged,
    Map<String, dynamic>? formData,
    void Function()? onSubmit,
    FilePickerCallback? onFilePick,
    DatePickerCallback? onDatePick,
    TimePickerCallback? onTimePick,
    bool enableLinks = true,
  }) {
    // Host-registered builder wins.
    final customBuilder = _customComponents[component.type];
    if (customBuilder != null) {
      return customBuilder.build(
        FormioComponentBuildContext(
          component: component,
          value: value,
          onChanged: onChanged,
          formData: formData,
          onSubmit: onSubmit,
          onFilePick: onFilePick,
          onDatePick: onDatePick,
          onTimePick: onTimePick,
        ),
      );
    }

    // Premium / less-common fallbacks. Basic inputs (textfield, select, …) and
    // layout (panel, columns, datagrid, …) are rendered natively by
    // EngineFormRenderer and never reach this switch.
    switch (component.type) {
      case 'button':
        return ButtonComponent(component: component, onPressed: () {}, isDisabled: false);
      case 'day':
        return DayComponent(component: component, value: value, onChanged: onChanged, formData: formData);
      case 'address':
        return AddressComponent(component: component, value: value is Map<String, dynamic> ? value : {}, onChanged: onChanged);
      case 'tags':
        return TagsComponent(component: component, value: value, onChanged: onChanged);
      case 'survey':
        final surveyValue = value is Map ? Map<String, String>.fromEntries((value).entries.map((e) => MapEntry(e.key.toString(), e.value.toString()))) : <String, String>{};
        return SurveyComponent(component: component, value: surveyValue, onChanged: onChanged);
      case 'signature':
        return SignatureComponent(component: component, value: value, onChanged: onChanged);
      case 'hidden':
        return HiddenComponent(component: component, value: value, onChanged: onChanged);
      case 'datasource':
        return DataSourceComponent(component: component, value: value, onChanged: onChanged, formData: formData);
      case 'datamap':
        final dataMapValue = value is Map ? Map<String, String>.fromEntries((value).entries.map((e) => MapEntry(e.key.toString(), e.value.toString()))) : <String, String>{};
        return DataMapComponent(component: component, value: dataMapValue, onChanged: onChanged);
      case 'dynamicwizard':
        return DynamicWizardComponent(
          component: component,
          value: value is List ? List<Map<String, dynamic>>.from(value) : [],
          onChanged: (val) => onChanged(val),
          formData: formData,
          onFilePick: onFilePick,
          onDatePick: onDatePick,
          onTimePick: onTimePick,
        );
      case 'htmlelement':
        return HtmlElementComponent(component: component, formData: formData, enableLinks: enableLinks);
      case 'content':
        return ContentComponent(component: component, formData: formData, enableLinks: enableLinks);
      case 'alert':
        return AlertComponent(component: component, formData: formData);
      case 'file':
        return FileComponent(
          component: component,
          value: value is List ? value.cast<FileData>() : <FileData>[],
          onChanged: (files) => onChanged(files),
          onFilePick: onFilePick,
        );
      case 'captcha':
        return CaptchaComponent(component: component, value: value, onChanged: onChanged);
      case 'tagpad':
        return TagpadComponent(component: component, value: value is List ? value.cast<String>() : null, onChanged: onChanged);
      case 'sketchpad':
        return SketchpadComponent(component: component, value: value as String?, onChanged: onChanged);
      case 'reviewpage':
        return ReviewPageComponent(component: component, value: value is Map<String, dynamic> ? value : null, onChanged: onChanged);
      case 'datatable':
        return DataTableComponent(component: component, value: value is List ? value.cast<Map<String, dynamic>>() : null, onChanged: onChanged);
      case 'custom':
        return CustomComponent(component: component, value: value, onChanged: onChanged);
      default:
        return UnknownComponent(component: component);
    }
  }
}
