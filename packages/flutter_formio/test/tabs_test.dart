/// `tabs` must render an actual tab bar showing one tab at a time, not the old
/// flattened concatenation of every tab's contents.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formio/formio.dart';

import 'support/fake_engine.dart';

Map<String, dynamic> field(String key, String label) => {
      'key': key,
      'type': 'textfield',
      'label': label,
      'input': true,
    };

Map<String, dynamic> tabsForm(List<Map<String, dynamic>> tabs) => {
      'display': 'form',
      'components': [
        {'type': 'tabs', 'key': 'tabs1', 'components': tabs},
      ],
    };

void main() {
  Future<void> pump(
    WidgetTester tester,
    Map<String, dynamic> form, {
    FormEngine? engine,
    FormioTheme theme = const FormioTheme(),
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EngineFormRenderer(
          engine: engine ?? FakeEngine(),
          form: form,
          theme: theme,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  final twoTabs = tabsForm([
    {
      'key': 'tabA',
      'label': 'Details',
      'components': [field('a', 'Field A')],
    },
    {
      'key': 'tabB',
      'label': 'Extras',
      'components': [field('b', 'Field B')],
    },
  ]);

  testWidgets('renders a TabBar with one tab per entry', (tester) async {
    await pump(tester, twoTabs);

    expect(find.byType(TabBar), findsOneWidget);
    expect(find.byType(Tab), findsNWidgets(2));
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Extras'), findsOneWidget);
  });

  testWidgets('uses a swipeable TabBarView, not a flattened column',
      (tester) async {
    await pump(tester, twoTabs);

    expect(find.byType(TabBarView), findsOneWidget,
        reason: 'tabs must be swipeable, not tap-only');
    expect(find.text('Field A'), findsOneWidget);
  });

  /// Swipes horizontally from a point clear of any input.
  ///
  /// A [TextField] runs its own horizontal drag recognizer for text selection
  /// and wins the arena, so a swipe that *starts* on a field selects text rather
  /// than changing tabs — standard Flutter behaviour for a swipeable page
  /// containing inputs. Real users swipe from a neutral area; tapping the tab
  /// always works regardless.
  Future<void> swipeLeft(WidgetTester tester) async {
    final view = tester.getRect(find.byType(TabBarView));
    await tester.dragFrom(
      Offset(view.center.dx, view.top + 6), // the label row
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('swiping moves to the next tab', (tester) async {
    await pump(tester, twoTabs);
    expect(find.text('Field A'), findsOneWidget);

    await swipeLeft(tester);

    expect(find.text('Field B'), findsOneWidget);
    expect(find.text('Field A'), findsNothing,
        reason: 'the first tab should have scrolled away');
  });

  testWidgets('swiping keeps the TabBar selection in step', (tester) async {
    await pump(tester, twoTabs);
    await swipeLeft(tester);

    final controller =
        tester.widget<TabBarView>(find.byType(TabBarView)).controller!;
    expect(controller.index, 1,
        reason: 'the bar and the pages share one TabController');
  });

  testWidgets('the viewport is sized to the active page, not collapsed',
      (tester) async {
    await pump(tester, twoTabs);

    final view = tester.getSize(find.byType(TabBarView));
    expect(view.height, greaterThan(0),
        reason: 'an unmeasured page must not collapse to zero height');
    expect(view.height.isFinite, isTrue);
  });

  testWidgets('tapping a tab swaps the content', (tester) async {
    await pump(tester, twoTabs);

    await tester.tap(find.text('Extras'));
    await tester.pumpAndSettle();

    expect(find.text('Field B'), findsOneWidget);
    expect(find.text('Field A'), findsNothing);
  });

  testWidgets('a field keeps its value across a tab switch', (tester) async {
    await pump(tester, twoTabs);

    await tester.enterText(find.byType(TextField), 'typed');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Extras'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    expect(find.text('typed'), findsOneWidget,
        reason: 'controllers are keyed by data path, so state must survive');
  });

  testWidgets('a tab the engine hides by key is dropped', (tester) async {
    await pump(tester, twoTabs, engine: FakeEngine(hidden: {'tabB': true}));

    expect(find.byType(Tab), findsNWidgets(1));
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Extras'), findsNothing);
  });

  testWidgets('an error in an inactive tab is flagged on its tab',
      (tester) async {
    // Errors only show once submitted, so drive the submit button first.
    await pump(
      tester,
      twoTabs,
      engine: FakeEngine(errors: [
        const FormLogicError(path: 'b', rule: 'required'),
      ]),
    );

    expect(find.byIcon(Icons.error_outline), findsNothing,
        reason: 'nothing is flagged before submit');

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    // Field B lives in the inactive tab, so the badge is the only clue.
    expect(find.text('Field B'), findsNothing);
    expect(find.byIcon(Icons.error_outline), findsOneWidget,
        reason: 'an invalid field behind another tab must be findable');
  });

  testWidgets('an error nested in a panel inside a tab still flags it',
      (tester) async {
    final nested = tabsForm([
      {
        'key': 'tabA',
        'label': 'First',
        'components': [field('a', 'Field A')],
      },
      {
        'key': 'tabB',
        'label': 'Second',
        'components': [
          {
            'type': 'panel',
            'key': 'p',
            'title': 'Inner',
            'components': [field('deep', 'Deep Field')],
          },
        ],
      },
    ]);

    await pump(tester, nested,
        engine: FakeEngine(errors: [
          const FormLogicError(path: 'deep', rule: 'required'),
        ]));
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('a textarea in a tab does not crash the error walk',
      (tester) async {
    // Regression: the walker read `rows` on every component, but a textarea's
    // `rows` is its line count (an int), not a table's list of rows — casting it
    // to List threw "type 'int' is not a subtype of type 'List<dynamic>?'".
    final withTextarea = tabsForm([
      {
        'key': 'tabA',
        'label': 'First',
        'components': [
          {
            'key': 'notes',
            'type': 'textarea',
            'label': 'Notes',
            'input': true,
            'rows': 3,
          },
        ],
      },
      {
        'key': 'tabB',
        'label': 'Second',
        'components': [field('b', 'Field B')],
      },
    ]);

    await pump(tester, withTextarea);
    expect(tester.takeException(), isNull);
    expect(find.text('Notes'), findsOneWidget);

    // The badge walk runs on submit — that is where it used to blow up.
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a non-list `columns` value is ignored, not cast',
      (tester) async {
    final oddColumns = tabsForm([
      {
        'key': 'tabA',
        'label': 'First',
        'components': [
          // Some component types carry `columns` as a count.
          {...field('a', 'Field A'), 'columns': 2},
        ],
      },
    ]);

    await pump(tester, oddColumns);
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  group('appearance', () {
    testWidgets('the bar drops the divider and spans the indicator',
        (tester) async {
      await pump(tester, twoTabs);
      final bar = tester.widget<TabBar>(find.byType(TabBar));

      expect(bar.dividerHeight, 0,
          reason: 'the full-width Material divider fights the content card');
      expect(bar.indicatorSize, TabBarIndicatorSize.tab,
          reason: 'the default label-width indicator reads as stubby');
    });

    testWidgets('tab content is grouped in a card', (tester) async {
      await pump(tester, twoTabs);

      expect(
        find.descendant(
            of: find.byType(TabBarView), matching: find.byType(Card)),
        findsOneWidget,
        reason: 'loose fields give no sense of what belongs to the tab',
      );
    });

    testWidgets('the card follows the theme sectionDecoration', (tester) async {
      await pump(
        tester,
        twoTabs,
        theme: FormioTheme(
          sectionDecoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE4EAEB)),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );

      // Same treatment panels get: a decorated container instead of a Card.
      expect(
          find.descendant(
              of: find.byType(TabBarView), matching: find.byType(Card)),
          findsNothing);
      final decorated = tester
          .widgetList<Container>(find.descendant(
              of: find.byType(TabBarView), matching: find.byType(Container)))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.border != null);
      expect(decorated, isNotEmpty);
      expect(decorated.first.borderRadius, BorderRadius.circular(8));
    });
  });

  testWidgets('a tabs component with no tabs renders nothing', (tester) async {
    await pump(tester, tabsForm(const []));

    expect(find.byType(TabBar), findsNothing);
  });
}
