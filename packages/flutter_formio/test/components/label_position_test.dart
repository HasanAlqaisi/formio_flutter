/// `labelPosition` carries a side *and* an alignment: `left-right` means "label
/// on the left, its text right-aligned".
///
/// Only the side used to be read, so every side-label rendered left-aligned —
/// 8 components in the sample forms ask for `left-right`.
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
      FormLogicResult(data: submissionData, hidden: const {}, errors: const []);
}

void main() {
  Future<void> pump(WidgetTester tester, String? labelPosition,
      {TextDirection direction = TextDirection.ltr}) async {
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: EngineFormRenderer(
            engine: _PassthroughEngine(),
            form: {
              'display': 'form',
              'components': [
                {
                  'key': 'name',
                  'type': 'textfield',
                  'label': 'Name',
                  'input': true,
                  if (labelPosition != null) 'labelPosition': labelPosition,
                },
              ],
            },
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  TextAlign? alignOfLabel(WidgetTester tester) =>
      tester.widget<Text>(find.text('Name')).textAlign;

  /// Whether the label is laid out before the field, in reading order.
  bool labelComesFirst(WidgetTester tester) =>
      tester.getTopLeft(find.text('Name')).dx <
      tester.getTopLeft(find.byType(TextField)).dx;

  testWidgets('left-right right-aligns the label but keeps it on the left',
      (tester) async {
    await pump(tester, 'left-right');
    expect(alignOfLabel(tester), TextAlign.end);
    expect(labelComesFirst(tester), isTrue);
  });

  testWidgets('left-left keeps the label left-aligned on the left',
      (tester) async {
    await pump(tester, 'left-left');
    expect(alignOfLabel(tester), TextAlign.start);
    expect(labelComesFirst(tester), isTrue);
  });

  testWidgets('right-right puts the label after the field, right-aligned',
      (tester) async {
    await pump(tester, 'right-right');
    expect(alignOfLabel(tester), TextAlign.end);
    expect(labelComesFirst(tester), isFalse);
  });

  testWidgets('a bare right side still works and defaults to start-aligned',
      (tester) async {
    // 11 components in the samples use plain `right`, with no second segment.
    await pump(tester, 'right');
    expect(alignOfLabel(tester), TextAlign.start);
    expect(labelComesFirst(tester), isFalse);
  });

  testWidgets('top stacks the label above and is the default', (tester) async {
    await pump(tester, null);
    expect(labelComesFirst(tester), isFalse,
        reason: 'stacked, so both share a left edge');
    expect(tester.getTopLeft(find.text('Name')).dy,
        lessThan(tester.getTopLeft(find.byType(TextField)).dy));
  });

  testWidgets('under RTL a left side becomes the leading side', (tester) async {
    // `start`/`end` rather than `left`/`right`, so the label sits leading and
    // its alignment mirrors with the text direction.
    await pump(tester, 'left-right', direction: TextDirection.rtl);
    expect(alignOfLabel(tester), TextAlign.end);
    // Leading under RTL is the right-hand side, so the label is no longer first
    // by x-coordinate.
    expect(labelComesFirst(tester), isFalse);
  });
}
