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
      await tester.pumpWidget(host('00/00/0000'));
      expect(tester.takeException(), isNull);
      expect(find.byType(DropdownButtonFormField<int>), findsNWidgets(3));
    });

    testWidgets('out-of-range parts do not crash the dropdowns',
        (tester) async {
      await tester.pumpWidget(host('99/40/0000'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a valid DD/MM/YYYY date renders selected', (tester) async {
      await tester.pumpWidget(host('15/06/2020'));
      expect(tester.takeException(), isNull);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('2020'), findsOneWidget);
    });
  });
}
