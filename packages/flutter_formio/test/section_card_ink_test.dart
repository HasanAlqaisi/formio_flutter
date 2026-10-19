/// A checkbox inside a themed panel keeps its own background and ink splash.
///
/// `ListTile` and its subclasses paint those on the nearest [Material] ancestor.
/// A themed `sectionCard` fills its background, so without a Material of its own
/// inside the card, the fill covers everything the tile paints — and the
/// framework reports it as an error in debug builds.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formio/formio.dart';

import 'support/fake_engine.dart';

void main() {
  final theme = FormioTheme(
    sectionDecoration: BoxDecoration(
      color: const Color(0xFF1B2733),
      border: Border.all(color: const Color(0xFF33414F)),
      borderRadius: BorderRadius.circular(8),
    ),
  );

  final form = {
    'display': 'form',
    'components': [
      {
        'type': 'panel',
        'key': 'panel',
        'title': 'Issue',
        'input': false,
        'components': [
          {
            'type': 'checkbox',
            'key': 'submitCase',
            'label': 'submit case',
            'input': true,
          },
        ],
      },
    ],
  };

  testWidgets('a checkbox in a themed panel paints on a Material of its own',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EngineFormRenderer(
          engine: FakeEngine(),
          theme: theme,
          form: form,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(CheckboxListTile), findsOneWidget);

    final Material material = tester.widget(
      find
          .ancestor(
            of: find.byType(CheckboxListTile),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.type, MaterialType.transparency);
  });
}
