/// `content` renders form-authored HTML, so its `html` property and its link
/// handling both take untrusted-shaped input.
library;

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formio/formio.dart';
import 'package:formio/src/widgets/components/safe_link.dart';

void main() {
  Future<void> pump(WidgetTester tester, Map<String, dynamic> raw,
      {Map<String, dynamic>? data}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ContentComponent(
          component: ComponentModel.fromJson(raw),
          formData: data,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> content(Object? html) => {
        'key': 'c1',
        'type': 'content',
        'label': 'Content',
        'input': false,
        'html': html,
      };

  testWidgets('renders the html property', (tester) async {
    await pump(tester, content('<p>Hello there</p>'));

    expect(find.byType(Html), findsOneWidget);
    expect(find.textContaining('Hello there'), findsWidgets);
  });

  testWidgets('interpolates {{data.x}}', (tester) async {
    await pump(tester, content('<p>Hi {{data.name}}</p>'),
        data: {'name': 'Joe'});

    expect(find.textContaining('Hi Joe'), findsWidgets);
  });

  testWidgets('empty html renders nothing', (tester) async {
    await pump(tester, content('   '));

    expect(find.byType(Html), findsNothing);
  });

  testWidgets('a non-string html value does not throw', (tester) async {
    // `interpolate` takes a String; a numeric `html` used to reach it as dynamic.
    await pump(tester, content(42));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('42'), findsWidgets);
  });

  testWidgets('a missing html value renders nothing', (tester) async {
    await pump(tester, content(null));

    expect(tester.takeException(), isNull);
    expect(find.byType(Html), findsNothing);
  });

  group('link targets', () {
    // openFormLink is exercised directly: launching needs a platform channel,
    // but the parse/allow-list decision is pure and is where the bugs were.
    test('a malformed href is ignored rather than throwing', () async {
      // Uri.parse would have thrown FormatException on tap.
      await expectLater(openFormLink('ht!tp://[bad'), completes);
    });

    test('null and blank are ignored', () async {
      await expectLater(openFormLink(null), completes);
      await expectLater(openFormLink('   '), completes);
    });

    test('a disallowed scheme is ignored', () async {
      // Would previously have been handed to launchUrl as-is.
      for (final url in ['file:///etc/passwd', 'myapp://do-something']) {
        await expectLater(openFormLink(url), completes);
      }
    });
  });
}
