// ignore_for_file: depend_on_referenced_packages

import 'package:formio/formio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ComponentModel', () {
    test('parses core fields from JSON', () {
      final c = ComponentModel.fromJson({
        'key': 'name',
        'type': 'textfield',
        'label': 'Full Name',
        'input': true,
      });
      expect(c.key, 'name');
      expect(c.type, 'textfield');
      expect(c.label, 'Full Name');
    });
  });

  // NOTE: EngineFormRenderer is exercised on-device via example/main_form_demo.dart
  // (it requires a live flutter_js runtime, so it isn't unit-testable here).
}
