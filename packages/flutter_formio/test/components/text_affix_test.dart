// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:formio/formio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Passes data straight through — this suite only exercises input decoration.
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
  group('text field prefix/suffix', () {
    Future<void> pumpForm(WidgetTester tester,
        {Map<String, dynamic> extra = const {}}) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EngineFormRenderer(
            engine: _PassthroughEngine(),
            form: {
              'components': [
                {
                  'key': 'amount',
                  'type': 'textfield',
                  'input': true,
                  'label': 'Amount',
                  'prefix': r'$',
                  'suffix': 'USD',
                  ...extra,
                },
              ],
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    /// Walks up from [text] looking for an ancestor that fades it out. The old
    /// `prefixText`/`suffixText` path wrapped the affix in an [AnimatedOpacity]
    /// driven by the floating label, which is exactly the regression here.
    double effectiveOpacity(WidgetTester tester, String text) {
      var opacity = 1.0;
      for (final w in tester.widgetList(find.ancestor(
        of: find.text(text),
        matching: find.byType(AnimatedOpacity),
      ))) {
        opacity *= (w as AnimatedOpacity).opacity;
      }
      return opacity;
    }

    testWidgets('are visible while the field is empty and unfocused',
        (tester) async {
      await pumpForm(tester);

      // Nothing typed, nothing focused — the state where they used to vanish.
      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.text(r'$'), findsOneWidget);
      expect(find.text('USD'), findsOneWidget);
      expect(effectiveOpacity(tester, r'$'), 1.0,
          reason: 'prefix is faded out while empty/unfocused');
      expect(effectiveOpacity(tester, 'USD'), 1.0,
          reason: 'suffix is faded out while empty/unfocused');
    });

    testWidgets('stay visible after focus and typing', (tester) async {
      await pumpForm(tester);

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.text(r'$'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '42');
      await tester.pumpAndSettle();
      expect(find.text(r'$'), findsOneWidget);
      expect(find.text('USD'), findsOneWidget);
      expect(effectiveOpacity(tester, r'$'), 1.0);
    });

    testWidgets('omitted when the schema has no prefix/suffix', (tester) async {
      await pumpForm(tester, extra: {'prefix': '', 'suffix': null});

      expect(find.text(r'$'), findsNothing);
      expect(find.text('USD'), findsNothing);
    });

    testWidgets('tolerate non-string schema values', (tester) async {
      await pumpForm(tester, extra: {'prefix': 5, 'suffix': 0.5});

      // Would previously throw a CastError on `raw['prefix'] as String?`.
      expect(tester.takeException(), isNull);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('0.5'), findsOneWidget);
    });
  });
}
