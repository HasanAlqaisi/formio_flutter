# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.0] - 2026-08-10

Major release. Form logic is now delegated to Form.io's own `@formio/core`
running headless via `flutter_js`, replacing the hand-rolled Dart evaluators.
This gives full logic fidelity — conditionals, calculations, Logic-tab actions,
and validation, **including custom JavaScript** — and eliminates a large class
of drift bugs.

### Added

- `EngineFormRenderer` — engine-driven, path-aware renderer over nested submissions.
- `FormLogicEngine` — headless `@formio/core` wrapper (`init` / `setForm` / `processData`),
  behind a `FormEngine` interface so it can be mocked or replaced (e.g. isolate-hosted).
- Custom-component extension API: `customComponents` map + `FormioFieldContext`
  (`value` / `setValue` / `read` / `error` / `controller` / `builtin` / `chrome`)
  + `FormioFieldBuilder`. Register new types or override built-ins.
- Control-presentation API: `EngineFormRenderer.controls`
  (`FormioControlBuilders`, `FormioSelectSpec`, `FormioBuiltInSelect`) — swap the
  widget for a built-in control while the package keeps the schema behaviour.
- Remote select sources: `dataSrc: "url"` selects fetch their own options (cached
  per resolved URL, `lazyLoad` deferred until first open); `dataSrc: "resource"`
  and the `resource` component type via `EngineFormRenderer.resourceSource`
  (`FormioResourceSource`), with an explicit data-source error when unreachable.
- Searchable single/multi select picker for long option lists.
- `FormioTheme` design tokens via `EngineFormRenderer.theme` — text, input
  decoration, spacing, `sectionDecoration`, `submitButtonStyle`, `accentColor`,
  `columnBreakpoint` — plus `FormioThemeScope.of(context)` for widgets below the
  renderer.
- Responsive `columns`/`table` (stack below `columnBreakpoint` per column) and
  schema `labelPosition` support, including left/right label alignment.
- Text input fidelity: `inputMask` formatting as you type, prefix/suffix addons,
  numeric formatting for `number`/`currency` (integer-only, decimal precision).
- Platform-styled date/time pickers, and dates rendered in the schema's `format`.
- Reorderable `datagrid` rows (drag handles) and a swipeable `tabs` bar.
- Safer form-authored HTML: tag validation, void elements, guarded link taps.
- `EngineFormRenderer.textDirection` for right-to-left forms.
- Localized validation errors via `ComponentFactory.setLocale`, including
  limit-aware messages (e.g. "Must be at most 20 characters").
- Built-in Arabic localization: `ArabicFormioLocalizations`.
- Per-component error boundary: a throwing component degrades to a placeholder
  instead of taking down the whole form.

### Changed

- Conditionals, calculations, and validation now run in `@formio/core`, not Dart.
- Discrete selections (dropdowns, chips, checkboxes) recompute immediately;
  text input stays debounced.
- Data components are bound by path even when the schema omits `input: true`
  (Form.io carries the flag in each class's own `defaultSchema`).

### Removed — BREAKING

- **The separate `formio_api` package is merged into `formio`.** Its models,
  REST client, and utilities now ship inside this package — import everything
  from `package:formio/formio.dart` (drop any `package:formio_api/...` imports
  and the `formio_api` dependency). The Form.io logic now runs in `@formio/core`,
  so the pure-Dart evaluators `formio_api` used to carry are gone:
  `ConditionalEvaluator`, `CalculationEvaluator`, and `TemplateParser`.
- `FormRenderer`, `WizardRenderer`, `FormDataProvider`.
- Stock components (and their exports) for types the engine renders natively —
  `textfield`, `textarea`, `number`, `currency`, `email`, `url`, `password`,
  `phoneNumber`, `checkbox`, `radio`, `select`, `selectboxes`, `date`, `datetime`,
  `time`, `columns`, `table`, `panel`, `well`, `fieldset`, `tabs`, `container`,
  `datagrid`, `editgrid`. `ComponentFactory` remains as the premium-type fallback
  (address, signature, file, survey, …) and the host-registration mechanism.
- The pure-Dart `FormioLocale` interface (localization goes through
  `FormioLocalizations` / `ComponentFactory.setLocale`) and the standalone Dart
  validators the engine replaced.

### Fixed

- Conditionally-hidden panels no longer render as dead, engine-reverted shells.
- Panel/fieldset headers read `title`/`legend` instead of the default `label`.
- `content` / `htmlelement` components interpolate `{{data.x}}`.

### Performance

- The form is cached JS-side (`setForm`); only the submission crosses the FFI
  boundary per recompute — a ~3000–9000× smaller payload on large forms.

## [2.0.4] - 2026-02-11

### Added

- Added sticky header support with `sticky_headers` package for improved form navigation
- Added button registration functionality for enhanced component management
- Added new translation support for internationalization

### Fixed

- Fixed `initialData` override for all nested components
- Fixed form submission nesting issues
- Fixed survey component scroll bug
- Fixed validation bugs affecting form validation behavior
- Improved URL parser for better link handling
- Code cleanup: Removed empty containers

## [2.0.3] - 2026-01-14

### Added

- Added `enableLinks` parameter to `HtmlElementComponent` for controlling link interactivity
  - Matching behavior with `ContentComponent`
  - Defaults to `true` for backward compatibility
  - Imported `url_launcher` package for link handling

### Fixed

- Fixed duplicate `fieldWidget` variable declaration in `form_renderer.dart`
- Cleaned up example code: Removed undefined `CustomSubmitButtonBuilder` registration

## [2.0.2] - 2026-01-13

### Added

- Added DataSourceComponent to main library file

## [2.0.1] - 2026-01-13

### Changed

- Updated dependencies for pub.dev compatibility:
  - `flutter_lints`: ^3.0.0 → ^6.0.0
- Changed `formio_api` from path dependency to hosted dependency ^2.0.1

### Added

- Added missing `dio` ^5.9.0 dependency (required by `datasource_component`)

### Fixed

- Removed debug print statements for production readiness
- Cleaned up unused state fields in components

## [2.0.0] - 2026-01-13

### Breaking Changes

- **Package Split**: `formio` package has been split into two packages:
  - `formio_api` - Pure Dart API client (no Flutter dependencies)
  - `flutter_formio` - Flutter widgets for rendering forms
- **Import Changes**: Update imports from `package:formio/formio.dart` to `package:formio/formio.dart`
- **JS Evaluator**: Must now explicitly initialize JavaScript evaluator in `main()`:
  ```dart
  JavaScriptEvaluator.setEvaluator(FlutterJsEvaluator());
  ```

### Added

- **Pure Dart Support**: `formio_api` can now be used in non-Flutter Dart projects
- **Pluggable JS Engine**: `JsEvaluator` interface allows custom JavaScript implementations
- **Custom Locale Interface**: Pure Dart `FormioLocale` interface for API package
- **Dependency Injection**: Platform-independent architecture with injectable components
- **NoOp JS Evaluator**: Testing-friendly no-op evaluator for unit tests

### Changed

- **Package Structure**: Monorepo with `packages/formio_api` and `packages/flutter_formio`
- **Dependencies**: `flutter_formio` now depends on `formio_api` ^2.0.0
- **Component Builder**: Changed from typedef to abstract class `FormioComponentBuilder`

### Improved

- **Modularity**: Clean separation between API logic and UI components
- **Testability**: Pure Dart API package is easier to test
- **Flexibility**: Custom JS engines, locales, and validators
- **Documentation**: Comprehensive README, migration guide, and API documentation

## [1.1.0] - 2026-01-12

### Added

- JavaScript evaluation support for calculations and validations
- flutter_js integration for cross-platform JS execution
- Comprehensive validation system with 15+ validators
- JSONLogic-based conditional rendering
- Plugin system for custom components

### Fixed

- Conditional logic edge cases
- Validation message formatting
- Wizard navigation issues

## [1.0.0] - 2026-01-10

### Added

- Initial release
- 46+ Form.io components
- Wizard forms support
- API integration (forms, submissions, users)
- Localization support
- Material Design theming

---

[3.0.0]: https://github.com/mskayali/formio_flutter/compare/v2.0.4...v3.0.0
[2.0.0]: https://github.com/mskayali/formio_flutter/compare/v1.1.0...v2.0.0
[1.1.0]: https://github.com/mskayali/formio_flutter/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/mskayali/formio_flutter/releases/tag/v1.0.0
