/// What a `time` component stores.
///
/// The engine strict-parses the value against the schema's `dataFormat`
/// (`HH:mm:ss` by default), so a bare time of day is the only shape that
/// validates — and the only shape that reads back into the field.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_form.dart';

void main() {
  Future<Map<String, dynamic>> pump(
    WidgetTester tester, {
    String type = 'time',
    String? format,
    String? dataFormat,
    String? stored,
  }) =>
      pumpForm(
        tester,
        initialData: stored == null ? null : {'when': stored},
        form: formOf([
          field(type, 'when', label: 'When', extra: {
            if (format != null) 'format': format,
            if (dataFormat != null) 'dataFormat': dataFormat,
          }),
        ]),
      );

  /// Opens the field's picker and confirms whatever it opened on.
  Future<void> pickUnchanged(WidgetTester tester, IconData icon) async {
    await tester.tap(find.byIcon(icon));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  testWidgets('a stored time of day renders', (tester) async {
    await pump(tester, format: 'HH:mm', stored: '15:56:00');
    expect(find.text('15:56'), findsOneWidget);
  });

  testWidgets('a stored time of day renders without a format', (tester) async {
    await pump(tester, stored: '15:56:00');
    expect(find.text('15:56'), findsOneWidget);
  });

  testWidgets('a time is stored in its dataFormat', (tester) async {
    final data = await pump(tester, format: 'HH:mm', stored: '09:30:00');

    await pickUnchanged(tester, Icons.access_time);

    // Not an ISO timestamp: the engine strict-parses this against `HH:mm:ss`.
    expect(data['when'], '09:30:00');
  });

  testWidgets('an authored dataFormat is honoured both ways', (tester) async {
    final data = await pump(
      tester,
      format: 'HH:mm',
      dataFormat: 'HH:mm',
      stored: '09:30',
    );
    expect(find.text('09:30'), findsOneWidget);

    await pickUnchanged(tester, Icons.access_time);
    expect(data['when'], '09:30');
  });

  testWidgets('a timestamp stored by an older submission still reads', (
    tester,
  ) async {
    await pump(tester, format: 'HH:mm', stored: '2026-03-09T15:04:00.000');
    expect(find.text('15:04'), findsOneWidget);
  });

  testWidgets('a datetime keeps storing a timestamp', (tester) async {
    final data = await pump(
      tester,
      type: 'datetime',
      format: 'yyyy-MM-dd',
      stored: '2026-03-09T15:04:00.000',
    );

    await pickUnchanged(tester, Icons.calendar_today);

    expect(data['when'], startsWith('2026-03-09T'));
  });

  testWidgets('an unparseable value leaves the field unset', (tester) async {
    await pump(tester, format: 'HH:mm', stored: 'half past three');
    expect(find.text('Select…'), findsOneWidget);
  });
}
