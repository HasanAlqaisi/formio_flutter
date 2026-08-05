/// Single-choice picker for a `select` whose schema asks for search.
///
/// [DropdownButton] cannot host a search box, so `searchEnabled: true` had
/// nowhere to land — the renderer ignored it outright and a 300-option select
/// was a scroll-and-hope list. 316 of the 333 selects in the sample forms set
/// it, so "ignored" was the common case, not the edge one.
///
/// The multi-select equivalent already worked this way; this is its single-value
/// counterpart, so both shapes of `select` search the same.
library;

import 'package:flutter/material.dart';
import 'package:formio/formio.dart';

class SelectPickerField extends StatelessWidget {
  const SelectPickerField({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.hint,
    this.enabled = true,
    this.searchable = true,
    this.loadOptions,
  });

  /// Available options as `{label, value}` maps.
  final List<Map<String, dynamic>> options;

  /// The selected option's value as a string, or null.
  final String? selected;

  /// Called with the chosen value, or null when the choice is cleared.
  final ValueChanged<String?> onChanged;

  final String? hint;
  final bool enabled;

  /// Whether the picker offers a search field (`searchEnabled`).
  final bool searchable;

  /// Loads the options as the picker opens, for a `lazyLoad` source.
  ///
  /// Awaited *before* the list is shown, and its result is what gets rendered:
  /// the dialog sits on its own route, so options arriving later would never
  /// reach it. Null for a source that is already resolved.
  final Future<List<Map<String, dynamic>>> Function()? loadOptions;

  String? _labelFor(String value) {
    for (final o in options) {
      if (o['value']?.toString() == value) {
        return o['label']?.toString() ?? value;
      }
    }
    return null;
  }

  Future<void> _open(BuildContext context) async {
    // Fresh from the loader when there is one; otherwise what we were given.
    final available = await loadOptions?.call() ?? options;
    if (!context.mounted) return;
    final formioTheme = FormioThemeScope.of(context);
    var query = '';
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final q = query.toLowerCase();
          final filtered = q.isEmpty
              ? available
              : available
                  .where((o) =>
                      (o['label']?.toString() ?? '').toLowerCase().contains(q))
                  .toList();
          return AlertDialog(
            title: Text(hint ?? ComponentFactory.locale.searchPlaceholder),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (searchable)
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: ComponentFactory.locale.searchPlaceholder,
                      ),
                      onChanged: (v) => setState(() => query = v),
                    ),
                  if (searchable) const SizedBox(height: 8),
                  Flexible(
                    child: filtered.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(ComponentFactory.locale.noOptions),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final value = filtered[i]['value']?.toString();
                              final isSelected = value == selected;
                              return ListTile(
                                dense: true,
                                selected: isSelected,
                                // Without this the selected row takes
                                // `colorScheme.primary`, which is a fill colour
                                // and unreadable as text on a dark sheet.
                                selectedColor:
                                    formioTheme.resolvedAccentColor(context),
                                title: Text(
                                    filtered[i]['label']?.toString() ?? ''),
                                trailing:
                                    isSelected ? const Icon(Icons.check) : null,
                                // One tap picks and closes: a single choice
                                // needs no confirm step.
                                onTap: value == null
                                    ? null
                                    : () => Navigator.pop(ctx, value),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                style: formioTheme.resolvedSecondaryActionStyle(context),
                onPressed: () => Navigator.pop(ctx),
                child: Text(ComponentFactory.locale.cancel),
              ),
            ],
          );
        },
      ),
    );
    if (chosen != null) onChanged(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FormioThemeScope.of(context);
    final label = selected == null ? null : _labelFor(selected!);

    return InkWell(
      onTap: enabled ? () => _open(context) : null,
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: theme.isDense,
          border: theme.resolvedInputBorder(context),
          enabledBorder: theme.inputBorder,
          contentPadding: theme.inputContentPadding,
          fillColor: theme.inputFillColor,
          filled: theme.inputFillColor != null,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        // A stored value that is no longer among the options still shows, rather
        // than reading as an empty field — a saved answer outliving a change to
        // its option source is data, not nothing.
        child: label == null
            ? Text(
                selected ?? hint ?? '',
                style: selected != null
                    ? theme.inputTextStyle
                    : (theme.hintStyle ??
                        TextStyle(color: Theme.of(context).hintColor)),
              )
            : Text(label, style: theme.inputTextStyle),
      ),
    );
  }
}
