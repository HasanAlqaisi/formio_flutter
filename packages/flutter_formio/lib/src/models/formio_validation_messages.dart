/// Messages for validation rules that [FormioLocalizations] does not name.
///
/// These twelve `@formio/core` rules had no wording of their own, so every one of
/// them surfaced as the generic "Invalid value" — a `maxWords` failure and a
/// `unique` failure told the user exactly the same nothing.
///
/// They live in a **separate, optional** interface rather than being added to
/// [FormioLocalizations] because that class is documented as something hosts
/// `implements`, and Dart's `implements` requires every member — even ones with
/// bodies. Adding getters there would break every existing host implementation
/// at compile time. Implementing this alongside it is opt-in: a host that skips
/// it keeps the old generic fallback and still compiles.
///
/// [DefaultFormioLocalizations] implements it, so English and Arabic have these
/// out of the box.
library;

abstract class FormioValidationMessages {
  /// The chosen value is not one of the available options. Covers the engine's
  /// `invalidOption`, `select` and `onlyAvailableItems` rules, which all mean
  /// the same thing to the person filling the form.
  String get invalidOption;

  /// `unique` — this value is already used by another row or submission.
  String get valueMustBeUnique;

  /// `array` — the component expected a list and did not get one.
  String get valueMustBeList;

  /// `nonarray` — the component expected a single value and got a list.
  String get valueMustNotBeList;

  /// `invalidValueProperty` — the option source has no such value property. A
  /// schema fault rather than a user mistake, so it is worth reading as one.
  String get invalidValueProperty;

  /// `minWords` — fewer words than [limit].
  String getMinWordsMessage(String limit);

  /// `maxWords` — more words than [limit].
  String getMaxWordsMessage(String limit);

  /// `minSelectedCount` — fewer than [limit] boxes ticked.
  ///
  /// Form.io lets an author override this per component with
  /// `minSelectedCountMessage`; this is the wording when they have not.
  String getMinSelectedMessage(String limit);

  /// `maxSelectedCount` — more than [limit] boxes ticked.
  String getMaxSelectedMessage(String limit);
}
