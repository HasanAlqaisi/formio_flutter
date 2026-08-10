/// Twelve `@formio/core` validation rules had no wording of their own, so a
/// `maxWords` failure and a `unique` failure both read "Invalid value".
///
/// The messages live in an *optional* [FormioValidationMessages] interface: the
/// core [FormioLocalizations] is documented as something hosts `implements`, and
/// Dart's `implements` demands every member, so adding getters there would break
/// every existing host at compile time.
library;

// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_test/flutter_test.dart';
import 'package:formio/formio.dart';
import 'package:formio/src/widgets/component_builders.dart'
    show messageForError;

/// A host localization written before these rules existed: it implements only
/// [FormioLocalizations]. It must keep compiling *and* keep the old fallback.
class _LegacyLocalizations implements FormioLocalizations {
  const _LegacyLocalizations();

  @override
  String get invalidValue => 'LEGACY-FALLBACK';

  @override
  String get fieldRequired => 'LEGACY-REQUIRED';

  // Everything else is irrelevant to this test; a host would fill these in.
  @override
  dynamic noSuchMethod(Invocation invocation) => 'unused';
}

FormLogicError err(String rule, {String? setting, String? messageKey}) =>
    FormLogicError(
        path: 'f', rule: rule, setting: setting, messageKey: messageKey);

void main() {
  tearDown(
      () => ComponentFactory.setLocale(const DefaultFormioLocalizations()));

  group('English', () {
    setUp(() => ComponentFactory.setLocale(const DefaultFormioLocalizations()));

    test('option rules all read as "pick an available option"', () {
      // Three engine rules, one thing worth saying to whoever fills the form.
      for (final rule in ['invalidOption', 'select', 'onlyAvailableItems']) {
        expect(
            messageForError(err(rule)), 'Select one of the available options',
            reason: rule);
      }
    });

    test('unique, array and nonarray each say something distinct', () {
      expect(messageForError(err('unique')), 'This value is already used');
      expect(messageForError(err('array')), 'Expected a list of values');
      expect(messageForError(err('nonarray')), 'Expected a single value');
      // Three rules that used to be indistinguishable.
      expect(
        {
          messageForError(err('unique')),
          messageForError(err('array')),
          messageForError(err('nonarray')),
        }.length,
        3,
      );
    });

    test('word and selection counts carry the limit', () {
      expect(messageForError(err('minWords', setting: '5')),
          'Must be at least 5 words');
      expect(messageForError(err('maxWords', setting: '20')),
          'Must be at most 20 words');
      expect(messageForError(err('minSelectedCount', setting: '2')),
          'Select at least 2');
      expect(messageForError(err('maxSelectedCount', setting: '3')),
          'Select at most 3');
    });

    test('a limit-based rule degrades when the engine reports no limit', () {
      // Better a generic message than "Must be at least null words".
      expect(messageForError(err('minWords')), 'Invalid value');
      expect(messageForError(err('maxLength')), 'Invalid value');
    });

    test('invalidValueProperty reads as a misconfiguration', () {
      // A schema fault, not something the person filling the form can fix.
      expect(messageForError(err('invalidValueProperty')),
          contains('misconfigured'));
    });

    test('json carries the author\'s own message, like custom', () {
      expect(messageForError(err('json', messageKey: 'Pick a weekday')),
          'Pick a weekday');
      expect(messageForError(err('json')), 'Invalid value');
    });

    test('an unknown rule still falls back rather than throwing', () {
      expect(messageForError(err('somethingTheEngineAddedLater')),
          'Invalid value');
    });
  });

  group('Arabic', () {
    setUp(() => ComponentFactory.setLocale(const ArabicFormioLocalizations()));

    test('inherits the new messages translated, not in English', () {
      final message = messageForError(err('unique'));
      expect(message, 'هذه القيمة مستخدمة بالفعل');
      // Guards against an override being forgotten and English leaking through.
      expect(message, isNot(contains('already')));
    });

    test('a limit is interpolated into the Arabic wording', () {
      expect(messageForError(err('maxWords', setting: '20')), contains('20'));
    });
  });

  group('a host localization predating these rules', () {
    setUp(() => ComponentFactory.setLocale(const _LegacyLocalizations()));

    test('still compiles and keeps the generic fallback', () {
      // The whole reason the messages are in a separate interface: this class
      // does not implement it, and must not have to.
      expect(messageForError(err('unique')), 'LEGACY-FALLBACK');
      expect(messageForError(err('minWords', setting: '5')), 'LEGACY-FALLBACK');
      expect(messageForError(err('invalidOption')), 'LEGACY-FALLBACK');
    });

    test('rules it does define are unaffected', () {
      expect(messageForError(err('required')), 'LEGACY-REQUIRED');
    });
  });
}
