/// `htmlelement` wraps its `content` in `tag` (default `p`). Only `hr` used to
/// be honoured, so the tag-based styling never matched anything else.
library;

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formio/formio.dart';

void main() {
  Future<void> pump(WidgetTester tester, Map<String, dynamic> raw,
      {Map<String, dynamic>? data}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HtmlElementComponent(
          component: ComponentModel.fromJson({
            'key': 'h1',
            'type': 'htmlelement',
            'input': false,
            ...raw,
          }),
          formData: data,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  String rendered(WidgetTester tester) =>
      tester.widget<Html>(find.byType(Html)).data ?? '';

  testWidgets('wraps content in the given tag', (tester) async {
    await pump(tester, {'tag': 'h1', 'content': 'Big Title'});

    expect(rendered(tester), '<h1>Big Title</h1>',
        reason: 'without the wrapper the h1 style never applies');
  });

  testWidgets('defaults to a paragraph', (tester) async {
    await pump(tester, {'content': 'Just text'});

    expect(rendered(tester), '<p>Just text</p>');
  });

  testWidgets('a void tag renders standalone', (tester) async {
    await pump(tester, {'tag': 'hr'});

    expect(rendered(tester), '<hr/>');
  });

  testWidgets('interpolates content before wrapping', (tester) async {
    await pump(tester, {'tag': 'h2', 'content': 'Hi {{data.name}}'},
        data: {'name': 'Joe'});

    expect(rendered(tester), '<h2>Hi Joe</h2>');
  });

  testWidgets('empty content renders nothing', (tester) async {
    await pump(tester, {'tag': 'h1', 'content': '  '});

    expect(find.byType(Html), findsNothing);
  });

  testWidgets('a non-element tag falls back to p rather than being emitted',
      (tester) async {
    // The tag is written into markup, so it must not carry arbitrary text.
    await pump(tester, {'tag': 'script src=x', 'content': 'hello'});

    expect(rendered(tester), '<p>hello</p>');
  });

  testWidgets('a non-string tag does not throw', (tester) async {
    await pump(tester, {'tag': 42, 'content': 'hello'});

    expect(tester.takeException(), isNull);
    expect(rendered(tester), '<p>hello</p>');
  });
}
