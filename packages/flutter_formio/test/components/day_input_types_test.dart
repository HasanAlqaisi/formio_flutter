/// `fields.<part>.type` drives which control each part of a `day` renders.
///
/// Per Form.io's Day docs the property is **required with a default of `text`**,
/// so only an explicit `select` is a dropdown. An earlier implementation had
/// this inverted — anything other than `number` became a dropdown, so the
/// documented default rendered the wrong control.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formio/formio.dart';

import '../support/fake_engine.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    Map<String, dynamic>? fields,
    Map<String, dynamic> extra = const {},
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EngineFormRenderer(
          engine: FakeEngine(),
          form: {
            'display': 'form',
            'components': [
              {
                'key': 'dob',
                'type': 'day',
                'label': 'Date',
                'input': true,
                if (fields != null) 'fields': fields,
                ...extra,
              },
            ],
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> parts(String day, String month, String year) => {
        'day': {'type': day, 'hide': false},
        'month': {'type': month, 'hide': false},
        'year': {'type': year, 'hide': false},
      };

  testWidgets('no fields config gives text inputs, the documented default',
      (tester) async {
    await pump(tester);

    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(find.byType(DropdownButtonFormField<int>), findsNothing,
        reason: 'type defaults to text, not select');
  });

  testWidgets('an explicit text type gives a text input', (tester) async {
    await pump(tester, fields: parts('text', 'text', 'text'));

    expect(find.byType(TextFormField), findsNWidgets(3));
  });

  testWidgets('select gives a dropdown', (tester) async {
    await pump(tester, fields: parts('select', 'select', 'select'));

    expect(find.byType(DropdownButtonFormField<int>), findsNWidgets(3));
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('number gives a text input', (tester) async {
    await pump(tester, fields: parts('number', 'number', 'number'));

    expect(find.byType(TextFormField), findsNWidgets(3));
  });

  testWidgets('a mixed config renders each part per its own type',
      (tester) async {
    // The real-world shape: numeric day/year either side of a month select.
    await pump(tester, fields: parts('number', 'select', 'number'));

    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
  });

  testWidgets('hideInputLabels drops the per-part labels', (tester) async {
    await pump(tester,
        fields: parts('text', 'text', 'text'),
        extra: {'hideInputLabels': true});

    // The overall component label stays; the per-part ones go.
    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Day'), findsNothing);
    expect(find.text('Month'), findsNothing);
    expect(find.text('Year'), findsNothing);
  });

  testWidgets('labels are shown by default', (tester) async {
    await pump(tester, fields: parts('text', 'text', 'text'));

    expect(find.text('Day'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Year'), findsOneWidget);
  });

  testWidgets('a hidden part is not rendered', (tester) async {
    final fields = parts('text', 'text', 'text');
    fields['day'] = {'type': 'text', 'hide': true};
    await pump(tester, fields: fields);

    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Day'), findsNothing);
  });
}
