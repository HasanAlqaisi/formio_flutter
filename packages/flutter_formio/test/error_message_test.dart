// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_test/flutter_test.dart';
import 'package:formio/formio.dart';
import 'package:formio/src/widgets/component_builders.dart' as cb;

void main() {
  setUp(() => ComponentFactory.setLocale(const DefaultFormioLocalizations()));

  test('messageForError maps engine rules to localized (default) messages', () {
    String m(String rule, {String? messageKey}) => cb.messageForError(
        FormLogicError(path: 'x', rule: rule, messageKey: messageKey));

    expect(m('required'), 'This field is required');
    expect(m('email'), 'Invalid email address');
    expect(m('url'), 'Invalid URL');
    expect(m('number'), 'Invalid number');
    expect(m('pattern'), 'Invalid format');
    // With no limit context, length/value rules fall back to the generic message.
    expect(m('minLength'), 'Invalid value');
    expect(m('maxLength'), 'Invalid value');
    // custom rules carry the form author's own message.
    expect(m('custom', messageKey: 'must be ok'), 'must be ok');
  });

  test('limit-based rules interpolate the engine-supplied setting', () {
    String m(String rule, String setting) => cb.messageForError(
        FormLogicError(path: 'x', rule: rule, setting: setting));

    expect(m('minLength', '3'), 'Must be at least 3 characters');
    expect(m('maxLength', '20'), 'Must be at most 20 characters');
    expect(m('min', '10'), 'Must be 10 or more');
    expect(m('max', '100'), 'Must be 100 or less');
  });

  test('the built-in Arabic locale localizes error messages', () {
    ComponentFactory.setLocale(const ArabicFormioLocalizations());
    String m(String rule) =>
        cb.messageForError(FormLogicError(path: 'x', rule: rule));

    String ml(String rule, String setting) => cb.messageForError(
        FormLogicError(path: 'x', rule: rule, setting: setting));

    expect(m('required'), 'هذا الحقل مطلوب');
    expect(m('email'), 'بريد إلكتروني غير صالح');
    expect(m('pattern'), 'تنسيق غير صالح');
    expect(m('minLength'), 'قيمة غير صالحة');
    // Limit-aware messages localize too.
    expect(ml('maxLength', '20'), 'يجب ألا يزيد عن 20 حرفًا');
    expect(ml('min', '10'), 'يجب أن تكون القيمة 10 أو أكثر');
    // Inherited (untranslated-in-error) + composed helpers.
    expect(const ArabicFormioLocalizations().submit, 'إرسال');
    expect(const ArabicFormioLocalizations().getRequiredMessage('الاسم'),
        'الاسم مطلوب.');

    ComponentFactory.setLocale(const DefaultFormioLocalizations());
  });
}
