#!/usr/bin/env bash
#
# #159. Paid review guards:
#   1. No tracked file links the dead booking pages. Each booking button
#      opens an email through the obfuscated mail link, with a subject.
#   2. The two review name tokens are intact, with their public fallbacks.
#   3. The sample report PDF exists and the Readiness and Pricing pages,
#      and the report template docs page, link it.
#   4. Review scope and time stay in the private overlay: no public
#      review text states them.

set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
pricing="$root/pricing.html"
readiness="$root/readiness.html"
pdf="$root/reports/sample-readiness-report.pdf"
pdf_href='href="/reports/sample-readiness-report.pdf"'
pass=0
fail=0

ok()  { pass=$((pass + 1)); printf '  ok    %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; }
assert() { local n="$1"; shift; if "$@"; then ok "$n"; else bad "$n"; fi; }

file_has()   { grep -Fq -- "$2" "$1"; }
file_lacks() { ! grep -Fq -- "$2" "$1"; }

# --- 1. Booking buttons ---

# Tracked text files that can hold a link. This test and the lychee ignore
# file are left out: they name the dead pages on purpose or not at all.
no_dead_booking_links() {
  local hits
  hits=$(git -C "$root" grep -l -I -E 'cal\.com/apexyard/(demo|review)' -- \
    ':!.github/tests/test-paid-review.sh' ':!docs/reviews/**' ':!docs/screenshots/**' || true)
  [ -z "$hits" ] || { echo "    dead booking link in: $hits"; return 1; }
}
assert "no tracked file links the dead booking pages" no_dead_booking_links
assert ".lycheeignore has no booking-service entry" file_lacks "$root/.lycheeignore" 'cal\.com'

# Each <a> whose text starts with "Book", plus "Talk to us", must be a
# mailto-cta with the address parts and a subject.
booking_buttons_mail() {
  python3 -I - "$root" <<'PY'
import re, subprocess, sys
root = sys.argv[1]
files = subprocess.run(["git", "-C", root, "ls-files", "*.html", "apexdock/*.html"],
                       capture_output=True, text=True, check=True).stdout.split()
tag = re.compile(r"<a\b([^>]*)>(.*?)</a>", re.S | re.I)
bad, seen = [], 0
for name in sorted(set(files)):
    text = open(f"{root}/{name}", encoding="utf-8").read()
    for attrs, inner in tag.findall(text):
        label = re.sub(r"<[^>]+>", "", inner).strip()
        if not (label.lower().startswith("book ") or label == "Talk to us"):
            continue
        seen += 1
        cls = re.search(r'class="([^"]*)"', attrs)
        subj = re.search(r'data-s="([^"]+)"', attrs)
        if not (cls and "mailto-cta" in cls.group(1).split()
                and 'data-u="hello"' in attrs and 'data-d="apexyard.ai"' in attrs
                and subj and subj.group(1).strip()
                and 'href="#"' in attrs):
            bad.append(f"{name}: {label}")
if seen < 20:
    print(f"    only {seen} booking buttons found")
    sys.exit(1)
if bad:
    print("    not an email link: " + "; ".join(bad))
    sys.exit(1)
PY
}
assert "every booking button opens an email with a subject" booking_buttons_mail

assert "the review buttons name the request in the subject" \
  bash -c "grep -Fq 'data-s=\"Book a short review\"' \"\$1\" && grep -Fq 'data-s=\"Book a full assessment\"' \"\$1\" && grep -Fq 'data-s=\"Book a readiness call\"' \"\$1\"" _ "$pricing"
assert "the ApexDock onboarding page assembles its mail link" \
  file_has "$root/apexdock/onboarding/index.html" "document.querySelectorAll('.mailto-cta')"
assert "product.js assembles the mail links" \
  file_has "$root/product.js" "document.querySelectorAll('.mailto-cta')"
assert "privacy.html no longer names a booking service" \
  file_lacks "$root/privacy.html" 'booking service'

# --- 2. Name tokens ---
token_once() { # <key> <fallback>
  local n
  n=$(grep -o "<!--{{$1}}-->[^<]*<!--/{{$1}}-->" "$pricing" | wc -l | tr -d ' ')
  [ "$n" = "1" ] || { echo "    $1: $n wrapped tokens"; return 1; }
  grep -Fq "<!--{{$1}}-->$2<!--/{{$1}}-->" "$pricing" || { echo "    $1: fallback is not '$2'"; return 1; }
}
assert "ASSESS_SHORT_NAME token is intact with fallback 'Short review'" token_once ASSESS_SHORT_NAME 'Short review'
assert "ASSESS_FULL_NAME token is intact with fallback 'Full assessment'" token_once ASSESS_FULL_NAME 'Full assessment'
assert "the two name keys are on the common-wording list" \
  bash -c "grep -qx ASSESS_SHORT_NAME \"\$1\" && grep -qx ASSESS_FULL_NAME \"\$1\"" _ "$root/.github/scripts/overlay-common-wording.txt"

# --- 3. Sample report ---
pdf_ok() {
  [ -f "$pdf" ] || { echo "    missing: reports/sample-readiness-report.pdf"; return 1; }
  [ "$(head -c 5 "$pdf")" = "%PDF-" ] || { echo "    not a PDF"; return 1; }
  local size
  size=$(wc -c < "$pdf" | tr -d ' ')
  [ "$size" -gt 20000 ] && [ "$size" -lt 2000000 ] || { echo "    size $size bytes"; return 1; }
}
assert "the sample report PDF exists" pdf_ok
assert "pricing.html links the sample report" file_has "$pricing" "$pdf_href"
assert "readiness.html links the sample report" file_has "$readiness" "$pdf_href"
assert "the docs content map holds the report template page" \
  file_has "$root/docs-site/content-map.mjs" "slug: 'readiness/report-template'"
assert "the report template page links the sample report" \
  file_has "$root/docs-site/content-map.mjs" '(/reports/sample-readiness-report.pdf)'
# The docs sync rewrites root links that are not docs pages into GitHub
# URLs. SITE_PATHS in the content map keeps /reports/ links as site paths.
site_paths_keep_reports() {
  (cd "$root/docs-site" && node --input-type=module -e "
    import { SITE_PATHS } from './content-map.mjs';
    if (!SITE_PATHS.some((p) => '/reports/sample-readiness-report.pdf'.startsWith(p))) process.exit(1);
  ")
}
assert "the content map keeps /reports/ links as site paths" site_paths_keep_reports
assert "the docs sync leaves SITE_PATHS links as they are" \
  file_has "$root/docs-site/scripts/sync-content.mjs" 'if (SITE_PATHS.some((prefix) => target.startsWith(prefix))) return target;'
# When a local docs build exists, check the built link itself.
built_href_ok() {
  local built="$root/docs-site/dist/readiness/report-template.html"
  [ -f "$built" ] || return 0
  grep -Fq "$pdf_href" "$built" || { echo "    built page does not link $pdf_href"; return 1; }
  ! grep -q 'github.com/[^"]*/reports/sample-readiness-report.pdf' "$built" || { echo "    built page links a GitHub copy"; return 1; }
}
assert "the built docs page links the site PDF (when built)" built_href_ok
assert "pricing.html links the report template" file_has "$pricing" 'href="/docs/readiness/report-template"'
assert "readiness.html links the report template" file_has "$readiness" 'href="/docs/readiness/report-template"'

# --- 4. Review section ---
# The owner keeps the review scope, time and terms in the private overlay.
# The bracket forms keep the literal phrases out of this file too.
private_detail='5 working[ ]days|30[-]minute|two[ ]weeks|30[ ]days|statement[ ]of[ ]work|refun[d]'
no_private_detail() { # <file>
  if grep -Eiq -- "$private_detail" "$1"; then
    echo "    review scope or time in ${1#"$root"/}"
    return 1
  fi
}
assert "pricing.html states no review scope or time" no_private_detail "$pricing"
assert "the docs content map states no review scope or time" no_private_detail "$root/docs-site/content-map.mjs"
assert "pricing.html says what a review gives" file_has "$pricing" 'We run the readiness audit on your repository.'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
