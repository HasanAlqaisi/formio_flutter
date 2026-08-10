/// Widget tests for [EngineFormRenderer] using a fake [FormEngine] — no
/// flutter_js / device needed. Covers the rendering contract the renderer owns:
/// honoring the engine's hidden map (incl. layout panels by key) and gating
/// error display until touched/submitted.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formio/formio.dart';

import 'support/fake_engine.dart';

Widget _host(Map<String, dynamic> form, FormEngine engine) => MaterialApp(
      home: Scaffold(body: EngineFormRenderer(form: form, engine: engine)),
    );

final Map<String, dynamic> _form = {
  'display': 'form',
  'components': [
    {'type': 'textfield', 'key': 'visible', 'label': 'Visible', 'input': true},
    {
      'type': 'panel',
      'key': 'hp',
      'title': 'Hidden Section',
      'components': [
        {
          'type': 'textfield',
          'key': 'inside',
          'label': 'Inside',
          'input': true
        },
      ],
    },
  ],
};

void main() {
  testWidgets('caches the form and renders visible components', (tester) async {
    final engine = FakeEngine();
    await tester.pumpWidget(_host(_form, engine));

    expect(engine.lastForm, isNotNull); // setForm was called (form caching)
    expect(find.text('Visible'), findsOneWidget);
    expect(
        find.text('Hidden Section'), findsOneWidget); // panel shown by default
    expect(find.text('Inside'), findsOneWidget);
  });

  testWidgets('a panel the engine hides (by key) is not rendered',
      (tester) async {
    await tester.pumpWidget(_host(_form, FakeEngine(hidden: {'hp': true})));

    expect(find.text('Visible'), findsOneWidget); // sibling still shows
    expect(find.text('Hidden Section'), findsNothing); // hidden panel gone…
    expect(find.text('Inside'), findsNothing); // …along with its children
  });

  testWidgets('applies FormioTheme tokens (required suffix)', (tester) async {
    final form = {
      'display': 'form',
      'components': [
        {
          'type': 'textfield',
          'key': 'name',
          'label': 'Name',
          'input': true,
          'validate': {'required': true},
        },
      ],
    };
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EngineFormRenderer(
          form: form,
          engine: FakeEngine(),
          theme: const FormioTheme(requiredSuffix: ' (required)'),
        ),
      ),
    ));
    expect(find.text('Name (required)'), findsOneWidget);
  });

  testWidgets('a throwing component degrades to a placeholder, not a crash',
      (tester) async {
    final form = {
      'display': 'form',
      'components': [
        {'type': 'textfield', 'key': 'ok', 'label': 'OK', 'input': true},
        {'type': 'boom', 'key': 'boom', 'input': true},
      ],
    };
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EngineFormRenderer(
          form: form,
          engine: FakeEngine(),
          customComponents: {
            'boom': (ctx) => throw StateError('kaboom'),
          },
        ),
      ),
    ));

    expect(tester.takeException(), isNull); // error was caught, not propagated
    expect(find.text('OK'), findsOneWidget); // sibling still renders
    expect(find.textContaining('render error'),
        findsOneWidget); // placeholder shown
  });

  testWidgets('validation error is gated until submit', (tester) async {
    final engine = FakeEngine(
      errors: const [FormLogicError(path: 'visible', rule: 'required')],
    );
    await tester.pumpWidget(_host(_form, engine));

    // Not submitted / not touched → no error shown.
    expect(find.text('This field is required'), findsNothing);

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    // After submit → the error surfaces on the field.
    expect(find.text('This field is required'), findsOneWidget);
  });
}
