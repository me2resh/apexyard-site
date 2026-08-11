#!/usr/bin/env bash
#
# Regression guard for me2resh/apexyard-site#69 — the count verifier must fail
# when a site surface disagrees with the framework tag, and must refuse rather
# than guess when it cannot derive.
#
# Runs .github/scripts/verify-counts.sh against a synthetic framework repo and a
# synthetic site, both built in a tempdir, so nothing here touches the real
# framework clone, the network, or GitHub. The release check is not exercised:
# it is opt-in behind --releases precisely because it needs both.
#
# The case that matters most is "new surface, stale count" (case 3). The whole
# design claim of the verifier is that it finds count claims rather than
# looking for known ones in known files — if that regresses into a file
# allowlist, case 3 is what notices.
#
# Run locally:  .github/tests/test-verify-counts.sh
#
# This file lives under .github/ deliberately: the deploy workflows sync the
# repo root to S3 and exclude ".github/*", so test scaffolding stays off the
# public site.

set -uo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
script="$repo_root/.github/scripts/verify-counts.sh"
[ -x "$script" ] || { echo "FATAL: $script missing or not executable"; exit 1; }

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

pass=0; fail=0
ok()   { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }

# --- synthetic framework repo ------------------------------------------------
# 2 skills · 3 hooks (a _lib helper and a tests/ entry must not count) ·
# 1 agent · 2 roles (README must not count) · 1 rule.

fw="$workdir/framework"
mkdir -p "$fw"/.claude/{skills/alpha,skills/beta,hooks/tests,agents,rules} "$fw"/roles/eng
(
  cd "$fw" || exit 1
  git init -q . && git config user.email t@t.t && git config user.name t
  touch .claude/skills/alpha/SKILL.md .claude/skills/beta/SKILL.md
  touch .claude/hooks/one.sh .claude/hooks/two.sh .claude/hooks/three.sh
  touch .claude/hooks/_lib-helper.sh .claude/hooks/tests/test-x.sh
  touch .claude/agents/rex.md
  touch roles/eng/dev.md roles/eng/lead.md roles/eng/README.md
  touch .claude/rules/one.md
  git add -A && git commit -qm init && git tag v9.9.9
) || { echo "FATAL: could not build synthetic framework"; exit 1; }

run_case() {
  # $1 = site dir ; rest = args. Echoes "<exit>|<stderr+stdout>".
  local site="$1"; shift
  local out rc
  out=$(APEXYARD_REPO="$fw" REF=v9.9.9 SITE_ROOT="$site" "$script" "$@" 2>&1); rc=$?
  printf '%s|%s' "$rc" "$out"
}

new_site() {
  local site="$workdir/$1"; rm -rf "$site"; mkdir -p "$site"
  (
    cd "$site" || exit 1
    git init -q . && git config user.email t@t.t && git config user.name t
  )
  echo "$site"
}

commit_site() { (cd "$1" && git add -A && git commit -qm s); }

echo "verify-counts.sh"

# --- case 1: every surface agrees -------------------------------------------
site=$(new_site site-clean)
cat > "$site/index.html" <<'EOF'
<p>2 slash commands, 3 shell hooks, 1 sub-agent, 2 roles, 1 rule.</p>
EOF
printf 'Docs: 2 skills and 3 hooks.\n' > "$site/llms.txt"
commit_site "$site"
res=$(run_case "$site"); rc="${res%%|*}"; out="${res#*|}"
if [ "$rc" = 0 ]; then ok "clean site exits 0"; else bad "clean site exits 0" "got $rc: $out"; fi

# --- case 2: a stale count on an existing page ------------------------------
site=$(new_site site-stale)
printf '<p>2 slash commands, 49 shell hooks.</p>\n' > "$site/index.html"
commit_site "$site"
res=$(run_case "$site"); rc="${res%%|*}"; out="${res#*|}"
if [ "$rc" = 1 ]; then ok "stale count exits 1"; else bad "stale count exits 1" "got $rc: $out"; fi
case "$out" in
  *"index.html"*"says 49 hooks"*) ok "names the file, the wrong number, and the right one" ;;
  *) bad "names the file, the wrong number, and the right one" "$out" ;;
esac

# --- case 3: a NEW surface nobody added to any list -------------------------
# The design claim under test. A file that did not exist when the verifier was
# written must still be checked.
site=$(new_site site-newpage)
printf '<p>2 slash commands</p>\n' > "$site/index.html"
printf '<p>Now with 11 rules.</p>\n' > "$site/brand-new-page.html"
commit_site "$site"
res=$(run_case "$site"); rc="${res%%|*}"; out="${res#*|}"
if [ "$rc" = 1 ]; then ok "new surface with a stale count is caught"; else bad "new surface with a stale count is caught" "got $rc: $out"; fi
case "$out" in
  *"brand-new-page.html"*) ok "names the new surface" ;;
  *) bad "names the new surface" "$out" ;;
esac

# --- case 4: the documented not-a-count lines are left alone ----------------
site=$(new_site site-excluded)
{
  printf '<p>2 slash commands</p>\n'
  printf '<div>settings.json diff: 55 -> 56 hooks, zero removed</div>\n'
  printf "<div>Spawning 3 agents...</div>\\n"
  printf '<p>File 5-20 structured tickets in one flow.</p>\n'
} > "$site/index.html"
# shellcheck disable=SC2016  # backticks are literal markdown here, not a subshell
printf 'The `55 → 56 hooks` line counts wiring entries.\n' > "$site/README.md"
commit_site "$site"
res=$(run_case "$site"); rc="${res%%|*}"; out="${res#*|}"
if [ "$rc" = 0 ]; then ok "documented non-counts are not flagged"; else bad "documented non-counts are not flagged" "got $rc: $out"; fi

# --- case 5: cannot derive -> refuse (exit 2), never guess ------------------
site=$(new_site site-clean2)
printf '<p>2 slash commands</p>\n' > "$site/index.html"
commit_site "$site"

out=$(APEXYARD_REPO="" REF=v9.9.9 SITE_ROOT="$site" "$script" 2>&1); rc=$?
if [ "$rc" = 2 ]; then ok "missing APEXYARD_REPO exits 2"; else bad "missing APEXYARD_REPO exits 2" "got $rc: $out"; fi

out=$(APEXYARD_REPO="$fw" REF=v0.0.0-nope SITE_ROOT="$site" "$script" 2>&1); rc=$?
if [ "$rc" = 2 ]; then ok "unresolvable REF exits 2"; else bad "unresolvable REF exits 2" "got $rc: $out"; fi

# --- case 6: framework layout moved -> refuse, don't report zero ------------
# An empty .claude/skills/ means the glob stopped matching. Reporting "the site
# should say 0 skills" would be worse than not running: it would rewrite every
# correct page to a wrong number.
fw2="$workdir/framework-moved"
mkdir -p "$fw2"/.claude/rules
(
  cd "$fw2" || exit 1
  git init -q . && git config user.email t@t.t && git config user.name t
  touch .claude/rules/one.md
  git add -A && git commit -qm init && git tag v9.9.9
) || { echo "FATAL: could not build moved-layout framework"; exit 1; }
out=$(APEXYARD_REPO="$fw2" REF=v9.9.9 SITE_ROOT="$site" "$script" 2>&1); rc=$?
if [ "$rc" = 2 ]; then ok "vanished primitive refuses (exit 2), does not report 0"; else bad "vanished primitive refuses (exit 2), does not report 0" "got $rc: $out"; fi

# --- verdict -----------------------------------------------------------------
echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
