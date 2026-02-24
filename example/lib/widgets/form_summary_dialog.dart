/// Form summary dialog with inline editing capability.
///
/// Displays answered fields and allows tapping on any answer
/// to re-answer it before final submission.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:formio_api/formio_api.dart';

import '../models/prompt_dictionary.dart';
import '../services/ai_service.dart';

class FormSummaryDialog extends StatefulWidget {
  final Map<String, dynamic> formData;
  final List<ComponentModel> questions;
  final VoidCallback? onSubmit;
  final VoidCallback? onDismiss;

  /// Called when user wants to edit a specific field.
  /// Passes the ComponentModel key to re-ask.
  final void Function(String key)? onEditField;

  const FormSummaryDialog({
    super.key,
    required this.formData,
    required this.questions,
    this.onSubmit,
    this.onDismiss,
    this.onEditField,
  });

  @override
  State<FormSummaryDialog> createState() => _FormSummaryDialogState();
}

class _FormSummaryDialogState extends State<FormSummaryDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = PromptDictionary.current;

    return ScaleTransition(
      scale: _scaleAnim,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 600),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.surface,
                theme.colorScheme.surface.withAlpha(245),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withAlpha(30),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.tertiary,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: theme.colorScheme.onPrimary,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      d.summaryCompleted,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      d.summaryReview,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimary.withAlpha(200),
                      ),
                    ),
                  ],
                ),
              ),
              // Summary list
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: _getDisplayItems().length,
                  separatorBuilder: (_, __) => Divider(
                    color: theme.colorScheme.outlineVariant.withAlpha(100),
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final item = _getDisplayItems()[index];
                    final canEdit = widget.onEditField != null;

                    return InkWell(
                      onTap: canEdit
                          ? () {
                              HapticFeedback.selectionClick();
                              Navigator.of(context).pop();
                              widget.onEditField?.call(item['key']!);
                            }
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                item['label']!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: Text(
                                item['value']!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (canEdit)
                              Icon(
                                Icons.edit_rounded,
                                size: 16,
                                color: theme.colorScheme.primary.withAlpha(150),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Action buttons
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            widget.onDismiss ?? () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(d.summaryEdit),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () {
                          HapticFeedback.heavyImpact();
                          widget.onSubmit?.call();
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.send_rounded),
                        label: Text(d.summarySubmit),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build display items by matching questions to form data.
  List<Map<String, String>> _getDisplayItems() {
    final items = <Map<String, String>>[];
    for (final q in widget.questions) {
      final value = widget.formData[q.key];
      items.add({
        'key': q.key,
        'label': q.label.isNotEmpty ? q.label : q.key,
        'value': _formatValue(value, q),
      });
    }
    return items;
  }

  /// Format a value for human-readable display, using question type context.
  String _formatValue(dynamic value, ComponentModel question) {
    final d = PromptDictionary.current;

    // Null / missing
    if (value == null) return d.summaryNotAnswered;

    // Empty string
    if (value is String && value.trim().isEmpty) return d.summaryNotAnswered;

    // Native bool
    if (value is bool) return value ? d.labelYes : d.labelNo;

    // Bool-like values (AI may return 1/0/"true"/"false")
    if (_isBooleanType(question.type)) {
      return _parseBoolDisplay(value, d);
    }

    // Radio / Select — resolve raw value to human label
    if (question.type == 'radio' || question.type == 'select') {
      final label = _resolveLabel(value.toString(), question);
      // If couldn't resolve (label == raw value), try bool-like display
      if (label == value.toString()) {
        return _parseBoolDisplay(value, d);
      }
      return label;
    }

    // Selectboxes: Map<String, bool> → show only selected keys as LABELS
    if (value is Map) {
      if (question.type == 'selectboxes') {
        final selected = value.entries
            .where((e) => _isTruthy(e.value))
            .map((e) => _resolveLabel(e.key, question))
            .toList();
        return selected.isEmpty ? d.summaryNotAnswered : selected.join(', ');
      }
      // Generic map
      return value.entries
          .map((e) => '${e.key}: ${e.value}')
          .join(', ');
    }

    // Selectboxes: String "opt1, opt3" → resolve each key to label
    if (question.type == 'selectboxes' && value is String) {
      final keys = value.split(RegExp(r'[,\s]+')).where((k) => k.isNotEmpty);
      final options = AIService.extractOptions(question.raw);
      if (options.isNotEmpty) {
        final resolved = keys.map((k) => _resolveLabel(k, question));
        return resolved.join(', ');
      }
    }

    // List
    if (value is List) {
      return value.isEmpty
          ? d.summaryNotAnswered
          : value.map((e) => e.toString()).join(', ');
    }

    // Number formatting
    if (value is num) {
      // Show integers without decimals
      if (value == value.toInt()) return value.toInt().toString();
      return value.toString();
    }

    final str = value.toString();
    return str.isEmpty ? d.summaryNotAnswered : str;
  }

  /// True if this component type expects boolean-like values.
  bool _isBooleanType(String type) {
    return type == 'checkbox' || type == 'toggle';
  }

  /// Parse display text for a boolean-like value.
  String _parseBoolDisplay(dynamic value, PromptDictionary d) {
    if (value is bool) return value ? d.labelYes : d.labelNo;
    if (value is int) return value != 0 ? d.labelYes : d.labelNo;
    if (value is double) return value != 0 ? d.labelYes : d.labelNo;
    final str = value.toString().toLowerCase().trim();
    if (str == 'true' || str == '1' || str == 'evet' || str == 'yes') {
      return d.labelYes;
    }
    if (str == 'false' || str == '0' || str == 'hayır' || str == 'no') {
      return d.labelNo;
    }
    return value.toString();
  }

  /// Check if a value is truthy (for selectboxes).
  bool _isTruthy(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value != 0;
    final str = value.toString().toLowerCase().trim();
    return str == 'true' || str == '1';
  }

  /// Look up the human label for a value from component options.
  ///
  /// Uses [AIService.extractOptions] which handles all Form.io
  /// component structures (select, radio, selectboxes).
  String _resolveLabel(String valueKey, ComponentModel question) {
    final options = AIService.extractOptions(question.raw);
    for (final opt in options) {
      if (opt['value'] == valueKey) {
        return opt['label'] ?? valueKey;
      }
    }
    return valueKey;
  }
}
