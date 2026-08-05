/// The parts a single- and multi-select share: the tappable field, and the
/// searchable chooser behind it.
///
/// These were duplicated across [SelectPickerField] and [MultiSelectField] —
/// 84 identical lines out of ~140 each — and the copies had already drifted:
/// one read the form's theme tokens while the other kept a hardcoded
/// `OutlineInputBorder` with no fill, so a multi-select rendered visibly unlike
/// the text inputs beside it. Sharing the pieces is what stops that recurring.
library;

import 'package:flutter/material.dart';

import '../component_factory.dart' show ComponentFactory;
import '../form_theme.dart';
import 'select_options.dart' show FormioOption;

/// The closed control: a tappable box wearing the form's input decoration.
///
/// [child] is whatever the concrete control shows for its current value — one
/// label, or a row of chips.
class OptionFieldShell extends StatelessWidget {
  const OptionFieldShell({
    super.key,
    required this.onTap,
    required this.child,
    this.enabled = true,
  });

  final VoidCallback? onTap;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = FormioThemeScope.of(context);

    return InkWell(
      onTap: enabled ? onTap : null,
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
        child: child,
      ),
    );
  }
}

/// Placeholder text in the form's hint style.
Widget optionPlaceholder(BuildContext context, String? hint) {
  final theme = FormioThemeScope.of(context);
  return Text(
    hint ?? '',
    style: theme.hintStyle ?? TextStyle(color: Theme.of(context).hintColor),
  );
}

/// Opens the chooser and resolves with the selection, or null if dismissed.
///
/// One function for both shapes. With [multiple] false a tap picks and closes —
/// a single choice needs no confirm step — and the result holds at most one
/// option. With [multiple] true the rows are checkboxes and the result is
/// whatever was ticked when Save was pressed.
///
/// [loadOptions] is awaited *before* the dialog is shown and its result is what
/// gets rendered: the dialog sits on its own route, so options arriving later
/// would never reach it. That is how `lazyLoad` is honoured.
Future<List<FormioOption>?> showOptionPicker({
  required BuildContext context,
  required List<FormioOption> options,
  required Set<String> selectedKeys,
  required bool multiple,
  required bool searchable,
  String? title,
  Future<List<FormioOption>> Function()? loadOptions,
}) async {
  final available = await loadOptions?.call() ?? options;
  if (!context.mounted) return null;

  final theme = FormioThemeScope.of(context);
  final loc = ComponentFactory.locale;
  final chosen = {...selectedKeys};
  var query = '';

  return showDialog<List<FormioOption>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) {
        final needle = query.toLowerCase();
        final visible = needle.isEmpty
            ? available
            : [
                for (final option in available)
                  if (option.label.toLowerCase().contains(needle)) option,
              ];

        return AlertDialog(
          title: title == null ? null : Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (searchable) ...[
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: loc.searchPlaceholder,
                    ),
                    onChanged: (value) => setState(() => query = value),
                  ),
                  const SizedBox(height: 8),
                ],
                Flexible(
                  child: visible.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(loc.noOptions),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: visible.length,
                          itemBuilder: (_, i) {
                            final option = visible[i];
                            final isSelected = chosen.contains(option.key);
                            if (!multiple) {
                              return ListTile(
                                dense: true,
                                selected: isSelected,
                                // Without this the selected row takes
                                // `colorScheme.primary`, a fill colour that is
                                // unreadable as text on a dark sheet.
                                selectedColor:
                                    theme.resolvedAccentColor(context),
                                title: Text(option.label),
                                trailing:
                                    isSelected ? const Icon(Icons.check) : null,
                                onTap: () =>
                                    Navigator.pop(dialogContext, [option]),
                              );
                            }
                            return CheckboxListTile(
                              dense: true,
                              value: isSelected,
                              title: Text(option.label),
                              onChanged: (ticked) => setState(() =>
                                  ticked == true
                                      ? chosen.add(option.key)
                                      : chosen.remove(option.key)),
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
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(loc.cancel),
            ),
            if (multiple)
              FilledButton(
                style: theme.resolvedPrimaryActionStyle(context),
                onPressed: () => Navigator.pop(dialogContext, [
                  // Preserve the source order rather than tick order, so the
                  // chips read the same way the list did.
                  for (final option in available)
                    if (chosen.contains(option.key)) option,
                ]),
                child: Text(loc.save),
              ),
          ],
        );
      },
    ),
  );
}
