# Form.io Native Demo

A minimal example that renders real [Form.io](https://form.io) forms **natively
in Flutter**, with all logic — calculations, conditionals, Logic-tab actions,
and validation (including custom JavaScript) — driven by the real `@formio/core`
engine running headless via `FormLogicEngine`.

## Run

```bash
flutter pub get
flutter run
```

Pick one of the bundled sample forms from the dropdown and tap **Open form**.
The form renders natively; edits recompute through the engine, hidden fields
disappear, validation runs live, and a valid submission is printed to the
console.

## What it shows

| File | Purpose |
| ---- | ------- |
| `lib/main.dart` | App entry — loads a form from assets and renders it with `EngineFormRenderer`. |
| `lib/custom_components.dart` | Host-provided custom components (`fmsfile`, `location`, `sites`) demonstrating the `customComponents` extension API — domain widgets live in the app, not the package. |
| `assets/form-samples/` | Sample Form.io definitions (add your own `.json` here). |

## Key ideas

- **`EngineFormRenderer(form:, engine:, customComponents:, onSubmit:)`** is the
  whole integration surface.
- **`FormLogicEngine`** wraps `@formio/core`; call `init()` once, then hand it to
  the renderer.
- **Custom components** are registered by the host app via a
  `{ type: builder }` map — the package ships the *ability*, you provide the
  widgets. The same mechanism overrides or re-skins any built-in field.
- Creatio forms wrapped as `{ "template": "<stringified JSON>" }` are unwrapped
  on load (see `main.dart`).

> The sample forms in `assets/form-samples/` are gitignored — drop your own
> Form.io JSON there to try it.
