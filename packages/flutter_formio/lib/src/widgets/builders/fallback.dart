/// Anything the renderer does not draw natively goes to the stock
/// [ComponentFactory], guarded so one bad component cannot take down the form.
library;

import 'package:flutter/material.dart';
import 'package:formio/formio.dart';

import '../form_field_scope.dart';
import 'field_chrome.dart';

// ---- fallback to the stock component set --------------------------------

/// Coerce engine values into the type each stock leaf widget expects.
dynamic coerceValue(String? type, dynamic v) {
  if (v == null) return null;
  switch (type) {
    case 'number':
    case 'currency':
      if (v is num) return v;
      if (v is String) return num.tryParse(v);
      return null;
    case 'checkbox':
      if (v is bool) return v;
      if (v is String) return v.toLowerCase() == 'true';
      return v == true;
    case 'textfield':
    case 'textarea':
    case 'email':
    case 'url':
    case 'phoneNumber':
    case 'password':
      return v is String ? v : v.toString();
    default:
      return v;
  }
}

/// Renders any type not handled natively via the stock [ComponentFactory]
/// (incl. host-registered custom components), guarded against build errors.
Widget buildFallback(
    FieldScope s, Map<String, dynamic> raw, String path, String? type) {
  final model = ComponentModel.fromJson(raw);
  try {
    final built = ComponentFactory.build(
      component: model,
      value: coerceValue(type, s.getValue(path)),
      onChanged: (v) => s.setValue(path, v),
      // Pass the real submission so content/html elements can interpolate
      // {{data.x}} and any stock widget can see sibling data.
      formData: s.data,
    );
    final decorationTheme = s.theme.resolvedInputDecorationTheme(s.context);
    final themed = decorationTheme == null
        ? built
        : Theme(
            data: Theme.of(s.context)
                .copyWith(inputDecorationTheme: decorationTheme),
            child: built,
          );
    // A stock component only knows its schema key, which repeats in every row
    // of a grid and under every container that scopes it. The path does not, so
    // the ids it builds hang off this instead.
    return FormioSemanticsScope(
      prefix: formioSemanticsId(path),
      child: themed,
    );
  } catch (e) {
    return placeholderCard(s.context,
        '${type ?? '?'} "${raw['label'] ?? raw['key']}" — render error: $e');
  }
}
