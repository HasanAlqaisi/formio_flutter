/// Dropdown-style multi-select for Form.io `select` components with
/// `multiple: true`.
///
/// Shows the current selection as chips inside a tappable, dropdown-like field
/// and opens a searchable checklist to change it. This mirrors Form.io's own
/// `choicesjs` multi-select and scales to large option sets.
///
/// The field shell and the chooser are shared with [SelectPickerField]; only the
/// closed-state display and the confirm step differ.
library;

import 'package:flutter/material.dart';

import 'option_picker.dart';
import 'select_options.dart' show FormioOption;

class MultiSelectField extends StatelessWidget {
  const MultiSelectField({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.hint,
    this.enabled = true,
    this.searchable = true,
    this.loadOptions,
  });

  final List<FormioOption> options;

  /// The current selection. Entries need not appear in [options]: a stored value
  /// can outlive a change to its option source, and dropping it silently would
  /// lose data.
  final List<FormioOption> selected;

  final ValueChanged<List<FormioOption>> onChanged;

  /// Placeholder shown when nothing is selected.
  final String? hint;

  final bool enabled;

  /// Whether the checklist offers a search field (`searchEnabled`).
  final bool searchable;

  /// Loads the options as the checklist opens, for a `lazyLoad` source.
  final Future<List<FormioOption>> Function()? loadOptions;

  Future<void> _open(BuildContext context) async {
    final result = await showOptionPicker(
      context: context,
      options: options,
      selectedKeys: {for (final option in selected) option.key},
      multiple: true,
      searchable: searchable,
      title: hint,
      loadOptions: loadOptions,
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return OptionFieldShell(
      enabled: enabled,
      onTap: () => _open(context),
      child: selected.isEmpty
          ? optionPlaceholder(context, hint)
          : Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final option in selected)
                  Chip(
                    label: Text(option.label),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onDeleted: enabled
                        ? () => onChanged([
                              for (final other in selected)
                                if (other.key != option.key) other,
                            ])
                        : null,
                  ),
              ],
            ),
    );
  }
}
