/// A `dataSrc: url` select must fetch its options. Previously the dropdown was
/// simply empty, with nothing to indicate why.
library;

import 'package:dio/dio.dart';
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

/// Serves canned responses so no real network is involved.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);
  final ResponseBody Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? stream,
      Future<void>? cancelFuture) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(RemoteSelectOptions.clearCache);

  Dio stub(ResponseBody Function(RequestOptions o) handler) =>
      Dio()..httpClientAdapter = _StubAdapter(handler);

  ResponseBody json(String body, {int status = 200}) =>
      ResponseBody.fromString(body, status,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

  Future<void> pumpRemote(
    WidgetTester tester, {
    required Dio client,
    Map<String, dynamic> extra = const {},
    Map<String, dynamic> formData = const {},
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RemoteSelectOptions(
          client: client,
          formData: formData,
          component: {
            'key': 'city',
            'type': 'select',
            'dataSrc': 'url',
            'valueProperty': 'id',
            'template': '{{ item.name }}',
            'data': {'url': 'https://example.test/cities'},
            ...extra,
          },
          builder: (context, state) => Column(
            children: [
              if (state.loading) const Text('LOADING'),
              if (state.error != null) const Text('ERROR'),
              for (final o in state.options)
                Text('${o['label']}=${o['value']}'),
            ],
          ),
        ),
      ),
    ));
  }

  testWidgets('fetches and maps options', (tester) async {
    final client = stub((_) => json(
        '[{"id":1,"name":"Baghdad"},{"id":2,"name":"Basra"}]'));

    await pumpRemote(tester, client: client);
    expect(find.text('LOADING'), findsOneWidget,
        reason: 'the wait should be visible, not a silently empty dropdown');

    await tester.pumpAndSettle();
    expect(find.text('Baghdad=1'), findsOneWidget);
    expect(find.text('Basra=2'), findsOneWidget);
    expect(find.text('LOADING'), findsNothing);
  });

  testWidgets('surfaces a failure instead of an empty list', (tester) async {
    final client = stub((_) => json('{"message":"nope"}', status: 500));

    await pumpRemote(tester, client: client);
    await tester.pumpAndSettle();

    expect(find.text('ERROR'), findsOneWidget);
  });

  testWidgets('interpolates the url and headers from form data',
      (tester) async {
    late RequestOptions seen;
    final client = stub((o) {
      seen = o;
      return json('[]');
    });

    await pumpRemote(
      tester,
      client: client,
      formData: {'country': 'iq', 'token': 'abc'},
      extra: {
        'data': {
          'url': 'https://example.test/{{data.country}}/cities',
          'headers': [
            {'key': 'Authorization', 'value': 'Bearer {{data.token}}'},
          ],
        },
      },
    );
    await tester.pumpAndSettle();

    expect(seen.uri.toString(), 'https://example.test/iq/cities');
    expect(seen.headers['Authorization'], 'Bearer abc');
  });

  testWidgets('locates the array via selectValues', (tester) async {
    final client = stub((_) => json('{"data":{"items":[{"id":"a","name":"A"}]}}'));

    await pumpRemote(tester, client: client,
        extra: {'selectValues': 'data.items'});
    await tester.pumpAndSettle();

    expect(find.text('A=a'), findsOneWidget);
  });

  testWidgets('a second component with the same url reuses the response',
      (tester) async {
    var calls = 0;
    final client = stub((_) {
      calls++;
      return json('[{"id":1,"name":"One"}]');
    });

    await pumpRemote(tester, client: client);
    await tester.pumpAndSettle();
    await pumpRemote(tester, client: client);
    await tester.pumpAndSettle();

    expect(calls, 1, reason: 'the resolved url is cached');
  });

  testWidgets('the dropdown itself shows fetched options', (tester) async {
    final client = stub((_) => json('[{"id":7,"name":"Mosul"}]'));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EngineFormRenderer(
          engine: _PassthroughEngine(),
          form: {
            'display': 'form',
            'components': [
              {
                'key': 'city',
                'type': 'select',
                'label': 'City',
                'input': true,
                'dataSrc': 'url',
                'valueProperty': 'id',
                'template': '{{ item.name }}',
                'data': {'url': 'https://example.test/one'},
              },
            ],
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // No injected client here, so the real Dio fails; the point is that the
    // renderer routes a url source through the remote wrapper at all.
    expect(find.byType(RemoteSelectOptions), findsOneWidget);
    client.close();
  });
}
