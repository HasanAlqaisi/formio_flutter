// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_test/flutter_test.dart';
import 'package:formio/formio.dart';
import 'package:formio/src/widgets/component_builders.dart' as cb;

void main() {
  setUp(() => ComponentFactory.setLocale(const DefaultFormioLocalizations()));

  test('messageForError maps engine rules to localized (default) messages', () {
    String m(String rule, {String? messageKey}) =>
        cb.messageForError(FormLogicError(path: 'x', rule: rule, messageKey: messageKey));

    expect(m('required'), 'This field is required');
    expect(m('email'), 'Invalid email address');
    expect(m('url'), 'Invalid URL');
    expect(m('number'), 'Invalid number');
    expect(m('pattern'), 'Invalid format');
    // Unmapped built-ins fall back to the generic message.
    expect(m('minLength'), 'Invalid value');
    expect(m('maxLength'), 'Invalid value');
    // custom rules carry the form author's own message.
    expect(m('custom', messageKey: 'must be ok'), 'must be ok');
  });

  test('a custom locale localizes error messages', () {
    ComponentFactory.setLocale(const _ArabicRequired());
    expect(
      cb.messageForError(const FormLogicError(path: 'x', rule: 'required')),
      'هذا الحقل مطلوب',
    );
    ComponentFactory.setLocale(const DefaultFormioLocalizations());
  });
}

/// Minimal locale override: only translates the required message (others inherit
/// the English defaults via [DefaultFormioLocalizations]).
class _ArabicRequired extends DefaultFormioLocalizations {
  const _ArabicRequired();
  @override
  String get fieldRequired => 'هذا الحقل مطلوب';
}
