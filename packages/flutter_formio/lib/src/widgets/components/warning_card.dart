/// The amber diagnostic card shared by the developer-facing notices — an
/// unsupported component type, or a component that threw while rendering.
///
/// These deliberately stand apart from the themed form fields: they report a
/// schema or registration problem, not user-facing content. Standing out is not
/// the same as ignoring the theme though — the colours below adapt to
/// brightness, so a dark form does not get a light rectangle punched through it.
library;

import 'package:flutter/material.dart';

@immutable
class WarningColors {
  const WarningColors({
    required this.background,
    required this.border,
    required this.icon,
    required this.title,
    required this.detail,
  });

  final Color background;
  final Color border;
  final Color icon;
  final Color title;
  final Color detail;

  factory WarningColors.of(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.dark) {
      // A translucent wash over the existing surface, rather than an opaque
      // light panel: it stays legible without glaring.
      const amber = Color(0xFFFFB74D);
      return WarningColors(
        background: amber.withValues(alpha: 0.10),
        border: amber.withValues(alpha: 0.55),
        icon: amber,
        title: const Color(0xFFFFCC80),
        detail: theme.colorScheme.onSurfaceVariant,
      );
    }
    return WarningColors(
      background: Colors.orange.shade50,
      border: Colors.orange.shade300,
      icon: Colors.orange.shade700,
      title: Colors.orange.shade900,
      detail: Colors.grey.shade700,
    );
  }
}

/// Wraps [child] in the shared warning container.
Widget warningCard(
  BuildContext context, {
  required Widget child,
  EdgeInsetsGeometry margin = const EdgeInsets.symmetric(vertical: 4),
  EdgeInsetsGeometry padding = const EdgeInsets.all(12),
}) {
  final colors = WarningColors.of(context);
  return Container(
    margin: margin,
    padding: padding,
    decoration: BoxDecoration(
      color: colors.background,
      border: Border.all(color: colors.border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: child,
  );
}
