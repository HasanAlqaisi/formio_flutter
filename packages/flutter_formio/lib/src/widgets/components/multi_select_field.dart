/// Dropdown-style multi-select for Form.io `select` components with
/// `multiple: true`.
///
/// Shows the current selection as chips inside a tappable, dropdown-like field
/// and opens a searchable checklist to change it. This mirrors Form.io's own
/// `choicesjs` multi-select and scales to large option sets
library;

import 'package:flutter/material.dart';
import 'package:formio/formio.dart';

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

  /// Available options as `{label, value}` maps.
  final List<Map<String, dynamic>> options;

  /// Currently-selected option values (as strings).
  final Set<String> selected;

  /// Called with the new selection whenever it changes.
  final ValueChanged<List<String>> onChanged;

  /// Placeholder shown when nothing is selected.
  final String? hint;

  final bool enabled;

  /// Whether the checklist offers a search field (`searchEnabled`).
  final bool searchable;

  /// Loads the options as the checklist opens, for a `lazyLoad` source.
  ///
  /// Awaited before the list is shown, and its result is what gets rendered —
  /// the dialog is on its own route, so a later arrival would never reach it.
  final Future<List<Map<String, dynamic>>> Function()? loadOptions;

  String _labelFor(String value) {
    for (final o in options) {
      if (o['value']?.toString() == value) {
        return o['label']?.toString() ?? value;
      }
    }
    return value;
  }

  Future<void> _open(BuildContext context) async {
    final available = await loadOptions?.call() ?? options;
    if (!context.mounted) return;
    final theme = FormioThemeScope.of(context);
    final temp = {...selected};
    var query = '';
    final result = await showDialog<List<String>>(
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
                              final val = filtered[i]['value']?.toString();
                              return CheckboxListTile(
                                dense: true,
                                value: val != null && temp.contains(val),
                                title: Text(
                                    filtered[i]['label']?.toString() ?? ''),
                                onChanged: val == null
                                    ? null
                                    : (sel) => setState(() => sel == true
                                        ? temp.add(val)
                                        : temp.remove(val)),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                style: theme.resolvedSecondaryActionStyle(context),
                onPressed: () => Navigator.pop(ctx),
                child: Text(ComponentFactory.locale.cancel),
              ),
              FilledButton(
                style: theme.resolvedPrimaryActionStyle(context),
                onPressed: () => Navigator.pop(ctx, temp.toList()),
                child: Text(ComponentFactory.locale.save),
              ),
            ],
          );
        },
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FormioThemeScope.of(context);

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
        child: selected.isEmpty
            ? Text(
                hint ?? '',
                style: theme.hintStyle ??
                    TextStyle(color: Theme.of(context).hintColor),
              )
            : Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final v in selected)
                    Chip(
                      label: Text(_labelFor(v)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onDeleted: enabled
                          ? () =>
                              onChanged(selected.where((x) => x != v).toList())
                          : null,
                    ),
                ],
              ),
      ),
    );
  }
}
