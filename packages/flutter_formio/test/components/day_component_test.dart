// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:formio/formio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DayComponent', () {
    Widget host(String? value) => MaterialApp(
          home: Scaffold(
            body: DayComponent(
              component: ComponentModel.fromJson({
                'key': 'day',
                'type': 'day',
                'label': 'Day',
              }),
              value: value,
              onChanged: (_) {},
            ),
          ),
        );

    testWidgets('"00/00/0000" (Form.io "no date") renders without asserting',
        (tester) async {
      // Regression: zero day/month/year are not among the dropdown items, so a
      // raw initialValue: 0 used to trip DropdownButton's single-item assertion.
      // With no `fields` config, `type` defaults to `text`, so these are text
      // inputs — the zero parts must simply read as empty.
      await tester.pumpWidget(host('00/00/0000'));
      expect(tester.takeException(), isNull);
      expect(find.byType(TextFormField), findsNWidgets(3));
      for (final f
          in tester.widgetList<TextFormField>(find.byType(TextFormField))) {
        expect(f.controller!.text, isEmpty);
      }
    });

    testWidgets('out-of-range parts do not crash the dropdowns',
        (tester) async {
      await tester.pumpWidget(host('99/40/0000'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a valid MM/DD/YYYY date renders selected', (tester) async {
      // `dayFirst` is unset, and Form.io defaults it to false — so the month
      // comes first. (This previously passed '15/06/2020', which under that
      // default means month 15; the engine rejects it as an invalid day too.)
      await tester.pumpWidget(host('06/15/2020'));
      expect(tester.takeException(), isNull);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('2020'), findsOneWidget);
    });

    testWidgets('dayFirst:true reads the day from the first segment',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DayComponent(
            component: ComponentModel.fromJson({
              'key': 'day',
              'type': 'day',
              'label': 'Day',
              'dayFirst': true,
            }),
            value: '15/06/2020',
            onChanged: (_) {},
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
    });
  });
}
