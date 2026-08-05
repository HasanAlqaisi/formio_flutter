/// Resolving select options from a schema — the pure half of remote-backed
/// selects. Only inline `values` was supported, so `dataSrc: json`/`url` gave an
/// empty dropdown.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:formio/formio.dart';

void main() {
  group('dataSrc detection', () {
    test('absent or "values" is the inline source', () {
      expect(selectDataSourceOf({}), SelectDataSource.inline);
      expect(
          selectDataSourceOf({'dataSrc': 'values'}), SelectDataSource.inline);
    });

    test('recognises the remote sources', () {
      expect(selectDataSourceOf({'dataSrc': 'json'}), SelectDataSource.json);
      expect(selectDataSourceOf({'dataSrc': 'url'}), SelectDataSource.url);
      expect(selectDataSourceOf({'dataSrc': 'resource'}),
          SelectDataSource.resource);
      expect(
          selectDataSourceOf({'dataSrc': 'custom'}), SelectDataSource.custom);
    });
  });

  group('readPath', () {
    test('walks maps and list indices', () {
      final source = {
        'data': {
          'items': [
            {'id': 1},
            {'id': 2},
          ],
        },
      };
      expect(readPath(source, 'data.items.1.id'), 2);
    });

    test('a missing or mistyped segment gives null, not a throw', () {
      expect(readPath({'a': 1}, 'a.b.c'), isNull);
      expect(
          readPath({
            'a': [1]
          }, 'a.nope'),
          isNull);
      expect(readPath(null, 'a'), isNull);
    });

    test('an empty path returns the source', () {
      expect(readPath({'a': 1}, null), {'a': 1});
      expect(readPath({'a': 1}, ''), {'a': 1});
    });
  });

  group('labelForItem', () {
    test('renders a template and strips its markup', () {
      expect(
        labelForItem({'name': 'Baghdad'},
            template: '<span>{{ item.name }}</span>'),
        'Baghdad',
      );
    });

    test('handles several expressions and a bare item reference', () {
      expect(
        labelForItem({'first': 'A', 'last': 'B'},
            template: '{{ item.first }} {{ item.last }}'),
        'A B',
      );
      expect(labelForItem('plain', template: '{{ item }}'), 'plain');
    });

    test('a template resolving to nothing falls back', () {
      // A conventional key is used when the template yields nothing…
      expect(labelForItem({'name': 'N'}, template: '{{ item.nope }}'), 'N');
      // …and with nothing recognisable, the row itself is shown rather than an
      // invisible blank entry.
      expect(labelForItem({'a': 1}, template: '{{ item.nope }}'), '{a: 1}');
    });

    test('falls back through the conventional keys', () {
      expect(labelForItem({'label': 'L', 'name': 'N'}), 'L');
      expect(labelForItem({'name': 'N', 'title': 'T'}), 'N');
      expect(labelForItem({'title': 'T'}), 'T');
      expect(labelForItem({'value': 'V'}), 'V');
    });

    test('a scalar row is its own label', () {
      expect(labelForItem('Basra'), 'Basra');
      expect(labelForItem(7), '7');
    });
  });

  group('valueForItem', () {
    test('valueProperty selects a field, including a nested one', () {
      expect(valueForItem({'id': 5, 'name': 'x'}, valueProperty: 'id'), 5);
      expect(
        valueForItem({
          'meta': {'code': 'IQ'}
        }, valueProperty: 'meta.code'),
        'IQ',
      );
    });

    test('without valueProperty an option-shaped row uses its value', () {
      expect(valueForItem({'label': 'A', 'value': 'a'}), 'a');
    });

    test('without valueProperty a plain row is stored whole', () {
      // Form.io stores the entire object when no valueProperty is set.
      final row = {'id': 1, 'name': 'x'};
      expect(valueForItem(row), row);
      expect(valueForItem('scalar'), 'scalar');
    });

    test('preserves the declared type', () {
      expect(valueForItem({'id': 5}, valueProperty: 'id'), isA<int>());
      expect(valueForItem({'ok': true}, valueProperty: 'ok'), isA<bool>());
    });
  });

  group('optionsFromPayload', () {
    test('maps a flat list', () {
      final options = optionsFromPayload(
        [
          {'id': 1, 'name': 'Baghdad'},
          {'id': 2, 'name': 'Basra'},
        ],
        {'valueProperty': 'id', 'template': '{{ item.name }}'},
      );
      expect(options, [
        {'label': 'Baghdad', 'value': 1},
        {'label': 'Basra', 'value': 2},
      ]);
    });

    test('selectValues locates the array inside a wrapped response', () {
      final options = optionsFromPayload(
        {
          'data': {
            'items': [
              {'id': 'a', 'name': 'A'},
            ],
          },
        },
        {
          'selectValues': 'data.items',
          'valueProperty': 'id',
          'template': '{{ item.name }}',
        },
      );
      expect(options, [
        {'label': 'A', 'value': 'a'},
      ]);
    });

    test('a selectValues path that misses the array still finds it', () {
      // Reported case: selectValues "users.0.firstName" resolves to a single
      // string, which yielded an empty dropdown with no explanation.
      final payload = {
        'users': [
          {'id': 1, 'firstName': 'Emily'},
          {'id': 2, 'firstName': 'Michael'},
        ],
        'total': 208,
      };
      final options = optionsFromPayload(payload, {
        'selectValues': 'users.0.firstName',
        'valueProperty': 'id',
        'template': '{{ item.firstName }}',
      });
      expect(options, [
        {'label': 'Emily', 'value': 1},
        {'label': 'Michael', 'value': 2},
      ]);
    });

    test('a wrapped payload with no selectValues finds the array', () {
      final options = optionsFromPayload(
        {
          'total': 2,
          'items': [
            {'label': 'A', 'value': 'a'}
          ]
        },
        const {},
      );
      expect(options.single['value'], 'a');
    });

    test('a correct selectValues still wins over the search', () {
      final options = optionsFromPayload(
        {
          'wrong': [
            {'label': 'W', 'value': 'w'}
          ],
          'right': [
            {'label': 'R', 'value': 'r'}
          ],
        },
        {'selectValues': 'right'},
      );
      expect(options.single['value'], 'r');
    });

    test('a non-list payload yields no options rather than throwing', () {
      expect(optionsFromPayload('nonsense', {}), isEmpty);
      expect(optionsFromPayload(null, {}), isEmpty);
    });
  });

  group('localSelectOptions', () {
    test('reads inline values from either location', () {
      expect(
        localSelectOptions({
          'values': [
            {'label': 'A', 'value': 'a'},
          ],
        }),
        [
          {'label': 'A', 'value': 'a'},
        ],
      );
      expect(
        localSelectOptions({
          'data': {
            'values': [
              {'label': 'B', 'value': 'b'},
            ],
          },
        }),
        [
          {'label': 'B', 'value': 'b'},
        ],
      );
    });

    test('dataSrc json reads an inline array', () {
      final options = localSelectOptions({
        'dataSrc': 'json',
        'valueProperty': 'id',
        'template': '{{ item.name }}',
        'data': {
          'json': [
            {'id': 1, 'name': 'One'},
          ],
        },
      });
      expect(options, [
        {'label': 'One', 'value': 1},
      ]);
    });

    test('dataSrc json also accepts a stringified array', () {
      final options = localSelectOptions({
        'dataSrc': 'json',
        'data': {'json': '[{"label":"A","value":"a"}]'},
      });
      expect(options.single['value'], 'a');
    });

    test('malformed json gives no options rather than throwing', () {
      expect(
        localSelectOptions({
          'dataSrc': 'json',
          'data': {'json': '{not json'}
        }),
        isEmpty,
      );
    });

    test('a url source has nothing available locally', () {
      expect(
        localSelectOptions({
          'dataSrc': 'url',
          'data': {'url': 'https://x'}
        }),
        isEmpty,
      );
    });
  });
}
