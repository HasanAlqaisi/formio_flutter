/// `reorder: true` lets a datagrid's rows be dragged into a different order.
///
/// 12 of the 85 datagrids in the sample forms ask for it and nothing read the
/// flag, so those rows were fixed in the order they were entered.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_form.dart';

void main() {
  Future<Map<String, dynamic>> pump(
    WidgetTester tester, {
    bool reorder = false,
    bool disabled = false,
    bool disableAddingRemovingRows = false,
    List<Map<String, dynamic>> rows = const [
      {'name': 'Ada'},
      {'name': 'Grace'},
      {'name': 'Hedy'},
    ],
  }) async {
    return pumpForm(
      tester,
      initialData: {'people': rows},
      // No scroll wrapper: the renderer provides its own scroll view, which is
      // exactly why the reorderable list must not scroll itself.
      form: formOf([
        field('datagrid', 'people', label: 'People', extra: {
          'reorder': reorder,
          'disabled': disabled,
          'disableAddingRemovingRows': disableAddingRemovingRows,
          'components': [field('textfield', 'name', label: 'Name')],
        }),
      ]),
    );
  }

  List<String?> namesIn(Map<String, dynamic> data) => [
        for (final r in (data['people'] as List? ?? const []))
          r is Map ? r['name'] as String? : null,
      ];

  testWidgets('no handle without the flag', (tester) async {
    await pump(tester);
    expect(find.byIcon(Icons.drag_handle), findsNothing);
    expect(find.byType(ReorderableListView), findsNothing);
  });

  testWidgets('reorder: true gives every row a drag handle', (tester) async {
    await pump(tester, reorder: true);
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(3));
  });

  testWidgets('dragging a row moves it in the submission', (tester) async {
    final data = await pump(tester, reorder: true);
    expect(namesIn(data), ['Ada', 'Grace', 'Hedy']);

    // Drag the first row's handle down past the second.
    final handle = find.byIcon(Icons.drag_handle).first;
    final start = tester.getCenter(handle);
    // An explicit handle starts the drag immediately — no long-press needed.
    final gesture = await tester.startGesture(start);
    await tester.pump();
    // Incremental moves: one big jump can be dropped by the drag recogniser.
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 16));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(namesIn(data), ['Grace', 'Ada', 'Hedy']);
  });

  testWidgets('a disabled grid cannot be reordered', (tester) async {
    await pump(tester, reorder: true, disabled: true);
    expect(find.byIcon(Icons.drag_handle), findsNothing);
  });

  testWidgets('disableAddingRemovingRows still allows reordering',
      (tester) async {
    // Reordering neither adds nor removes a row, so the flag does not govern it.
    await pump(tester, reorder: true, disableAddingRemovingRows: true);
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(3));
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('a single row shows no handle', (tester) async {
    await pump(tester, reorder: true, rows: const [
      {'name': 'Ada'}
    ]);
    expect(find.byIcon(Icons.drag_handle), findsNothing);
  });
}
