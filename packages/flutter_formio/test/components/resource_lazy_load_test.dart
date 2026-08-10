/// `dataSrc: "resource"` (and the `resource` component type), plus `lazyLoad`.
///
/// `resource` used to fall through to the unknown-component placeholder, so the
/// field never reached the submission at all. `lazyLoad` was unread, so every
/// remote select fetched the moment the form was built.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formio/formio.dart';

import '../support/fake_engine.dart';

void main() {
  setUp(RemoteSelectOptions.clearCache);

  Map<String, dynamic> resourceForm({
    String type = 'select',
    bool lazyLoad = false,
    int? limit,
  }) =>
      {
        'display': 'form',
        'components': [
          {
            'key': 'who',
            'type': type,
            'label': 'Who',
            'input': true,
            'dataSrc': 'resource',
            'lazyLoad': lazyLoad,
            if (limit != null) 'limit': limit,
            'data': {'resource': 'RES123'},
            'valueProperty': '_id',
            'template': '{{ item.data.name }}',
          },
        ],
      };

  Future<Map<String, dynamic>> pump(
    WidgetTester tester,
    Map<String, dynamic> form, {
    FormioResourceSource? source,
  }) async {
    final latest = <String, dynamic>{};
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EngineFormRenderer(
          engine: FakeEngine(),
          form: form,
          resourceSource: source,
          onChanged: (d) {
            latest
              ..clear()
              ..addAll(d);
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return latest;
  }

  testWidgets('the resource component type renders a select, not a placeholder',
      (tester) async {
    // The *type* must dispatch to a select — otherwise the field is a warning
    // card and its value can never be collected. Lazy, so the control stays on
    // screen instead of being replaced by the not-configured error.
    await pump(tester, resourceForm(type: 'resource', lazyLoad: true));
    expect(find.byType(UnknownComponent), findsNothing);
    expect(find.byType(FormioBuiltInSelect), findsOneWidget);
    expect(find.byType(SelectPickerField), findsOneWidget);
  });

  testWidgets('a resource with no configured project reports an error',
      (tester) async {
    await pump(tester, resourceForm());
    // Misconfigured, not empty — an empty list would look like "no results".
    expect(find.text(ComponentFactory.locale.dataSourceError), findsOneWidget);
  });

  test('the submissions URL is built from the project and resource id', () {
    // The piece that turns a bare resource id into something addressable.
    const source = FormioResourceSource(
      projectUrl: 'https://proj.form.io/',
      headers: {'x-jwt-token': 'tok'},
    );
    expect(source.submissionsUrl('RES123', limit: 100),
        'https://proj.form.io/form/RES123/submission?limit=100');
    // A trailing slash on the project URL must not double up.
    expect(source.submissionsUrl('RES123'),
        'https://proj.form.io/form/RES123/submission');
  });

  testWidgets('lazyLoad off fetches immediately; the wait is visible',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EngineFormRenderer(
          engine: FakeEngine(),
          form: resourceForm(),
          resourceSource:
              const FormioResourceSource(projectUrl: 'https://proj.form.io'),
        ),
      ),
    ));
    // One frame in, the request is already in flight and says so.
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('lazyLoad on keeps the control on screen and makes no request',
      (tester) async {
    await pump(tester, resourceForm(lazyLoad: true),
        source: const FormioResourceSource(projectUrl: 'https://proj.form.io'));

    // The control must stay mounted rather than being swapped for a spinner —
    // it is what triggers the fetch, and unmounting it would close the picker
    // the user just opened.
    expect(find.byType(SelectPickerField), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // Nothing is shown as an error either: not-yet-asked is not a failure.
    expect(find.text(ComponentFactory.locale.dataSourceError), findsNothing);
  });

  testWidgets('a lazy select with no project still opens rather than breaking',
      (tester) async {
    await pump(tester, resourceForm(lazyLoad: true));
    await tester.tap(find.byType(SelectPickerField));
    await tester.pumpAndSettle();

    // Empty, and honest about it, instead of throwing on the missing config.
    expect(find.text(ComponentFactory.locale.noOptions), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('selectLimit reads both numeric and string forms', () {
    expect(selectLimit({'limit': 100}), 100);
    expect(selectLimit({'limit': '50'}), 50);
    expect(selectLimit({'limit': ''}), isNull);
    expect(selectLimit(const {}), isNull);
  });

  test('resourceIdOf trims and rejects blanks', () {
    expect(
        resourceIdOf({
          'data': {'resource': ' RES1 '}
        }),
        'RES1');
    expect(
        resourceIdOf({
          'data': {'resource': '  '}
        }),
        isNull);
    expect(resourceIdOf(const {}), isNull);
  });

  test('selectNeedsFetch covers url and resource only', () {
    expect(selectNeedsFetch({'dataSrc': 'url'}), isTrue);
    expect(selectNeedsFetch({'dataSrc': 'resource'}), isTrue);
    expect(selectNeedsFetch({'dataSrc': 'values'}), isFalse);
    expect(selectNeedsFetch({'dataSrc': 'json'}), isFalse);
    expect(selectNeedsFetch(const {}), isFalse);
  });
}
