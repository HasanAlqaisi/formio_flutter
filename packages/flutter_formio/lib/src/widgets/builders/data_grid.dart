/// datagrid / editgrid: a repeating set of rows.
library;

import 'package:flutter/material.dart';
import 'package:formio/formio.dart';

import '../form_field_scope.dart';
import 'field_chrome.dart';
import 'schema_text.dart';

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
  final addLabel = affixText(raw, 'addAnother') ??
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
                    tooltip: affixText(raw, 'removeRow') ?? loc.removeRow,
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
