/// Form control semantics ids must be unique per datagrid row and free of
/// regex metacharacters, so Maestro can match them with `id:`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formio/formio.dart';

import '../support/pump_form.dart';

/// `values` for an option control, built from bare value strings.
Map<String, dynamic> options(List<String> values) => {
      'values': [
        for (final v in values) {'label': v.toUpperCase(), 'value': v},
      ],
    };

void main() {
  group('formioSemanticsId', () {
    test('writes each row index as _row<i>', () {
      expect(formioSemanticsId('grid[0].choice'), 'formio_grid_row0_choice');
      expect(formioSemanticsId('a[2].b[10].c'), 'formio_a_row2_b_row10_c');
    });

    test('flattens everything outside [A-Za-z0-9_]', () {
      // A dot matches any character under regex, so it cannot stay either.
      expect(formioSemanticsId('one.two'), 'formio_one_two');
      expect(formioSemanticsId('a-b c'), 'formio_a_b_c');
    });

    test('leaves a plain key alone', () {
      expect(formioSemanticsId('choice'), 'formio_choice');
    });
  });

  testWidgets('row controls get unique ids without brackets', (tester) async {
    await pumpForm(
      tester,
      initialData: {
        'grid': [{}, {}],
      },
      form: formOf([
        field('datagrid', 'grid', label: 'Grid', extra: {
          'components': [
            field('radio', 'choice', label: 'Choice', extra: options(['a'])),
            field('selectboxes', 'pick', label: 'Pick', extra: options(['x'])),
          ],
        }),
        field('radio', 'solo', label: 'Solo', extra: options(['a'])),
      ]),
    );

    for (final id in const [
      'formio_grid_row0_choice_option_a',
      'formio_grid_row1_choice_option_a',
      'formio_grid_row0_pick_option_x',
      'formio_grid_row1_pick_option_x',
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
      'formio_grid_row0.choice_option_a',
    ]) {
      expect(find.bySemanticsIdentifier(id), findsNothing, reason: id);
    }
  });

  testWidgets('stock components in a row get the row path, not their key',
      (tester) async {
    // These are built by ComponentFactory, which only ever sees the schema
    // key — the same key in both rows. They read the path off the scope the
    // fallback builder wraps them in.
    await pumpForm(
      tester,
      initialData: {
        'grid': [{}, {}],
      },
      form: formOf([
        field('datagrid', 'grid', label: 'Grid', extra: {
          'components': [
            field('day', 'dob', label: 'DOB'),
            field('signature', 'sig', label: 'Sig'),
            field('file', 'doc', label: 'Doc'),
          ],
        }),
      ]),
    );

    for (final id in const [
      'formio_grid_row0_dob_month',
      'formio_grid_row1_dob_month',
      'formio_grid_row0_sig_pad',
      'formio_grid_row1_sig_pad',
      'formio_grid_row0_sig_clear',
      'formio_grid_row1_sig_clear',
      'formio_grid_row0_doc_upload',
      'formio_grid_row1_doc_upload',
    ]) {
      expect(find.bySemanticsIdentifier(id), findsOneWidget, reason: id);
    }

    // The key-only ids every row used to share.
    for (final id in const [
      'formio_dob_month',
      'formio_sig_pad',
      'formio_doc_upload',
    ]) {
      expect(find.bySemanticsIdentifier(id), findsNothing, reason: id);
    }
  });

  testWidgets('a container scopes the keys it nests', (tester) async {
    // `container` nests the data path, so the same key under two of them is
    // legal — and used to give two controls one id.
    await pumpForm(
      tester,
      form: formOf([
        for (final name in ['home', 'work'])
          field('container', name, extra: {
            'components': [field('signature', 'sig', label: 'Sig')],
          }),
      ]),
    );

    expect(find.bySemanticsIdentifier('formio_home_sig_pad'), findsOneWidget);
    expect(find.bySemanticsIdentifier('formio_work_sig_pad'), findsOneWidget);
    expect(find.bySemanticsIdentifier('formio_sig_pad'), findsNothing);
  });

  testWidgets('option values keep no regex metacharacters', (tester) async {
    await pumpForm(
      tester,
      form: formOf([
        field('radio', 'r', label: 'R', extra: options(['a+b', 'c (d)'])),
      ]),
    );

    // `formio_r_option_a+b` would match "ab" under regex, never itself.
    expect(find.bySemanticsIdentifier('formio_r_option_a_b'), findsOneWidget);
    expect(find.bySemanticsIdentifier('formio_r_option_c__d_'), findsOneWidget);
  });

  testWidgets('a component built outside the renderer falls back to its key',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SignatureComponent(
          component: ComponentModel.fromJson(field('signature', 'sig')),
          value: null,
          onChanged: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('formio_sig_pad'), findsOneWidget);
  });
}
