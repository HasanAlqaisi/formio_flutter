// Regression tests for the built @formio/core engine bundle.
//
// Runs the SHIPPED bundle (packages/flutter_formio/assets/…) against small,
// self-contained synthetic forms — no domain samples, so this is CI-safe and
// deterministic. Each test guards a behavior the Flutter renderer depends on;
// several encode bugs we actually hit (conditionally-hidden panels keyed by
// `key`, nested field paths, form-caching parity).
//
//   node --test           (from tools/formio-core)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import vm from 'node:vm';

// ---- load the shipped bundle into an isolated context -----------------------
const HERE = dirname(fileURLToPath(import.meta.url));
const BUNDLE = join(HERE, '../../../packages/flutter_formio/assets/formio/fms-formio-core.bundle.js');
const ctx = { console };
ctx.globalThis = ctx;
vm.createContext(ctx);
vm.runInContext(readFileSync(BUNDLE, 'utf8') + '\nglobalThis.__FMS = FMS;', ctx);
const FMS = ctx.__FMS;

/** Set the form then process data through the cached path (validation on by default). */
function run(form, data = {}, validate = true) {
  const set = JSON.parse(FMS.fmsSetForm(JSON.stringify(form)));
  assert.equal(set.error, undefined, `fmsSetForm error: ${set.error}`);
  const res = JSON.parse(FMS.fmsProcessData(JSON.stringify(data), validate));
  assert.equal(res.error, undefined, `fmsProcessData error: ${res.error}`);
  return res;
}

const field = (key, extra = {}) => ({ type: 'textfield', key, input: true, ...extra });
const num = (key, extra = {}) => ({ type: 'number', key, input: true, ...extra });

// ---- exports API ------------------------------------------------------------
test('bundle exposes the expected globals', () => {
  assert.deepEqual(
    Object.keys(FMS).sort(),
    ['fmsProcess', 'fmsProcessData', 'fmsSetForm'],
  );
});

// ---- conditional hiding (the class of bug we fixed) -------------------------
test('conditionally-hidden panel is reported in the hidden map by its key', () => {
  const form = {
    display: 'form',
    components: [
      { type: 'selectboxes', key: 'materials', input: true, data: { values: [{ label: 'Wood', value: 'wood' }] } },
      {
        type: 'panel', key: 'woodPanel', title: 'Wood',
        conditional: { show: true, when: 'materials', eq: 'wood' },
        components: [field('woodQty')],
      },
    ],
  };
  // No materials selected → panel hidden, keyed by the panel's own key.
  assert.equal(run(form, {}).hidden.woodPanel, true);
  // Wood selected → panel shown (absent from the hidden map).
  assert.equal(run(form, { materials: { wood: true } }).hidden.woodPanel, undefined);
});

test('nested field is hidden by its full data path', () => {
  const form = {
    display: 'form',
    components: [
      field('toggle'),
      {
        type: 'container', key: 'box', input: true,
        components: [field('inner', { conditional: { show: true, when: 'toggle', eq: 'go' } })],
      },
    ],
  };
  assert.equal(run(form, {}).hidden['box.inner'], true);
  assert.equal(run(form, { toggle: 'go' }).hidden['box.inner'], undefined);
});

test('clearHidden wipes the value of a hidden field', () => {
  const form = {
    display: 'form',
    components: [
      { type: 'selectboxes', key: 'materials', input: true, data: { values: [{ label: 'Wood', value: 'wood' }] } },
      {
        type: 'panel', key: 'woodPanel',
        conditional: { show: true, when: 'materials', eq: 'wood' },
        components: [field('woodQty', { clearOnHide: true })],
      },
    ],
  };
  // Value present but panel hidden → engine clears it.
  const res = run(form, { woodQty: 'x' });
  assert.ok(res.data.woodQty === undefined || res.data.woodQty === '');
});

// ---- calculations & custom JS (fidelity the Dart port couldn't match) -------
test('calculateValue computes from sibling data', () => {
  const form = { display: 'form', components: [num('a'), num('b'), num('total', { calculateValue: 'value = data.a + data.b' })] };
  assert.equal(run(form, { a: 2, b: 3 }).data.total, 5);
});

test('custom JavaScript validation runs with the real eval context', () => {
  const form = {
    display: 'form',
    components: [field('x', { validate: { custom: "valid = (input === 'ok') ? true : 'must be ok'" } })],
  };
  const bad = run(form, { x: 'no' }).errors;
  assert.equal(bad.length, 1);
  assert.equal(bad[0].path, 'x');
  assert.equal(bad[0].rule, 'custom');
  assert.equal(run(form, { x: 'ok' }).errors.length, 0);
});

test('limit validators report their setting for specific messages', () => {
  const form = {
    display: 'form',
    components: [
      field('a', { validate: { maxLength: 5 } }),
      num('n', { validate: { min: 10 } }),
    ],
  };
  const errs = run(form, { a: 'toolong', n: 3 }).errors;
  const byRule = Object.fromEntries(errs.map((e) => [e.rule, e]));
  assert.equal(byRule.maxLength.setting, '5');
  assert.equal(byRule.min.setting, '10');
});

// ---- validation toggle (live-by-default; opt-in skip) -----------------------
test('required validation runs by default and is skippable', () => {
  const form = { display: 'form', components: [field('r', { validate: { required: true } })] };
  assert.equal(run(form, {}, true).errors.length, 1);   // live validation (default)
  assert.equal(run(form, {}, false).errors.length, 0);  // draft fast-pass
});

// ---- data shape round-trips -------------------------------------------------
test('datagrid rows round-trip (added rows persist)', () => {
  const form = { display: 'form', components: [{ type: 'datagrid', key: 'grid', input: true, components: [field('name')] }] };
  assert.equal(run(form, { grid: [{ name: 'a' }, { name: 'b' }] }).data.grid.length, 2);
});

// ---- 2a: cached-form path is identical to the one-shot path ------------------
test('fmsProcessData (cached form) === fmsProcess (one-shot payload)', () => {
  const form = {
    display: 'form',
    components: [
      field('toggle'),
      { type: 'container', key: 'box', input: true, components: [field('inner', { conditional: { show: true, when: 'toggle', eq: 'go' } })] },
      num('a'), num('b'), num('total', { calculateValue: 'value = data.a + data.b' }),
    ],
  };
  const data = { toggle: 'go', a: 4, b: 6 };
  FMS.fmsSetForm(JSON.stringify(form));
  const cached = FMS.fmsProcessData(JSON.stringify(data), true);
  const oneShot = FMS.fmsProcess(JSON.stringify({ form, submission: { data } }));
  assert.equal(cached, oneShot);
});
