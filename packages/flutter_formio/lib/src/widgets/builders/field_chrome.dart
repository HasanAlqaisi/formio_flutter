/// The frame around every control: label, description, inline error, and the
/// card that wraps a section.
library;

import 'package:flutter/material.dart';
import 'package:formio/formio.dart';

import '../components/warning_card.dart';
import '../form_field_scope.dart';
import 'error_messages.dart';
import 'schema_text.dart';

// ---- field chrome (label position + description + inline error) ----------

Widget buildField(
    FieldScope s, Map<String, dynamic> raw, String path, Widget control,
    {bool showLabel = true}) {
  final ctx = s.context;
  final label = (!showLabel || raw['hideLabel'] == true)
      ? ''
      : (raw['label'] as String? ?? '');
  final required = raw['validate']?['required'] == true;
  final pos = raw['labelPosition'] as String? ?? 'top';
  final desc = raw['description'] as String?;
  final error = s.errorFor(path);

  // A side `labelPosition` carries two things: `left-right` puts the label on
  // the left with its text right-aligned (against the field it belongs to).
  // Only the side used to be read, so every side-label rendered left-aligned.
  final side = pos.split('-').first;
  final labelAlign = pos.split('-').length > 1 ? pos.split('-')[1] : null;

  final labelWidget = label.isEmpty
      ? null
      : labelWithRequired(label,
          required: required,
          theme: s.theme,
          context: ctx,
          // start/end rather than left/right so the alignment still means
          // "leading"/"trailing" under RTL.
          textAlign: labelAlign == 'right' ? TextAlign.end : TextAlign.start,
          style: s.theme.resolvedLabelStyle(ctx));

  Widget labeled;
  if (labelWidget == null) {
    labeled = control;
  } else if (side == 'left' || side == 'right') {
    final lw = (raw['labelWidth'] as num?)?.toInt().clamp(10, 90) ?? 30;
    // The label must fill its cell for textAlign to have anywhere to move it.
    final labelCell = Expanded(
        flex: lw, child: SizedBox(width: double.infinity, child: labelWidget));
    final fieldCell = Expanded(flex: 100 - lw, child: control);
    labeled = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: side == 'left'
          ? [labelCell, const SizedBox(width: 8), fieldCell]
          : [fieldCell, const SizedBox(width: 8), labelCell],
    );
  } else if (pos == 'bottom') {
    labeled = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [control, const SizedBox(height: 4), labelWidget]);
  } else {
    labeled = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [labelWidget, const SizedBox(height: 4), control]);
  }

  return Padding(
    padding: s.theme.fieldPadding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        labeled,
        if (desc != null && desc.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(desc, style: s.theme.resolvedDescriptionStyle(ctx)),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(messageForError(error),
                style: s.theme.resolvedErrorStyle(ctx)),
          ),
      ],
    ),
  );
}

Widget sectionCard(FormioTheme theme, Widget child) {
  final padded = Padding(padding: theme.sectionPadding, child: child);
  final decoration = theme.sectionDecoration;
  return decoration == null
      ? Card(margin: theme.sectionMargin, child: padded)
      : Container(
          margin: theme.sectionMargin,
          decoration: decoration,
          child: padded,
        );
}

Widget placeholderCard(BuildContext ctx, String text) => warningCard(
      ctx,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      child: Text(text, style: TextStyle(color: WarningColors.of(ctx).title)),
    );
