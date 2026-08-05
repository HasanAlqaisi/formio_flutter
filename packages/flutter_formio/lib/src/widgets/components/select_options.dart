/// Resolving a select's options from its schema.
///
/// Form.io selects (and `radio`/`selectboxes`) draw their options from one of
/// several sources, chosen by `dataSrc`. Only the inline `values` list was
/// supported, so any remote-backed select rendered an **empty** dropdown.
///
/// The engine does not fetch for us: `fetchProcessInfo` runs only in the
/// server-side `submission` target, and the client-side validators merely check
/// the chosen value against the available items (`validate.select`,
/// `validate.onlyAvailableItems`). Loading them is the renderer's job.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, immutable, kDebugMode;

/// One resolved option: what to show, and what to store.
///
/// Lives here rather than beside the control builders because it is plain data
/// that both the resolvers and the picker widgets need — keeping it next to the
/// widgets forced them into an import cycle, and forced the pickers to take
/// untyped `{label, value}` maps instead.
@immutable
class FormioOption {
  const FormioOption({required this.label, required this.value});

  final String label;

  /// The value to store, with its schema type intact — a `valueProperty` of
  /// `id` over numeric ids yields `int`, not `"1"`.
  final Object? value;

  /// Stable key for widgets that address options by string.
  String get key => value?.toString() ?? '';

  @override
  String toString() => 'FormioOption($label -> $value)';
}

/// [optionsFromPayload]'s `{label, value}` rows as typed options.
List<FormioOption> typedOptions(List<Map<String, dynamic>> rows) => [
      for (final row in rows)
        FormioOption(
            label: row['label']?.toString() ?? '', value: row['value']),
    ];

/// Where a component's options come from.
enum SelectDataSource {
  /// Inline `values` (or `data.values`) — the default. Not named `values`,
  /// which collides with the enum's own static member.
  inline,

  /// An inline JSON array in `data.json`.
  json,

  /// Fetched from `data.url`.
  url,

  /// A Form.io resource id in `data.resource`, fetched from the project's
  /// submissions endpoint. Needs a [FormioResourceSource] — an id alone is not
  /// addressable.
  resource,

  /// A JavaScript expression in `data.custom`.
  custom,
}

SelectDataSource selectDataSourceOf(Map<String, dynamic> raw) =>
    switch (raw['dataSrc']?.toString()) {
      'json' => SelectDataSource.json,
      'url' => SelectDataSource.url,
      'resource' => SelectDataSource.resource,
      'custom' => SelectDataSource.custom,
      // Absent or 'values'.
      _ => SelectDataSource.inline,
    };

/// Reads a dotted path (`a.b.c`) out of nested maps/lists.
Object? readPath(Object? source, String? path) {
  if (path == null || path.isEmpty) return source;
  Object? current = source;
  for (final segment in path.split('.')) {
    if (segment.isEmpty) continue;
    if (current is Map) {
      current = current[segment];
    } else if (current is List) {
      final index = int.tryParse(segment);
      if (index == null || index < 0 || index >= current.length) return null;
      current = current[index];
    } else {
      return null;
    }
  }
  return current;
}

final _templateExpression = RegExp(r'\{\{\s*([\w.]+)\s*\}\}');
final _htmlTag = RegExp(r'<[^>]*>');

/// The visible label for [item].
///
/// Form.io's `template` is a snippet like `<span>{{ item.name }}</span>`, so the
/// expressions are resolved against the item and the markup stripped — there is
/// no HTML in a dropdown row.
String labelForItem(Object? item, {String? template}) {
  if (template != null && template.trim().isNotEmpty) {
    _warnUnresolvedTemplate(template, item);
    final rendered = template.replaceAllMapped(_templateExpression, (match) {
      var expression = match.group(1)!;
      // Templates address the row as `item`.
      if (expression == 'item') return item?.toString() ?? '';
      if (expression.startsWith('item.')) {
        expression = expression.substring('item.'.length);
      }
      return readPath(item, expression)?.toString() ?? '';
    });
    final text = rendered.replaceAll(_htmlTag, '').trim();
    if (text.isNotEmpty) return text;
  }
  if (item is Map) {
    // The conventional keys, in the order Form.io itself falls back through.
    for (final key in const ['label', 'name', 'title', 'text', 'value']) {
      final candidate = item[key];
      if (candidate != null && candidate.toString().isNotEmpty) {
        return candidate.toString();
      }
    }
  }
  return item?.toString() ?? '';
}

/// Points out a template whose expressions resolve to nothing, which otherwise
/// shows up only as unreadable rows.
void _warnUnresolvedTemplate(String template, Object? item) {
  if (!kDebugMode || item is! Map) return;
  for (final match in _templateExpression.allMatches(template)) {
    var expression = match.group(1)!;
    if (expression == 'item') return;
    if (expression.startsWith('item.')) {
      expression = expression.substring('item.'.length);
    }
    if (readPath(item, expression) == null) {
      debugPrint('⚠️ Select template "\$template" found no "\$expression" on a '
          'row with keys \${item.keys.toList()}.');
      return;
    }
  }
}

/// The stored value for [item].
///
/// With no `valueProperty`, Form.io stores the whole row — so an object-valued
/// select keeps its object.
Object? valueForItem(Object? item, {String? valueProperty}) {
  if (valueProperty == null || valueProperty.isEmpty) {
    if (item is Map && item.containsKey('value')) return item['value'];
    return item;
  }
  return readPath(item, valueProperty);
}

/// Normalises anything option-shaped into `{label, value}` rows.
///
/// [payload] may be the schema's inline list or a fetched body; `selectValues`
/// locates the array inside a wrapped response (`{"data": {"items": [...]}}`).
List<Map<String, dynamic>> optionsFromPayload(
  Object? payload,
  Map<String, dynamic> raw,
) {
  final rows = _rowsIn(payload, raw['selectValues']?.toString());

  final template = raw['template']?.toString();
  final valueProperty = raw['valueProperty']?.toString();

  return [
    for (final row in rows)
      if (row != null)
        {
          'label': labelForItem(row, template: template),
          'value': valueForItem(row, valueProperty: valueProperty),
        },
  ];
}

/// Finds the list of rows in [payload].
///
/// `selectValues` is meant to be the path to the array, but it is easy to point
/// at something else — a path like `users.0.firstName` resolves to a single
/// string, which used to yield no options at all and no explanation. So a path
/// that does not land on a list is reported and then ignored in favour of
/// looking for the array: the payload itself, or its first list-valued entry
/// (`{"users": [...]}`, `{"data": [...]}`).
List<Object?> _rowsIn(Object? payload, String? selectValues) {
  if (selectValues != null && selectValues.isNotEmpty) {
    final located = readPath(payload, selectValues);
    if (located is List) return located;
    if (kDebugMode) {
      debugPrint('⚠️ selectValues "\$selectValues" does not point at a list '
          '(found \${located.runtimeType}); searching the response instead.');
    }
  }
  if (payload is List) return payload;
  if (payload is Map) {
    for (final value in payload.values) {
      if (value is List) return value;
    }
  }
  return const [];
}

/// Where `dataSrc: "resource"` components fetch from, and with what credentials.
///
/// A resource component carries only a form id (`data.resource`); the project it
/// belongs to is deployment configuration, not schema, so the host supplies it.
/// Without one, a resource-backed select has no addressable endpoint and reports
/// a data-source error rather than an empty list.
@immutable
class FormioResourceSource {
  const FormioResourceSource(
      {required this.projectUrl, this.headers = const {}});

  /// Base URL of the Form.io project, e.g. `https://abc.form.io`. A trailing
  /// slash is tolerated.
  final String projectUrl;

  /// Sent with every resource request — typically `x-jwt-token` for an
  /// authenticated project.
  final Map<String, String> headers;

  /// The submissions endpoint for [resourceId].
  ///
  /// [limit] comes from the component's own `limit` (Form.io's builder writes
  /// 100). Passing it matters: the endpoint's own default page size is small,
  /// so omitting it silently truncates the options.
  String submissionsUrl(String resourceId, {int? limit}) {
    final base = projectUrl.endsWith('/')
        ? projectUrl.substring(0, projectUrl.length - 1)
        : projectUrl;
    final query = limit == null ? '' : '?limit=$limit';
    return '$base/form/$resourceId/submission$query';
  }
}

/// `limit` from the schema, for paging a remote source.
int? selectLimit(Map<String, dynamic> raw) {
  final limit = raw['limit'];
  if (limit is num) return limit.toInt();
  if (limit is String) return int.tryParse(limit.trim());
  return null;
}

/// The resource id of a `dataSrc: "resource"` component, or null.
String? resourceIdOf(Map<String, dynamic> raw) {
  final data = raw['data'];
  final id = data is Map ? data['resource']?.toString() : null;
  return (id == null || id.trim().isEmpty) ? null : id.trim();
}

/// Whether [raw] needs a network call before it has any options.
bool selectNeedsFetch(Map<String, dynamic> raw) {
  final source = selectDataSourceOf(raw);
  return source == SelectDataSource.url || source == SelectDataSource.resource;
}

/// Options available without a network call: the inline `values` list, or the
/// inline JSON array for `dataSrc: json`.
List<Map<String, dynamic>> localSelectOptions(Map<String, dynamic> raw) {
  final data = raw['data'];

  if (selectDataSourceOf(raw) == SelectDataSource.json) {
    var json = data is Map ? data['json'] : null;
    // Exported schemas sometimes carry `data.json` as a JSON *string*.
    if (json is String) {
      try {
        json = jsonDecode(json);
      } catch (_) {
        return const [];
      }
    }
    return optionsFromPayload(json, raw);
  }

  final values = (raw['values'] as List?) ??
      (data is Map ? data['values'] as List? : null) ??
      const [];
  return [
    for (final v in values)
      if (v is Map<String, dynamic>) v,
  ];
}
