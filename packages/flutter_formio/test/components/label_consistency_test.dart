/// Every stock component that draws its own label must take it from the active
/// [FormioTheme], so one form doesn't show three different label weights.
///
/// Stock components are built through the static `ComponentFactory`, which
/// carries no theme, so they read it from [FormioThemeScope].
///
/// The list below is exhaustive on purpose: an earlier sweep used a single-line
/// pattern and silently missed `address`, `datatable`, `tagpad` and `tags`,
/// whose `Text(...)` calls span multiple lines.
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

void main() {
  const labelStyle = TextStyle(fontSize: 12.5, color: Color(0xFF707070));
  const themed = FormioTheme(labelStyle: labelStyle);

  /// type -> the label text to look for.
  const selfLabelling = {
    'signature': 'Sign',
    'sketchpad': 'Sketch',
    'file': 'Attach',
    'survey': 'Survey',
    'day': 'Date',
    'datamap': 'Data Map',
    'address': 'Address',
    'datatable': 'Table',
    'tagpad': 'Tagpad',
    'tags': 'Tags',
  };

  Future<void> pump(WidgetTester tester, String type, String label) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EngineFormRenderer(
          engine: _PassthroughEngine(),
          theme: themed,
          form: {
            'display': 'form',
            'components': [
              {'key': type, 'type': type, 'label': label, 'input': true},
            ],
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final entry in selfLabelling.entries) {
    testWidgets('${entry.key} label follows FormioTheme', (tester) async {
      await pump(tester, entry.key, entry.value);

      final found = find.text(entry.value);
      expect(found, findsWidgets,
          reason: '${entry.key} did not render its label at all');
      final style = tester.widget<Text>(found.first).style;
      expect(style?.fontSize, labelStyle.fontSize,
          reason: '${entry.key} still uses a textTheme style of its own');
      expect(style?.color, labelStyle.color);
    });
  }

  testWidgets('a stock label matches a built-in field label', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EngineFormRenderer(
          engine: _PassthroughEngine(),
          theme: themed,
          form: {
            'display': 'form',
            'components': [
              {
                'key': 'builtIn',
                'type': 'textfield',
                'label': 'Built In',
                'input': true,
              },
              {
                'key': 'stock',
                'type': 'signature',
                'label': 'Stock',
                'input': true,
              },
            ],
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final builtIn = tester.widget<Text>(find.text('Built In')).style;
    final stock = tester.widget<Text>(find.text('Stock')).style;
    expect(stock?.fontSize, builtIn?.fontSize);
    expect(stock?.color, builtIn?.color);
    expect(stock?.fontWeight, builtIn?.fontWeight);
  });
}
