/// Design tokens for [EngineFormRenderer]'s built-in widgets.
///
/// Pass a `FormioTheme` to the renderer to restyle labels, inputs, errors, and
/// panel headers without replacing the widgets themselves. Any token left null
/// falls back to a sensible default derived from the ambient Material theme, so
/// a bare `FormioTheme()` matches today's look.
///
/// For deeper control (rendering a whole component type differently), register a
/// builder via `EngineFormRenderer.customComponents` instead.
library;

import 'package:flutter/material.dart';

@immutable
class FormioTheme {
  const FormioTheme({
    this.labelStyle,
    this.descriptionStyle,
    this.errorStyle,
    this.panelTitleStyle,
    this.affixStyle,
    this.inputBorder,
    this.inputContentPadding,
    this.isDense = true,
    this.fieldPadding = const EdgeInsets.symmetric(vertical: 6),
    this.sectionMargin = const EdgeInsets.symmetric(vertical: 6),
    this.requiredSuffix = ' *',
    this.columnBreakpoint = 170.0,
  });

  /// Style for field labels. Default: `w500`.
  final TextStyle? labelStyle;

  /// Style for the help/description text under a field. Default: 12pt hint.
  final TextStyle? descriptionStyle;

  /// Style for the inline validation error. Default: 12pt `colorScheme.error`.
  final TextStyle? errorStyle;

  /// Style for panel/fieldset/well headers. Default: `bold`.
  final TextStyle? panelTitleStyle;

  /// Style for a field's `prefix`/`suffix` addon text (e.g. `$`, `kg`).
  /// Default: the ambient hint colour.
  final TextStyle? affixStyle;

  /// Border for text/date inputs. Default: [OutlineInputBorder].
  final InputBorder? inputBorder;

  /// Content padding inside text/date inputs. Default: framework/`isDense`.
  final EdgeInsetsGeometry? inputContentPadding;

  /// Whether inputs use a dense layout. Default: true.
  final bool isDense;

  /// Vertical spacing wrapped around each field's chrome.
  final EdgeInsetsGeometry fieldPadding;

  /// Margin around panel/fieldset/well/datagrid section cards.
  final EdgeInsetsGeometry sectionMargin;

  /// Appended to a required field's label. Default: `' *'`.
  final String requiredSuffix;

  /// Minimum per-column pixel width before a `columns`/`table` row collapses to
  /// a stacked layout (so labels/fields aren't crushed on narrow screens).
  /// Default: 170.
  final double columnBreakpoint;

  // --- resolved accessors (apply defaults against the ambient theme) ---

  TextStyle resolvedLabelStyle(BuildContext c) =>
      labelStyle ?? const TextStyle(fontWeight: FontWeight.w500);

  TextStyle resolvedDescriptionStyle(BuildContext c) =>
      descriptionStyle ?? TextStyle(fontSize: 12, color: Theme.of(c).hintColor);

  TextStyle resolvedErrorStyle(BuildContext c) =>
      errorStyle ??
      TextStyle(fontSize: 12, color: Theme.of(c).colorScheme.error);

  TextStyle resolvedPanelTitleStyle(BuildContext c) =>
      panelTitleStyle ?? const TextStyle(fontWeight: FontWeight.bold);

  TextStyle resolvedAffixStyle(BuildContext c) =>
      affixStyle ?? TextStyle(color: Theme.of(c).hintColor);

  InputBorder resolvedInputBorder(BuildContext c) =>
      inputBorder ?? const OutlineInputBorder();

  FormioTheme copyWith({
    TextStyle? labelStyle,
    TextStyle? descriptionStyle,
    TextStyle? errorStyle,
    TextStyle? panelTitleStyle,
    TextStyle? affixStyle,
    InputBorder? inputBorder,
    EdgeInsetsGeometry? inputContentPadding,
    bool? isDense,
    EdgeInsetsGeometry? fieldPadding,
    EdgeInsetsGeometry? sectionMargin,
    String? requiredSuffix,
    double? columnBreakpoint,
  }) =>
      FormioTheme(
        labelStyle: labelStyle ?? this.labelStyle,
        descriptionStyle: descriptionStyle ?? this.descriptionStyle,
        errorStyle: errorStyle ?? this.errorStyle,
        panelTitleStyle: panelTitleStyle ?? this.panelTitleStyle,
        affixStyle: affixStyle ?? this.affixStyle,
        inputBorder: inputBorder ?? this.inputBorder,
        inputContentPadding: inputContentPadding ?? this.inputContentPadding,
        isDense: isDense ?? this.isDense,
        fieldPadding: fieldPadding ?? this.fieldPadding,
        sectionMargin: sectionMargin ?? this.sectionMargin,
        requiredSuffix: requiredSuffix ?? this.requiredSuffix,
        columnBreakpoint: columnBreakpoint ?? this.columnBreakpoint,
      );
}
