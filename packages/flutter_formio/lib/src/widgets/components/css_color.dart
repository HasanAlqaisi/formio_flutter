/// Parses the CSS colour strings Form.io schemas carry (`penColor`,
/// `backgroundColor`, …) into Flutter [Color]s.
library;

import 'package:flutter/material.dart';

/// A small set of CSS names Form.io's own defaults and builder use.
const _namedColors = <String, int>{
  'black': 0xFF000000,
  'white': 0xFFFFFFFF,
  'red': 0xFFFF0000,
  'green': 0xFF008000,
  'blue': 0xFF0000FF,
  'grey': 0xFF808080,
  'gray': 0xFF808080,
  'transparent': 0x00000000,
};

final _rgbPattern = RegExp(
  r'^rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*(?:,\s*([\d.]+)\s*)?\)$',
);

/// Returns the [Color] for [value], or null when it is absent or unparseable —
/// callers fall back to their own default rather than guessing.
///
/// Handles `#rgb`, `#rrggbb`, `rgb(r,g,b)`, `rgba(r,g,b,a)` and the common
/// names above. Unsupported forms (`hsl()`, `currentColor`, …) return null.
Color? parseCssColor(Object? value) {
  if (value is Color) return value;
  if (value is! String) return null;
  final input = value.trim().toLowerCase();
  if (input.isEmpty) return null;

  final named = _namedColors[input];
  if (named != null) return Color(named);

  if (input.startsWith('#')) {
    var hex = input.substring(1);
    // #rgb -> #rrggbb
    if (hex.length == 3) {
      hex = hex.split('').map((c) => '$c$c').join();
    }
    if (hex.length != 6) return null;
    final rgb = int.tryParse(hex, radix: 16);
    return rgb == null ? null : Color(0xFF000000 | rgb);
  }

  final match = _rgbPattern.firstMatch(input);
  if (match == null) return null;
  int channel(String? s) =>
      ((double.tryParse(s ?? '') ?? 0).clamp(0, 255)).round();
  final alpha = match.group(4);
  return Color.fromARGB(
    alpha == null
        ? 255
        : ((double.tryParse(alpha) ?? 1).clamp(0, 1) * 255).round(),
    channel(match.group(1)),
    channel(match.group(2)),
    channel(match.group(3)),
  );
}
