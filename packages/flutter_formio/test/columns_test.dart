/// `columns` grid behaviour, against the wiki's Column Configuration table:
/// `width` is required with a default of **6**, and `offset`/`push`/`pull`
/// default to 0.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formio/formio.dart';

class _PassthroughEngine implements FormEngine {
  @override
  void setForm(Map<String, dynamic> form) {}

  @override
  FormLogicResult processData(Map<String, dynamic> submissionData,
          {bool validate = true}) =>
      FormLogicResult(
          data: submissionData, hidden: const {}, errors: const []);
}

Map<String, dynamic> field(String key, String label) => {
      'key': key,
      'type': 'textfield',
      'label': label,
      'input': true,
    };

void main() {
  Future<void> pump(WidgetTester tester, List<Map<String, dynamic>> columns,
      {double breakpoint = 10}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EngineFormRenderer(
          engine: _PassthroughEngine(),
          // Low breakpoint so columns stay side by side and widths are testable.
          theme: FormioTheme(columnBreakpoint: breakpoint),
          form: {
            'display': 'form',
            'components': [
              {'type': 'columns', 'key': 'cols', 'columns': columns},
            ],
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Width of the column box containing the field labelled [label].
  double columnWidth(WidgetTester tester, String label) => tester
      .widgetList<SizedBox>(find.ancestor(
        of: find.text(label),
        matching: find.byType(SizedBox),
      ))
      .map((b) => b.width)
      .whereType<double>()
      .reduce((a, b) => a > b ? a : b);

  testWidgets('an explicit width sizes the column', (tester) async {
    await pump(tester, [
      {'width': 3, 'components': [field('a', 'A')]},
      {'width': 9, 'components': [field('b', 'B')]},
    ]);

    final a = columnWidth(tester, 'A');
    final b = columnWidth(tester, 'B');
    // 3:9 units, so B is about three times A.
    expect(b / a, closeTo(3.0, 0.15));
  });

  testWidgets('a width given as a string does not crash', (tester) async {
    // Regression: `c['width'] as num?` threw on "6" — the same unsafe-cast
    // class as a textarea's integer `rows`.
    await pump(tester, [
      {'width': '3', 'components': [field('a', 'A')]},
      {'width': '9', 'components': [field('b', 'B')]},
    ]);

    expect(tester.takeException(), isNull);
    expect(columnWidth(tester, 'B') / columnWidth(tester, 'A'),
        closeTo(3.0, 0.15));
  });

  testWidgets('a missing width defaults to 6, not full width', (tester) async {
    await pump(tester, [
      {'components': [field('a', 'A')]},
      {'components': [field('b', 'B')]},
    ]);

    final a = columnWidth(tester, 'A');
    final b = columnWidth(tester, 'B');
    expect(a, closeTo(b, 1.0), reason: 'two default columns should be equal');
    // Half of the ~800px viewport, not all of it.
    expect(a, lessThan(500), reason: 'default width 12 made columns full-width');
  });

  testWidgets('columns stack when narrower than the breakpoint',
      (tester) async {
    await pump(
      tester,
      [
        {'width': 6, 'components': [field('a', 'A')]},
        {'width': 6, 'components': [field('b', 'B')]},
      ],
      // Force the collapse path.
      breakpoint: 4000,
    );

    // Stacked: B sits below A rather than beside it.
    expect(tester.getTopLeft(find.text('B')).dy,
        greaterThan(tester.getTopLeft(find.text('A')).dy));
    expect(tester.getTopLeft(find.text('B')).dx,
        closeTo(tester.getTopLeft(find.text('A')).dx, 1.0));
  });

  testWidgets('an empty columns component renders nothing', (tester) async {
    await pump(tester, const []);
    expect(find.byType(Wrap), findsNothing);
  });
}
