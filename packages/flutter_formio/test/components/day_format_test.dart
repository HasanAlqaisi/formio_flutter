/// The `day` value must match what `@formio/core` reads.
///
/// From the engine bundle: `validateDay` and `isPartialDay` both index the value
/// with `dayFirst ? [0,1,2] : [1,0,2]`, and `getDayFormat` builds `D/M/YYYY` vs
/// `M/D/YYYY` while dropping hidden parts. So `dayFirst` defaults to **false**,
/// meaning `MM/DD/YYYY` — this component used to always write day-first, handing
/// the engine the month in the day slot.
///
/// Fields are addressed by **label**, never by position: driving them
/// positionally cannot detect a swapped order, because the display order and the
/// write order change together and produce an identical string.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formio/formio.dart';

void main() {
  /// All parts as `number`, so each slot is a plain text field addressable by
  /// its label and readable via its controller.
  Map<String, dynamic> schema({
    bool? dayFirst,
    bool hideDay = false,
  }) =>
      {
        'key': 'dob',
        'type': 'day',
        'label': 'Date',
        if (dayFirst != null) 'dayFirst': dayFirst,
        'fields': {
          'day': {'type': 'number', 'hide': hideDay},
          'month': {'type': 'number', 'hide': false},
          'year': {'type': 'number', 'hide': false},
        },
      };

  Future<String?> Function() pump(
    WidgetTester tester,
    Map<String, dynamic> component, {
    String? value,
  }) {
    String? written;
    late final Future<void> pumped = tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DayComponent(
          component: ComponentModel.fromJson(component),
          value: value,
          onChanged: (v) => written = v,
        ),
      ),
    ));
    return () async {
      await pumped;
      await tester.pumpAndSettle();
      return written;
    };
  }

  /// The field carrying [label] — 'Day', 'Month' or 'Year'.
  Finder fieldFor(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byType(TextFormField),
      );

  Future<void> type(WidgetTester tester, String label, int value) async {
    await tester.enterText(fieldFor(label), '$value');
    await tester.pumpAndSettle();
  }

  String shown(WidgetTester tester, String label) =>
      tester.widget<TextFormField>(fieldFor(label)).controller!.text;

  group('write order', () {
    testWidgets('defaults to month-first (MM/DD/YYYY), as Form.io does',
        (tester) async {
      final written = pump(tester, schema());
      await written();

      // 7 March 1990, entered semantically.
      await type(tester, 'Month', 3);
      await type(tester, 'Day', 7);
      await type(tester, 'Year', 1990);

      expect(await written(), '03/07/1990',
          reason: 'month belongs in the first segment when dayFirst is unset');
    });

    testWidgets('dayFirst:true writes day-first (DD/MM/YYYY)', (tester) async {
      final written = pump(tester, schema(dayFirst: true));
      await written();

      await type(tester, 'Month', 3);
      await type(tester, 'Day', 7);
      await type(tester, 'Year', 1990);

      expect(await written(), '07/03/1990',
          reason: 'the same date must serialise day-first here');
    });

    testWidgets('a hidden part is omitted from the value, not zero-filled',
        (tester) async {
      final written = pump(tester, schema(hideDay: true));
      await written();

      expect(find.byType(TextFormField), findsNWidgets(2));
      await type(tester, 'Month', 3);
      await type(tester, 'Year', 1990);

      expect(await written(), '03/1990',
          reason: 'the engine shifts its indices when segments are missing');
    });

    testWidgets('an incomplete date writes null', (tester) async {
      final written = pump(tester, schema());
      await written();

      await type(tester, 'Month', 3);
      expect(await written(), isNull);
    });

    testWidgets('a day above 12 lands in the day segment', (tester) async {
      // 25 can only be a day; if it appeared first the order would be wrong in a
      // way the engine would reject as an invalid month.
      final written = pump(tester, schema());
      await written();

      await type(tester, 'Month', 6);
      await type(tester, 'Day', 25);
      await type(tester, 'Year', 2001);

      expect(await written(), '06/25/2001');
    });
  });

  group('read order', () {
    testWidgets('reads MM/DD/YYYY by default', (tester) async {
      // 03/07/1990 is 7 March: month in the first segment.
      final written = pump(tester, schema(), value: '03/07/1990');
      await written();

      expect(shown(tester, 'Month'), '3');
      expect(shown(tester, 'Day'), '7');
      expect(shown(tester, 'Year'), '1990');
    });

    testWidgets('reads DD/MM/YYYY when dayFirst is true', (tester) async {
      final written = pump(tester, schema(dayFirst: true), value: '07/03/1990');
      await written();

      expect(shown(tester, 'Day'), '7');
      expect(shown(tester, 'Month'), '3');
    });

    testWidgets('a value read back in keeps month and day in their slots',
        (tester) async {
      final written = pump(tester, schema(), value: '03/07/1990');
      await written();

      // Change only the year — entering the same value emits no onChanged, so it
      // has to differ. Month and day must come back out where they went in.
      await type(tester, 'Year', 1991);
      expect(await written(), '03/07/1991');
    });

    testWidgets('reads a hidden-day value with two segments', (tester) async {
      final written = pump(tester, schema(hideDay: true), value: '03/1990');
      await written();

      expect(shown(tester, 'Month'), '3');
      expect(shown(tester, 'Year'), '1990');
    });

    testWidgets('still accepts an ISO value', (tester) async {
      final written = pump(tester, schema(), value: '1990-03-07');
      await written();

      expect(shown(tester, 'Month'), '3');
      expect(shown(tester, 'Day'), '7');
      expect(shown(tester, 'Year'), '1990');
    });

    testWidgets('"00/00/0000" reads as no date', (tester) async {
      final written = pump(tester, schema(), value: '00/00/0000');
      await written();

      expect(shown(tester, 'Month'), isEmpty);
      expect(shown(tester, 'Day'), isEmpty);
      expect(shown(tester, 'Year'), isEmpty);
    });
  });
}
