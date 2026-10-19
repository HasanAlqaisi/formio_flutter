# Form.io Flutter

Render [Form.io](https://form.io) forms natively in Flutter — with the **real
Form.io logic engine**, not a re-implementation.

[![Pub Version](https://img.shields.io/pub/v/formio)](https://pub.dev/packages/formio)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

As of **3.0.0**, all form logic — conditionals, calculations, Logic-tab actions,
and validation (including custom JavaScript) — is delegated to Form.io's own
[`@formio/core`](https://www.npmjs.com/package/@formio/core) running headless via
[`flutter_js`](https://pub.dev/packages/flutter_js). Behavior matches the Form.io
web renderer by construction, with **no WebView**. Flutter only draws the widgets.

> **Upgrading from 2.x?** `FormRenderer`/`WizardRenderer` are replaced by
> `EngineFormRenderer`, and the separate `formio_api` package is merged into
> `formio`. See the [CHANGELOG](packages/flutter_formio/CHANGELOG.md) for the
> full list of breaking changes.

## How it works

```
Form JSON ─► EngineFormRenderer ──(on every change)──► FormLogicEngine
                    ▲                                   (@formio/core in flutter_js)
                    └────────── { data, hidden, errors } ◄──┘
```

`EngineFormRenderer` owns the nested submission. On every change it sends the data
to the engine and repaints from `{ data, hidden, errors }`. Basic inputs and
layout are rendered natively; premium/less-common types fall back to
`ComponentFactory`; anything domain-specific is provided by **your** app.

## Install

```yaml
dependencies:
  formio: ^3.0.0
```

```dart
import 'package:formio/formio.dart';
```

## Quick start

Initialize the engine once (it loads the `@formio/core` bundle), then hand it to
the renderer:

```dart
import 'package:flutter/material.dart';
import 'package:formio/formio.dart';

late final FormLogicEngine engine;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  engine = FormLogicEngine();
  await engine.init(); // loads the bundle once
  runApp(const MyApp());
}

class FormPage extends StatelessWidget {
  const FormPage({super.key, required this.form});
  final Map<String, dynamic> form; // parsed Form.io JSON (a `components` tree)

  @override
  Widget build(BuildContext context) => Scaffold(
        body: EngineFormRenderer(
          form: form,
          engine: engine,
          onSubmit: (data) => debugPrint('Submitted: $data'),
          onChanged: (data) {/* live data on every edit */},
        ),
      );
}
```

`form` is the parsed Form.io definition. If your export wraps it (e.g. Creatio's
`{"template": "<stringified JSON>"}`), unwrap and `jsonDecode` it first:

```dart
final outer = jsonDecode(raw);
final tpl = outer is Map && outer['template'] != null ? outer['template'] : outer;
final form = (tpl is String ? jsonDecode(tpl) : tpl) as Map<String, dynamic>;
```

### `EngineFormRenderer` options

| Parameter | Purpose |
|-----------|---------|
| `form` | Parsed Form.io definition (required). |
| `engine` | An initialized `FormLogicEngine` (required). |
| `initialData` | Pre-populate the submission. |
| `onSubmit` | Called with the data when the built-in Submit passes validation. |
| `onChanged` | Called with the live data on every recompute. |
| `customComponents` | Host builders for custom types / overrides (see below). |
| `controls` | Host widgets for the *look* of built-in controls, behavior kept (see below). |
| `resourceSource` | Project URL + headers for `dataSrc: "resource"` selects. |
| `theme` | `FormioTheme` design tokens. |
| `textDirection` | `TextDirection.rtl` for RTL forms (defaults to ambient). |
| `debounce` | Text-input recompute debounce (default 450 ms). |

## Custom components & overrides

Domain-specific widgets (file pickers, maps, signature pads…) live in **your**
app — the package provides the extension point, you provide the widget. The same
map overrides any built-in type.

```dart
EngineFormRenderer(
  form: form,
  engine: engine,
  customComponents: {
    'geopoint': (ctx) => MyMapField(ctx),       // a brand-new type
    'sites':   (ctx) => ctx.builtin('select'), // alias to a built-in
    'select':  (ctx) => MyBrandedSelect(ctx),  // override a built-in
  },
);
```

Each builder receives a `FormioFieldContext`:

```dart
class MyFileField extends StatelessWidget {
  const MyFileField(this.ctx, {super.key});
  final FormioFieldContext ctx;

  @override
  Widget build(BuildContext context) {
    final ids = (ctx.value as List?) ?? const [];
    return ctx.chrome(Column(children: [        // optional standard label/error
      for (final id in ids) Text('$id'),
      OutlinedButton(
        onPressed: () async {
          final id = await MyStorage.pickAndUpload();
          ctx.setValue([...ids, id], immediate: true); // triggers a recompute
        },
        child: const Text('Upload'),
      ),
    ]));
  }
}
```

`FormioFieldContext` exposes: `value` / `setValue` / `read(path)` / `error` /
`controller()` / `focusNode()` / `child()` / `builtin(type)` / `chrome()` /
`theme` / `component` / `path`.

### Restyling a built-in control

`customComponents` replaces a component outright — schema handling included. If
you only want your own *widget* for a built-in control, use `controls`: the
package still resolves the schema (`dataSrc`, `valueProperty`, `template`,
remote loading, value coercion) and hands you the result.

```dart
EngineFormRenderer(
  form: form,
  engine: engine,
  controls: FormioControlBuilders(
    select: (context, spec) {
      // delegate the cases you don't want to style:
      if (spec.multiple) return FormioBuiltInSelect(spec: spec);
      return MyDropdown(
        options: spec.options,            // resolved, typed values
        value: spec.selected?.value,
        loading: spec.loading,            // remote fetch in flight
        onChanged: spec.onChanged,
      );
    },
  ),
);
```

`FormioSelectSpec` carries `options` / `value` / `selected` / `selectedMany` /
`onChanged` / `label` / `placeholder` / `enabled` / `multiple` / `required` /
`searchable` / `loading` / `error` / `ensureOptions`. Return
`FormioBuiltInSelect(spec: spec)` for any case you don't want to style.

### Remote & resource selects

Selects with `dataSrc: "url"` fetch their options directly (the engine never
fetches — that only happens server-side in Form.io). Responses are cached per
resolved URL, and `lazyLoad` components fetch on first open.

`dataSrc: "resource"` (and the `resource` component type) carries only a form
id, so the project it lives in is deployment config — pass it in:

```dart
EngineFormRenderer(
  form: form,
  engine: engine,
  resourceSource: const FormioResourceSource(
    projectUrl: 'https://myproject.form.io',
    headers: {'x-jwt-token': '…'},
  ),
);
```

Leave it null if no form uses a resource source; those components then show a
data-source error instead of an empty list that would never fill.

### A note on buttons

Form.io `button` components are **not** rendered — submission is driven by the
renderer's own Submit button + `onSubmit`. To render a form button with custom
behavior, override it: `customComponents: {'button': (ctx) => ...}`.

## Theming

```dart
EngineFormRenderer(
  form: form,
  engine: engine,
  theme: const FormioTheme(
    labelStyle: TextStyle(fontWeight: FontWeight.w600),
    inputBorder: OutlineInputBorder(),
    requiredSuffix: ' *',
    columnBreakpoint: 170, // px below which columns/tables stack (responsive)
  ),
);
```

Every token defaults to the ambient Material theme, so `FormioTheme()` keeps the
stock look. Available tokens:

| Group | Tokens |
|-------|--------|
| Text | `labelStyle`, `descriptionStyle`, `errorStyle`, `panelTitleStyle`, `affixStyle`, `inputTextStyle`, `hintStyle` |
| Input | `inputFillColor`, `inputBorder`, `focusedInputBorder`, `errorInputBorder`, `inputContentPadding`, `isDense` |
| Layout | `fieldPadding`, `sectionMargin`, `sectionPadding`, `sectionDecoration`, `columnBreakpoint` |
| Misc | `requiredSuffix`, `requiredSuffixColor`, `submitButtonStyle`, `accentColor` |

Inside a custom component, read the active tokens with `ctx.theme` — or
`FormioThemeScope.of(context)` in a widget further down the tree.

Layouts are **responsive**: `columns` and `table` sit side-by-side on wide
screens and stack vertically on narrow ones (threshold = `columnBreakpoint`).
Field label placement follows the schema's `labelPosition` (including
left/right alignment).

## Validation

Live validation runs by default. Error text is localized and, where the engine
supplies a limit, specific — e.g. `Must be at most 20 characters`,
`Must be 10 or more`. Custom-validation messages authored in the form are shown
as-is.

## Internationalization & RTL

```dart
// Global locale for built-in strings & error messages:
ComponentFactory.setLocale(const ArabicFormioLocalizations()); // built-in Arabic
// or provide your own by subclassing DefaultFormioLocalizations.

EngineFormRenderer(form: form, engine: engine, textDirection: TextDirection.rtl);
```

## Repository layout

```
packages/flutter_formio/   # the published `formio` package
tools/formio-core/         # @formio/core bundle source (esbuild) + engine tests
example/                   # runnable demo (flutter run)
docs/                      # developer guide, status report, form-authoring rules
```

Engineers: start with the [Developer Guide](docs/developer-guide.md). Form
authors: [Form Authoring Guidelines](docs/form-authoring-guidelines.md).

### Rebuilding the engine bundle

The `@formio/core` bundle ships as a package asset. After editing
`tools/formio-core/entry.js`:

```bash
cd tools/formio-core
npm ci
npm run build   # → packages/flutter_formio/assets/formio/formio-core.bundle.js
npm test        # engine regression tests
```

## Example

```bash
cd example
flutter pub get
flutter run
```

Pick a bundled sample form and open it — logic, validation, and custom components
all run live. See [example/README.md](example/README.md).

## Contributing

Contributions are welcome. Please run `flutter analyze` and `flutter test` (in
`packages/flutter_formio`) plus `npm test` (in `tools/formio-core`) before a PR.

## License

MIT License — see [LICENSE](LICENSE).

## Support

- 📖 [Documentation](https://github.com/mskayali/formio_flutter)
- 🐛 [Issue Tracker](https://github.com/mskayali/formio_flutter/issues)
- 💬 [Discussions](https://github.com/mskayali/formio_flutter/discussions)

## Credits

Built with ❤️ for the Flutter community. Form.io is a trademark of Form.io, Inc.
