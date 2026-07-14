// Standalone entrypoint to test the headless Form.io logic engine
// (@formio/core in flutter_js) on-device.
//
//   flutter run -t lib/main_engine_test.dart
//
// Verifies the engine loads and runs the evaluator pipeline (calculate, logic,
// conditions, clearHidden, validate) against real form templates, and reports
// timings so we can gauge QuickJS (Android) / JavaScriptCore (iOS) behavior.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:formio/formio.dart';

void main() => runApp(const EngineTestApp());

class EngineTestApp extends StatelessWidget {
  const EngineTestApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Form.io Engine Test',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: const EngineTestScreen(),
      );
}

class EngineTestScreen extends StatefulWidget {
  const EngineTestScreen({super.key});

  @override
  State<EngineTestScreen> createState() => _EngineTestScreenState();
}

class _EngineTestScreenState extends State<EngineTestScreen> {
  final _engine = FormLogicEngine();
  final _forms = List.generate(10, (i) => 'form${i + 1}.json');
  String _selected = 'form1.json';

  bool _busy = false;
  String _log = 'Pick a form and tap Run.';

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _log = 'Running $_selected …';
    });
    final buf = StringBuffer();
    try {
      // 1) init engine (loads the 536KB bundle once)
      final swInit = Stopwatch()..start();
      await _engine.init();
      swInit.stop();
      buf.writeln('engine.init(): ${swInit.elapsedMilliseconds} ms  (loads bundle once)');

      // 2) load + decode the form template
      final raw = await rootBundle.loadString('assets/form-samples/$_selected');
      final outer = jsonDecode(raw);
      final tpl = outer is Map && outer['template'] != null ? outer['template'] : outer;
      final form = (tpl is String ? jsonDecode(tpl) : tpl) as Map<String, dynamic>;
      final componentCount = _countComponents(form['components']);
      buf.writeln('form: $_selected  ($componentCount components)');

      // 3) process with empty data (exercises calc + logic + conditions + validate)
      final sw = Stopwatch()..start();
      final result = _engine.process(form: form, submissionData: {});
      sw.stop();

      buf.writeln('process(): ${sw.elapsedMilliseconds} ms');
      buf.writeln('');
      buf.writeln('✓ errors: ${result.errors.length}');
      buf.writeln('✓ hidden (conditional): ${result.hidden.length}');
      buf.writeln('✓ calculated data keys: ${result.data.length}');
      final number = result.data['Number'];
      if (number != null) buf.writeln('✓ crypto case-number: $number');
      buf.writeln('');
      buf.writeln('first errors:');
      for (final e in result.errors.take(8)) {
        buf.writeln('  • ${e.path}  [${e.rule}]');
      }
      buf.writeln('');
      buf.writeln('sample data keys: ${result.data.keys.take(12).toList()}');
    } catch (e, s) {
      buf.writeln('✗ FAILED: $e');
      buf.writeln(s.toString().split('\n').take(4).join('\n'));
    }
    setState(() {
      _busy = false;
      _log = buf.toString();
    });
  }

  int _countComponents(dynamic node) {
    var n = 0;
    void walk(dynamic c) {
      if (c is List) {
        for (final x in c) {
          walk(x);
        }
      } else if (c is Map) {
        if (c['type'] != null) n++;
        for (final k in const ['components', 'columns', 'rows']) {
          if (c[k] != null) walk(c[k]);
        }
      }
    }

    walk(node);
    return n;
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Form.io Engine Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selected,
                    items: _forms
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _selected = v ?? _selected),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _busy ? null : _run,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Run'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _log,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
