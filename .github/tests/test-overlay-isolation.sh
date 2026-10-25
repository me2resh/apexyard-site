#!/usr/bin/env bash
#
# Static guard for #102: the private staging overlay stays in one job.
#
#   1. Only deploy-staging-v2.yml reads STAGING_OVERLAY or runs the overlay
#      scripts, and only that workflow declares the `staging` environment.
#   2. deploy-staging-v2.yml runs only on a push to `staging`, writes only to
#      the staging bucket, and never uploads or summarises the overlaid site.
#   3. The production jobs read no secret and deploy the plain checkout.
#   4. Public files hold placeholder tokens only, each wrapped around a
#      visible fallback, and no price-shaped text.

set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
wf="$root/.github/workflows"
v2="$wf/deploy-staging-v2.yml"
pass=0
fail=0

ok()  { pass=$((pass + 1)); printf '  ok    %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; }
assert() { local n="$1"; shift; if "$@"; then ok "$n"; else bad "$n"; fi; }

# Code lines only: workflow and script headers name these words on purpose.
code() { grep -vE '^\s*#' "$1"; }

only_v2_mentions() { # <regex>
  local f hits=""
  for f in "$wf"/*.yml; do
    [ "$f" = "$v2" ] && continue
    if code "$f" | grep -qE -- "$1"; then hits="$hits $(basename "$f")"; fi
  done
  [ -z "$hits" ] || { echo "    found in:$hits"; return 1; }
}

assert "v2 workflow exists"                              test -f "$v2"
assert "only v2 reads STAGING_OVERLAY"                   only_v2_mentions 'STAGING_OVERLAY'
assert "only v2 runs apply-overlay.sh"                   only_v2_mentions 'apply-overlay\.sh'
assert "only v2 runs check-prod-overlay-free.sh"         only_v2_mentions 'check-prod-overlay-free\.sh'
assert "v2 reads the secret only into OVERLAY_JSON"      bash -c "code_lines=\$(grep -vE '^\s*#' '$v2' | grep 'secrets\.'); [ -n \"\$code_lines\" ] && ! grep -vqE '^\s*OVERLAY_JSON: \\$\\{\\{ secrets\.STAGING_OVERLAY \\}\\}\s*$' <<<\"\$code_lines\""
assert "v2 has no upload-artifact"                       bash -c "! grep -vE '^\s*#' '$v2' | grep -q 'upload-artifact'"
assert "v2 writes nothing to the step summary"           bash -c "! grep -vE '^\s*#' '$v2' | grep -q 'GITHUB_STEP_SUMMARY'"
assert "v2 never names the production bucket"            bash -c "! grep -q 'apexyard-site-prod' '$v2'"
assert "v2 syncs the overlaid copy, not the checkout"    bash -c "grep -vE '^\s*#' '$v2' | grep -q 'aws s3 sync \"\$RUNNER_TEMP/site\"'"
assert "v2 runs the production leak check"               bash -c "grep -vE '^\s*#' '$v2' | grep -q 'check-prod-overlay-free.sh'"
assert "no workflow uses set -x"                         bash -c "! grep -vhE '^\s*#' '$wf'/*.yml | grep -qE 'set -[a-z]*x|set -o xtrace'"

yaml_checks() {
  python3 - "$wf" <<'PY'
import glob, os, sys, yaml

wf = sys.argv[1]
errors = []

def env_name(job):
    env = job.get("environment")
    return env.get("name") if isinstance(env, dict) else env

for path in sorted(glob.glob(os.path.join(wf, "*.yml"))):
    doc = yaml.safe_load(open(path))
    base = os.path.basename(path)
    for name, job in (doc.get("jobs") or {}).items():
        if env_name(job) == "staging" and base != "deploy-staging-v2.yml":
            errors.append(f"{base}:{name} declares the staging environment")

v2 = yaml.safe_load(open(os.path.join(wf, "deploy-staging-v2.yml")))
on = v2.get("on", v2.get(True))  # PyYAML reads the bare key `on` as True
if set(on) != {"push"}:
    errors.append(f"v2 triggers must be push only, found {sorted(map(str, on))}")
elif on["push"].get("branches") != ["staging"] or set(on["push"]) != {"branches"}:
    errors.append("v2 must trigger on push to the staging branch only")
jobs = v2.get("jobs") or {}
if len(jobs) != 1:
    errors.append("v2 must have exactly one job")
for name, job in jobs.items():
    if env_name(job) != "staging":
        errors.append(f"v2:{name} must declare the staging environment")
    if "refs/heads/staging" not in str(job.get("if", "")):
        errors.append(f"v2:{name} must guard on refs/heads/staging")

prod = yaml.safe_load(open(os.path.join(wf, "deploy-aws.yml")))
for name in ("approve-production", "deploy-production"):
    job = (prod.get("jobs") or {}).get(name)
    if job is None:
        errors.append(f"deploy-aws.yml has no {name} job")
        continue
    text = yaml.safe_dump(job)
    if "secrets." in text:
        errors.append(f"deploy-aws.yml:{name} reads a secret")
    if "RUNNER_TEMP/site" in text:
        errors.append(f"deploy-aws.yml:{name} syncs an overlaid copy")
    if env_name(job) not in (None, "production"):
        errors.append(f"deploy-aws.yml:{name} declares a non-production environment")

for e in errors:
    print("    " + e)
sys.exit(1 if errors else 0)
PY
}
if python3 -c 'import yaml' 2>/dev/null; then
  assert "workflow structure keeps the overlay isolated" yaml_checks
else
  echo "  skip  workflow structure check (PyYAML not installed)"
fi

# Public files: tokens only in the wrapped form, from the documented set,
# and no price-shaped text. game.html is a game with prices in its puzzles;
# it holds no token and is not part of the pricing surface.
public_checks() {
  python3 - "$root" <<'PY'
import glob, os, re, sys

root = sys.argv[1]
DOCUMENTED = {"TEAM_PRICE", "TEAM_PRICE_NOTE", "TEAM_SUMMARY", "PLAN_HINT"}
WRAPPED = re.compile(r"<!--\{\{([A-Z][A-Z0-9_]*)\}\}-->(.*?)<!--/\{\{\1\}\}-->", re.S)
ANY = re.compile(r"\{\{([A-Z][A-Z0-9_]*)\}\}")
PRICE = re.compile(
    r"[$£€]\s?\d"
    r"|\b\d[\d,.]*\s?(usd|gbp|eur)\b"
    r"|\bper\s(seat|user|month|year)\b"
    r"|/(mo|month|seat|user)\b",
    re.I,
)

# Third-party fees that the site quotes as facts, not ApexYard prices.
THIRD_PARTY = [
    ("apexdock/index.html", "membership (US$99/year)"),  # Apple Developer Program
]

files = []
for pattern in ("*.html", "*.md.gen", "*.txt", "*.xml", "skill.md", "apexdock/**/*"):
    files += glob.glob(os.path.join(root, pattern), recursive=True)
errors = []
seen = set()
for path in sorted(set(files)):
    if not os.path.isfile(path):
        continue
    rel = os.path.relpath(path, root)
    try:
        text = open(path, encoding="utf-8").read()
    except UnicodeDecodeError:
        continue
    stripped = text
    for m in WRAPPED.finditer(text):
        seen.add(m.group(1))
        if not m.group(2).strip():
            errors.append(f"{rel}: token {m.group(1)} has an empty fallback")
    stripped = WRAPPED.sub("", text)
    for m in ANY.finditer(stripped):
        errors.append(f"{rel}: token {m.group(1)} is not in the wrapped form")
    if rel != "game.html":
        for m in PRICE.finditer(stripped):
            line_text = stripped[stripped.rfind("\n", 0, m.start()) + 1:].split("\n", 1)[0]
            if any(rel == f and a in line_text for f, a in THIRD_PARTY):
                continue
            line = stripped.count("\n", 0, m.start()) + 1
            errors.append(f"{rel}:{line}: price-shaped text")
unknown = seen - DOCUMENTED
if unknown:
    errors.append(f"undocumented tokens: {sorted(unknown)} (update DOCUMENTED and the PR token list)")
for e in errors:
    print("    " + e)
sys.exit(1 if errors else 0)
PY
}
assert "public files hold wrapped tokens and no prices"  public_checks

echo
echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]
