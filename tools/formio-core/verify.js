require('./entry.js');
const fs = require('fs');
const path = '/Users/hasanalqaisi/Documents/dev/flutter_projects/fms_flutter/form-samples/form1.json';
const raw = JSON.parse(fs.readFileSync(path, 'utf8'));
const form = JSON.parse(raw.template);

function run(label, data) {
  const out = JSON.parse(globalThis.fmsProcess(JSON.stringify({ form, submission: { data } })));
  if (out.error) { console.log(`\n[${label}] ENGINE ERROR:\n`, out.error.split('\n').slice(0,4).join('\n')); return; }
  console.log(`\n=== ${label} ===`);
  console.log('  errors:', out.errors.length, out.errors.slice(0,6).map(e=>`${e.path}: ${e.message}`));
  const cond = out.conditionals || {};
  const hidden = Object.entries(cond).filter(([k,v])=>v && v.conditionallyHidden===true || v===true).map(([k])=>k);
  console.log('  conditionals keys:', Object.keys(cond).length);
  // show a few calculated data keys
  const keys = Object.keys(out.data);
  console.log('  data keys count:', keys.length, '| sample:', keys.slice(0,10));
  if (out.data.Number) console.log('  calculated Number (crypto):', out.data.Number);
}

run('empty data', {});
run('civil work = yes (should reveal note conditional)', { Civil_Work: { yes: true } });
