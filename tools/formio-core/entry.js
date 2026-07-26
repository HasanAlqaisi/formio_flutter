// Headless Form.io logic engine for flutter_js (QuickJS/JavaScriptCore).
//
// Exposes:
//   globalThis.fmsSetForm(formJson)               -> {ok} | {error}
//     Parses + strips the form ONCE and caches it. Call on form load.
//   globalThis.fmsProcessData(dataJson, validate) -> resultJson
//     Runs the pipeline against the cached form; only the (small) submission
//     data crosses the Dart<->JS boundary. `validate=false` skips the validate
//     processor (live/keystroke pass); blur/submit should pass true.
//   globalThis.fmsProcess(payloadJson)            -> resultJson   (legacy)
//     One-shot {form, submission} — re-parses the form every call. Kept for
//     compatibility and A/B testing; prefer fmsSetForm + fmsProcessData.
const { processSync, ProcessTargets, ProcessorMap, Utils } = require('@formio/core');

// The `evaluator` preset seeds only customDefaultValue. Prepend the base
// `defaultValue` processor so nested containers are initialized (row context is
// non-null for their children's logic) and schema defaults are applied — exactly
// as the real Form.io renderer does.
var FULL = [ProcessorMap.defaultValue].concat(ProcessTargets.evaluator);
// Live pass: everything except validation (validate runs on blur/submit).
var LIVE = FULL.filter(function (p) { return p !== ProcessorMap.validate; });

// --- minimal polyfills for headless engines (QuickJS lacks some) ---
(function () {
  var g = typeof globalThis !== 'undefined' ? globalThis : this;
  if (!g.crypto || !g.crypto.getRandomValues) {
    g.crypto = g.crypto || {};
    g.crypto.getRandomValues = function (arr) {
      for (var i = 0; i < arr.length; i++) arr[i] = Math.floor(Math.random() * 256);
      return arr;
    };
  }
})();

// Some forms embed browser-only widgets in script fields (window/document/
// fetch/sessionStorage/setInterval) — e.g. the "mileage panel". Those can't run
// headless and are reimplemented as native widgets, so we strip the DOM scripts
// before processing to avoid noisy (caught) exceptions.
var DOM_RE = /\b(window|document|sessionStorage|localStorage|performance|setInterval|XMLHttpRequest)\b|fetch\s*\(/;
function stripDomScripts(node) {
  if (Array.isArray(node)) {
    for (var i = 0; i < node.length; i++) stripDomScripts(node[i]);
    return;
  }
  if (!node || typeof node !== 'object') return;
  if (typeof node.calculateValue === 'string' && DOM_RE.test(node.calculateValue)) node.calculateValue = '';
  if (typeof node.customConditional === 'string' && DOM_RE.test(node.customConditional)) node.customConditional = '';
  if (node.validate && typeof node.validate.custom === 'string' && DOM_RE.test(node.validate.custom)) node.validate.custom = '';
  var keys = ['components', 'columns', 'rows'];
  for (var k = 0; k < keys.length; k++) if (node[keys[k]]) stripDomScripts(node[keys[k]]);
}

function runPipeline(form, data, validate) {
  var submission = { data: data };
  var scope = { errors: [] };
  processSync({
    components: form.components || [],
    data: data,
    scope: scope,
    form: form,
    submission: submission,
    processors: validate ? FULL : LIVE,
  });
  // Build the COMPLETE hidden map. Two sources must be merged:
  //  - scope.conditionals: simple/JSONLogic conditionals ({path, conditionallyHidden})
  //  - component.hidden (after processing): static `hidden:true` + Logic-tab
  //    property(hidden) actions — which are NOT in scope.conditionals.
  var hidden = {};
  (scope.conditionals || []).forEach(function (c) {
    if (c && c.conditionallyHidden && c.path) hidden[c.path] = true;
  });
  try {
    Utils.eachComponentData(form.components, data, function (component, compData, row, path) {
      if (component && component.input && component.hidden === true && path) {
        hidden[path] = true;
      }
    });
  } catch (e) {
    /* ignore walk errors */
  }
  return {
    data: data,
    hidden: hidden,
    errors: (scope.errors || []).map(function (e) {
      var ctx = e.context || {};
      return {
        path: ctx.path || '',
        key: ctx.component && ctx.component.key,
        rule: e.ruleName,
        messageKey: e.errorKeyOrMessage,
        level: e.level,
        // The rule's limit/param (e.g. maxLength "5", min "10", pattern regex),
        // so the client can build a specific message like "at most 5 characters".
        setting: ctx.setting != null ? String(ctx.setting) : undefined,
      };
    }),
  };
}

// Cached, pre-stripped form (set once per form via fmsSetForm). Reused across
// fmsProcessData calls so only the small data map crosses the FFI boundary.
var cachedForm = null;

globalThis.fmsSetForm = function (formJson) {
  try {
    var form = JSON.parse(formJson);
    stripDomScripts(form.components || []);
    cachedForm = form;
    return JSON.stringify({ ok: true });
  } catch (e) {
    cachedForm = null;
    return JSON.stringify({ error: String(e && e.stack || e) });
  }
};

globalThis.fmsProcessData = function (dataJson, validate) {
  try {
    if (!cachedForm) {
      return JSON.stringify({ error: 'No form set — call fmsSetForm first.' });
    }
    var data = JSON.parse(dataJson) || {};
    return JSON.stringify(runPipeline(cachedForm, data, validate !== false));
  } catch (e) {
    return JSON.stringify({ error: String(e && e.stack || e) });
  }
};

// Legacy one-shot API: full {form, submission} payload every call.
globalThis.fmsProcess = function (payloadJson) {
  try {
    var input = JSON.parse(payloadJson);
    var form = input.form || {};
    stripDomScripts(form.components || []);
    var submission = input.submission || { data: {} };
    var data = submission.data || (submission.data = {});
    return JSON.stringify(runPipeline(form, data, true));
  } catch (e) {
    return JSON.stringify({ error: String(e && e.stack || e) });
  }
};

module.exports = {
  fmsSetForm: globalThis.fmsSetForm,
  fmsProcessData: globalThis.fmsProcessData,
  fmsProcess: globalThis.fmsProcess,
};
