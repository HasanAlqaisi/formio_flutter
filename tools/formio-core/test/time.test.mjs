// What the engine accepts as a `time` component's value.
//
// `validateTime` strict-parses the stored value against the component's
// `dataFormat` (default `HH:mm:ss`), so a full timestamp fails even though it
// carries the same instant. The Flutter time control stores a bare time of day
// because of this; these tests pin the rule it has to satisfy.
//
//   node --test           (from tools/formio-core)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import vm from 'node:vm';

const HERE = dirname(fileURLToPath(import.meta.url));
const BUNDLE = join(HERE, '../../../packages/flutter_formio/assets/formio/formio-core.bundle.js');
const ctx = { console };
ctx.globalThis = ctx;
vm.createContext(ctx);
vm.runInContext(readFileSync(BUNDLE, 'utf8') + '\nglobalThis.__FormioCore = FormioCore;', ctx);
const FIO = ctx.__FormioCore;

/** Validation errors for `when` after storing `value` on a time component. */
function errorsFor(value, extra = {}) {
  const form = {
    display: 'form',
    components: [
      {
        type: 'time',
        key: 'when',
        input: true,
        label: 'When',
        format: 'HH:mm',
        ...extra,
      },
    ],
  };
  const set = JSON.parse(FIO.fioSetForm(JSON.stringify(form)));
  assert.equal(set.error, undefined, `fioSetForm error: ${set.error}`);
  const res = JSON.parse(FIO.fioProcessData(JSON.stringify({ when: value }), true));
  assert.equal(res.error, undefined, `fioProcessData error: ${res.error}`);
  return res.errors;
}

const rules = (value, extra) => errorsFor(value, extra).map((e) => e.rule);

test('a bare time of day validates', () => {
  assert.deepEqual(rules('15:56:00'), []);
});

test('a timestamp does not validate', () => {
  // The shape `DateTime.toIso8601String()` produces.
  assert.deepEqual(rules('2026-08-06T15:56:00.000'), ['time']);
});

test('a time missing its seconds does not validate against the default', () => {
  assert.deepEqual(rules('15:56'), ['time']);
});

test('an authored dataFormat decides what validates', () => {
  assert.deepEqual(rules('15:56', { dataFormat: 'HH:mm' }), []);
  assert.deepEqual(rules('15:56:00', { dataFormat: 'HH:mm' }), ['time']);
});

test('an empty value is left to the required rule', () => {
  assert.deepEqual(rules(''), []);
  assert.deepEqual(rules('', { validate: { required: true } }), ['required']);
});
