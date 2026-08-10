/// Text-like inputs: textfield, textarea, number, currency, email, url,
/// phoneNumber, password.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/input_mask.dart';
import '../components/numeric_format.dart';
import '../form_field_scope.dart';
import 'schema_text.dart';

const kTextTypes = {
  'textfield',
  'textarea',
  'number',
  'currency',
  'email',
  'url',
  'phoneNumber',
  'password',
};

// ---- text inputs (controller-bound; live calc / read-only) ---------------

/// Maps a Form.io text component [type] to the mobile keyboard best suited to
/// it, mirroring the HTML5 input-type keyboards Form.io's web renderer relies
/// on (email → `@`/`.` keys, phone → dial pad, url → `/`/`.com` keys).
TextInputType _keyboardTypeFor(String type) {
  switch (type) {
    case 'textarea':
      return TextInputType.multiline;
    case 'number':
    case 'currency':
      return const TextInputType.numberWithOptions(decimal: true);
    case 'email':
      return TextInputType.emailAddress;
    case 'url':
      return TextInputType.url;
    case 'phoneNumber':
      return TextInputType.phone;
    default:
      return TextInputType.text;
  }
}

/// Reads a `prefix`/`suffix` addon from the schema, tolerating non-string JSON
/// values (`{"suffix": 5}`). Returns null when absent or blank.

Widget _affix(String text, TextStyle style, {required bool isPrefix}) =>
    Padding(
      // Directional so the gap stays on the inner side under RTL.
      padding: isPrefix
          ? const EdgeInsetsDirectional.only(start: 12, end: 4)
          : const EdgeInsetsDirectional.only(start: 4, end: 12),
      child: Text(text, style: style),
    );

/// `decimalLimit` from the schema, defaulting to 2 for currency and to "no
/// forced decimals" for a plain number.
int? _decimalLimitFor(
  Map<String, dynamic> raw, {
  required bool isCurrency,
  bool requireDecimal = false,
}) {
  final declared = raw['decimalLimit'];
  final limit = declared is num
      ? declared.toInt()
      : (declared is String ? int.tryParse(declared.trim()) : null);
  if (limit != null) return limit.clamp(0, 10);
  // Currency always shows decimals; a plain number only when asked to.
  return (isCurrency || requireDecimal) ? kCurrencyDecimalLimit : null;
}

Widget buildTextLeaf(
    FieldScope s, Map<String, dynamic> raw, String path, String type) {
  final ctx = s.context;
  final controller = s.controllerFor(path);
  final focus = s.focusFor(path);

  final readOnly = raw['disabled'] == true || raw['readOnly'] == true;
  final isNumber = type == 'number' || type == 'currency';
  final isCurrency = type == 'currency';
  final locale = Localizations.maybeLocaleOf(ctx)?.toString();

  // Form.io defaults `delimiter` to true for currency and false for number, so
  // a number field is only reformatted when its author asks for it.
  final grouping = isNumber &&
      (raw['delimiter'] == true || (isCurrency && raw['delimiter'] != false));
  // `requireDecimal` pads the decimals even when digits are not grouped.
  final requireDecimal = isNumber && raw['requireDecimal'] == true;
  // Nothing else enforces `validate.integer`: it has no rule in @formio/core,
  // which leans on the browser's number input for it. So the field has to.
  final integerOnly = isNumber && raw['validate']?['integer'] == true;
  final decimalLimit = integerOnly
      ? 0
      : _decimalLimitFor(raw,
          isCurrency: isCurrency, requireDecimal: requireDecimal);

  // Formatted while the field is idle, raw while the user is in it — otherwise
  // separators would fight the cursor mid-edit.
  final engineValue = isNumber && (grouping || requireDecimal)
      ? formatNumeric(s.getValue(path),
          grouping: grouping, decimalLimit: decimalLimit, locale: locale)
      : s.getValue(path)?.toString() ?? '';
  if (!focus.hasFocus && controller.text != engineValue) {
    controller.text = engineValue;
  }

  // Only an explicit mask is applied. Form.io's builder always writes one for a
  // phone number, but defaulting to its US shape here would mangle every
  // non-US number in a schema that omitted it.
  final inputMask = isNumber ? null : affixText(raw, 'inputMask');

  final prefix = affixText(raw, 'prefix') ??
      // A currency's symbol goes in the prefix slot, unless the author set one.
      (isCurrency ? currencySymbolFor(raw['currency'], locale) : null);
  final suffix = affixText(raw, 'suffix');
  final affixStyle = s.theme.resolvedAffixStyle(ctx);

  final formatters = <TextInputFormatter>[
    if (inputMask != null) MaskedInputFormatter(inputMask),
    if (grouping || integerOnly)
      GroupedNumberInputFormatter(
          locale: locale, decimalLimit: decimalLimit, grouping: grouping),
  ];

  return TextField(
    controller: controller,
    focusNode: focus,
    readOnly: readOnly,
    obscureText: type == 'password',
    keyboardType: integerOnly
        ? const TextInputType.numberWithOptions(decimal: false)
        : _keyboardTypeFor(type),
    // Regroups digits live; without it separators only appeared on blur.
    inputFormatters: formatters.isEmpty ? null : formatters,
    style: s.theme.inputTextStyle,
    maxLines: type == 'textarea' ? (raw['rows'] as num?)?.toInt() ?? 3 : 1,
    decoration: InputDecoration(
      isDense: s.theme.isDense,
      border: s.theme.resolvedInputBorder(ctx),
      enabledBorder: s.theme.inputBorder,
      focusedBorder: s.theme.focusedInputBorder,
      errorBorder: s.theme.errorInputBorder,
      focusedErrorBorder: s.theme.errorInputBorder,
      contentPadding: s.theme.inputContentPadding,
      hintText: raw['placeholder'] as String?,
      hintStyle: s.theme.hintStyle,
      prefixIcon:
          prefix == null ? null : _affix(prefix, affixStyle, isPrefix: true),
      suffixIcon:
          suffix == null ? null : _affix(suffix, affixStyle, isPrefix: false),
      // Without this the addon is forced into the default 48x48 icon box.
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      // The read-only tint takes precedence over the theme's own fill.
      fillColor: readOnly
          ? Theme.of(ctx).disabledColor.withValues(alpha: 0.05)
          : s.theme.inputFillColor,
      filled: readOnly || s.theme.inputFillColor != null,
    ),
    onChanged: readOnly
        ? null
        : (v) =>
            s.setValue(path, isNumber ? parseNumeric(v, locale: locale) : v),
  );
}
