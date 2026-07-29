/// Locale-aware formatting and parsing for `number` and `currency` fields.
///
/// Parsing uses [NumberFormat] so decimal and grouping separators follow the
/// active locale.
library;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Form.io's default decimal places for currency fields.
const int kCurrencyDecimalLimit = 2;

/// Returns the display symbol for an ISO currency [code].
String? currencySymbolFor(Object? code, String? locale) {
  final name = code?.toString().trim();
  if (name == null || name.isEmpty) return null;
  try {
    return NumberFormat.simpleCurrency(locale: locale, name: name)
        .currencySymbol;
  } catch (_) {
    return name;
  }
}

/// Formats a numeric value for display.
String formatNumeric(
  Object? value, {
  required bool grouping,
  int? decimalLimit,
  String? locale,
}) {
  if (value == null) return '';
  final number = value is num ? value : num.tryParse(value.toString());
  if (number == null) return value.toString();

  try {
    final format = NumberFormat.decimalPattern(locale);
    if (!grouping) format.turnOffGrouping();

    if (decimalLimit != null) {
      format
        ..minimumFractionDigits = decimalLimit
        ..maximumFractionDigits = decimalLimit;
    }

    return format.format(number);
  } catch (_) {
    return value.toString();
  }
}

/// Converts user input into the stored value.
///
/// Returns:
/// - `null` for empty input.
/// - A parsed [num] when valid.
/// - The original text otherwise, allowing validation to report an invalid
///   number instead of treating the field as empty.
Object? parseNumeric(String text, {String? locale}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;

  final plain = num.tryParse(trimmed);
  if (plain != null) return plain;

  try {
    return NumberFormat.decimalPattern(locale).parse(trimmed);
  } catch (_) {
    return trimmed;
  }
}

/// Formats grouped numbers while preserving the caret position.
class GroupedNumberInputFormatter extends TextInputFormatter {
  GroupedNumberInputFormatter({this.locale, this.decimalLimit});

  final String? locale;
  final int? decimalLimit;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final decimal = NumberFormat.decimalPattern(locale).symbols.DECIMAL_SEP;

    bool isValueChar(String c) {
      final code = c.codeUnitAt(0);
      return (code >= 0x30 && code <= 0x39) || c == decimal || c == '-';
    }

    final typed = newValue.text;
    final stripped = typed.split('').where(isValueChar).join();

    if (stripped.isEmpty || stripped == '-') {
      return newValue.copyWith(text: stripped);
    }

    // Preserve the caret relative to the remaining value characters.
    final caret = newValue.selection.baseOffset.clamp(0, typed.length);
    final trailing = typed.substring(caret).split('').where(isValueChar).length;

    final negative = stripped.startsWith('-');
    final body = negative ? stripped.substring(1) : stripped;
    final parts = body.split(decimal);

    final integerPart = parts.first;
    var decimalPart = parts.length > 1 ? parts.sublist(1).join() : null;

    if (decimalPart != null && decimalLimit != null) {
      decimalPart = decimalPart.substring(
        0,
        decimalPart.length.clamp(0, decimalLimit!),
      );
    }

    final groupedInteger = integerPart.isEmpty
        ? ''
        : formatNumeric(
            int.tryParse(integerPart) ?? integerPart,
            grouping: true,
            locale: locale,
          );

    final rebuilt = StringBuffer()
      ..write(negative ? '-' : '')
      ..write(groupedInteger)
      // Preserve a trailing decimal separator while typing.
      ..write(decimalPart != null ? '$decimal$decimalPart' : '');

    final text = rebuilt.toString();

    // Restore the caret by counting value characters from the end.
    var offset = text.length;
    var seen = 0;
    while (offset > 0 && seen < trailing) {
      offset--;
      if (isValueChar(text[offset])) seen++;
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
      composing: TextRange.empty,
    );
  }
}
