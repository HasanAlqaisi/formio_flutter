/// Pumps a form for a widget test.
///
/// For the common case — a form, maybe a theme, read the resulting submission.
/// Tests needing something unusual in the tree (a `Directionality` wrapper, a
/// custom `ThemeData`, an outer scroll view) should keep building their own; this
/// exists to remove the boilerplate, not to become the only way in.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formio/formio.dart';

import 'fake_engine.dart';

export 'fake_engine.dart' show FakeEngine, formOf, field;

/// Renders [form] and returns the live submission.
///
/// The returned map is **updated in place** on every `onChanged`, so a test can
/// hold it once and assert against it after each interaction.
Future<Map<String, dynamic>> pumpForm(
  WidgetTester tester, {
  required Map<String, dynamic> form,
  FormEngine? engine,
  Map<String, dynamic>? initialData,
  FormioTheme theme = const FormioTheme(),
  FormioControlBuilders controls = const FormioControlBuilders(),
  FormioResourceSource? resourceSource,
  Map<String, FormioFieldBuilder>? customComponents,
  TextDirection? textDirection,
  ThemeData? appTheme,
  void Function(Map<String, dynamic> data)? onSubmit,
  bool settle = true,
}) async {
  final latest = <String, dynamic>{};

  await tester.pumpWidget(MaterialApp(
    theme: appTheme,
    home: Scaffold(
      body: EngineFormRenderer(
        engine: engine ?? FakeEngine(),
        form: form,
        initialData: initialData,
        theme: theme,
        controls: controls,
        resourceSource: resourceSource,
        customComponents: customComponents,
        textDirection: textDirection,
        onSubmit: onSubmit,
        onChanged: (data) {
          latest
            ..clear()
            ..addAll(data);
        },
      ),
    ),
  ));

  if (settle) await tester.pumpAndSettle();
  return latest;
}

/// Lets a debounced write land.
///
/// `pumpAndSettle` stops as soon as no frame is scheduled, so it does **not**
/// flush the renderer's text-input debounce — a test that types and then asserts
/// on recomputed state needs real time to pass.
Future<void> settleDebounce(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}
