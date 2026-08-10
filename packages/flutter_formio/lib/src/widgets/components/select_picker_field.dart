/// Single-choice picker for a `select` whose schema asks for search.
///
/// [DropdownButton] cannot host a search box, so `searchEnabled: true` had
/// nowhere to land — the renderer ignored it outright and a 300-option select
/// was a scroll-and-hope list. 316 of the 333 selects in the sample forms set
/// it, so "ignored" was the common case, not the edge one.
///
/// The field shell and the chooser are shared with [MultiSelectField]; only the
/// closed-state display differs.
library;

import 'package:flutter/material.dart';

import '../form_theme.dart';
import 'option_picker.dart';
import 'select_options.dart' show FormioOption;

class SelectPickerField extends StatelessWidget {
  const SelectPickerField({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.storedValue,
    this.hint,
    this.enabled = true,
    this.searchable = true,
    this.loadOptions,
  });

  final List<FormioOption> options;

  /// The current selection, or null. Not required to be one of [options]: a
  /// stored value can outlive a change to its option source.
  final FormioOption? selected;

  /// The raw stored value. Shown when it matches no option, so a saved answer
  /// that outlived its option source still reads as data rather than as an empty
  /// field.
  final Object? storedValue;

  final ValueChanged<FormioOption> onChanged;

  final String? hint;
  final bool enabled;

  /// Whether the chooser offers a search field (`searchEnabled`).
  final bool searchable;

  /// Loads the options as the chooser opens, for a `lazyLoad` source.
  final Future<List<FormioOption>> Function()? loadOptions;

  Future<void> _open(BuildContext context) async {
    final result = await showOptionPicker(
      context: context,
      options: options,
      selectedKeys: {if (selected != null) selected!.key},
      multiple: false,
      searchable: searchable,
      title: hint,
      loadOptions: loadOptions,
    );
    if (result != null && result.isNotEmpty) onChanged(result.first);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FormioThemeScope.of(context);
    final label = selected?.label ?? storedValue?.toString();

    return OptionFieldShell(
      enabled: enabled,
      onTap: () => _open(context),
      child: (label == null || label.isEmpty)
          ? optionPlaceholder(context, hint)
          : Text(label, style: theme.inputTextStyle),
    );
  }
}
