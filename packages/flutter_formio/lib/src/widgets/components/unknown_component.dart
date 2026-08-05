/// A Flutter widget that renders a fallback UI for unrecognized component types.
///
/// This component is used when the ComponentFactory encounters a component type
/// that is not supported. It displays a warning message instead of crashing.
library;

import 'package:flutter/material.dart';

import 'warning_card.dart';

import 'package:formio/formio.dart';

class UnknownComponent extends StatelessWidget {
  /// The Form.io component definition.
  final ComponentModel component;

  /// Optional: Show debug information (raw JSON).
  final bool showDebugInfo;

  const UnknownComponent({
    super.key,
    required this.component,
    this.showDebugInfo = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = WarningColors.of(context);
    return warningCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: colors.icon, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Unsupported Component Type',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colors.title,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Type: ${component.type}',
            style: TextStyle(fontSize: 12, color: colors.detail),
          ),
          Text(
            'Key: ${component.key}',
            style: TextStyle(fontSize: 12, color: colors.detail),
          ),
          if (component.label.isNotEmpty)
            Text(
              'Label: ${component.label}',
              style: TextStyle(fontSize: 12, color: colors.detail),
            ),
          if (showDebugInfo) ...[
            const SizedBox(height: 8),
            const Divider(),
            Text(
              'Raw JSON:',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: colors.detail),
            ),
            const SizedBox(height: 4),
            Text(
              component.raw.toString(),
              style: TextStyle(
                  fontSize: 10, color: colors.detail, fontFamily: 'monospace'),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
