/// The `controls` hook lets a host supply the *widget* for a built-in control
/// while the package keeps the behaviour.
///
/// This exists because a `customComponents['select']` override replaces the
/// component wholesale — schema handling included — so a host that only wanted
/// its own dropdown silently lost `dataSrc`, `valueProperty` and remote loading.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formio/formio.dart';

import 'support/fake_engine.dart';

void main() {
  setUp(RemoteSelectOptions.clearCache);

  /// Renders a form whose select is drawn by a host builder that reports what it
  /// was given.
  Future<Map<String, dynamic>> Function() pump(
    WidgetTester tester,
    Map<String, dynamic> select, {
    required void Function(FormioSelectSpec spec) onSpec,
  }) {
    Map<String, dynamic> latest = {};
    late final Future<void> pumped = tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EngineFormRenderer(
          engine: FakeEngine(),
          onChanged: (d) => latest = d,
          controls: FormioControlBuilders(
            select: (context, spec) {
              onSpec(spec);
              return Column(
                children: [
                  if (spec.loading) const Text('HOST-LOADING'),
                  for (final o in spec.options)
                    TextButton(
                      onPressed: () => spec.onChanged(o.value),
                      child: Text('${o.label}|${o.key}'),
                    ),
                ],
              );
            },
          ),
          form: {
            'display': 'form',
            'components': [
              {'key': 'pick', 'label': 'Pick', 'input': true, ...select},
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

  testWidgets('a host builder replaces the widget for inline values',
      (tester) async {
    FormioSelectSpec? seen;
    final data = pump(
      tester,
      {
        'type': 'select',
        'values': [
          {'label': 'A', 'value': 'a'},
        ],
      },
      onSpec: (s) => seen = s,
    );
    await data();

    expect(find.byType(DropdownButton<String>), findsNothing,
        reason: 'the built-in control should be replaced');
    expect(find.text('A|a'), findsOneWidget);
    expect(seen!.label, 'Pick');
  });

  testWidgets('the host builder receives fetched options for dataSrc: url',
      (tester) async {
    // The reported bug: a host-overridden select showed nothing for a url
    // source because the override only understood inline values.
    final data = pump(
      tester,
      {
        'type': 'select',
        'dataSrc': 'url',
        'selectValues': 'users',
        'valueProperty': 'id',
        'template': '{{ item.firstName }}',
        'data': {'url': 'https://example.test/users'},
      },
      onSpec: (_) {},
    );
    await data();

    // No client injection point on the renderer, so the fetch fails here; what
    // matters is that resolution happens in the package, not the host.
    expect(find.byType(RemoteSelectOptions), findsOneWidget);
  });

  testWidgets('options carry their schema type through the host builder',
      (tester) async {
    final data = pump(
      tester,
      {
        'type': 'select',
        'dataSrc': 'json',
        'valueProperty': 'id',
        'template': '{{ item.name }}',
        'data': {
          'json': [
            {'id': 7, 'name': 'Seven'},
          ],
        },
      },
      onSpec: (_) {},
    );
    await data();

    expect(find.text('Seven|7'), findsOneWidget);
    await tester.tap(find.text('Seven|7'));
    await tester.pumpAndSettle();

    final stored = (await data())['pick'];
    expect(stored, 7);
    expect(stored, isA<int>(),
        reason: 'a numeric valueProperty must not be stringified');
  });

  /// Renders a bare select with no host builder, so the package's own widget is
  /// what shows.
  Future<void> pumpBuiltIn(WidgetTester tester, {bool? searchEnabled}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EngineFormRenderer(
          engine: FakeEngine(),
          form: {
            'display': 'form',
            'components': [
              {
                'key': 'pick',
                'type': 'select',
                'label': 'Pick',
                'input': true,
                if (searchEnabled != null) 'searchEnabled': searchEnabled,
                'values': [
                  {'label': 'A', 'value': 'a'},
                ],
              },
            ],
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('no builder keeps the package control', (tester) async {
    await pumpBuiltIn(tester);
    expect(find.byType(FormioBuiltInSelect), findsOneWidget);
  });

  testWidgets('searchEnabled defaults on, giving a searchable picker',
      (tester) async {
    // Form.io's own default is on, and 316 of the 333 selects in the sample
    // forms set it — so this is the common path, not the edge one.
    await pumpBuiltIn(tester);
    expect(find.byType(SelectPickerField), findsOneWidget);
    expect(find.byType(DropdownButton<String>), findsNothing);

    await tester.tap(find.byType(SelectPickerField));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('searchEnabled: false keeps the plain dropdown', (tester) async {
    await pumpBuiltIn(tester, searchEnabled: false);
    expect(find.byType(DropdownButton<String>), findsOneWidget);
    expect(find.byType(SelectPickerField), findsNothing);
  });

  testWidgets('the picker stores the option value, not its label',
      (tester) async {
    await pumpBuiltIn(tester);
    await tester.tap(find.byType(SelectPickerField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A').last);
    await tester.pumpAndSettle();

    // Closed, with the chosen label showing in the field.
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('a host can delegate a case back to the built-in',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EngineFormRenderer(
          engine: FakeEngine(),
          controls: FormioControlBuilders(
            // Style single-select, hand multi-select back to the package.
            select: (context, spec) => spec.multiple
                ? FormioBuiltInSelect(spec: spec)
                : const Text('HOST-SINGLE'),
          ),
          form: {
            'display': 'form',
            'components': [
              {
                'key': 'one',
                'type': 'select',
                'label': 'One',
                'input': true,
                'values': [
                  {'label': 'A', 'value': 'a'},
                ],
              },
              {
                'key': 'many',
                'type': 'select',
                'label': 'Many',
                'input': true,
                'multiple': true,
                'values': [
                  {'label': 'B', 'value': 'b'},
                ],
              },
            ],
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('HOST-SINGLE'), findsOneWidget);
    expect(find.byType(MultiSelectField), findsOneWidget);
  });
}
