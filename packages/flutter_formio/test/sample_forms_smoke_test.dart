/// Renders every real sample form end to end.
///
/// The unit tests use minimal synthetic schemas — which is why a textarea's
/// integer `rows` slipped past them and crashed on a real form. These forms
/// carry the actual mix (datagrid, columns, table, creatioContainer, unknown
/// vendor types), so a type assumption that only holds for `textfield` fails
/// here instead of on a device.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formio/formio.dart';

import 'support/fake_engine.dart';

/// Form.io exports sometimes wrap the schema in a stringified `template`.
Map<String, dynamic>? _loadForm(File file) {
  dynamic decoded = jsonDecode(file.readAsStringSync());
  if (decoded is Map && decoded['template'] != null) {
    final template = decoded['template'];
    decoded = template is String ? jsonDecode(template) : template;
  }
  return decoded is Map<String, dynamic> ? decoded : null;
}

void main() {
  final directory = Directory('../../example/assets/form-samples');
  final samples = directory.existsSync()
      ? (directory
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];

  test('the sample forms are present', () {
    expect(samples, isNotEmpty,
        reason: 'no samples found at ${directory.path} — this suite would '
            'silently pass while testing nothing');
  });

  Future<void> render(WidgetTester tester, Map<String, dynamic> form) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EngineFormRenderer(
          engine: FakeEngine(),
          form: form,
          // A real host theme, so themed paths are exercised too.
          theme: FormioTheme(
            inputBorder: OutlineInputBorder(
              borderSide: const BorderSide(width: 1.25),
              borderRadius: BorderRadius.circular(8),
            ),
            inputFillColor: const Color(0xFFFFFFFF),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final file in samples) {
    final name = file.uri.pathSegments.last;

    testWidgets('$name renders without throwing', (tester) async {
      final form = _loadForm(file);
      if (form == null) return; // not a form document
      await render(tester, form);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name renders inside tabs without throwing', (tester) async {
      // Wrapping in tabs forces the error-badge walk across every component
      // type this form contains — exactly the path that crashed on `rows`.
      final form = _loadForm(file);
      if (form == null) return;
      final components = form['components'];
      if (components is! List || components.isEmpty) return;

      await render(tester, {
        'display': 'form',
        'components': [
          {
            'type': 'tabs',
            'key': 'smokeTabs',
            'components': [
              {'key': 't1', 'label': 'One', 'components': components},
              {'key': 't2', 'label': 'Two', 'components': const []},
            ],
          },
        ],
      });
      expect(tester.takeException(), isNull);

      // Submitting is what triggers the badge walk over the whole subtree.
      final submit = find.text('Submit');
      if (submit.evaluate().isNotEmpty) {
        await tester.tap(submit, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
