import 'package:flutter_test/flutter_test.dart';
import 'package:formio_api/formio_api.dart';
import 'package:speech2form/services/ai_service.dart';

void main() {
  group('Selectboxes label resolution', () {
    test('extractOptions returns correct options for selectboxes', () {
      final componentJson = {
        'type': 'selectboxes',
        'key': 'sideEffects',
        'label': 'Yan etkiler',
        'values': [
          {'label': 'Enjeksiyon yerinde ağrı', 'value': 'opt1'},
          {'label': 'Kızarıklık', 'value': 'opt2'},
          {'label': 'Baş ağrısı', 'value': 'opt3'},
          {'label': 'Bulantı', 'value': 'opt4'},
        ],
      };

      final component = ComponentModel.fromJson(componentJson);
      final options = AIService.extractOptions(component.raw);

      print('Component raw keys: ${component.raw.keys}');
      print('Component raw["values"]: ${component.raw["values"]}');
      print('Extracted options: $options');

      expect(options.length, 4);
      expect(options[0]['label'], 'Enjeksiyon yerinde ağrı');
      expect(options[0]['value'], 'opt1');
    });

    test('resolves opt keys to labels from Map value', () {
      final componentJson = {
        'type': 'selectboxes',
        'key': 'sideEffects',
        'label': 'Yan etkiler',
        'values': [
          {'label': 'Enjeksiyon yerinde ağrı', 'value': 'opt1'},
          {'label': 'Kızarıklık', 'value': 'opt2'},
          {'label': 'Baş ağrısı', 'value': 'opt3'},
          {'label': 'Bulantı', 'value': 'opt4'},
        ],
      };

      final component = ComponentModel.fromJson(componentJson);
      
      // Simulate AI returning a Map<String, dynamic>
      final aiValue = <String, dynamic>{
        'opt1': true,
        'opt2': false,
        'opt3': true,
        'opt4': false,
      };

      // Reproduce the _formatValueForDisplay logic
      final options = AIService.extractOptions(component.raw);
      final selected = aiValue.entries
          .where((e) =>
              e.value == true ||
              e.value == 1 ||
              e.value.toString().toLowerCase() == 'true')
          .map((e) {
            final key = e.key.toString();
            for (final opt in options) {
              if (opt['value'] == key) {
                return opt['label'] ?? key;
              }
            }
            return key;
          })
          .toList();

      print('Selected (resolved): $selected');

      expect(selected, ['Enjeksiyon yerinde ağrı', 'Baş ağrısı']);
      expect(selected, isNot(contains('opt1')));
      expect(selected, isNot(contains('opt3')));
    });

    test('resolves opt keys from String value', () {
      final componentJson = {
        'type': 'selectboxes',
        'key': 'sideEffects',
        'label': 'Yan etkiler',
        'values': [
          {'label': 'Enjeksiyon yerinde ağrı', 'value': 'opt1'},
          {'label': 'Kızarıklık', 'value': 'opt2'},
          {'label': 'Baş ağrısı', 'value': 'opt3'},
          {'label': 'Bulantı', 'value': 'opt4'},
        ],
      };

      final component = ComponentModel.fromJson(componentJson);
      
      // Simulate AI returning a comma-separated string
      const aiValue = 'opt1, opt3';

      final keys = aiValue.split(RegExp(r'[,\s]+')).where((k) => k.isNotEmpty);
      final options = AIService.extractOptions(component.raw);
      
      print('Keys parsed: ${keys.toList()}');
      print('Options available: $options');
      
      final resolved = keys.map((k) {
        for (final opt in options) {
          if (opt['value'] == k) return opt['label'] ?? k;
        }
        return k;
      }).toList();

      print('Resolved: $resolved');

      expect(resolved, ['Enjeksiyon yerinde ağrı', 'Baş ağrısı']);
    });

    test('resolves generic opt-N keys by index fallback', () {
      final componentJson = {
        'type': 'selectboxes',
        'key': 'sideEffects',
        'label': 'Yan etkiler',
        'values': [
          {'label': 'Enjeksiyon yerinde ağrı', 'value': 'enjYeriAgri'},
          {'label': 'Kızarıklık', 'value': 'kizariklik'},
          {'label': 'Baş ağrısı', 'value': 'basAgrisi'},
          {'label': 'Bulantı', 'value': 'bulanti'},
        ],
      };

      final component = ComponentModel.fromJson(componentJson);
      final options = AIService.extractOptions(component.raw);

      // AI incorrectly returns opt1, opt3 instead of real value keys
      final genericKeys = ['opt1', 'opt3'];

      // Simulate fallback resolution
      final resolved = genericKeys.map((key) {
        // Direct match first
        for (final opt in options) {
          if (opt['value'] == key) return opt['label'] ?? key;
        }
        // Fallback: opt-N → index
        final indexMatch = RegExp(r'^opt(\d+)$').firstMatch(key);
        if (indexMatch != null) {
          final idx = int.parse(indexMatch.group(1)!) - 1;
          if (idx >= 0 && idx < options.length) {
            return options[idx]['label'] ?? key;
          }
        }
        return key;
      }).toList();

      // opt1 → index 0 → Enjeksiyon yerinde ağrı
      // opt3 → index 2 → Baş ağrısı
      expect(resolved, ['Enjeksiyon yerinde ağrı', 'Baş ağrısı']);
    });
  });
}
