/// Form control semantics ids must be unique per datagrid row and free of
/// regex brackets, so Maestro can match them with `id:`.
library;

import 'package:flutter_test/flutter_test.dart';

import '../support/pump_form.dart';

void main() {
  testWidgets('row controls get unique ids without brackets', (tester) async {
    await pumpForm(
      tester,
      initialData: {
        'grid': [{}, {}],
      },
      form: formOf([
        field('datagrid', 'grid', label: 'Grid', extra: {
          'components': [
            field('radio', 'choice', label: 'Choice', extra: {
              'values': [
                {'label': 'A', 'value': 'a'},
                {'label': 'B', 'value': 'b'},
              ],
            }),
            field('selectboxes', 'pick', label: 'Pick', extra: {
              'values': [
                {'label': 'X', 'value': 'x'},
                {'label': 'Y', 'value': 'y'},
              ],
            }),
          ],
        }),
        field('radio', 'solo', label: 'Solo', extra: {
          'values': [
            {'label': 'A', 'value': 'a'},
            {'label': 'B', 'value': 'b'},
          ],
        }),
      ]),
    );

    for (final id in const [
      'formio_grid_row0.choice_option_a',
      'formio_grid_row1.choice_option_a',
      'formio_grid_row0.pick_option_x',
      'formio_grid_row1.pick_option_x',
      'formio_grid_row0_remove',
      'formio_grid_row1_remove',
      'formio_grid_add',
      'formio_solo_option_a',
    ]) {
      expect(find.bySemanticsIdentifier(id), findsOneWidget, reason: id);
    }

    for (final id in const [
      'formio_choice_option_a',
      'formio_grid[0]_remove',
    ]) {
      expect(find.bySemanticsIdentifier(id), findsNothing, reason: id);
    }
  });
}
