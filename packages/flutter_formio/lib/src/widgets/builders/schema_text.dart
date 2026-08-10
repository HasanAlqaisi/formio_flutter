/// Reading display strings off a raw component schema.
///
/// Both of these tolerate non-string JSON (`{"suffix": 5}`) and blank values,
/// because real schemas carry both and casting throws on them.
library;

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
