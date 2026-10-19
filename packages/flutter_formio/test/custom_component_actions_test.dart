/// A component can put its own actions where the form's Submit button is.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formio/formio.dart';

import 'support/pump_form.dart';

/// Claims the bar while mounted and gives it back when disposed, as the
/// contract asks.
class _Wizard extends StatefulWidget {
  const _Wizard(this.ctx, {super.key, required this.claims});

  final FormioFieldContext ctx;
  final bool claims;

  @override
  State<_Wizard> createState() => _WizardState();
}

class _WizardState extends State<_Wizard> {
  late FormioFieldContext _ctx = widget.ctx;

  @override
  void initState() {
    super.initState();
    _claim();
  }

  @override
  void didUpdateWidget(_Wizard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ctx = widget.ctx;
    if (widget.claims != oldWidget.claims) _claim();
  }

  void _claim() => _ctx.setActions(widget.claims ? _next : null);

  Widget _next(BuildContext context) =>
      TextButton(onPressed: () {}, child: const Text('NEXT'));

  @override
  void dispose() {
    _ctx.releaseActions(_next);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Text('WIZARD');
}

void main() {
  final submit = find.widgetWithText(ElevatedButton, 'Submit');

  testWidgets('replaces the Submit button while the component claims it',
      (tester) async {
    await pumpForm(
      tester,
      customComponents: {'wizard': (ctx) => _Wizard(ctx, claims: true)},
      form: formOf([field('wizard', 'wizard')]),
    );

    expect(find.text('NEXT'), findsOneWidget);
    expect(submit, findsNothing);
    // The test id belongs to the default button, so it goes with it.
    expect(find.bySemanticsIdentifier('formio_submit'), findsNothing);
  });

  testWidgets('the default Submit button keeps its test id', (tester) async {
    await pumpForm(tester, form: formOf([field('textfield', 'notes')]));

    expect(submit, findsOneWidget);
    expect(find.bySemanticsIdentifier('formio_submit'), findsOneWidget);
  });

  testWidgets('gives the Submit button back when released', (tester) async {
    var claims = true;
    await pumpForm(
      tester,
      customComponents: {'wizard': (ctx) => _Wizard(ctx, claims: claims)},
      form: formOf([
        field('wizard', 'wizard'),
        field('textfield', 'notes'),
      ]),
    );

    claims = false;
    await tester.enterText(find.byType(TextField), 'x');
    await settleDebounce(tester);

    expect(find.text('NEXT'), findsNothing);
    expect(submit, findsOneWidget);
  });

  testWidgets('gives the Submit button back when the component is hidden',
      (tester) async {
    final hidden = <String, dynamic>{};
    await pumpForm(
      tester,
      engine: FakeEngine(hidden: hidden),
      customComponents: {'wizard': (ctx) => _Wizard(ctx, claims: true)},
      form: formOf([
        field('wizard', 'wizard'),
        field('textfield', 'notes'),
      ]),
    );

    hidden['wizard'] = true;
    await tester.enterText(find.byType(TextField), 'x');
    await settleDebounce(tester);

    expect(find.text('WIZARD'), findsNothing);
    expect(submit, findsOneWidget);
  });

  testWidgets('keeps the bar of a component remounted at the same path',
      (tester) async {
    var generation = 0;
    await pumpForm(
      tester,
      customComponents: {
        'wizard': (ctx) =>
            _Wizard(ctx, key: ValueKey(generation), claims: true),
      },
      form: formOf([
        field('wizard', 'wizard'),
        field('textfield', 'notes'),
      ]),
    );

    generation++;
    await tester.enterText(find.byType(TextField), 'x');
    await settleDebounce(tester);

    expect(find.text('NEXT'), findsOneWidget);
    expect(submit, findsNothing);
  });
}
