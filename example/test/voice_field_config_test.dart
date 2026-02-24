import 'package:flutter_test/flutter_test.dart';
import 'package:formio_api/formio_api.dart';

import 'package:speech2form/models/voice_field_config.dart';

ComponentModel _component(String type, {Map<String, dynamic>? extra}) {
  return ComponentModel.fromJson({
    'type': type,
    'key': '${type}_key',
    'label': '${type} Label',
    ...?extra,
  });
}

void main() {
  group('VoiceFieldConfig - Classification', () {
    test('textfield is voice-compatible with freeText strategy', () {
      final config = VoiceFieldConfig.fromComponent(_component('textfield'));
      expect(config.isVoiceCompatible, isTrue);
      expect(config.strategy, VoiceInputStrategy.freeText);
      expect(config.promptTemplate, contains('metin'));
    });

    test('number is voice-compatible with numeric strategy', () {
      final config = VoiceFieldConfig.fromComponent(_component('number'));
      expect(config.isVoiceCompatible, isTrue);
      expect(config.strategy, VoiceInputStrategy.numeric);
      expect(config.promptTemplate, contains('sayı'));
    });

    test('select is voice-compatible with singleSelect strategy', () {
      final config = VoiceFieldConfig.fromComponent(_component('select'));
      expect(config.isVoiceCompatible, isTrue);
      expect(config.strategy, VoiceInputStrategy.singleSelect);
    });

    test('radio is voice-compatible with singleSelect strategy', () {
      final config = VoiceFieldConfig.fromComponent(_component('radio'));
      expect(config.isVoiceCompatible, isTrue);
      expect(config.strategy, VoiceInputStrategy.singleSelect);
    });

    test('selectboxes is voice-compatible with multiSelect strategy', () {
      final config = VoiceFieldConfig.fromComponent(_component('selectboxes'));
      expect(config.isVoiceCompatible, isTrue);
      expect(config.strategy, VoiceInputStrategy.multiSelect);
      expect(config.promptTemplate, contains('birden fazla'));
    });

    test('checkbox is voice-compatible with boolean strategy', () {
      final config = VoiceFieldConfig.fromComponent(_component('checkbox'));
      expect(config.isVoiceCompatible, isTrue);
      expect(config.strategy, VoiceInputStrategy.boolean);
      expect(config.promptTemplate, contains('evet'));
    });

    test('email is voice-compatible with email strategy', () {
      final config = VoiceFieldConfig.fromComponent(_component('email'));
      expect(config.isVoiceCompatible, isTrue);
      expect(config.strategy, VoiceInputStrategy.email);
      expect(config.promptTemplate, contains('@'));
    });

    test('phoneNumber is voice-compatible with phone strategy', () {
      final config = VoiceFieldConfig.fromComponent(_component('phoneNumber'));
      expect(config.isVoiceCompatible, isTrue);
      expect(config.strategy, VoiceInputStrategy.phone);
      expect(config.promptTemplate, contains('05'));
    });

    test('datetime is voice-compatible with date strategy', () {
      final config = VoiceFieldConfig.fromComponent(_component('datetime'));
      expect(config.isVoiceCompatible, isTrue);
      expect(config.strategy, VoiceInputStrategy.date);
      expect(config.promptTemplate, contains('ISO 8601'));
    });

    test('time is voice-compatible with time strategy', () {
      final config = VoiceFieldConfig.fromComponent(_component('time'));
      expect(config.isVoiceCompatible, isTrue);
      expect(config.strategy, VoiceInputStrategy.time);
      expect(config.promptTemplate, contains('HH:mm'));
    });

    test('tags is voice-compatible with tags strategy', () {
      final config = VoiceFieldConfig.fromComponent(_component('tags'));
      expect(config.isVoiceCompatible, isTrue);
      expect(config.strategy, VoiceInputStrategy.tags);
    });

    test('url is voice-compatible with url strategy', () {
      final config = VoiceFieldConfig.fromComponent(_component('url'));
      expect(config.isVoiceCompatible, isTrue);
      expect(config.strategy, VoiceInputStrategy.url);
      expect(config.promptTemplate, contains('https'));
    });

    test('currency is voice-compatible with numeric strategy', () {
      final config = VoiceFieldConfig.fromComponent(_component('currency'));
      expect(config.isVoiceCompatible, isTrue);
      expect(config.strategy, VoiceInputStrategy.numeric);
      expect(config.promptTemplate, contains('para'));
    });
  });

  group('VoiceFieldConfig - Skipped Types', () {
    for (final type in [
      'signature', 'file', 'captcha', 'sketchpad', 'tagpad',
      'hidden', 'button', 'datasource', 'container', 'datagrid',
      'editgrid', 'nestedform', 'form', 'dynamicwizard',
      'datatable', 'datamap', 'reviewpage', 'custom', 'survey',
    ]) {
      test('$type is NOT voice-compatible', () {
        final config = VoiceFieldConfig.fromComponent(_component(type));
        expect(config.isVoiceCompatible, isFalse);
        expect(config.strategy, VoiceInputStrategy.skip);
        expect(config.skipReason, isNotNull);
        expect(config.skipReason, isNotEmpty);
      });
    }
  });

  group('VoiceFieldConfig - Constraint Extraction', () {
    test('extracts maxLength from validate', () {
      final config = VoiceFieldConfig.fromComponent(
        _component('textfield', extra: {
          'validate': {'maxLength': 50},
        }),
      );
      expect(config.constraints['maxLength'], 50);
      expect(config.promptTemplate, contains('50'));
    });

    test('extracts min/max from number component', () {
      final config = VoiceFieldConfig.fromComponent(
        _component('number', extra: {
          'validate': {'min': 0, 'max': 100},
        }),
      );
      expect(config.constraints['min'], 0);
      expect(config.constraints['max'], 100);
      expect(config.promptTemplate, contains('0'));
      expect(config.promptTemplate, contains('100'));
    });

    test('extracts decimalLimit from currency', () {
      final config = VoiceFieldConfig.fromComponent(
        _component('currency', extra: {
          'decimalLimit': 2,
          'currency': 'USD',
        }),
      );
      expect(config.constraints['decimalLimit'], 2);
      expect(config.constraints['currency'], 'USD');
      expect(config.promptTemplate, contains('USD'));
    });
  });
}
