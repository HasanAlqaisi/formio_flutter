/// A host custom component's writes must reach the submission.
///
/// This is the seam host types like `fmsfile` depend on: if the renderer derives
/// an empty path for an unknown type, `setValue` is dropped with only a debug
/// warning and the field silently submits its default.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formio/formio.dart';

import 'support/pump_form.dart';

void main() {
  /// A minimal host component that appends to a list value, the shape a file
  /// upload uses.
  Widget appender(FormioFieldContext ctx) => TextButton(
        onPressed: () {
          final current =
              ctx.value is List ? [...ctx.value as List] : <dynamic>[];
          ctx.setValue([
            ...current,
            {'name': 'file${current.length + 1}.pdf', 'storage': 'fms'},
          ], immediate: true);
        },
        child: const Text('ADD'),
      );

  testWidgets('a custom type with input: true lands in the submission',
      (tester) async {
    final data = await pumpForm(
      tester,
      customComponents: {'fmsfile': appender},
      form: formOf([
        field('fmsfile', 'fileUploadTest', label: 'Upload'),
      ]),
    );

    // What the user saw: the key present but empty.
    expect(data['fileUploadTest'], anyOf(isNull, isEmpty));

    await tester.tap(find.text('ADD'));
    await tester.pumpAndSettle();

    final stored = data['fileUploadTest'] as List;
    expect(stored, hasLength(1));
    expect(stored.first['name'], 'file1.pdf');
    expect(stored.first['storage'], 'fms');
  });

  testWidgets('appending keeps earlier entries', (tester) async {
    final data = await pumpForm(
      tester,
      customComponents: {'fmsfile': appender},
      form: formOf([field('fmsfile', 'files', label: 'Files')]),
    );

    await tester.tap(find.text('ADD'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ADD'));
    await tester.pumpAndSettle();

    expect((data['files'] as List).map((e) => e['name']),
        ['file1.pdf', 'file2.pdf']);
  });

  testWidgets('the value survives to onSubmit', (tester) async {
    Map<String, dynamic>? submitted;
    await pumpForm(
      tester,
      customComponents: {'fmsfile': appender},
      onSubmit: (data) => submitted = data,
      form: formOf([field('fmsfile', 'files', label: 'Files')]),
    );

    await tester.tap(find.text('ADD'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit'));
    await tester.pumpAndSettle();

    expect(submitted?['files'], hasLength(1));
  });

  testWidgets('a custom type WITHOUT input has no path, and cannot store',
      (tester) async {
    // The failure mode worth knowing about: the renderer only treats a type it
    // does not recognise as data-bound when the schema says `input: true`.
    // Form.io's own component classes always write it, but a hand-authored
    // schema might not.
    final data = await pumpForm(
      tester,
      customComponents: {'mystery': appender},
      form: formOf([
        {'type': 'mystery', 'key': 'ghost', 'label': 'Ghost'},
      ]),
    );

    await tester.tap(find.text('ADD'));
    await tester.pumpAndSettle();

    expect(data['ghost'], isNull,
        reason: 'no `input: true`, so there is no path to write to');
  });

  group('a component that owns values outside its key', () {
    testWidgets('writes another path into the submission', (tester) async {
      final data = await pumpForm(
        tester,
        customComponents: {
          'stepper': (ctx) => TextButton(
                onPressed: () =>
                    ctx.write('task.submitted', true, immediate: true),
                child: const Text('FLAG'),
              ),
        },
        initialData: {
          'task': {'taskId': 't-1'},
        },
        form: formOf([field('stepper', 'stepper', label: 'Stepper')]),
      );

      await tester.tap(find.text('FLAG'));
      await tester.pumpAndSettle();

      expect(data['task'], {'taskId': 't-1', 'submitted': true});
    });

    testWidgets('reads the whole submission, including other fields',
        (tester) async {
      Map<String, dynamic>? seen;
      await pumpForm(
        tester,
        customComponents: {
          'stepper': (ctx) => TextButton(
                onPressed: () => seen = ctx.data,
                child: const Text('READ'),
              ),
        },
        initialData: {
          'notes': 'gate code 12',
          'stepper': {'step': 3},
        },
        form: formOf([
          field('textfield', 'notes', label: 'Notes'),
          field('stepper', 'stepper', label: 'Stepper'),
        ]),
      );

      await tester.tap(find.text('READ'));
      await tester.pumpAndSettle();

      expect(seen?['notes'], 'gate code 12');
      expect(seen?['stepper'], {'step': 3});
    });

    testWidgets('sees a write made since it was built', (tester) async {
      Map<String, dynamic>? seen;
      await pumpForm(
        tester,
        customComponents: {
          'stepper': (ctx) => Column(
                children: [
                  TextButton(
                    onPressed: () => ctx.setValue({'step': 4}, immediate: true),
                    child: const Text('NEXT'),
                  ),
                  TextButton(
                    onPressed: () => seen = ctx.data,
                    child: const Text('READ'),
                  ),
                ],
              ),
        },
        form: formOf([field('stepper', 'stepper', label: 'Stepper')]),
      );

      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('READ'));
      await tester.pumpAndSettle();

      expect(seen?['stepper'], {'step': 4});
    });

    testWidgets('cannot change the submission through the snapshot',
        (tester) async {
      late FormioFieldContext context;
      await pumpForm(
        tester,
        customComponents: {
          'stepper': (ctx) {
            context = ctx;
            return const SizedBox();
          },
        },
        form: formOf([field('stepper', 'stepper', label: 'Stepper')]),
      );

      expect(() => context.data['stepper'] = 1, throwsUnsupportedError);
    });
  });
}
