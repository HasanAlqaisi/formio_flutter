/// Emphasis colour and container borders on a themed form.
///
/// Two faults this pins down. The active tab was handed the *field label* style
/// for `labelStyle` — which in [TabBar] governs the selected tab — so it wore the
/// secondary grey and read as disabled while the inactive tabs kept the brighter
/// default. And repeated-row cards drew the ambient divider colour, which is
/// brighter than a themed input border, so a row outshone the fields inside it.
///
/// The accent is its own token because `colorScheme.primary` is a *fill* colour,
/// picked to sit under white text. A design system's on-background accent is
/// usually lighter; using the fill for a tab label is what looked disabled.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formio/formio.dart';

import 'support/fake_engine.dart';

void main() {
  // Mirrors fms's dark palette: a dark maroon fill and a light pink text accent.
  const fillAccent = Color(0xFF6A1E39);
  const textAccent = Color(0xFFFF6F91);
  const mutedLabel = Color(0xFF9AA8B8);
  const borderColor = Color(0xFF33414F);

  final theme = FormioTheme(
    accentColor: textAccent,
    labelStyle: const TextStyle(fontSize: 12.5, color: mutedLabel),
    inputBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: borderColor),
    ),
  );

  Future<void> pump(
    WidgetTester tester,
    Map<String, dynamic> form, {
    FormioTheme? formioTheme,
  }) async {
    await tester.pumpWidget(MaterialApp(
      // A primary that is deliberately *not* the accent, so a fallback to it
      // would be visible.
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark().copyWith(primary: fillAccent),
      ),
      home: Scaffold(
        body: EngineFormRenderer(
          engine: FakeEngine(),
          theme: formioTheme ?? theme,
          form: form,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  final tabsForm = {
    'display': 'form',
    'components': [
      {
        'type': 'tabs',
        'key': 'tabs',
        'components': [
          {
            'label': 'Tab 1',
            'key': 'tab1',
            'components': [
              {'key': 'a', 'type': 'textfield', 'label': 'A', 'input': true},
            ],
          },
          {'label': 'Tab 2', 'key': 'tab2', 'components': <dynamic>[]},
        ],
      },
    ],
  };

  final gridForm = {
    'display': 'form',
    'components': [
      {
        'key': 'rows',
        'type': 'datagrid',
        'label': 'Edit Grid',
        'input': true,
        'components': [
          {
            'key': 'a',
            'type': 'textfield',
            'label': 'Text Field',
            'input': true
          },
        ],
      },
    ],
  };

  group('tabs', () {
    testWidgets(
        'the active tab uses the accent, the inactive ones the muted '
        'label colour', (tester) async {
      await pump(tester, tabsForm);
      final bar = tester.widget<TabBar>(find.byType(TabBar));

      expect(bar.labelColor, textAccent);
      expect(bar.unselectedLabelColor, mutedLabel);
      // The bug was these two being effectively swapped.
      expect(bar.labelColor, isNot(bar.unselectedLabelColor));
    });

    testWidgets('labelStyle no longer carries the muted colour',
        (tester) async {
      await pump(tester, tabsForm);
      final bar = tester.widget<TabBar>(find.byType(TabBar));

      // `labelStyle` governs the *selected* tab, so a secondary colour here is
      // exactly what made the active tab look disabled.
      expect(bar.labelStyle?.color, textAccent);
      expect(bar.unselectedLabelStyle?.color, mutedLabel);
    });

    testWidgets('the indicator uses the accent, not the ambient primary',
        (tester) async {
      await pump(tester, tabsForm);
      expect(tester.widget<TabBar>(find.byType(TabBar)).indicatorColor,
          textAccent);
    });

    testWidgets('with no accent set it falls back to the ambient primary',
        (tester) async {
      await pump(tester, tabsForm, formioTheme: const FormioTheme());
      expect(tester.widget<TabBar>(find.byType(TabBar)).labelColor, fillAccent);
    });
  });

  group('focused input labels', () {
    testWidgets('a day text input uses the form accent', (tester) async {
      await pump(tester, {
        'display': 'form',
        'components': [
          {
            'key': 'date',
            'type': 'day',
            'label': 'Date',
            'input': true,
          },
        ],
      });

      await tester.tap(find.byType(TextFormField).first);
      await tester.pump();

      final focusedInput = tester
          .widgetList<InputDecorator>(find.byType(InputDecorator))
          .firstWhere((input) => input.isFocused);
      expect(focusedInput.decoration.floatingLabelStyle?.color, textAccent);
    });
  });

  group('repeated-row cards', () {
    testWidgets('use the input border colour, not the ambient divider',
        (tester) async {
      await pump(tester, gridForm);
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      final card = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.border is Border && d.borderRadius != null);

      expect((card.border! as Border).top.color, borderColor);
      // And the same corner radius as the fields it contains.
      expect(card.borderRadius, BorderRadius.circular(8));
    });

    testWidgets('the add-row action uses the accent', (tester) async {
      await pump(tester, gridForm);
      final button = tester.widget<TextButton>(find.byType(TextButton).first);
      expect(
        button.style?.foregroundColor?.resolve(const <WidgetState>{}),
        textAccent,
      );
    });
  });
}
