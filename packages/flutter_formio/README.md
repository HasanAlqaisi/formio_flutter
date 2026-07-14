# flutter_formio

Flutter widgets for rendering [Form.io](https://form.io) forms.

As of **3.0.0**, form logic is delegated to Form.io's own **`@formio/core`**
running headless via [`flutter_js`](https://pub.dev/packages/flutter_js) — so
conditionals, calculations, Logic-tab actions, and validation (including custom
JavaScript) behave exactly like Form.io, without a WebView.

> Upgrading from 2.x? The old `FormRenderer` is replaced by `EngineFormRenderer`.
> See the [CHANGELOG](CHANGELOG.md) for the full list of breaking changes.

## How it works

```
Form JSON ─► EngineFormRenderer ──(on every change)──► FormLogicEngine
                    ▲                                   (@formio/core in flutter_js)
                    └────────── { data, hidden, errors } ◄──┘
```

`EngineFormRenderer` owns the nested submission and, on every change, hands the
form + data to the engine and repaints from the result. It renders basic inputs
and layout natively; premium/less-common types fall back to `ComponentFactory`.

## Install

```yaml
dependencies:
  formio: ^3.0.0
```

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:formio/formio.dart';

late final FormLogicEngine engine;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  engine = FormLogicEngine();
  await engine.init(); // loads the @formio/core bundle once
  runApp(const MyApp());
}

class FormPage extends StatelessWidget {
  const FormPage({super.key, required this.form});
  final Map<String, dynamic> form; // parsed Form.io JSON (a `components` tree)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EngineFormRenderer(
        form: form,
        engine: engine,
        onSubmit: (data) => debugPrint('Submitted: $data'),
        onChanged: (data) {/* live data */},
      ),
    );
  }
}
```

`form` is the parsed Form.io definition. If your export wraps it (e.g. Creatio's
`{"template": "<stringified JSON>"}`), unwrap and `jsonDecode` it first.

## Custom components

Domain-specific widgets (file pickers, maps, signature pads…) live in **your**
app and register on the renderer. The same mechanism overrides built-ins.

```dart
EngineFormRenderer(
  form: form,
  engine: engine,
  customComponents: {
    'fmsfile': (ctx) => MyFileField(ctx),      // a brand-new type
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
    return ctx.chrome(Column(children: [       // optional standard label/error
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
`theme`.

## Theming

```dart
EngineFormRenderer(
  form: form,
  engine: engine,
  theme: const FormioTheme(
    labelStyle: TextStyle(fontWeight: FontWeight.w600),
    inputBorder: OutlineInputBorder(),
    requiredSuffix: ' *',
  ),
);
```

Every token defaults to the ambient Material theme, so `FormioTheme()` keeps the
stock look.

## Right-to-left

```dart
EngineFormRenderer(form: form, engine: engine, textDirection: TextDirection.rtl);
```

`null` (default) inherits the ambient `Directionality`.

## Localized errors

Validation error text resolves through `ComponentFactory.locale`:

```dart
ComponentFactory.setLocale(const MyArabicLocalizations());
```

Custom-validation messages (authored in the form) are shown as-is.

## The engine bundle

The `@formio/core` bundle ships as a package asset. To rebuild it (after
changing `tools/formio-core/entry.js`):

```bash
cd tools/formio-core
npm ci
npm run build   # → packages/flutter_formio/assets/formio/fms-formio-core.bundle.js
npm test        # engine regression tests
```

## License

MIT
