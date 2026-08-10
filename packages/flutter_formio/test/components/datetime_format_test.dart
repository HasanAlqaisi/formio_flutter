/// A `date`/`datetime`/`time` component's `format` controls how the chosen value
/// reads back to the user.
///
/// It used to be ignored outright: every value rendered as `yyyy-MM-dd HH:mm`,
/// so a field asking for `hh:mm a` showed 24-hour time with no meridiem. Form.io
/// writes these patterns in the same token vocabulary ICU uses, so the schema
/// string goes straight to `DateFormat`.
library;

import 'package:flutter_test/flutter_test.dart';

import '../support/pump_form.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required String type,
    String? format,
    bool enableTime = false,
    required String stored,
  }) =>
      pumpForm(
        tester,
        initialData: {'when': stored},
        form: formOf([
          field(type, 'when', label: 'When', extra: {
            'enableTime': enableTime,
            if (format != null) 'format': format,
          }),
        ]),
      );

  testWidgets('a datetime honours its authored format', (tester) async {
    await pump(tester,
        type: 'datetime',
        enableTime: true,
        format: 'yyyy-MM-dd hh:mm a',
        stored: '2026-03-09T15:04:00.000');

    // 12-hour with a meridiem, which the old hardcoded format could not produce.
    expect(find.text('2026-03-09 03:04 PM'), findsOneWidget);
    expect(find.text('2026-03-09 15:04'), findsNothing);
  });

  testWidgets('a time honours a 24-hour format', (tester) async {
    await pump(tester,
        type: 'time', format: 'HH:mm', stored: '2026-03-09T15:04:00.000');
    expect(find.text('15:04'), findsOneWidget);
  });

  testWidgets('a day-month-year format reorders the parts', (tester) async {
    await pump(tester,
        type: 'date', format: 'dd/MM/yyyy', stored: '2026-03-09T00:00:00.000');
    expect(find.text('09/03/2026'), findsOneWidget);
  });

  testWidgets('no format falls back to the previous rendering', (tester) async {
    await pump(tester, type: 'date', stored: '2026-03-09T00:00:00.000');
    expect(find.text('2026-03-09'), findsOneWidget);
  });

  testWidgets('a format that renders blank falls back instead of showing empty',
      (tester) async {
    // DateFormat does not throw on a pattern it cannot read — it returns "".
    // An empty field reads as *unset*, which is worse than a wrong format, so
    // the blank has to be caught rather than displayed.
    await pump(tester,
        type: 'date',
        format: "'unterminated",
        stored: '2026-03-09T00:00:00.000');

    expect(tester.takeException(), isNull);
    expect(find.text('2026-03-09'), findsOneWidget);
  });

  testWidgets('an empty format is treated as absent', (tester) async {
    // Every component in the sample forms carries `format`, most of them blank.
    await pump(tester,
        type: 'date', format: '', stored: '2026-03-09T00:00:00.000');
    expect(find.text('2026-03-09'), findsOneWidget);
  });
}
