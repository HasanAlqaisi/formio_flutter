/// Design tokens for [EngineFormRenderer]'s built-in widgets.
///
/// Pass a `FormioTheme` to customize the renderer's appearance without
/// replacing its built-in widgets. Any null value falls back to the ambient
/// Material theme.
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
    this.inputTextStyle,
    this.hintStyle,
    this.inputFillColor,
    this.inputBorder,
    this.focusedInputBorder,
    this.errorInputBorder,
    this.inputContentPadding,
    this.isDense = true,
    this.fieldPadding = const EdgeInsets.symmetric(vertical: 6),
    this.sectionMargin = const EdgeInsets.symmetric(vertical: 6),
    this.sectionPadding = const EdgeInsets.all(12),
    this.sectionDecoration,
    this.requiredSuffix = ' *',
    this.requiredSuffixColor,
    this.columnBreakpoint = 170.0,
    this.submitButtonStyle,
    this.accentColor,
  });

  /// Style for field labels.
  final TextStyle? labelStyle;

  /// Style for field descriptions.
  final TextStyle? descriptionStyle;

  /// Style for validation errors.
  final TextStyle? errorStyle;

  /// Style for section titles.
  final TextStyle? panelTitleStyle;

  /// Style for prefix/suffix text.
  final TextStyle? affixStyle;

  /// Style for user-entered input text.
  final TextStyle? inputTextStyle;

  /// Style for placeholder text.
  final TextStyle? hintStyle;

  /// Background color for text/date inputs.
  final Color? inputFillColor;

  /// Default border for text/date inputs.
  final InputBorder? inputBorder;

  /// Border displayed while focused.
  final InputBorder? focusedInputBorder;

  /// Border displayed when validation fails.
  final InputBorder? errorInputBorder;

  /// Content padding inside text/date inputs.
  final EdgeInsetsGeometry? inputContentPadding;

  /// Whether inputs use a dense layout.
  final bool isDense;

  /// Padding around each field.
  final EdgeInsetsGeometry fieldPadding;

  /// Margin around sections.
  final EdgeInsetsGeometry sectionMargin;

  /// Padding inside sections.
  final EdgeInsetsGeometry sectionPadding;

  /// Decoration for section containers.
  final BoxDecoration? sectionDecoration;

  /// Suffix appended to required field labels.
  final String requiredSuffix;

  /// Color of [requiredSuffix]. Defaults to the ambient error colour, so the
  /// asterisk reads as red against the rest of the label.
  final Color? requiredSuffixColor;

  /// Minimum width per column before layouts stack vertically.
  final double columnBreakpoint;

  /// Style for the form's submit button.
  final ButtonStyle? submitButtonStyle;

  /// Colour for emphasis *on the form's own background* — the active tab and its
  /// indicator, the add-row action.
  ///
  /// Deliberately separate from the ambient `colorScheme.primary`, which is a
  /// *fill* colour chosen to sit under white text. A design system usually has a
  /// second, lighter accent for text and indicators, and using the fill colour
  /// for them leaves an active tab looking disabled on a dark ground.
  final Color? accentColor;

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

  /// Style for the submit button.
  ///
  /// Falls back to a full-width button whose corner radius matches the inputs,
  /// so the form ends on something that looks like it belongs to the fields
  /// above it rather than a stock pill. Colours are left to the ambient
  /// [ElevatedButton] theme.
  ButtonStyle resolvedSubmitButtonStyle(BuildContext c) =>
      submitButtonStyle ??
      ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: resolvedInputRadius()),
      );

  Color resolvedRequiredSuffixColor(BuildContext c) =>
      requiredSuffixColor ?? Theme.of(c).colorScheme.error;

  Color resolvedAccentColor(BuildContext c) =>
      accentColor ?? Theme.of(c).colorScheme.primary;

  /// A foreground that actually reads on [resolvedAccentColor].
  ///
  /// Computed from the accent's own brightness rather than taken from
  /// `colorScheme.onPrimary`: the accent may not be the ambient primary, and a
  /// host whose `onPrimary` is dark produced dark text on a dark filled button.
  Color resolvedOnAccentColor(BuildContext c) =>
      ThemeData.estimateBrightnessForColor(resolvedAccentColor(c)) ==
              Brightness.dark
          ? Colors.white
          : Colors.black;

  /// The form's confirming action — a dialog's Save, a filled affirmative.
  ButtonStyle resolvedPrimaryActionStyle(BuildContext c) =>
      FilledButton.styleFrom(
        backgroundColor: resolvedAccentColor(c),
        foregroundColor: resolvedOnAccentColor(c),
      );

  /// The form's lower-emphasis actions — Cancel, Clear, Add, Upload.
  ///
  /// Accent-on-background rather than the ambient primary, which is a fill colour
  /// and comes out too dark to read as text on a dark form.
  ButtonStyle resolvedSecondaryActionStyle(BuildContext c) =>
      TextButton.styleFrom(foregroundColor: resolvedAccentColor(c));

  /// The border colour the inputs use, for widgets that paint their own edge.
  ///
  /// Falls back to the ambient divider colour, which is brighter than a themed
  /// input border and is what made repeated-row cards stand out from the fields
  /// inside them.
  Color resolvedBorderColor(BuildContext c) {
    final border = inputBorder;
    if (border is OutlineInputBorder) return border.borderSide.color;
    return Theme.of(c).dividerColor;
  }

  /// The corner radius the inputs use, so other surfaces can match it.
  BorderRadius resolvedInputRadius() {
    final border = inputBorder;
    if (border is OutlineInputBorder) return border.borderRadius;
    return BorderRadius.circular(8);
  }

  /// The input border expressed as a [BoxDecoration], for widgets that paint
  /// their own container instead of using an [InputDecoration] — a signature
  /// canvas, a survey table — so their edge matches the text inputs.
  ///
  /// Falls back to the ambient divider colour at radius 8 when [inputBorder] is
  /// unset, which is what those widgets already drew.
  BoxDecoration resolvedContainerDecoration(BuildContext c) {
    final border = inputBorder;
    return BoxDecoration(
      border: border is OutlineInputBorder
          ? Border.all(
              color: border.borderSide.color,
              width: border.borderSide.width,
            )
          : Border.all(color: Theme.of(c).dividerColor),
      borderRadius: resolvedInputRadius(),
      color: inputFillColor,
    );
  }

  /// Whether any input-level token is set. Used to decide if the stock
  /// component set needs its ambient [InputDecorationTheme] overridden.
  bool get _stylesInputs =>
      accentColor != null ||
      inputBorder != null ||
      focusedInputBorder != null ||
      errorInputBorder != null ||
      inputFillColor != null ||
      hintStyle != null ||
      inputContentPadding != null;

  /// The input tokens expressed as an [InputDecorationTheme], or null when none
  /// are set.
  ///
  /// The stock component set (`day`, `address`, `survey`, …) builds bare
  /// [InputDecoration]s and cannot see a [FormioTheme], so the renderer injects
  /// this above them. Returning null when nothing is customised keeps a bare
  /// `FormioTheme()` from changing how those widgets already look.
  InputDecorationTheme? resolvedInputDecorationTheme(BuildContext c) {
    if (!_stylesInputs) return null;
    return InputDecorationTheme(
      isDense: isDense,
      border: resolvedInputBorder(c),
      enabledBorder: inputBorder,
      focusedBorder: focusedInputBorder,
      errorBorder: errorInputBorder,
      focusedErrorBorder: errorInputBorder,
      contentPadding: inputContentPadding,
      hintStyle: hintStyle,
      floatingLabelStyle: TextStyle(color: resolvedAccentColor(c)),
      fillColor: inputFillColor,
      filled: inputFillColor != null,
    );
  }

  FormioTheme copyWith({
    TextStyle? labelStyle,
    TextStyle? descriptionStyle,
    TextStyle? errorStyle,
    TextStyle? panelTitleStyle,
    TextStyle? affixStyle,
    TextStyle? inputTextStyle,
    TextStyle? hintStyle,
    Color? inputFillColor,
    InputBorder? inputBorder,
    InputBorder? focusedInputBorder,
    InputBorder? errorInputBorder,
    EdgeInsetsGeometry? inputContentPadding,
    bool? isDense,
    EdgeInsetsGeometry? fieldPadding,
    EdgeInsetsGeometry? sectionMargin,
    EdgeInsetsGeometry? sectionPadding,
    BoxDecoration? sectionDecoration,
    String? requiredSuffix,
    Color? requiredSuffixColor,
    double? columnBreakpoint,
  }) =>
      FormioTheme(
        labelStyle: labelStyle ?? this.labelStyle,
        descriptionStyle: descriptionStyle ?? this.descriptionStyle,
        errorStyle: errorStyle ?? this.errorStyle,
        panelTitleStyle: panelTitleStyle ?? this.panelTitleStyle,
        affixStyle: affixStyle ?? this.affixStyle,
        inputTextStyle: inputTextStyle ?? this.inputTextStyle,
        hintStyle: hintStyle ?? this.hintStyle,
        inputFillColor: inputFillColor ?? this.inputFillColor,
        inputBorder: inputBorder ?? this.inputBorder,
        focusedInputBorder: focusedInputBorder ?? this.focusedInputBorder,
        errorInputBorder: errorInputBorder ?? this.errorInputBorder,
        inputContentPadding: inputContentPadding ?? this.inputContentPadding,
        isDense: isDense ?? this.isDense,
        fieldPadding: fieldPadding ?? this.fieldPadding,
        sectionMargin: sectionMargin ?? this.sectionMargin,
        sectionPadding: sectionPadding ?? this.sectionPadding,
        sectionDecoration: sectionDecoration ?? this.sectionDecoration,
        requiredSuffix: requiredSuffix ?? this.requiredSuffix,
        requiredSuffixColor: requiredSuffixColor ?? this.requiredSuffixColor,
        columnBreakpoint: columnBreakpoint ?? this.columnBreakpoint,
      );
}

/// Makes the active [FormioTheme] available to widgets below the renderer.
///
/// [of] returns a default `FormioTheme()` when there is no scope above, so a
/// stock component still works when used standalone.
class FormioThemeScope extends InheritedWidget {
  const FormioThemeScope({
    required this.theme,
    required super.child,
    super.key,
  });

  final FormioTheme theme;

  static FormioTheme of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FormioThemeScope>()?.theme ??
      const FormioTheme();

  @override
  bool updateShouldNotify(FormioThemeScope oldWidget) =>
      oldWidget.theme != theme;
}
