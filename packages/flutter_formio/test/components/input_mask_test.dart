/// `inputMask` must be applied as the user types, because `@formio/core`
/// validates the value against it — an unmasked phone number is rejected with a
/// `mask` error, not merely displayed unformatted.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formio/formio.dart';

import '../support/fake_engine.dart';
import 'package:formio/src/widgets/component_builders.dart'
    show messageForError;
import 'package:formio/src/widgets/components/input_mask.dart';

void main() {
  group('the formatter', () {
    String apply(String mask, String input) => MaskedInputFormatter(mask)
        .formatEditUpdate(
          const TextEditingValue(),
          TextEditingValue(
            text: input,
            selection: TextSelection.collapsed(offset: input.length),
          ),
        )
        .text;

    test('inserts literals for the default phone mask', () {
      expect(apply('(999) 999-9999', '5551234567'), '(555) 123-4567');
    });

    test('stops at the payload rather than showing empty slots', () {
      expect(apply('(999) 999-9999', '555'), '(555');
      expect(apply('(999) 999-9999', '5551'), '(555) 1');
    });

    test('re-masking its own output is stable', () {
      const mask = '(999) 999-9999';
      final once = apply(mask, '5551234567');
      expect(apply(mask, once), once,
          reason: 'literals must not be duplicated on re-entry');
    });

    test('9 rejects letters, a rejects digits, * takes either', () {
      expect(apply('999', '5a5'), '55');
      expect(apply('aaa', 'a1b'), 'ab');
      expect(apply('***', 'a1b'), 'a1b');
    });

    test('extra input beyond the mask is dropped', () {
      expect(apply('999', '123456'), '123');
    });

    test('empty input clears', () {
      expect(apply('(999) 999-9999', ''), '');
      expect(apply('(999) 999-9999', '()- '), '');
    });

    test('an empty mask passes text through', () {
      expect(apply('', 'anything'), 'anything');
    });
  });

  group('in the renderer', () {
    Future<Map<String, dynamic>> Function() pump(
      WidgetTester tester,
      Map<String, dynamic> extra, {
      String type = 'phoneNumber',
    }) {
      Map<String, dynamic> latest = {};
      late final Future<void> pumped = tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EngineFormRenderer(
            engine: FakeEngine(),
            onChanged: (d) => latest = d,
            form: {
              'display': 'form',
              'components': [
                {
                  'key': 'phone',
                  'type': type,
                  'label': 'Phone',
                  'input': true,
                  ...extra,
                },
              ],
            },
          ),
        ),
      ));
      return () async {
        await pumped;
        await tester.pumpAndSettle();
        return latest;
      };
    }

    testWidgets('masks a phone number as typed', (tester) async {
      final data = pump(tester, {'inputMask': '(999) 999-9999'});
      await data();

      await tester.enterText(find.byType(TextField), '5551234567');
      await tester.pumpAndSettle();

      expect(find.text('(555) 123-4567'), findsOneWidget);
      expect((await data())['phone'], '(555) 123-4567',
          reason: 'the masked value is what the engine validates');
    });

    testWidgets('no mask leaves input untouched', (tester) async {
      // Form.io's builder always writes a mask, but defaulting to its US shape
      // would mangle non-US numbers in a schema that omitted it.
      final data = pump(tester, const {});
      await data();

      await tester.enterText(find.byType(TextField), '+44 7700 900123');
      await tester.pumpAndSettle();

      expect((await data())['phone'], '+44 7700 900123');
    });

    testWidgets('a mask also applies to a textfield', (tester) async {
      final data = pump(tester, {'inputMask': '999-aa'}, type: 'textfield');
      await data();

      await tester.enterText(find.byType(TextField), '123ab');
      await tester.pumpAndSettle();

      expect(find.text('123-ab'), findsOneWidget);
    });

    testWidgets('a numeric field ignores inputMask', (tester) async {
      // Masking and digit grouping would fight each other.
      final data = pump(tester, {'inputMask': '999-999', 'delimiter': true},
          type: 'number');
      await data();

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pumpAndSettle();

      expect(find.text('123,456'), findsOneWidget);
    });
  });

  group('error messages', () {
    test('a mask violation reads as a format problem, not "Invalid value"', () {
      expect(
        messageForError(const FormLogicError(path: 'p', rule: 'mask')),
        ComponentFactory.locale.invalidFormat,
      );
      expect(
        messageForError(const FormLogicError(path: 'p', rule: 'mask')),
        isNot(ComponentFactory.locale.invalidValue),
      );
    });

    test('day part rules name the missing part', () {
      final loc = ComponentFactory.locale;
      expect(
        messageForError(
            const FormLogicError(path: 'd', rule: 'requiredMonthField')),
        loc.getRequiredMessage(loc.month),
      );
    });

    test('date bounds read as value bounds', () {
      final loc = ComponentFactory.locale;
      expect(
        messageForError(const FormLogicError(
            path: 'd', rule: 'minDate', setting: '2020-01-01')),
        loc.getMinValueMessage('2020-01-01'),
      );
    });
  });
}
