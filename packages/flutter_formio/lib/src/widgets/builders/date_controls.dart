/// date / datetime / time, with platform-native pickers.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../form_field_scope.dart';

// ---- date / datetime / time ---------------------------------------------

String _two(int n) => n.toString().padLeft(2, '0');

/// Renders [dt] with the schema's `format`, or null when there is no usable one.
///
/// Form.io writes display formats in the same token vocabulary ICU uses —
/// `yyyy`, `MM`, `dd`, `HH` (24-hour), `hh` (12-hour), `mm`, `a` — so the
/// schema's string goes straight to [DateFormat]. Before this, `format` was
/// ignored outright and every value rendered as `yyyy-MM-dd HH:mm`, so a field
/// asking for `hh:mm a` showed 24-hour time with no meridiem.
///
/// Returns null when the pattern yields nothing usable, so the field falls back
/// to its default rendering.
///
/// [DateFormat] is lenient to a fault: it does not throw on a pattern it cannot
/// read, it returns a blank string (an unterminated quote, or a lone `ZZZZZ`).
/// A blank reads as an *unset* field, which is worse than a wrongly-formatted
/// one — so an empty result is rejected, not just an exception.
///
/// A pattern ICU parses but disagrees with is left alone: `format` is authored
/// content, and second-guessing a valid-but-odd pattern would be guessing.
String? _formattedDate(Object? format, DateTime dt, String? locale) {
  final pattern = format?.toString();
  if (pattern == null || pattern.isEmpty) return null;
  try {
    final text = DateFormat(pattern, locale).format(dt);
    return text.isEmpty ? null : text;
  } catch (_) {
    return null;
  }
}

/// How a `time` component stores its value.
///
/// The engine strict-parses the stored value against this pattern, so a `time`
/// field must be written in it — an ISO timestamp fails validation even though
/// it carries the same instant. Form.io defaults it to `HH:mm:ss`.
String _timeDataFormat(Map<String, dynamic> raw) {
  final format = raw['dataFormat']?.toString();
  return (format == null || format.isEmpty) ? _defaultTimeFormat : format;
}

const _defaultTimeFormat = 'HH:mm:ss';

/// [dt]'s time of day in the schema's storage format.
String _storedTime(DateTime dt, Map<String, dynamic> raw) {
  try {
    final text = DateFormat(_timeDataFormat(raw)).format(dt);
    if (text.isNotEmpty) return text;
  } catch (_) {
    // Falls through: an unreadable pattern is no reason to store nothing.
  }
  return '${_two(dt.hour)}:${_two(dt.minute)}:${_two(dt.second)}';
}

/// Reads a stored value, which for a [timeOnly] component carries no date.
///
/// ISO is tried first regardless: a field that stored a full timestamp — a
/// `datetime`, or a `time` written before this understood the difference — still
/// has to render.
DateTime? _parseStored(String? value, Map<String, dynamic> raw,
    {required bool timeOnly}) {
  if (value == null || value.isEmpty) return null;

  final iso = DateTime.tryParse(value);
  if (iso != null || !timeOnly) return iso;

  for (final pattern in {
    _timeDataFormat(raw),
    _defaultTimeFormat,
    'HH:mm',
  }) {
    try {
      return DateFormat(pattern).parseStrict(value);
    } catch (_) {
      continue;
    }
  }
  return null;
}

/// Presents an iOS-style wheel picker in a bottom sheet and resolves to the
/// chosen [DateTime], or `null` if the sheet is dismissed without confirming.
Future<DateTime?> _showCupertinoDateTime(
    BuildContext ctx, DateTime initial, CupertinoDatePickerMode mode) {
  var result = initial;
  return showCupertinoModalPopup<DateTime>(
    context: ctx,
    builder: (sheetCtx) => Container(
      height: 300,
      color: CupertinoColors.systemBackground.resolveFrom(sheetCtx),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              height: 240,
              child: CupertinoDatePicker(
                mode: mode,
                initialDateTime: initial,
                minimumYear: 1900,
                maximumYear: 2100,
                use24hFormat: MediaQuery.of(sheetCtx).alwaysUse24HourFormat,
                onDateTimeChanged: (d) => result = d,
              ),
            ),
            CupertinoButton(
              onPressed: () => Navigator.of(sheetCtx).pop(result),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget buildDateTime(
    FieldScope s, Map<String, dynamic> raw, String path, String type) {
  final ctx = s.context;
  final disabled = raw['disabled'] == true || raw['readOnly'] == true;
  final enableDate =
      type == 'date' || (type == 'datetime' && raw['enableDate'] != false);
  final enableTime =
      type == 'time' || (type == 'datetime' && raw['enableTime'] == true);
  // Only Form.io's `time` type stores a bare time of day; a `datetime` with its
  // date input switched off still stores a timestamp.
  final timeOnly = type == 'time';
  final current = s.getValue(path)?.toString();
  final dt = _parseStored(current, raw, timeOnly: timeOnly);

  String display() {
    if (dt == null) return raw['placeholder'] as String? ?? 'Select…';
    final authored = _formattedDate(
        raw['format'], dt, Localizations.maybeLocaleOf(ctx)?.toString());
    if (authored != null) return authored;
    final d = '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';
    final t = '${_two(dt.hour)}:${_two(dt.minute)}';
    if (enableDate && enableTime) return '$d $t';
    if (enableTime) return t;
    return d;
  }

  Future<void> pick() async {
    var picked = dt ?? DateTime.now();
    final platform = Theme.of(ctx).platform;
    final useCupertino =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    if (useCupertino) {
      // Native-feeling iOS wheel picker; a single wheel covers all three modes.
      final mode = enableDate && enableTime
          ? CupertinoDatePickerMode.dateAndTime
          : enableTime
              ? CupertinoDatePickerMode.time
              : CupertinoDatePickerMode.date;
      final result = await _showCupertinoDateTime(ctx, picked, mode);
      if (result == null) return;
      // Preserve the components the chosen mode doesn't edit.
      picked = switch (mode) {
        CupertinoDatePickerMode.date => DateTime(
            result.year, result.month, result.day, picked.hour, picked.minute),
        CupertinoDatePickerMode.time => DateTime(
            picked.year, picked.month, picked.day, result.hour, result.minute),
        _ => result,
      };
    } else {
      if (enableDate) {
        final d = await showDatePicker(
          context: ctx,
          initialDate: picked,
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
        );
        if (d == null) return;
        picked = DateTime(d.year, d.month, d.day, picked.hour, picked.minute);
      }
      if (enableTime && ctx.mounted) {
        final t = await showTimePicker(
          context: ctx,
          initialTime: TimeOfDay.fromDateTime(picked),
        );
        if (t == null) return;
        picked =
            DateTime(picked.year, picked.month, picked.day, t.hour, t.minute);
      }
    }
    s.setValue(
      path,
      timeOnly ? _storedTime(picked, raw) : picked.toIso8601String(),
      immediate: true,
    );
  }

  return InkWell(
    onTap: disabled ? null : pick,
    child: InputDecorator(
      decoration: InputDecoration(
        isDense: s.theme.isDense,
        border: s.theme.resolvedInputBorder(ctx),
        enabledBorder: s.theme.inputBorder,
        focusedBorder: s.theme.focusedInputBorder,
        errorBorder: s.theme.errorInputBorder,
        focusedErrorBorder: s.theme.errorInputBorder,
        contentPadding: s.theme.inputContentPadding,
        suffixIcon: Icon(enableTime && !enableDate
            ? Icons.access_time
            : Icons.calendar_today),
        fillColor: disabled
            ? Theme.of(ctx).disabledColor.withValues(alpha: 0.05)
            : s.theme.inputFillColor,
        filled: disabled || s.theme.inputFillColor != null,
      ),
      // Unset: the placeholder uses the hint style, a chosen value the input style.
      child: Text(display(),
          style: dt == null
              ? (s.theme.hintStyle ?? TextStyle(color: Theme.of(ctx).hintColor))
              : s.theme.inputTextStyle),
    ),
  );
}
