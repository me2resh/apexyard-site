#!/usr/bin/env bash
#
# Guard for #102: keel_versions claim hides " and versions" when not live.
# Checks claims.js, pricing.html markup, and product.js claim-off behaviour.
# Passes whether keel_versions is 'live' or 'coming' (planned switch-on).

set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
fail=0

pass() { printf 'PASS  %s\n' "$1"; }
fail_msg() { printf 'FAIL  %s\n' "$1"; fail=1; }

claims="$root/claims.js"
pricing="$root/pricing.html"
product="$root/product.js"

# Value on the keel_versions assignment line (single-quoted).
kv=$(sed -n "s/^[[:space:]]*keel_versions:[[:space:]]*'\([^']*\)'.*/\1/p" "$claims" | head -n1)
if [ "$kv" = "live" ] || [ "$kv" = "coming" ]; then
  pass "claims.js has keel_versions: '$kv'"
else
  fail_msg "claims.js keel_versions must be 'live' or 'coming' (got ${kv:-missing})"
fi

check='keel_versions: Keel owners and versions work on production for a Team org (an entry shows its owner and version history over MCP and on the dashboard). If not, set keel_versions to '\''coming'\'' so the line reads '\''with owners'\'' only.'
if grep -F "$check" "$claims" >/dev/null; then
  pass "claims.js header has keel_versions switch-on check"
else
  fail_msg "claims.js header missing keel_versions switch-on check"
fi

inner='<span data-claim="keel_versions" data-claim-off=""> and versions</span>'
if grep -F "$inner" "$pricing" >/dev/null; then
  pass "pricing.html has keel_versions inner span"
else
  fail_msg "pricing.html missing keel_versions inner span"
fi

node_out=$(node - "$claims" "$product" <<'NODE'
const fs = require('fs');
const claimsPath = process.argv[2];
const productPath = process.argv[3];
const claimsSrc = fs.readFileSync(claimsPath, 'utf8');
const productSrc = fs.readFileSync(productPath, 'utf8');

function makeEl(attrs, text) {
  const data = Object.assign({}, attrs);
  let content = text;
  return {
    getAttribute: function (name) { return Object.prototype.hasOwnProperty.call(data, name) ? data[name] : null; },
    setAttribute: function (name, value) { data[name] = String(value); },
    hasAttribute: function (name) { return Object.prototype.hasOwnProperty.call(data, name); },
    get textContent() { return content; },
    set textContent(v) { content = v == null ? '' : String(v); },
    closest: function () { return null; },
    contains: function () { return false; },
    addEventListener: function () {},
    focus: function () {},
    classList: { add: function () {}, toggle: function () { return false; }, contains: function () { return false; }, remove: function () {} }
  };
}

// state: undefined = use claims.js as-is; otherwise inject keel_versions.
function run(state) {
  const outer = makeEl({ 'data-claim': 'kb_mcp' }, '');
  const inner = makeEl({ 'data-claim': 'keel_versions', 'data-claim-off': '' }, ' and versions');
  // Mirror pricing.html: outer holds prefix; inner is the versions fragment.
  const prefix = 'Keel shared across your organisation, with owners';
  outer.textContent = prefix; // overwritten below via composition
  const lineText = function () {
    return prefix + inner.textContent;
  };

  const claimEls = [outer, inner];
  const empty = [];
  const appended = [];
  global.window = {
    APEXYARD_CLAIMS: null,
    gtag: undefined,
    matchMedia: undefined,
    fetch: undefined,
    history: undefined,
    addEventListener: function () {}
  };
  global.location = { hash: '', replace: function () {} };
  global.navigator = {};
  global.document = {
    body: { hasAttribute: function () { return false; } },
    documentElement: {
      classList: { add: function () {} },
      getAttribute: function () { return null; },
      setAttribute: function () {}
    },
    head: {
      appendChild: function (child) { appended.push(child); }
    },
    createElement: function () { return makeEl({}, ''); },
    getElementById: function () { return null; },
    querySelector: function () { return null; },
    querySelectorAll: function (sel) {
      if (sel === '[data-claim]') return claimEls;
      return empty;
    },
    addEventListener: function () {}
  };
  global.window.APEXYARD_CLAIMS = undefined;
  eval(claimsSrc);
  if (state !== undefined) {
    global.window.APEXYARD_CLAIMS.keel_versions = state;
  }
  const value = global.window.APEXYARD_CLAIMS.keel_versions;
  eval(productSrc);
  return {
    inner: inner.textContent,
    line: lineText(),
    stateAttr: inner.getAttribute('data-claim-state'),
    value: value,
    appended: appended
  };
}

let errors = [];

const file = run(undefined);
const expectedFileLine = file.value === 'live'
  ? 'Keel shared across your organisation, with owners and versions'
  : 'Keel shared across your organisation, with owners';
if (file.line !== expectedFileLine) {
  errors.push("file (" + file.value + "): line is " + JSON.stringify(file.line));
}

const live = run('live');
if (live.inner !== ' and versions') {
  errors.push("live: inner text is " + JSON.stringify(live.inner));
}
if (live.line !== 'Keel shared across your organisation, with owners and versions') {
  errors.push("live: line is " + JSON.stringify(live.line));
}
if (live.stateAttr !== 'live') {
  errors.push("live: data-claim-state is " + JSON.stringify(live.stateAttr));
}

const coming = run('coming');
if (coming.inner !== '') {
  errors.push("coming: inner text is " + JSON.stringify(coming.inner));
}
if (coming.line !== 'Keel shared across your organisation, with owners') {
  errors.push("coming: line is " + JSON.stringify(coming.line));
}
if (coming.stateAttr !== 'coming') {
  errors.push("coming: data-claim-state is " + JSON.stringify(coming.stateAttr));
}

const scripts = file.appended.map(function (el) { return el.src; });
if (scripts.length !== 2 || scripts[0] !== '/site-config.js' || scripts[1] !== '/waitlist.js') {
  errors.push('appended scripts are ' + JSON.stringify(scripts));
}

if (errors.length) {
  errors.forEach(function (e) { console.log('FAIL  product.js: ' + e); });
  process.exit(1);
}
console.log('PASS  product.js file value yields expected Keel line');
console.log('PASS  product.js live keeps " and versions"');
console.log('PASS  product.js coming drops " and versions"');
console.log('PASS  product.js appends /site-config.js then /waitlist.js');
NODE
)
node_rc=$?
printf '%s\n' "$node_out"
if [ "$node_rc" -ne 0 ]; then
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo "keel-claim: FAIL"
  exit 1
fi
echo "keel-claim: PASS"
exit 0
