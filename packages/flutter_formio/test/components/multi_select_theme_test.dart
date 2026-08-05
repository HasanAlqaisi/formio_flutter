/// A multi-select must be indistinguishable from the text inputs beside it.
///
/// It was the last built-in control drawing a stock `OutlineInputBorder` with no
/// fill, so under a themed form it showed a brighter border over a transparent
/// background while every field around it was filled and subtly outlined.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formio/formio.dart';

class _PassthroughEngine implements FormEngine {
  @override
  void setForm(Map<String, dynamic> form) {}
  @override
  FormLogicResult processData(Map<String, dynamic> submissionData,
          {bool validate = true}) =>
      FormLogicResult(data: submissionData, hidden: const {}, errors: const []);
}

void main() {
  const fill = Color(0xFF1B2430);
  const borderColor = Color(0xFF33414F);
  final theme = FormioTheme(
    inputFillColor: fill,
    inputBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(6)),
      borderSide: BorderSide(color: borderColor),
    ),
    hintStyle: const TextStyle(color: Color(0xFF7A8899)),
  );

  /// A form holding a multi-select and a text input, so the two can be compared
  /// as they actually render together.
  Future<void> pump(WidgetTester tester, {FormioTheme? formioTheme}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EngineFormRenderer(
          engine: _PassthroughEngine(),
          theme: formioTheme ?? theme,
          form: const {
            'display': 'form',
            'components': [
              {
                'key': 'nets',
                'type': 'select',
                'label': 'From Net',
                'input': true,
                'multiple': true,
                'searchEnabled': false,
                'data': {
                  'values': [
                    {'label': 'A', 'value': 'a'},
                    {'label': 'B', 'value': 'b'},
                  ]
                },
              },
              {
                'key': 'name',
                'type': 'textfield',
                'label': 'Name',
                'input': true
              },
            ],
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  InputDecoration decorationOf(WidgetTester tester, Finder within) => tester
      .widget<InputDecorator>(
          find.descendant(of: within, matching: find.byType(InputDecorator)))
      .decoration;

  testWidgets('the multi-select takes its fill and border from the form theme',
      (tester) async {
    await pump(tester);

    final decoration =
        decorationOf(tester, find.byType(MultiSelectField).first);

    expect(decoration.filled, isTrue,
        reason: 'a transparent box beside filled inputs reads as a different '
            'kind of field');
    expect(decoration.fillColor, fill);
    expect((decoration.enabledBorder as OutlineInputBorder?)?.borderSide.color,
        borderColor);
  });

  testWidgets('its decoration matches the text input next to it',
      (tester) async {
    await pump(tester);

    final select = decorationOf(tester, find.byType(MultiSelectField).first);
    final input =
        tester.widget<TextField>(find.byType(TextField).first).decoration!;

    // The comparison that matters: same fill, same border, same density.
    expect(select.fillColor, input.fillColor);
    expect(select.filled, input.filled);
    expect(select.isDense, input.isDense);
    expect((select.enabledBorder as OutlineInputBorder?)?.borderSide.color,
        (input.enabledBorder as OutlineInputBorder?)?.borderSide.color);
    expect((select.enabledBorder as OutlineInputBorder?)?.borderRadius,
        (input.enabledBorder as OutlineInputBorder?)?.borderRadius);
  });

  testWidgets('an unthemed form is unfilled rather than given a colour',
      (tester) async {
    // With no tokens set the control must stay neutral, not invent a fill.
    await pump(tester, formioTheme: const FormioTheme());

    final decoration =
        decorationOf(tester, find.byType(MultiSelectField).first);
    expect(decoration.filled, isFalse);
    expect(decoration.fillColor, isNull);
  });

  testWidgets('the placeholder uses the theme hint style', (tester) async {
    await pump(tester);
    final hint = tester.widget<Text>(
      find.descendant(
        of: find.byType(MultiSelectField).first,
        matching: find.byType(Text),
      ),
    );
    expect(hint.style?.color, const Color(0xFF7A8899));
  });
}
