/// The chooser shared by single- and multi-select.
///
/// Both controls used to carry their own copy — 84 identical lines each — and the
/// copies had already drifted, which is how a multi-select ended up with a stock
/// border and no fill while the single one was themed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formio/formio.dart';

void main() {
  const options = [
    FormioOption(label: 'Ada', value: 1),
    FormioOption(label: 'Grace', value: 2),
    FormioOption(label: 'Hedy', value: 3),
  ];

  /// Renders a button that opens the chooser and records what it returns.
  Future<List<FormioOption>? Function()> pump(
    WidgetTester tester, {
    required bool multiple,
    bool searchable = true,
    Set<String> selectedKeys = const {},
    Future<List<FormioOption>> Function()? loadOptions,
  }) async {
    List<FormioOption>? result;
    var returned = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showOptionPicker(
                context: context,
                options: options,
                selectedKeys: selectedKeys,
                multiple: multiple,
                searchable: searchable,
                loadOptions: loadOptions,
              );
              returned = true;
            },
            child: const Text('OPEN'),
          ),
        ),
      ),
    ));
    return () {
      expect(returned, isTrue, reason: 'the picker never resolved');
      return result;
    };
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
  }

  testWidgets('single: one tap picks and closes, with no confirm step',
      (tester) async {
    final result = await pump(tester, multiple: false);
    await open(tester);

    // No Save — a single choice does not need confirming.
    expect(find.text(ComponentFactory.locale.save), findsNothing);
    await tester.tap(find.text('Grace'));
    await tester.pumpAndSettle();

    final chosen = result();
    expect(chosen?.single.value, 2);
    expect(chosen?.single.value, isA<int>(),
        reason: 'the option keeps its schema type');
  });

  testWidgets('multiple: ticks accumulate and Save confirms them',
      (tester) async {
    final result = await pump(tester, multiple: true);
    await open(tester);

    await tester.tap(find.text('Hedy'));
    await tester.pump();
    await tester.tap(find.text('Ada'));
    await tester.pump();
    await tester.tap(find.text(ComponentFactory.locale.save));
    await tester.pumpAndSettle();

    final chosen = result();
    // Source order, not tick order, so the chips read like the list did.
    expect(chosen?.map((o) => o.value).toList(), [1, 3]);
  });

  testWidgets('multiple: Cancel discards the ticks', (tester) async {
    final result = await pump(tester, multiple: true, selectedKeys: {'1'});
    await open(tester);

    await tester.tap(find.text('Hedy'));
    await tester.pump();
    await tester.tap(find.text(ComponentFactory.locale.cancel));
    await tester.pumpAndSettle();

    expect(result(), isNull, reason: 'null means "leave it as it was"');
  });

  testWidgets('search filters by label', (tester) async {
    await pump(tester, multiple: false);
    await open(tester);

    await tester.enterText(find.byType(TextField), 'gra');
    await tester.pumpAndSettle();

    expect(find.text('Grace'), findsOneWidget);
    expect(find.text('Ada'), findsNothing);
  });

  testWidgets('searchable: false offers no search field', (tester) async {
    await pump(tester, multiple: true, searchable: false);
    await open(tester);

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Ada'), findsOneWidget);
  });

  testWidgets('a search matching nothing says so rather than showing blank',
      (tester) async {
    await pump(tester, multiple: false);
    await open(tester);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text(ComponentFactory.locale.noOptions), findsOneWidget);
  });

  testWidgets('loadOptions is awaited before the list is shown',
      (tester) async {
    // The dialog is on its own route, so options arriving after it opens would
    // never reach it — this is the ordering `lazyLoad` depends on.
    await pump(
      tester,
      multiple: false,
      loadOptions: () async => const [FormioOption(label: 'Late', value: 9)],
    );
    await open(tester);

    expect(find.text('Late'), findsOneWidget);
    expect(find.text('Ada'), findsNothing);
  });

  testWidgets('dismissing by barrier resolves null', (tester) async {
    final result = await pump(tester, multiple: false);
    await open(tester);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(result(), isNull);
  });
}
