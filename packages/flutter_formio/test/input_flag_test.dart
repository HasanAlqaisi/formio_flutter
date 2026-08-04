/// Regression tests for data-path binding when a schema omits `input: true`.
///
/// Form.io's component classes carry `input` in their own `defaultSchema`, so a
/// hand-written or partial schema without the flag still describes a data
/// component. Before this was handled, such a component rendered a fully
/// editable control bound to an empty path and the first keystroke crashed with
/// `Bad state: No element` from `_setPath`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formio/formio.dart';

/// Passes data straight through; these tests only exercise path binding.
class _PassthroughEngine implements FormEngine {
  @override
  void setForm(Map<String, dynamic> form) {}

  @override
  FormLogicResult processData(Map<String, dynamic> submissionData,
          {bool validate = true}) =>
      FormLogicResult(
          data: submissionData, hidden: const {}, errors: const []);
}

void main() {
  /// Renders [components] and exposes the latest submission data.
  Future<Map<String, dynamic>> Function() pump(
    WidgetTester tester,
    List<Map<String, dynamic>> components,
  ) {
    Map<String, dynamic> latest = {};
    late final Future<void> pumped = tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EngineFormRenderer(
          engine: _PassthroughEngine(),
          form: {'display': 'form', 'components': components},
          onChanged: (d) => latest = d,
        ),
      ),
    ));
    return () async {
      await pumped;
      return latest;
    };
  }

  group('a data component with no `input` flag', () {
    testWidgets('binds to its key and does not crash on typing',
        (tester) async {
      final data = pump(tester, [
        // No 'input': true — the case that used to crash.
        {'key': 'amount', 'type': 'textfield', 'label': 'Amount'},
      ]);
      await data();

      await tester.enterText(find.byType(TextField), '42');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(await data(), containsPair('amount', '42'),
          reason: 'value must land under the component key');
    });

    testWidgets('nests under its parent container path', (tester) async {
      final data = pump(tester, [
        {
          'key': 'outer',
          'type': 'container',
          'input': true,
          'components': [
            {'key': 'inner', 'type': 'textfield', 'label': 'Inner'},
          ],
        },
      ]);
      await data();

      await tester.enterText(find.byType(TextField), 'hi');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(await data(), containsPair('outer', containsPair('inner', 'hi')));
    });

    testWidgets('applies to every data type, not just text', (tester) async {
      final data = pump(tester, [
        {
          'key': 'choice',
          'type': 'radio',
          'label': 'Choice',
          'values': [
            {'label': 'A', 'value': 'a'},
            {'label': 'B', 'value': 'b'},
          ],
        },
      ]);
      await data();

      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(await data(), containsPair('choice', 'b'));
    });
  });

  group('container nesting', () {
    testWidgets('a container without an `input` flag still nests its children',
        (tester) async {
      // Form.io's Container carries input: true and nests children under its
      // key — that is the component's whole purpose, so a partial schema that
      // omits the flag must still nest rather than flatten.
      final data = pump(tester, [
        {
          'key': 'userInformation',
          'type': 'container',
          'components': [
            {'key': 'firstName', 'type': 'textfield', 'label': 'First'},
          ],
        },
      ]);
      await data();

      await tester.enterText(find.byType(TextField), 'Joe');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(await data(),
          containsPair('userInformation', containsPair('firstName', 'Joe')),
          reason: 'flattening would put firstName at the submission root');
    });
  });

  group('explicit flags still win', () {
    testWidgets('`input: false` on a data component does not crash',
        (tester) async {
      final data = pump(tester, [
        {
          'key': 'amount',
          'type': 'textfield',
          'label': 'Amount',
          'input': false,
        },
      ]);
      await data();

      // Path-less, so the write is dropped with a debug warning — but the form
      // must survive it rather than throwing from onChanged.
      await tester.enterText(find.byType(TextField), '42');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(await data(), isNot(contains('amount')));
    });

    testWidgets('a presentational type stays unbound', (tester) async {
      final data = pump(tester, [
        {'key': 'blurb', 'type': 'content', 'html': '<p>hello</p>'},
        {'key': 'amount', 'type': 'textfield', 'label': 'Amount'},
      ]);
      await data();

      await tester.enterText(find.byType(TextField), '7');
      await tester.pumpAndSettle();

      final result = await data();
      expect(result, containsPair('amount', '7'));
      expect(result, isNot(contains('blurb')),
          reason: 'content is presentational and must not collect data',);
    });
  });
}
