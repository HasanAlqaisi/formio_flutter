/// A fieldset's header is `legend`; a panel's/well's is `title`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formio/formio.dart';

import 'support/fake_engine.dart';

void main() {
  Future<void> pump(WidgetTester tester, Map<String, dynamic> section) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EngineFormRenderer(
          engine: FakeEngine(),
          form: {
            'display': 'form',
            'components': [section]
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('a fieldset shows its legend', (tester) async {
    await pump(tester, {
      'type': 'fieldset',
      'key': 'fs',
      'legend': 'Personal',
      'components': []
    });

    expect(find.text('Personal'), findsOneWidget);
  });

  testWidgets('a fieldset prefers legend over title', (tester) async {
    await pump(tester, {
      'type': 'fieldset',
      'key': 'fs',
      'legend': 'Legend wins',
      'title': 'Title loses',
      'components': [],
    });

    expect(find.text('Legend wins'), findsOneWidget);
    expect(find.text('Title loses'), findsNothing);
  });

  testWidgets('a panel prefers title over legend', (tester) async {
    await pump(tester, {
      'type': 'panel',
      'key': 'p',
      'title': 'Title wins',
      'legend': 'Legend loses',
      'components': [],
    });

    expect(find.text('Title wins'), findsOneWidget);
    expect(find.text('Legend loses'), findsNothing);
  });

  testWidgets('the builder default label is not used as a header',
      (tester) async {
    await pump(tester, {
      'type': 'fieldset',
      'key': 'fs',
      'label': 'Field Set',
      'components': []
    });

    expect(find.text('Field Set'), findsNothing);
  });

  testWidgets('a non-string legend does not throw', (tester) async {
    await pump(tester,
        {'type': 'fieldset', 'key': 'fs', 'legend': 7, 'components': []});

    expect(tester.takeException(), isNull);
    expect(find.text('7'), findsOneWidget);
  });
}
