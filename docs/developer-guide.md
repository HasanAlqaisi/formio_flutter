# Developer Guide — flutter_formio

> **Audience:** engineers working on this package. Read this end-to-end once; it
> explains the architecture, the non-obvious bits, how to extend it, and the
> technical approach for the work that's still open. For the high-level status /
> risks / plan (PM view), see the companion [Status, Risks & Plan](engine-migration-report.md).

---

## 1. Mental model (read this first)

The package renders [Form.io](https://form.io) forms in Flutter. The one idea
that explains everything else:

> **We do not re-implement Form.io logic. We run Form.io's own logic engine
> (`@formio/core`) headless, and Flutter only draws widgets.**

A Form.io form is a JSON tree of components. Each component can carry logic:
conditionals (show/hide), calculations, Logic-tab actions, and validation —
often as **custom JavaScript**. Re-implementing all of that in Dart drifts from
the real Form.io on every release (our production forms use ~1,225 such hooks).
So instead:

```
        edit ▲                              │ recompute
             │                              ▼
   ┌─────────────────────┐   data   ┌──────────────────────────┐
   │  EngineFormRenderer  │ ───────► │  FormLogicEngine          │
   │  (Flutter widgets)   │          │  (@formio/core in         │
   │                      │ ◄─────── │   flutter_js / QuickJS)   │
   └─────────────────────┘  {data,   └──────────────────────────┘
                             hidden,
                             errors}
```

On every change, the renderer sends the submission data to the engine and gets
back `{ data, hidden, errors }`, then repaints. Behavior matches the Form.io web
renderer **by construction**, with no WebView.

---

## 2. Repository layout

```
packages/flutter_formio/      # the published package (pub name: `formio`)
  lib/formio.dart             # public barrel (exports)
  lib/src/core/               # engine, JS evaluator, interpolation
  lib/src/models/             # Form.io models, localizations
  lib/src/widgets/            # renderer, theme, extension-point contexts
    engine_form_renderer.dart # the stateful host + type dispatch
    component_builders.dart   # barrel over builders/ (renderer imports it as `cb`)
    builders/                 # the per-type builders, split by concern
    control_builders.dart     # host hooks for the *look* of a built-in control
    components/               # richer/stock widgets + premium fallbacks
  lib/src/network|services/   # Form.io REST client (merged from old formio_api)
  assets/formio/formio-core.bundle.js   # the built engine (a shipped asset)
  test/                       # Dart widget + unit tests

tools/formio-core/            # engine bundle SOURCE
  entry.js                    # what gets bundled (the JS bridge)
  test/engine.test.mjs        # engine regression tests (run the shipped bundle)
  package.json                # esbuild build script

example/                      # runnable demo app (flutter run)
docs/                         # this guide + the PM report + authoring guidelines
.github/workflows/ci.yml      # engine tests + bundle-drift guard + flutter analyze/test
```

Historical note: there used to be a second package `formio_api` (pure Dart). It
was merged into `formio` in 3.0 — the split existed to keep logic in pure Dart,
which the engine made moot. Everything imports from `package:formio/formio.dart`.

---

## 3. The engine bundle (`tools/formio-core`)

`entry.js` is bundled by esbuild into a single self-contained file shipped as a
Flutter asset. It exposes three globals on `globalThis`:

| Global | Purpose |
|--------|---------|
| `fioSetForm(formJson)` | Parse + DOM-strip + **cache** the form once. |
| `fioProcessData(dataJson, validate)` | Run the pipeline against the cached form; only the (small) submission crosses the FFI boundary. |
| `fioProcess(payloadJson)` | Legacy one-shot `{form, submission}` — re-parses the form each call. Kept for A/B testing. |

**Output contract** — every call returns `{ data, hidden, errors }`:
- `data` — the recomputed nested submission (defaults + calculations applied).
- `hidden` — a merged map: `scope.conditionals` (simple/JSONLogic) **plus** a
  post-process tree-walk for `component.hidden` (static `hidden:true` +
  Logic-tab `property(hidden)` actions, which are *not* in `scope.conditionals`).
  ⚠️ **Input components are keyed by data path; layout components by `key`.**
- `errors[]` — `{ path, key, rule, messageKey, level, setting }`. `setting` is the
  rule's limit (e.g. `maxLength` → `"5"`), used to build specific messages.

**Headless survival tactics** baked into `entry.js`:
- **Processor list** — `FULL = [defaultValue].concat(evaluator)`; `LIVE = FULL`
  minus `validate`. `defaultValue` is prepended so nested containers initialize.
- **Polyfills** — QuickJS lacks `crypto.getRandomValues`; we shim it.
- **DOM-script stripping** — scripts referencing `window`/`document`/`fetch`/
  `setInterval`/… can't run headless, so they're blanked (`DOM_RE`) before
  processing. See §11 for what this means and how to restore lost behavior.

**Build & verify:**

```bash
cd tools/formio-core
npm ci
npm run build   # → packages/flutter_formio/assets/formio/formio-core.bundle.js
npm test        # engine regression tests against the SHIPPED bundle
```

The committed bundle **must** equal a fresh build — CI's *bundle-drift guard*
rebuilds and fails on any diff. So: edit `entry.js` → `npm run build` → commit the
regenerated bundle. Never hand-edit the bundle.

---

## 4. The Dart engine (`lib/src/core/form_logic_engine.dart`)

`FormLogicEngine` wraps the bundle running in `flutter_js`:

- `init()` — load the runtime + evaluate the bundle once (call at startup).
- `setForm(form)` — cache the form JS-side. Call when the form loads/changes.
- `processData(data, {validate = true})` — run the pipeline against the cached
  form; returns a `FormLogicResult`. **Synchronous** (flutter_js is FFI on the
  platform thread) — the renderer debounces it.
- `process({form, submission})` — legacy one-shot convenience.

It implements the **`FormEngine`** interface (`setForm` + `processData`). The
renderer depends only on that interface, so you can drop in a fake in tests or an
isolate-hosted engine later without touching the widget.

**The double-encode marshalling gotcha:** data is JSON-encoded *twice* so it
survives as a JS string literal inside `runtime.evaluate('… = "<json>";')`:

```dart
runtime.evaluate('globalThis.__fioData = ${jsonEncode(jsonEncode(data))};');
```

Result types: `FormLogicResult { data, hidden, errors, isValid, isHidden(path) }`
and `FormLogicError { path, key, rule, messageKey, level, setting }`.

---

## 5. The renderer (`lib/src/widgets/engine_form_renderer.dart`)

`EngineFormRenderer` is the stateful host. It owns:

- **`_data`** — the nested submission (`a.b[0].c` path-addressed; see `_getPath`/
  `_setPath`, which parse indices via a regex).
- **the engine loop** — `_recompute()` → `_ensureFormSet()` → `engine.processData`
  → `setState` with `{data, hidden, errors}`.
- **debounce** — text edits schedule a 450 ms recompute; discrete taps
  (dropdowns, chips, checkboxes) recompute **immediately** (`setValue(...,
  immediate: true)`).
- **validation gating** — errors show only after submit or once a field is
  `_touched` (blur), so users aren't yelled at while typing.
- **submit** — the renderer draws its own Submit button; on tap it validates and
  calls `onSubmit(data)`.

### Constructor parameters

| Param | Meaning |
|-------|---------|
| `form` | Parsed Form.io definition. |
| `engine` | An initialized `FormEngine`. |
| `initialData` | Seed submission. |
| `onSubmit` / `onChanged` | Submit / live-data callbacks. |
| `customComponents` | `{type: builder}` — custom types & overrides (replaces a component outright). |
| `controls` | `FormioControlBuilders` — host widget for a built-in control, behaviour kept (§7b). |
| `resourceSource` | `FormioResourceSource` — project URL + headers for `dataSrc: "resource"` (§7c). |
| `theme` | `FormioTheme` design tokens. |
| `textDirection` | RTL/LTR (defaults to ambient `Directionality`). |
| `debounce` | Text recompute delay (default 450 ms). |

### Dispatch order (`_render`)

For each component, in order:

1. **Hidden guard** — if the engine marked it hidden (`_hidden[path]` for inputs,
   `_hidden[key]` for layout), render `SizedBox.shrink()`. *Getting the
   input-vs-layout keying wrong is how conditionally-hidden panels used to render
   as dead shells — see §11.*
2. **Custom component** — if `customComponents[type]` exists, use it (wins over
   everything below).
3. **Layout switch** — `columns`, `table`, `panel`/`well`/`fieldset`, `tabs`,
   `button` (rendered as nothing — see §11).
4. **Nesting types** — `container`, `creatioContainer` recurse.
5. **`_renderControl`** — the actual input: `select`/`resource` (Form.io's
   `resource` *is* a select whose options come from one)/`selectboxes`/`checkbox`/
   `radio`/`date`/`datetime`/`time`, text-like types (`kTextTypes`), array types
   (`datagrid`/`editgrid`), else **`buildFallback` → `ComponentFactory`**.

`_dataTypes` (the set above) default to `input: true` when the schema omits the
flag — Form.io keeps it in each component class's own `defaultSchema`, so a
hand-written or partial schema still describes a data component. Without the
default such a field rendered bound to an empty path and the first edit had
nowhere to write.

Everything in steps 3–5 is wrapped in `_guarded(...)` — a per-component **error
boundary** that degrades a throwing component to a placeholder card instead of
crashing the whole form.

### Responsive layout

`columns` and `table` (`lib/src/widgets/engine_form_renderer.dart`) use
`LayoutBuilder`: below `theme.columnBreakpoint` px per column they **stack
vertically**; above it they lay out side-by-side (columns flow in a `Wrap` by
their 12-unit Bootstrap grid width). This is why forms are readable on phones.

---

## 6. Builders, components, theming

- **`component_builders.dart`** — a **barrel** over `builders/`; the renderer
  imports it as `cb` and the tests target it, so the split stayed invisible:
  | File | Holds |
  |------|-------|
  | `builders/field_chrome.dart` | `buildField` — label (incl. `labelPosition`), description, inline error |
  | `builders/text_leaf.dart` | `kTextTypes`, keyboard mapping, `inputMask`, prefix/suffix addons, numeric formatting |
  | `builders/select_controls.dart` | `select`/`selectboxes`/`radio`/`checkbox`, option resolution |
  | `builders/date_controls.dart` | `date`/`datetime`/`time`, platform pickers, schema `format` |
  | `builders/data_grid.dart` | `datagrid`/`editgrid`, reorderable rows |
  | `builders/error_messages.dart` | `messageForError` — engine `rule` + `setting` → localized string |
  | `builders/fallback.dart` | `buildFallback` → `ComponentFactory` |
  | `builders/schema_text.dart` | reading label/placeholder/affix text off the schema |
- **`components/`** — richer/stock widgets: the select pickers
  (`SelectPickerField`, `MultiSelectField` — searchable, used for long/`multiple`
  option lists), `select_options.dart` / `remote_select_options.dart` (option
  resolution incl. remote sources, §7c), `DayComponent`, `input_mask.dart`,
  `numeric_format.dart`, `TabsSection` (swipeable tab bar), plus the
  premium-fallback set (`address`, `signature`, `file`, `survey`, …) reached via
  `ComponentFactory`.
- **`ComponentFactory`** — the fallback + host-registration mechanism for
  premium/less-common types and the global locale (`ComponentFactory.setLocale`).
- **`FormioTheme`** (`form_theme.dart`) — design tokens (label/description/error/
  panel-title/affix/input/hint text styles, input fill + normal/focused/error
  borders, `inputContentPadding`, `isDense`, `fieldPadding`, `sectionMargin`,
  `sectionPadding`, `sectionDecoration`, `requiredSuffix`, `requiredSuffixColor`,
  `columnBreakpoint`,
  `submitButtonStyle`, `accentColor`). Every token defaults to the ambient
  Material theme. `FormioThemeScope.of(context)` reads the active tokens from any
  widget below the renderer — that's how the stock `components/` widgets style
  themselves without being passed the theme.
- **Localization** (`models/formio_localizations*.dart`) — the string interface,
  the English default, and a built-in `ArabicFormioLocalizations`. Validation
  messages resolve through the active locale, including limit-aware ones
  (`getMinLengthMessage`, `getMaxValueMessage`, …).

---

## 7. Extension API — the seam for host code

Custom/overridden components live in the **host app**, not the package. Register
them on the renderer:

```dart
EngineFormRenderer(
  form: form, engine: engine,
  customComponents: {
    'geopoint': (ctx) => MyMapField(ctx),        // brand-new type
    'sites':    (ctx) => ctx.builtin('select'),  // reuse a built-in
    'select':   (ctx) => MyBrandedSelect(ctx),   // override a built-in
  },
);
```

Each builder receives a **`FormioFieldContext`** (`form_field_context.dart`),
a curated surface over the renderer's internals:

| Member | Use |
|--------|-----|
| `value` / `setValue(v, {immediate})` | Read/write this field. `setValue` triggers a recompute. |
| `read(path)` | Read any other field by absolute path. |
| `error` | This field's current validation error (already gated). |
| `controller()` / `focusNode()` | Persistent text controller / focus node. |
| `child(raw)` | Render a nested component definition. |
| `builtin(type)` | Delegate to a built-in builder (e.g. treat `sites` as a `select`). |
| `chrome(widget, {showLabel})` | Wrap your widget in the standard label/description/error chrome. |
| `theme` / `component` / `path` | Active tokens / this component's raw JSON / its data path. |

Internally, `FormioFieldContext` is built from `FieldScope` (`form_field_scope.dart`),
the private wiring to the renderer's state.

### Adding a new component (recipe)
1. In the host app, write a widget that takes a `FormioFieldContext`.
2. Register it: `customComponents: {'yourType': (ctx) => YourWidget(ctx)}`.
3. Read with `ctx.value` / `ctx.read`, write with `ctx.setValue` (use
   `immediate: true` for discrete changes), wrap with `ctx.chrome(...)` if you
   want the standard label/error.

To change a **built-in** type globally instead, override its key (`'select'`,
`'textfield'`, …) the same way — but for a control whose schema handling is
non-trivial, prefer §7b.

### 7b. Control builders — the *look* only (`control_builders.dart`)

`customComponents['select']` replaces the component outright, schema handling
included: the host then has to reimplement `dataSrc`, `valueProperty`,
`template`, remote loading and value coercion, and a host that only wanted its
own dropdown silently loses all of it. `EngineFormRenderer.controls` is the
narrower seam — the package resolves the schema and hands over the result:

```dart
controls: FormioControlBuilders(
  select: (context, spec) => spec.multiple
      ? FormioBuiltInSelect(spec: spec)   // delegate what you don't style
      : MyDropdown(
          options: spec.options,          // resolved, typed values
          value: spec.selected?.value,
          loading: spec.loading,
          onChanged: spec.onChanged,
        ),
),
```

`FormioSelectSpec` carries `component` / `options` / `value` / `selected` /
`selectedMany` / `onChanged` / `label` / `placeholder` / `enabled` / `multiple` /
`required` / `searchable` / `loading` / `error` / `ensureOptions`. Notes worth
knowing before you write one:

- **`searchable`** is the schema's `searchEnabled`, not an option-count heuristic
  — the sample forms set it on all 333 selects and 17 turn it *off* on long lists.
- **`selected` / `selectedMany`** keep a stored value that has no matching option
  as a bare label rather than dropping it: a saved answer that outlived a change
  to its option source is data.
- **`ensureOptions`** is non-null only for a `lazyLoad` remote source, and
  `options` is empty until it runs. It *resolves with* the options (rather than
  just triggering a fetch) because a control that opens a picker on its own route
  can't receive them afterwards. It's idempotent and safe to call from `build`.
- `FormioBuiltInSelect(spec: spec)` is the package's own select, so you can style
  one case and delegate the rest.

`FormioControlBuilders` currently hooks `select` only; add fields here (spec +
builder + a renderer call site) when another control needs the same treatment.

### 7c. Remote option sources

The engine never fetches — Form.io's `fetchProcessInfo` runs only in the
server-side `submission` target — so option loading is the renderer's job
(`components/remote_select_options.dart`):

- **`dataSrc: "url"`** — requests `data.url` (interpolated), caches the response
  per resolved URL so two components sharing a source fetch once and a rebuild
  doesn't re-request, and exposes `loading` / `error` on the spec.
- **`dataSrc: "resource"`** and the **`resource`** component type — the schema
  carries only a form id (`data.resource`), so the project is deployment config:
  the host passes `resourceSource: FormioResourceSource(projectUrl:, headers:)`.
  With none, the component reports a data-source error instead of an empty list
  that would never fill. The component's own `limit` is passed through — the
  endpoint's default page size is small and omitting it truncates the options.

---

## 8. Testing & CI

- **Dart** (`packages/flutter_formio/test`): renderer/widget tests driven by the
  shared `test/support/fake_engine.dart` (a `FormEngine` you script) and
  `test/support/pump_form.dart`; per-component tests in `test/components/`
  (masks, label position, datagrid reorder, remote/resource selects, day/time,
  …); message-mapping tests. Run: `flutter test`. Analyze: `flutter analyze lib test`.
- **Engine** (`tools/formio-core/test/*.test.mjs`): loads the **shipped**
  bundle and asserts behaviors the renderer depends on (hidden-by-key, nested
  paths, clearHidden, calculations, custom JS validation, limit `setting`,
  validate toggle, cache parity). Run: `npm test`.
- **CI** (`.github/workflows/ci.yml`): (1) engine job — `npm ci` → `npm test` →
  `npm run build` → **bundle-drift guard** (`git diff --quiet` on the rebuilt
  bundle); (2) flutter job — `pub get` → `analyze` → `test`.

When you change `entry.js`, always rebuild + commit the bundle or CI fails.

---

## 9. Local dev workflow

```bash
# Engine change:
cd tools/formio-core && npm run build && npm test

# Flutter change:
cd packages/flutter_formio && flutter analyze lib test && flutter test

# Try it end-to-end:
cd example && flutter pub get && flutter run
```

Creatio forms arrive wrapped as `{"template": "<stringified JSON>"}` — unwrap and
`jsonDecode` before handing to the renderer (see `example/lib/main.dart`).

---

## 10. Non-obvious things (gotchas)

- **Double-encode** submission data before `evaluate` (see §4) or the JS parse fails.
- **Hidden-map keying**: inputs by path, layout by key. Wrong choice → dead
  hidden panels or leaked hidden inputs.
- **Buttons are suppressed**: `case 'button': SizedBox.shrink()`. Submit is the
  renderer's job. Override `'button'` to render one (see §12b).
- **`00/00/0000` day value**: Form.io's "no date"; `DayComponent` maps non-positive
  parts to null (else the `DropdownButton` asserts on a value not in its items).
- **Multi-select**: `multiple: true` selects render as `MultiSelectField` (a
  searchable dropdown), not inline chips — required for 90+ option lists.
- **The engine never fetches**: url/resource select options are loaded by the
  renderer, not `@formio/core` (§7c). A missing `resourceSource` shows a
  data-source error, not an empty dropdown.
- **`input: true` is optional in schema**: Form.io keeps it in each class's
  `defaultSchema`, so `_dataTypes` default it on — see §5.
- **`immediate` vs debounced**: discrete changes pass `immediate: true`; text
  input is debounced. Get this wrong and taps feel laggy or text thrashes.
- **DOM-script stripping** silently blanks browser-only scripts — see §11/§12a.

---

## 11. The browser-only script problem (context for §12a)

Some production forms embed **browser** programs in `calculateValue` /
`customConditional` / `validate.custom`. `entry.js` blanks any script mentioning
`window`/`document`/`fetch`/`setInterval`/… so they don't crash the headless
engine. Across the 10 sample forms there are 38 such occurrences, but only **3
distinct scripts**:

1. **`FMS-xxxx` reference-ID generator** (most occurrences) — actually
   engine-safe; it uses `globalThis.crypto` (which we polyfill) and only *mentions*
   `window` in an unused fallback, so the filter over-strips it. *Fix: authors
   should drop the `window`/`self` fallbacks (see the
   [Form Authoring Guidelines](form-authoring-guidelines.md)); then it runs
   headless.*
2. **A panel's `show = window.location.href.includes('/task/')`** — a
   URL-based visibility gate. Headless there's no URL, so the panel never shows.
   *Fix: drive visibility from form data instead of the URL.*
3. **A live GPS "mileage" widget** — the only real feature. It reads a task id
   from the URL/session, `fetch`es task/timeline endpoints, computes travel
   distance, paints DOM, and polls every 30 s. It never sets a form value
   (`value = ''`). *Fix: reimplement as a native component (see §12a).*

Rule of thumb, enforced by the [Form Authoring Guidelines](form-authoring-guidelines.md): pure value
logic belongs in a form script; anything touching the network, DOM, storage,
timers, or the URL belongs in a **component**.

---

## 12. Technical approach for the remaining work

### 12a. Browser-only widgets → native components (High)

**Goal:** restore the behavior of the 3 scripts above without running browser JS.

**Approach:**
- **ID generator**: no code needed — advise authors to write it engine-safe
  (`globalThis.crypto`, no `window`). Optionally relax `DOM_RE` so a script that
  only *mentions* `window` in a `typeof window !== 'undefined'` guard isn't
  stripped. Add an engine test if we relax the regex.
- **Panel visibility**: author change — replace the URL check with a data
  condition. No package change.
- **Mileage widget**: implement as a host `customComponents` entry, e.g.
  `'mileageWidget'`. Design:
  - A `StatefulWidget` that takes `FormioFieldContext`.
  - `initState` → fetch via the app's real API client (the `dio`-based services in
    `lib/src/network|services`, or the host's own); `Timer.periodic` for the 30 s
    refresh; **cancel it in `dispose`**.
  - Read context (task id, etc.) from **form data** via `ctx.read('...')`, not a
    URL. Compute distance (haversine) in Dart.
  - Render a card; it's display-only, so it does not call `setValue`.
  - The form JSON becomes a clean marker: `{ "type": "mileageWidget", "input": false }`.
- **Deliverable also includes** documenting, per form, which scripts were dropped
  and whether each is restored or intentionally omitted.

**Why native, not "run the JS":** these scripts need network + a session + a real
UI; that's a component's job, and it's testable (mock the API, pump the widget).

### 12b. Embedded button actions (Medium)

**Problem:** form `button` components are suppressed; a custom builder can render
one, but `FormioFieldContext` currently can't *trigger* the form (submit/reset) —
only read/write data.

**Approach:** add `submit()` and `reset()` to `FormioFieldContext`, threaded from
the renderer:
- `EngineFormRenderer` already has `_submit()`. Add a `_reset()` (clear `_data` →
  recompute).
- Pass both into `FieldScope` and expose them on `FormioFieldContext`.
- Then a host can do:
  ```dart
  customComponents: {
    'button': (ctx) {
      switch (ctx.component['action']) {
        case 'submit': return ElevatedButton(onPressed: ctx.submit, child: Text(...));
        case 'reset':  return OutlinedButton(onPressed: ctx.reset,  child: Text(...));
        default:       return /* custom action using ctx.read/ctx.setValue */;
      }
    },
  }
  ```
- Data-only actions already work today via `ctx.setValue` (triggers a recompute).
  Only the submit/reset hook is missing.
- Add a widget test: a custom button calls `ctx.submit` → `onSubmit` fires.

### 12c. Background-thread engine (On demand — only if a form lags)

`processData` is synchronous FFI; on the current forms it's fast (form caching
means only the small submission crosses per edit). If a much heavier form ever
janks the UI, implement `FormEngine` on a background isolate. Because the renderer
depends only on the `FormEngine` interface, **no widget code changes** — you swap
the implementation and make the call sites `await`. Do this only with a profile
showing real jank; it adds async complexity otherwise.

---

## 13. Where to look first (quick index)

| I want to… | Go to |
|------------|-------|
| Understand the loop | `engine_form_renderer.dart` → `_render` / `_recompute` |
| Change engine logic | `tools/formio-core/entry.js` (then rebuild) |
| Add/skin a component | host `customComponents` + `FormioFieldContext` (§7) |
| Restyle a built-in control | `controls` + `FormioSelectSpec` (§7b) |
| Fix remote/resource options | `components/remote_select_options.dart`, `select_options.dart` (§7c) |
| Change validation text | `builders/error_messages.dart` `messageForError` + localizations |
| Change responsive behavior | `columns`/`table` cases + `FormioTheme.columnBreakpoint` |
| Add a regression test | `test/*_test.dart` (Dart) or `tools/formio-core/test/engine.test.mjs` (engine) |
