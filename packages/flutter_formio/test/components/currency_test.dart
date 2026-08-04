/// `currency` must show its symbol and group its digits, and — the part that
/// matters most — must always store a **number**, not the formatted text.
///
/// Parsing is locale-aware on purpose: stripping commas would turn `1,5` into
/// `15` in locales where the comma is the decimal separator.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formio/formio.dart';
import 'package:formio/src/widgets/components/numeric_format.dart';

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
  group('formatting helpers', () {
    test('a currency code resolves to its symbol', () {
      expect(currencySymbolFor('USD', 'en_US'), r'$');
      expect(currencySymbolFor('EUR', 'en_US'), isNotEmpty);
      // An unknown code is shown as-is rather than dropped.
      expect(currencySymbolFor('XYZ', 'en_US'), 'XYZ');
      expect(currencySymbolFor(null, 'en_US'), isNull);
      expect(currencySymbolFor('   ', 'en_US'), isNull);
    });

    test('grouping and decimal limit apply', () {
      expect(
        formatNumeric(1234.5, grouping: true, decimalLimit: 2, locale: 'en_US'),
        '1,234.50',
      );
      expect(
        formatNumeric(1234.5, grouping: false, decimalLimit: 2, locale: 'en_US'),
        '1234.50',
      );
    });

    test('parsing accepts grouped input and returns a num', () {
      expect(parseNumeric('1,234.56', locale: 'en_US'), 1234.56);
      expect(parseNumeric('1234.56', locale: 'en_US'), 1234.56);
      expect(parseNumeric('42', locale: 'en_US'), 42);
    });

    test('parsing respects the locale rather than stripping separators', () {
      // In de, comma is the decimal separator: 1,5 is one and a half, not 15.
      expect(parseNumeric('1,5', locale: 'de'), 1.5);
      expect(parseNumeric('1.234,56', locale: 'de'), closeTo(1234.56, 0.001));
    });

    test('empty clears, garbage is preserved for the engine to reject', () {
      expect(parseNumeric('', locale: 'en_US'), isNull);
      expect(parseNumeric('   ', locale: 'en_US'), isNull);
      // Kept as text so the engine reports "invalid number", not "required".
      expect(parseNumeric('abc', locale: 'en_US'), 'abc');
    });
  });

  group('in the renderer', () {
    Future<Map<String, dynamic>> Function() pump(
      WidgetTester tester,
      Map<String, dynamic> extra, {
      Map<String, dynamic>? initial,
      String type = 'currency',
    }) {
      Map<String, dynamic> latest = {};
      late final Future<void> pumped = tester.pumpWidget(MaterialApp(
        locale: const Locale('en', 'US'),
        supportedLocales: const [Locale('en', 'US')],
        home: Scaffold(
          body: EngineFormRenderer(
            engine: _PassthroughEngine(),
            initialData: initial,
            onChanged: (d) => latest = d,
            form: {
              'display': 'form',
              'components': [
                {
                  'key': 'amount',
                  'type': type,
                  'label': 'Amount',
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

    testWidgets('shows the currency symbol', (tester) async {
      final data = pump(tester, {'currency': 'USD'});
      await data();

      expect(find.text(r'$'), findsOneWidget,
          reason: 'the symbol was previously never rendered');
    });

    testWidgets('an explicit prefix wins over the symbol', (tester) async {
      final data = pump(tester, {'currency': 'USD', 'prefix': 'AMT'});
      await data();

      expect(find.text('AMT'), findsOneWidget);
      expect(find.text(r'$'), findsNothing);
    });

    testWidgets('formats a stored value while idle', (tester) async {
      final data = pump(tester, {'currency': 'USD'},
          initial: {'amount': 1234.5});
      await data();

      expect(find.text('1,234.50'), findsOneWidget);
    });

    testWidgets('typing grouped input stores a num, not the text',
        (tester) async {
      final data = pump(tester, {'currency': 'USD'});
      await data();

      await tester.enterText(find.byType(TextField), '1,234.56');
      await tester.pumpAndSettle();

      final stored = (await data())['amount'];
      expect(stored, isA<num>(),
          reason: 'storing "1,234.56" as a String breaks engine min/max');
      expect(stored, 1234.56);
    });

    testWidgets('groups digits live, while still focused', (tester) async {
      // The reported bug: typing 200000 showed "200000" until blur.
      final data = pump(tester, {'currency': 'USD'});
      await data();

      await tester.enterText(find.byType(TextField), '200000');
      await tester.pumpAndSettle();

      expect(find.text('200,000'), findsOneWidget,
          reason: 'separators must appear as the user types');
      expect((await data())['amount'], 200000);
    });

    testWidgets('the caret stays put when a separator is inserted',
        (tester) async {
      final data = pump(tester, {'currency': 'USD'});
      await data();

      final field = find.byType(TextField);
      await tester.enterText(field, '1234');
      await tester.pumpAndSettle();

      final controller = tester.widget<TextField>(field).controller!;
      expect(controller.text, '1,234');
      // Caret belongs after the last typed digit, not reset to 0 or stranded
      // before the inserted comma.
      expect(controller.selection.baseOffset, controller.text.length);
    });

    testWidgets('a decimal in progress is preserved', (tester) async {
      final data = pump(tester, {'currency': 'USD'});
      await data();

      final field = find.byType(TextField);
      // "1234." must survive so the next keystroke can make it "1234.5".
      await tester.enterText(field, '1234.');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, '1,234.');

      await tester.enterText(field, '1,234.5');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, '1,234.5');
      expect((await data())['amount'], 1234.5);
    });

    testWidgets('decimals are capped to decimalLimit while typing',
        (tester) async {
      final data = pump(tester, {'currency': 'USD', 'decimalLimit': 2});
      await data();

      await tester.enterText(find.byType(TextField), '1.23456');
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '1.23');
    });

    testWidgets('clearing the field stores null', (tester) async {
      final data = pump(tester, {'currency': 'USD'},
          initial: {'amount': 10});
      await data();

      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      expect((await data())['amount'], isNull);
    });

    testWidgets('a plain number is not reformatted unless asked',
        (tester) async {
      // Form.io defaults number's `delimiter` to false.
      final data = pump(tester, const {}, type: 'number',
          initial: {'amount': 1234.5});
      await data();

      expect(find.text('1234.5'), findsOneWidget);
      expect(find.text('1,234.50'), findsNothing);
    });

    testWidgets('requireDecimal pads decimals without grouping',
        (tester) async {
      final data = pump(tester, {'requireDecimal': true},
          type: 'number', initial: {'amount': 5});
      await data();

      expect(find.text('5.00'), findsOneWidget,
          reason: 'requireDecimal must apply even with delimiter off');
    });

    testWidgets('validate.integer rejects a decimal as typed', (tester) async {
      // @formio/core has no `integer` rule — it relies on the browser's number
      // input — so the field is the only thing that can enforce it.
      final data = pump(tester, {'validate': {'integer': true}},
          type: 'number');
      await data();

      await tester.enterText(find.byType(TextField), '12.75');
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '12');
      expect((await data())['amount'], 12);
    });

    testWidgets('validate.integer uses a keyboard without a decimal key',
        (tester) async {
      final data = pump(tester, {'validate': {'integer': true}},
          type: 'number');
      await data();

      expect(tester.widget<TextField>(find.byType(TextField)).keyboardType,
          const TextInputType.numberWithOptions(decimal: false));
    });

    testWidgets('a number with delimiter:true is grouped', (tester) async {
      final data = pump(tester, {'delimiter': true},
          type: 'number', initial: {'amount': 1234});
      await data();

      expect(find.text('1,234'), findsOneWidget);
    });
  });
}
