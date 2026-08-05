/// Host hooks for the *look* of a built-in control, with its behaviour left to
/// the package.
///
/// This is deliberately narrower than `customComponents`, which replaces a
/// component outright — schema handling included. Overriding `select` that way
/// means reimplementing `dataSrc`, `valueProperty`, `template`, remote loading
/// and value coercion in the host, and a host that only wanted its own dropdown
/// widget silently loses all of it.
///
/// A control builder receives the schema already resolved: options with typed
/// values, the current value, a setter, and the loading/error state of any
/// fetch. It returns the widget. Everything else stays in one place.
library;

import 'package:flutter/material.dart';

import 'components/multi_select_field.dart';
import 'components/select_picker_field.dart';

/// One resolved option: what to show, and what to store.
@immutable
class FormioOption {
  const FormioOption({required this.label, required this.value});

  final String label;

  /// The value to store, with its schema type intact — a `valueProperty` of
  /// `id` over numeric ids yields `int`, not `"1"`.
  final Object? value;

  /// Stable key for widgets that address options by string.
  String get key => value?.toString() ?? '';

  @override
  String toString() => 'FormioOption($label -> $value)';
}

/// A select, resolved and ready to render.
@immutable
class FormioSelectSpec {
  const FormioSelectSpec({
    required this.component,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.label,
    this.placeholder,
    this.enabled = true,
    this.multiple = false,
    this.required = false,
    this.searchable = true,
    this.loading = false,
    this.error,
    this.ensureOptions,
  });

  /// The raw schema, for anything not surfaced here.
  final Map<String, dynamic> component;

  /// Options from `values`, `data.json`, or a completed fetch.
  final List<FormioOption> options;

  /// Current value — a `List` when [multiple].
  final Object? value;

  /// Store a new value. Pass a `List` when [multiple].
  final ValueChanged<Object?> onChanged;

  final String label;
  final String? placeholder;
  final bool enabled;
  final bool multiple;
  final bool required;

  /// The schema's `searchEnabled`, defaulting to true as Form.io does.
  ///
  /// Worth honouring rather than guessing from the option count: the sample
  /// forms set it explicitly on 333 of 333 selects, and 17 of those turn it
  /// *off* on lists long enough that a size heuristic would have added it.
  final bool searchable;

  /// A fetch is in flight. [options] may already hold a cached result.
  final bool loading;

  /// The fetch failed. Worth showing rather than offering an empty list.
  final Object? error;

  /// Loads the options, for a remote source that sets `lazyLoad`.
  ///
  /// Null when the options are already resolved. When it is not null, [options]
  /// is empty until this has run: `lazyLoad` exists so a form with thirty
  /// remote selects makes no requests until one is opened.
  ///
  /// It resolves *with* the options rather than only triggering the fetch,
  /// because a control that opens a picker on its own route cannot receive them
  /// afterwards. Await it, then render what it returns.
  ///
  /// Idempotent — concurrent callers share one request — and safe to call from a
  /// `build`.
  final Future<List<FormioOption>> Function()? ensureOptions;

  /// [ensureOptions] in the `{label, value}` shape the built-in pickers take.
  Future<List<Map<String, dynamic>>> Function()? get _rawLoader {
    final load = ensureOptions;
    if (load == null) return null;
    return () async => [
          for (final o in await load()) {'label': o.label, 'value': o.value},
        ];
  }

  /// The option matching [value], or null when the stored value is not among
  /// them — which happens when a saved value predates a change to the source.
  FormioOption? get selected {
    final current = value?.toString();
    for (final option in options) {
      if (option.key == current) return option;
    }
    return null;
  }
}

typedef FormioSelectBuilder = Widget Function(
    BuildContext context, FormioSelectSpec spec);

/// Per-control presentation overrides. Any left null keeps the built-in widget.
@immutable
class FormioControlBuilders {
  const FormioControlBuilders({this.select});

  /// Renders `select` (single and multiple). Behaviour — including `dataSrc`
  /// resolution and remote loading — stays in the package.
  final FormioSelectBuilder? select;

  bool get isEmpty => select == null;
}

/// The package's own select, rendered from a [FormioSelectSpec].
///
/// Lets a host builder delegate the cases it does not want to style — returning
/// this for `spec.multiple`, say — instead of degrading the control or
/// reimplementing it.
class FormioBuiltInSelect extends StatelessWidget {
  const FormioBuiltInSelect({super.key, required this.spec});

  final FormioSelectSpec spec;

  @override
  Widget build(BuildContext context) {
    if (spec.multiple) {
      final current = spec.value;
      return MultiSelectField(
        options: [
          for (final o in spec.options) {'label': o.label, 'value': o.value},
        ],
        selected: (current is List ? current : const [])
            .map((e) => e?.toString())
            .whereType<String>()
            .where((e) => e.isNotEmpty)
            .toSet(),
        hint: spec.placeholder,
        enabled: spec.enabled,
        searchable: spec.searchable,
        loadOptions: spec._rawLoader,
        onChanged: (keys) {
          // Map the chosen keys back to their typed values.
          final byKey = {for (final o in spec.options) o.key: o.value};
          spec.onChanged([
            for (final key in keys)
              if (byKey.containsKey(key)) byKey[key] else key,
          ]);
        },
      );
    }

    final selected = spec.selected;
    // A searchable select needs a picker: DropdownButton has no room for a
    // search box, so it stays the widget for the short, unsearchable lists it
    // suits.
    if (spec.searchable) {
      return SelectPickerField(
        options: [
          for (final o in spec.options) {'label': o.label, 'value': o.value},
        ],
        selected: selected?.key ?? spec.value?.toString(),
        hint: spec.placeholder,
        enabled: spec.enabled,
        loadOptions: spec._rawLoader,
        onChanged: (key) {
          for (final o in spec.options) {
            if (o.key == key) {
              spec.onChanged(o.value);
              return;
            }
          }
        },
      );
    }

    return DropdownButton<String>(
      isExpanded: true,
      // A plain dropdown cannot await, so a lazy source is simply asked to
      // start loading; the menu fills on the following build.
      onTap: spec.ensureOptions == null ? null : () => spec.ensureOptions!(),
      value: selected?.key,
      hint: Text(spec.placeholder ?? 'Select…'),
      items: [
        for (final o in spec.options)
          DropdownMenuItem(value: o.key, child: Text(o.label)),
      ],
      onChanged: spec.enabled
          ? (key) {
              for (final o in spec.options) {
                if (o.key == key) {
                  // Write the option's own value so its schema type survives.
                  spec.onChanged(o.value);
                  return;
                }
              }
            }
          : null,
    );
  }
}
