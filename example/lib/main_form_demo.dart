// Standalone entrypoint that renders a real Form.io form NATIVELY, with all
// logic (calculations, conditionals, Logic-tab, custom validation) driven by
// @formio/core via FormLogicEngine.
//
//   flutter run -t lib/main_form_demo.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:formio/formio.dart';

import 'custom_components.dart';

void main() => runApp(const FormDemoApp());

class FormDemoApp extends StatelessWidget {
  const FormDemoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Form.io Native Demo',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: const FormPicker(),
      );
}

class FormPicker extends StatefulWidget {
  const FormPicker({super.key});
  @override
  State<FormPicker> createState() => _FormPickerState();
}

class _FormPickerState extends State<FormPicker> {
  final _engine = FormLogicEngine();
  final _forms = List.generate(10, (i) => 'form${i + 1}.json');
  String _selected = 'form1.json';
  bool _loading = false;

  Future<void> _open() async {
    setState(() => _loading = true);
    try {
      await _engine.init();
      final raw = await rootBundle.loadString('assets/form-samples/$_selected');
      final outer = jsonDecode(raw);
      final tpl = outer is Map && outer['template'] != null ? outer['template'] : outer;
      final form = (tpl is String ? jsonDecode(tpl) : tpl) as Map<String, dynamic>;
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(_selected)),
          body: EngineFormRenderer(
            form: form,
            engine: _engine,
            customComponents: creatioComponents,
            // The Creatio samples are Arabic; render right-to-left.
            textDirection: TextDirection.rtl,
            onSubmit: (data) {
              debugPrint('SUBMIT: ${jsonEncode(data)}');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Valid — submitted (see console)')),
              );
            },
          ),
        ),
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Form.io Native Demo')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: _selected,
                items: _forms
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged:
                    _loading ? null : (v) => setState(() => _selected = v ?? _selected),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _open,
                child: _loading
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Open form'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
