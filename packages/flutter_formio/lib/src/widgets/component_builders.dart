/// Stateless widget builders for each Form.io component type, used by
/// [EngineFormRenderer]. Each builder reads/writes through a [FieldScope] and
/// returns a widget; layout/array builders recurse via `scope.renderChild`.
library;

import 'package:flutter/material.dart';
import 'package:formio/formio.dart';

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

  final labelWidget = label.isEmpty
      ? null
      : Text(required ? '$label${s.theme.requiredSuffix}' : label,
          style: s.theme.resolvedLabelStyle(ctx));

  Widget labeled;
  if (labelWidget == null) {
    labeled = control;
  } else if (pos.startsWith('left') || pos.startsWith('right')) {
    final lw = (raw['labelWidth'] as num?)?.toInt().clamp(10, 90) ?? 30;
    final labelCell = Expanded(flex: lw, child: labelWidget);
    final fieldCell = Expanded(flex: 100 - lw, child: control);
    labeled = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: pos.startsWith('left')
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
      return e.setting != null
          ? loc.getMinLengthMessage(e.setting!)
          : loc.invalidValue;
    case 'maxLength':
      return e.setting != null
          ? loc.getMaxLengthMessage(e.setting!)
          : loc.invalidValue;
    case 'min':
      return e.setting != null
          ? loc.getMinValueMessage(e.setting!)
          : loc.invalidValue;
    case 'max':
      return e.setting != null
          ? loc.getMaxValueMessage(e.setting!)
          : loc.invalidValue;
    default:
      // minWords / maxWords / unique / …
      return loc.invalidValue;
  }
}

Widget placeholderCard(BuildContext ctx, String text) => Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: const TextStyle(color: Colors.orange)),
    );

// ---- text inputs (controller-bound; live calc / read-only) ---------------

Widget buildTextLeaf(
    FieldScope s, Map<String, dynamic> raw, String path, String type) {
  final ctx = s.context;
  final controller = s.controllerFor(path);
  final focus = s.focusFor(path);

  final engineValue = s.getValue(path)?.toString() ?? '';
  if (!focus.hasFocus && controller.text != engineValue) {
    controller.text = engineValue;
  }

  final readOnly = raw['disabled'] == true || raw['readOnly'] == true;
  final isNumber = type == 'number' || type == 'currency';

  return TextField(
    controller: controller,
    focusNode: focus,
    readOnly: readOnly,
    obscureText: type == 'password',
    keyboardType: type == 'textarea'
        ? TextInputType.multiline
        : isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
    maxLines: type == 'textarea' ? (raw['rows'] as num?)?.toInt() ?? 3 : 1,
    decoration: InputDecoration(
      isDense: s.theme.isDense,
      border: s.theme.resolvedInputBorder(ctx),
      contentPadding: s.theme.inputContentPadding,
      hintText: raw['placeholder'] as String?,
      prefixText: (raw['prefix'] as String?)?.isNotEmpty == true
          ? raw['prefix'] as String
          : null,
      suffixText: (raw['suffix'] as String?)?.isNotEmpty == true
          ? raw['suffix'] as String
          : null,
      fillColor:
          readOnly ? Theme.of(ctx).disabledColor.withValues(alpha: 0.05) : null,
      filled: readOnly,
    ),
    onChanged: readOnly
        ? null
        : (v) => s.setValue(path, isNumber ? (num.tryParse(v) ?? v) : v),
  );
}

// ---- select / selectboxes / checkbox / radio -----------------------------

List<Map<String, dynamic>> selectOptions(Map<String, dynamic> raw) {
  final data = raw['data'];
  final values = (raw['values'] as List?) ??
      (data is Map ? data['values'] as List? : null) ??
      const [];
  return [
    for (final v in values)
      if (v is Map<String, dynamic>) v,
  ];
}

Widget buildSelect(FieldScope s, Map<String, dynamic> raw, String path) {
  final options = selectOptions(raw);
  final multiple = raw['multiple'] == true;
  final disabled = raw['disabled'] == true;
  final current = s.getValue(path);

  if (multiple) {
    final selected = (current is List ? current : const [])
        .map((e) => e?.toString())
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .toSet();
    return MultiSelectField(
      options: options,
      selected: selected,
      hint: raw['placeholder'] as String?,
      enabled: !disabled,
      onChanged: (vals) => s.setValue(path, vals, immediate: true),
    );
  }

  final currentStr = current?.toString();
  final valueInItems = options.any((o) => o['value']?.toString() == currentStr);
  return DropdownButton<String>(
    isExpanded: true,
    value: valueInItems ? currentStr : null,
    hint: Text(raw['placeholder'] as String? ?? 'Select…'),
    items: [
      for (final o in options)
        DropdownMenuItem(
          value: o['value']?.toString(),
          child: Text(o['label']?.toString() ?? ''),
        ),
    ],
    onChanged: disabled ? null : (v) => s.setValue(path, v, immediate: true),
  );
}

Widget buildSelectBoxes(FieldScope s, Map<String, dynamic> raw, String path) {
  final options = selectOptions(raw);
  final disabled = raw['disabled'] == true;
  final current = s.getValue(path);
  final selected = <String, bool>{
    if (current is Map)
      for (final e in current.entries) e.key.toString(): e.value == true,
  };
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final o in options)
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
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
  );
}

Widget buildCheckbox(FieldScope s, Map<String, dynamic> raw, String path) {
  final v = s.getValue(path);
  final checked = v == true || v == 'true';
  final disabled = raw['disabled'] == true;
  return CheckboxListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    title: Text(labelText(raw, requiredSuffix: s.theme.requiredSuffix)),
    value: checked,
    onChanged: disabled
        ? null
        : (val) => s.setValue(path, val ?? false, immediate: true),
  );
}

Widget buildRadio(FieldScope s, Map<String, dynamic> raw, String path) {
  final options = selectOptions(raw);
  final disabled = raw['disabled'] == true;
  final current = s.getValue(path)?.toString();
  return RadioGroup<String>(
    groupValue: current,
    onChanged:
        disabled ? (_) {} : (val) => s.setValue(path, val, immediate: true),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final o in options)
          RadioListTile<String>(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(o['label']?.toString() ?? ''),
            value: o['value']?.toString() ?? '',
          ),
      ],
    ),
  );
}

// ---- date / datetime / time ---------------------------------------------

String _two(int n) => n.toString().padLeft(2, '0');

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
    final d = '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';
    final t = '${_two(dt.hour)}:${_two(dt.minute)}';
    if (enableDate && enableTime) return '$d $t';
    if (enableTime) return t;
    return d;
  }

  Future<void> pick() async {
    var picked = dt ?? DateTime.now();
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
    s.setValue(path, picked.toIso8601String(), immediate: true);
  }

  return InkWell(
    onTap: disabled ? null : pick,
    child: InputDecorator(
      decoration: InputDecoration(
        isDense: s.theme.isDense,
        border: s.theme.resolvedInputBorder(ctx),
        contentPadding: s.theme.inputContentPadding,
        suffixIcon: Icon(enableTime && !enableDate
            ? Icons.access_time
            : Icons.calendar_today),
        fillColor: disabled
            ? Theme.of(ctx).disabledColor.withValues(alpha: 0.05)
            : null,
        filled: disabled,
      ),
      child: Text(display(),
          style: TextStyle(color: dt == null ? Theme.of(ctx).hintColor : null)),
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
  final disabled = raw['disabled'] == true;

  return Card(
    margin: s.theme.sectionMargin,
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                  labelText(raw, requiredSuffix: s.theme.requiredSuffix),
                  style: s.theme.resolvedPanelTitleStyle(ctx)),
            ),
          for (var i = 0; i < rows.length; i++)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(ctx).dividerColor),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('#${i + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      if (!disabled)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () {
                            final next = [...rows]..removeAt(i);
                            s.setValue(path, next, immediate: true);
                          },
                        ),
                    ],
                  ),
                  for (final c in children)
                    if (c is Map<String, dynamic>)
                      s.renderChild(c, '$path[$i]'),
                ],
              ),
            ),
          if (!disabled)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add'),
                onPressed: () => s.setValue(
                    path, [...rows, <String, dynamic>{}],
                    immediate: true),
              ),
            ),
        ],
      ),
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
    return ComponentFactory.build(
      component: model,
      value: coerceValue(type, s.getValue(path)),
      onChanged: (v) => s.setValue(path, v),
      // Pass the real submission so content/html elements can interpolate
      // {{data.x}} and any stock widget can see sibling data.
      formData: s.data,
    );
  } catch (e) {
    return placeholderCard(s.context,
        '${type ?? '?'} "${raw['label'] ?? raw['key']}" — render error: $e');
  }
}
