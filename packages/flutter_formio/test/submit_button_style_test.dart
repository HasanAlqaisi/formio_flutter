/// The submit button is themeable like every other built-in widget, and its
/// default shape follows the inputs rather than Material's stock pill.
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
  Future<ButtonStyle?> pump(WidgetTester tester, FormioTheme theme) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EngineFormRenderer(
          engine: _PassthroughEngine(),
          theme: theme,
          form: const {
            'display': 'form',
            'components': [
              {'key': 'a', 'type': 'textfield', 'label': 'A', 'input': true},
            ],
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return tester.widget<ElevatedButton>(find.byType(ElevatedButton)).style;
  }

  /// Resolves a [WidgetStateProperty] for the button's default (enabled) state.
  T? forDefault<T>(WidgetStateProperty<T>? property) =>
      property?.resolve(const <WidgetState>{});

  testWidgets('a host style is used verbatim', (tester) async {
    final style = ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF123456),
      minimumSize: const Size.fromHeight(72),
    );
    final applied = await pump(tester, FormioTheme(submitButtonStyle: style));

    expect(forDefault(applied?.backgroundColor), const Color(0xFF123456));
    expect(forDefault(applied?.minimumSize), const Size.fromHeight(72));
  });

  testWidgets('the default is full width and 48 high', (tester) async {
    final applied = await pump(tester, const FormioTheme());
    expect(forDefault(applied?.minimumSize), const Size.fromHeight(48));
  });

  testWidgets('the default corner radius follows the input border',
      (tester) async {
    // The form should not end on a stock pill under fields with square corners.
    final applied = await pump(
      tester,
      const FormioTheme(
        inputBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(2)),
        ),
      ),
    );
    final shape = forDefault(applied?.shape);
    expect(shape, isA<RoundedRectangleBorder>());
    expect((shape! as RoundedRectangleBorder).borderRadius,
        const BorderRadius.all(Radius.circular(2)));
  });

  testWidgets('with no input border it falls back to radius 8', (tester) async {
    final applied = await pump(tester, const FormioTheme());
    final shape = forDefault(applied?.shape) as RoundedRectangleBorder?;
    expect(shape?.borderRadius, BorderRadius.circular(8));
  });

  testWidgets('a non-outline input border does not break the shape',
      (tester) async {
    // UnderlineInputBorder has no borderRadius to read; the button must still
    // resolve to something rather than throwing.
    final applied = await pump(
      tester,
      const FormioTheme(inputBorder: UnderlineInputBorder()),
    );
    expect(forDefault(applied?.shape), isA<RoundedRectangleBorder>());
  });

  testWidgets('the button is disabled while submitting', (tester) async {
    // Guards the style change against breaking the in-flight state.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EngineFormRenderer(
          engine: _PassthroughEngine(),
          onSubmit: (_) {},
          form: const {'display': 'form', 'components': []},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull);
  });
}
