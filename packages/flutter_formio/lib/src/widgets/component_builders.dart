/// Stateless widget builders for each Form.io component type, used by
/// [EngineFormRenderer]. Each builder reads/writes through a [FieldScope] and
/// returns a widget; layout/array builders recurse via `scope.renderChild`.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:formio/formio.dart';
import 'package:intl/intl.dart';

import 'components/input_mask.dart';
import 'components/numeric_format.dart';
import 'components/warning_card.dart';
import 'form_field_scope.dart';

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

// ---- field chrome (label position + description + inline error) ----------

Widget buildField(
    FieldScope s, Map<String, dynamic> raw, String path, Widget control,
    {bool showLabel = true}) {
  final ctx = s.context;
  final label = (!showLabel || raw['hideLabel'] == true)
      ? ''
      : (raw['label'] as String? ?? '');
  final required = raw['validate']?['required'] == true;
  final pos = raw['labelPosition'] as String? ?? 'top';
  final desc = raw['description'] as String?;
  final error = s.errorFor(path);

  // A side `labelPosition` carries two things: `left-right` puts the label on
  // the left with its text right-aligned (against the field it belongs to).
  // Only the side used to be read, so every side-label rendered left-aligned.
  final side = pos.split('-').first;
  final labelAlign = pos.split('-').length > 1 ? pos.split('-')[1] : null;

  final labelWidget = label.isEmpty
      ? null
      : Text(required ? '$label${s.theme.requiredSuffix}' : label,
          // start/end rather than left/right so the alignment still means
          // "leading"/"trailing" under RTL.
          textAlign: labelAlign == 'right' ? TextAlign.end : TextAlign.start,
          style: s.theme.resolvedLabelStyle(ctx));

  Widget labeled;
  if (labelWidget == null) {
    labeled = control;
  } else if (side == 'left' || side == 'right') {
    final lw = (raw['labelWidth'] as num?)?.toInt().clamp(10, 90) ?? 30;
    // The label must fill its cell for textAlign to have anywhere to move it.
    final labelCell = Expanded(
        flex: lw, child: SizedBox(width: double.infinity, child: labelWidget));
    final fieldCell = Expanded(flex: 100 - lw, child: control);
    labeled = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: side == 'left'
          ? [labelCell, const SizedBox(width: 8), fieldCell]
          : [fieldCell, const SizedBox(width: 8), labelCell],
    );
  } else if (pos == 'bottom') {
    labeled = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [control, const SizedBox(height: 4), labelWidget]);
  } else {
    labeled = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [labelWidget, const SizedBox(height: 4), control]);
  }

  return Padding(
    padding: s.theme.fieldPadding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        labeled,
        if (desc != null && desc.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(desc, style: s.theme.resolvedDescriptionStyle(ctx)),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(messageForError(error),
                style: s.theme.resolvedErrorStyle(ctx)),
          ),
      ],
    ),
  );
}

String labelText(Map<String, dynamic> raw, {String requiredSuffix = ' *'}) {
  final label = raw['label'] as String? ?? '';
  return raw['validate']?['required'] == true && label.isNotEmpty
      ? '$label$requiredSuffix'
      : label;
}

/// Localized message for an engine validation [e], via the global
/// [ComponentFactory.locale]. `custom` rules carry the form author's own
/// message in [FormLogicError.messageKey] and are shown as-is.
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
Widget sectionCard(FormioTheme theme, Widget child) {
  final padded = Padding(padding: theme.sectionPadding, child: child);
  final decoration = theme.sectionDecoration;
  return decoration == null
      ? Card(margin: theme.sectionMargin, child: padded)
      : Container(
          margin: theme.sectionMargin,
          decoration: decoration,
          child: padded,
        );
}

Widget placeholderCard(BuildContext ctx, String text) => warningCard(
      ctx,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      child: Text(text, style: TextStyle(color: WarningColors.of(ctx).title)),
    );

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
String? _affixText(Map<String, dynamic> raw, String key) {
  final v = raw[key];
  if (v == null) return null;
  final text = v.toString();
  return text.isEmpty ? null : text;
}

/// Builds an always-visible `prefix`/`suffix` addon.
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
  final inputMask = isNumber ? null : _affixText(raw, 'inputMask');

  final prefix = _affixText(raw, 'prefix') ??
      // A currency's symbol goes in the prefix slot, unless the author set one.
      (isCurrency ? currencySymbolFor(raw['currency'], locale) : null);
  final suffix = _affixText(raw, 'suffix');
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

// ---- select / selectboxes / checkbox / radio -----------------------------

/// Options a component can show without a network call — inline `values`, or an
/// inline array for `dataSrc: json`. A `url` source resolves to nothing here and
/// is fetched by [RemoteSelectOptions] instead.
List<Map<String, dynamic>> selectOptions(Map<String, dynamic> raw) =>
    localSelectOptions(raw);

Widget buildSelect(FieldScope s, Map<String, dynamic> raw, String path) {
  // `url` and `resource` both have to fetch first; everything else resolves
  // inline.
  if (selectNeedsFetch(raw)) {
    // Under `lazyLoad` the control must stay on screen while it loads: it is the
    // thing that triggered the fetch, and swapping it for a spinner would unmount
    // the picker the user just opened.
    final lazy = raw['lazyLoad'] == true;
    return RemoteSelectOptions(
      component: raw,
      formData: s.data,
      resourceSource: s.resourceSource,
      builder: (context, state) {
        if (!lazy && state.loading && state.options.isEmpty) {
          return Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: s.theme.resolvedAccentColor(s.context),
              ),
            ),
          );
        }
        if (!lazy && state.error != null && state.options.isEmpty) {
          return Text(ComponentFactory.locale.dataSourceError,
              style: s.theme.resolvedErrorStyle(s.context));
        }
        return _selectControl(
          s,
          raw,
          path,
          state.options,
          loading: state.loading,
          error: state.error,
          // Only a lazy source needs the loader; an eager one has already run,
          // and handing it over would invite a pointless second round trip.
          ensureOptions: lazy ? state.ensureLoaded : null,
        );
      },
    );
  }
  return _selectControl(s, raw, path, selectOptions(raw));
}

Widget _selectControl(
  FieldScope s,
  Map<String, dynamic> raw,
  String path,
  List<Map<String, dynamic>> options, {
  bool loading = false,
  Object? error,
  Future<List<Map<String, dynamic>>> Function()? ensureOptions,
}) {
  final disabled = raw['disabled'] == true;
  final spec = FormioSelectSpec(
    component: raw,
    options: [
      for (final o in options)
        FormioOption(label: o['label']?.toString() ?? '', value: o['value']),
    ],
    value: s.getValue(path),
    onChanged: (value) => s.setValue(path, value, immediate: true),
    label: raw['label']?.toString() ?? '',
    placeholder: raw['placeholder']?.toString(),
    enabled: !disabled,
    multiple: raw['multiple'] == true,
    required: raw['validate']?['required'] == true,
    // Form.io's own default is on, so only an explicit false turns search off.
    searchable: raw['searchEnabled'] != false,
    ensureOptions: ensureOptions == null
        ? null
        : () async => [
              for (final o in await ensureOptions())
                FormioOption(
                    label: o['label']?.toString() ?? '', value: o['value']),
            ],
    loading: loading,
    error: error,
  );

  // A host widget receives the schema already resolved, so it never needs to
  // know about dataSrc/valueProperty/template or do its own fetching.
  return s.controls.select?.call(s.context, spec) ??
      FormioBuiltInSelect(spec: spec);
}

/// Pulls a checkbox/radio label in next to its control.
Widget _tightTiles(Widget child) => ListTileTheme.merge(
      minLeadingWidth: 0,
      horizontalTitleGap: 8,
      child: child,
    );

Widget buildSelectBoxes(FieldScope s, Map<String, dynamic> raw, String path) {
  final options = selectOptions(raw);
  final disabled = raw['disabled'] == true;
  final current = s.getValue(path);
  final selected = <String, bool>{
    if (current is Map)
      for (final e in current.entries) e.key.toString(): e.value == true,
  };
  return _tightTiles(Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final o in options)
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(o['label']?.toString() ?? ''),
          value: selected[o['value']?.toString()] ?? false,
          onChanged: disabled
              ? null
              : (v) {
                  final key = o['value']?.toString();
                  if (key == null) return;
                  s.setValue(path, {...selected, key: v ?? false},
                      immediate: true);
                },
        ),
    ],
  ));
}

Widget buildCheckbox(FieldScope s, Map<String, dynamic> raw, String path) {
  final v = s.getValue(path);
  final checked = v == true || v == 'true';
  final disabled = raw['disabled'] == true;
  return _tightTiles(CheckboxListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    title: Text(labelText(raw, requiredSuffix: s.theme.requiredSuffix)),
    value: checked,
    onChanged: disabled
        ? null
        : (val) => s.setValue(path, val ?? false, immediate: true),
  ));
}

Widget buildRadio(FieldScope s, Map<String, dynamic> raw, String path) {
  final options = selectOptions(raw);
  final disabled = raw['disabled'] == true;
  final current = s.getValue(path)?.toString();
  return RadioGroup<String>(
    groupValue: current,
    onChanged:
        disabled ? (_) {} : (val) => s.setValue(path, val, immediate: true),
    child: _tightTiles(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final o in options)
          RadioListTile<String>(
            dense: true,
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(o['label']?.toString() ?? ''),
            value: o['value']?.toString() ?? '',
          ),
      ],
    )),
  );
}

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
  final current = s.getValue(path)?.toString();
  final dt = current != null ? DateTime.tryParse(current) : null;

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
    s.setValue(path, picked.toIso8601String(), immediate: true);
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

// ---- datagrid / editgrid -------------------------------------------------

Widget buildDataGrid(FieldScope s, Map<String, dynamic> raw, String path) {
  final ctx = s.context;
  final label = raw['label'] as String? ?? '';
  final children = (raw['components'] as List?) ?? const [];
  final rowsVal = s.getValue(path);
  final rows = rowsVal is List ? rowsVal : const [];
  // `disableAddingRemovingRows` fixes the row count without making the fields
  // read-only, which `disabled` also does.
  final locked =
      raw['disabled'] == true || raw['disableAddingRemovingRows'] == true;
  final loc = ComponentFactory.locale;
  final addLabel = _affixText(raw, 'addAnother') ??
      (rows.isEmpty ? loc.addEntry : loc.addAnother);
  // Reordering neither adds nor removes a row, so `disableAddingRemovingRows`
  // does not govern it — only a fully disabled grid does.
  final reorderable =
      raw['reorder'] == true && raw['disabled'] != true && rows.length > 1;

  Widget rowCard(int i) => Container(
        // ReorderableListView requires a key per child. Index-based is fine:
        // the rows' own values live in the submission, not in widget state.
        key: ValueKey('$path#row$i'),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          // The themed input border, not the ambient divider colour: a divider
          // is brighter than a form's own borders, so a row card outshone the
          // fields inside it.
          border: Border.all(color: s.theme.resolvedBorderColor(ctx)),
          borderRadius: s.theme.resolvedInputRadius(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('#${i + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                const Spacer(),
                if (reorderable)
                  // An explicit handle rather than a draggable row: the rows hold
                  // text fields, where a long-press means "select text", and the
                  // grid sits inside a scroll view that would otherwise win the
                  // drag.
                  ReorderableDragStartListener(
                    index: i,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.drag_handle, size: 20),
                    ),
                  ),
                if (!locked)
                  IconButton(
                    tooltip: _affixText(raw, 'removeRow') ?? loc.removeRow,
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () {
                      final next = [...rows]..removeAt(i);
                      s.setValue(path, next, immediate: true);
                    },
                  ),
              ],
            ),
            for (final c in children)
              if (c is Map<String, dynamic>) s.renderChild(c, '$path[$i]'),
          ],
        ),
      );

  /// [ReorderableListView.onReorderItem] already reports [newIndex] against the
  /// list with the dragged row removed, so no off-by-one adjustment is needed.
  ///
  /// The write waits for the end of the frame. The list still holds the dragged
  /// row in its overlay when this fires, and rebuilding the grid now would write
  /// the reordered values into text controllers whose fields are mid-teardown —
  /// "Cannot get renderObject of inactive element". One frame later the list has
  /// settled and the rebuild is ordinary.
  void reorder(int oldIndex, int newIndex) {
    final next = [...rows];
    next.insert(newIndex, next.removeAt(oldIndex));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      s.setValue(path, next, immediate: true);
    });
  }

  return sectionCard(
    s.theme,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(labelText(raw, requiredSuffix: s.theme.requiredSuffix),
                style: s.theme.resolvedPanelTitleStyle(ctx)),
          ),
        if (reorderable)
          ReorderableListView.builder(
            // The grid lives inside the form's own scroll view, so this list
            // contributes its natural height and never scrolls itself.
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: rows.length,
            itemBuilder: (_, i) => rowCard(i),
            onReorderItem: reorder,
          )
        else
          for (var i = 0; i < rows.length; i++) rowCard(i),
        if (!locked)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              // Accent rather than the ambient primary, which is a fill colour
              // and reads as too dark for text on a dark form.
              style: TextButton.styleFrom(
                  foregroundColor: s.theme.resolvedAccentColor(ctx)),
              icon: const Icon(Icons.add),
              label: Text(addLabel),
              onPressed: () => s.setValue(path, [...rows, <String, dynamic>{}],
                  immediate: true),
            ),
          ),
      ],
    ),
  );
}

// ---- fallback to the stock component set --------------------------------

/// Coerce engine values into the type each stock leaf widget expects.
dynamic coerceValue(String? type, dynamic v) {
  if (v == null) return null;
  switch (type) {
    case 'number':
    case 'currency':
      if (v is num) return v;
      if (v is String) return num.tryParse(v);
      return null;
    case 'checkbox':
      if (v is bool) return v;
      if (v is String) return v.toLowerCase() == 'true';
      return v == true;
    case 'textfield':
    case 'textarea':
    case 'email':
    case 'url':
    case 'phoneNumber':
    case 'password':
      return v is String ? v : v.toString();
    default:
      return v;
  }
}

/// Renders any type not handled natively via the stock [ComponentFactory]
/// (incl. host-registered custom components), guarded against build errors.
Widget buildFallback(
    FieldScope s, Map<String, dynamic> raw, String path, String? type) {
  final model = ComponentModel.fromJson(raw);
  try {
    final built = ComponentFactory.build(
      component: model,
      value: coerceValue(type, s.getValue(path)),
      onChanged: (v) => s.setValue(path, v),
      // Pass the real submission so content/html elements can interpolate
      // {{data.x}} and any stock widget can see sibling data.
      formData: s.data,
    );
    final decorationTheme = s.theme.resolvedInputDecorationTheme(s.context);
    return decorationTheme == null
        ? built
        : Theme(
            data: Theme.of(s.context)
                .copyWith(inputDecorationTheme: decorationTheme),
            child: built,
          );
  } catch (e) {
    return placeholderCard(s.context,
        '${type ?? '?'} "${raw['label'] ?? raw['key']}" — render error: $e');
  }
}
