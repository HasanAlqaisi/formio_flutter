/// Turning an engine validation failure into words.
library;

import 'package:formio/formio.dart';

String messageForError(FormLogicError e) {
  final loc = ComponentFactory.locale;
  // Optional, so a host localization predating these rules still compiles and
  // simply keeps the generic fallback. See [FormioValidationMessages].
  final extra = switch (loc) {
    final FormioValidationMessages m => m,
    _ => null,
  };

  /// A message that needs the rule's limit, degrading when the engine did not
  /// report one.
  String withSetting(String Function(String limit) message) =>
      e.setting != null ? message(e.setting!) : loc.invalidValue;

  switch (e.rule) {
    case 'required':
      return loc.fieldRequired;
    case 'email':
      return loc.invalidEmail;
    case 'url':
      return loc.invalidUrl;
    case 'number':
      return loc.invalidNumber;
    case 'pattern':
      return loc.invalidFormat;
    case 'custom':
      return e.messageKey ?? loc.invalidValue;
    case 'minLength':
      return withSetting(loc.getMinLengthMessage);
    case 'maxLength':
      return withSetting(loc.getMaxLengthMessage);
    case 'min':
      return withSetting(loc.getMinValueMessage);
    case 'max':
      return withSetting(loc.getMaxValueMessage);

    // A value that does not fit its required shape is a format problem, which
    // is what `invalidFormat` already says.
    case 'mask':
    case 'invalidDate':
    case 'invalidDay':
    case 'time':
      return loc.invalidFormat;

    // Date/year bounds read naturally as value bounds.
    case 'minDate':
    case 'minYear':
      return withSetting(loc.getMinValueMessage);
    case 'maxDate':
    case 'maxYear':
      return withSetting(loc.getMaxValueMessage);

    // The day component reports which of its parts is missing.
    case 'requiredDayField':
      return loc.getRequiredMessage(loc.day);
    case 'requiredMonthField':
      return loc.getRequiredMessage(loc.month);
    case 'requiredYearField':
      return loc.getRequiredMessage(loc.year);
    case 'requiredDayEmpty':
      return loc.fieldRequired;

    // The value is not among the source's options. Three engine rules, one thing
    // to say to whoever is filling the form.
    case 'invalidOption':
    case 'select':
    case 'onlyAvailableItems':
      return extra?.invalidOption ?? loc.invalidValue;

    case 'unique':
      return extra?.valueMustBeUnique ?? loc.invalidValue;
    case 'array':
      return extra?.valueMustBeList ?? loc.invalidValue;
    case 'nonarray':
      return extra?.valueMustNotBeList ?? loc.invalidValue;
    case 'invalidValueProperty':
      return extra?.invalidValueProperty ?? loc.invalidValue;

    case 'minWords':
      return extra == null
          ? loc.invalidValue
          : withSetting(extra.getMinWordsMessage);
    case 'maxWords':
      return extra == null
          ? loc.invalidValue
          : withSetting(extra.getMaxWordsMessage);
    case 'minSelectedCount':
      return extra == null
          ? loc.invalidValue
          : withSetting(extra.getMinSelectedMessage);
    case 'maxSelectedCount':
      return extra == null
          ? loc.invalidValue
          : withSetting(extra.getMaxSelectedMessage);

    // Like `custom`: a JSON-logic rule carries the author's own message.
    case 'json':
      return e.messageKey ?? loc.invalidValue;

    default:
      return loc.invalidValue;
  }
}

/// Wraps section content (panel / well / fieldset / datagrid) in the themed
/// card, so every section shares one look.
///
/// Uses [FormioTheme.sectionDecoration] when the theme supplies one (bordered,
/// optionally shadowed container); otherwise falls back to a Material [Card].
