/// Option-based controls: select, selectboxes, checkbox, radio.
library;

import 'package:flutter/material.dart';
import 'package:formio/formio.dart';

import '../form_field_scope.dart';
import 'schema_text.dart';

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
    options: typedOptions(options),
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
        : () async => typedOptions(await ensureOptions()),
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
    title: labelWithRequired(raw['label'] as String? ?? '',
        required: raw['validate']?['required'] == true,
        theme: s.theme,
        context: s.context),
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
