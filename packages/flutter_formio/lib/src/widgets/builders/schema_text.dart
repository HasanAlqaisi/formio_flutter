/// Reading display strings off a raw component schema.
///
/// Both of these tolerate non-string JSON (`{"suffix": 5}`) and blank values,
/// because real schemas carry both and casting throws on them.
library;

import 'package:flutter/material.dart';

import '../form_theme.dart';

/// A label with its required marker painted in [FormioTheme.requiredSuffixColor]
/// (the error colour by default), so a required field is spottable at a glance.
///
/// Takes the already-resolved [label] rather than the schema, because callers
/// apply their own rules first (`hideLabel`, a grid's column title).
Widget labelWithRequired(
  String label, {
  required bool required,
  required FormioTheme theme,
  required BuildContext context,
  TextStyle? style,
  TextAlign? textAlign,
}) =>
    Text.rich(
      TextSpan(
        text: label,
        children: required && label.isNotEmpty
            ? [
                TextSpan(
                  text: theme.requiredSuffix,
                  style: TextStyle(
                      color: theme.resolvedRequiredSuffixColor(context)),
                ),
              ]
            : null,
      ),
      style: style,
      textAlign: textAlign,
    );

String labelText(Map<String, dynamic> raw, {String requiredSuffix = ' *'}) {
  final label = raw['label'] as String? ?? '';
  return raw['validate']?['required'] == true && label.isNotEmpty
      ? '$label$requiredSuffix'
      : label;
}

/// Localized message for an engine validation [e], via the global
/// [ComponentFactory.locale]. `custom` rules carry the form author's own
/// message in [FormLogicError.messageKey] and are shown as-is.

String? affixText(Map<String, dynamic> raw, String key) {
  final v = raw[key];
  if (v == null) return null;
  final text = v.toString();
  return text.isEmpty ? null : text;
}

/// Builds an always-visible `prefix`/`suffix` addon.
