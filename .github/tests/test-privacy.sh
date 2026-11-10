#!/usr/bin/env bash
#
# #154. Privacy page guards: the page and its owner-fact placeholders, the
# footer and cookie-banner links to /privacy, the sitemap entry, and the
# handler that shows the cookie banner again.

set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
page="$root/privacy.html"
pass=0
fail=0

ok()  { pass=$((pass + 1)); printf '  ok    %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; }
assert() { local n="$1"; shift; if "$@"; then ok "$n"; else bad "$n"; fi; }

file_has()   { grep -Fq -- "$2" "$1"; }
file_lacks() { ! grep -Fq -- "$2" "$1"; }

# Pages with a site footer. architecture.html is a redirect with no footer.
footer_pages() {
  local f
  for f in "$root"/*.html; do
    [ "$(basename "$f")" = "architecture.html" ] && continue
    printf '%s\n' "$f"
  done
  printf '%s\n' "$root/apexdock/index.html" "$root/apexdock/onboarding/index.html" \
    "$root/docs-site/src/components/Footer.astro"
}

# --- 1. The page ---
assert "privacy.html exists" test -f "$page"
assert "privacy.html holds canonical /privacy" \
  file_has "$page" '<link rel="canonical" href="https://apexyard.ai/privacy">'
assert "privacy.html holds og:url /privacy" \
  file_has "$page" '<meta property="og:url" content="https://apexyard.ai/privacy">'
assert "privacy.html holds the company-number placeholder" \
  file_has "$page" 'data-owner-fact="company-number"'
assert "privacy.html holds the registered-office placeholder" \
  file_has "$page" 'data-owner-fact="registered-office"'
assert "privacy.html names ApexScript Ltd" file_has "$page" 'ApexScript Ltd'
assert "privacy.html uses the obfuscated mail link" \
  file_has "$page" 'class="mailto-cta" data-u="hello" data-d="apexyard.ai"'
assert "privacy.html links the ICO" file_has "$page" 'https://ico.org.uk'
assert "privacy.html states 12 months retention" file_has "$page" '12 months after our last contact'
assert "privacy.html has the reopen button" file_has "$page" 'data-consent-reopen'
assert "privacy.html has the consent banner" file_has "$page" 'id="consent"'
assert "privacy.html loads product.js" file_has "$page" '<script src="/product.js" defer></script>'
assert "privacy.html has no inline consent script" file_lacks "$page" "localStorage.removeItem"
assert "privacy.html does not name the booking company" file_lacks "$page" 'Cal.com'

# --- 2. Footers ---
# The footer markup only: the consent banner also links /privacy, so a
# whole-file match would pass with the footer link gone. Footer.astro is
# the docs footer itself.
footer_markup() { # <file>
  case "$1" in
    *.astro) cat "$1" ;;
    *) awk '/<footer/,/<\/footer>/' "$1" ;;
  esac
}

footers_link_privacy() {
  local f hits=""
  while IFS= read -r f; do
    footer_markup "$f" | grep -Fq 'href="/privacy"' || hits="$hits ${f#"$root"/}"
  done < <(footer_pages)
  [ -z "$hits" ] || { echo "    missing in:$hits"; return 1; }
}
assert "every footer links /privacy" footers_link_privacy

footers_have_placeholder() {
  local f hits=""
  while IFS= read -r f; do
    grep -Fq 'data-owner-fact="company-number"' "$f" || hits="$hits ${f#"$root"/}"
  done < <(footer_pages)
  [ -z "$hits" ] || { echo "    missing in:$hits"; return 1; }
}
assert "every footer marks the company number" footers_have_placeholder

no_to_follow() {
  local hits
  hits=$(grep -rlF --include='*.html' --include='*.astro' 'Company number: to follow' \
    "$root"/*.html "$root/apexdock" "$root/docs-site/src" 2>/dev/null || true)
  [ -z "$hits" ] || { echo "    found in: $hits"; return 1; }
}
assert "no page says Company number: to follow" no_to_follow

# --- 3. Cookie banners ---
banners_link_privacy() {
  local f hits="" n=0
  for f in "$root"/*.html; do
    grep -Fq 'id="consent"' "$f" || continue
    n=$((n + 1))
    awk '/id="consent"/,/consent__actions/' "$f" | grep -Fq '<a href="/privacy">Privacy</a>' \
      || hits="$hits $(basename "$f")"
  done
  [ "$n" -gt 0 ] || { echo "    no consent banner found"; return 1; }
  [ -z "$hits" ] || { echo "    missing in:$hits"; return 1; }
}
assert "every consent banner links /privacy" banners_link_privacy

no_google_policy() {
  local hits
  hits=$(grep -lF 'policies.google.com' "$root"/*.html "$root"/apexdock/*.html \
    "$root"/apexdock/onboarding/*.html 2>/dev/null || true)
  [ -z "$hits" ] || { echo "    found in: $hits"; return 1; }
}
assert "no page links policies.google.com" no_google_policy

# --- 4. Waitlist, sitemap, link check ---
assert "waitlist.html links /privacy" file_has "$root/waitlist.html" 'href="/privacy"'
assert "sitemap.xml holds /privacy" \
  file_has "$root/sitemap.xml" '<loc>https://apexyard.ai/privacy</loc>'
assert "link-check excludes the /privacy clean URL" \
  grep -Eq -- '--exclude "/\([a-z|-]*privacy[a-z|-]*\)' "$root/.github/workflows/link-check.yml"

# --- 5. Reopen handler ---
assert "product.js binds data-consent-reopen" \
  file_has "$root/product.js" "querySelectorAll('[data-consent-reopen]')"
assert "product.js clears ay-consent on reopen" \
  file_has "$root/product.js" 'localStorage.removeItem(KEY)'
assert "product.js sets analytics_storage denied on reopen" \
  file_has "$root/product.js" "analytics_storage: 'denied'"

# --- 6. Google tag only after Accept ---
gtag_block() { awk '/<!-- begin: gtag/,/<!-- end: gtag -->/' "$1"; }

loader_pages() {
  local f
  for f in "$root"/*.html; do
    grep -Fq '<!-- begin: gtag' "$f" && printf '%s\n' "$f"
  done
}

gtag_pages_have_loader() {
  local f hits="" n=0
  while IFS= read -r f; do
    n=$((n + 1))
    gtag_block "$f" | grep -Fq 'window.ayLoadAnalytics = function' || hits="$hits $(basename "$f")"
  done < <(loader_pages)
  [ "$n" -ge 13 ] || { echo "    only $n pages hold the gtag block"; return 1; }
  [ -z "$hits" ] || { echo "    missing in:$hits"; return 1; }
}
assert "every gtag block defines ayLoadAnalytics" gtag_pages_have_loader

no_static_gtag() {
  local hits
  hits=$(grep -lE '<script[^>]*src="https://www\.googletagmanager\.com' "$root"/*.html \
    "$root"/apexdock/*.html "$root"/apexdock/onboarding/*.html 2>/dev/null || true)
  [ -z "$hits" ] || { echo "    found in: $hits"; return 1; }
}
assert "no page loads gtag.js with a static script tag" no_static_gtag

gtag_blocks_identical() {
  local canon f hits=""
  canon=$(gtag_block "$page")
  [ -n "$canon" ] || { echo "    privacy.html has no gtag block"; return 1; }
  while IFS= read -r f; do
    [ "$(gtag_block "$f")" = "$canon" ] || hits="$hits $(basename "$f")"
  done < <(loader_pages)
  [ -z "$hits" ] || { echo "    differs in:$hits"; return 1; }
}
assert "the gtag block is identical on every page" gtag_blocks_identical

loader_waits_for_consent() {
  gtag_block "$page" | grep -Fq "if (localStorage.getItem('ay-consent') === 'granted') window.ayLoadAnalytics();"
}
assert "the gtag block loads the tag only for a stored Accept" loader_waits_for_consent

assert "product.js Accept calls the loader" \
  file_has "$root/product.js" 'window.ayLoadAnalytics();'
assert "product.js track() waits for the loaded tag" \
  file_has "$root/product.js" 'if (analyticsOn()) window.gtag('"'"'event'"'"', name);'
assert "waitlist.js sends waitlist_signup only after the tag loaded" \
  file_has "$root/waitlist.js" "if (window.ayAnalyticsLoaded === true && typeof window.gtag === 'function') window.gtag('event', 'waitlist_signup');"

inline_consent_uses_loader() {
  local f hits=""
  for f in "$root"/*.html; do
    grep -Fq "var KEY = 'ay-consent';" "$f" || continue
    grep -Fq 'window.ayLoadAnalytics();' "$f" || hits="$hits $(basename "$f")"
  done
  [ -z "$hits" ] || { echo "    missing in:$hits"; return 1; }
}
assert "inline consent scripts call the loader on Accept" inline_consent_uses_loader

# A loaded tag cannot be unloaded, so Decline and reopen set Google's
# disable flag. That stops the collect request when the page closes.
product_decline_disables() {
  grep -Fq "var GA_OFF = 'ga-disable-G-G3EMR3CB02';" "$root/product.js" \
    && grep -F -A3 "} else if (choice === 'denied') {" "$root/product.js" | grep -Fq 'window[GA_OFF] = true;'
}
assert "product.js sets ga-disable on Decline" product_decline_disables
assert "product.js sets ga-disable on reopen" \
  grep -Fq 'window[GA_OFF] = true;' "$root/product.js"
assert "product.js clears ga-disable on Accept" \
  grep -Fq 'window[GA_OFF] = false;' "$root/product.js"

inline_consent() { awk '/begin: consent/,/end: consent/' "$1" | sed -n '/<script>/,/<\/script>/p'; }
inline_consent_identical() {
  local f canon="" hits="" n=0
  for f in "$root"/*.html; do
    grep -Fq "var KEY = 'ay-consent';" "$f" || continue
    n=$((n + 1))
    inline_consent "$f" | grep -Fq "window['ga-disable-G-G3EMR3CB02'] = true;" \
      || hits="$hits $(basename "$f")"
    if [ -z "$canon" ]; then canon=$(inline_consent "$f")
    elif [ "$(inline_consent "$f")" != "$canon" ]; then hits="$hits $(basename "$f")(differs)"
    fi
  done
  [ "$n" -ge 4 ] || { echo "    only $n inline consent scripts"; return 1; }
  [ -z "$hits" ] || { echo "    problem in:$hits"; return 1; }
}
assert "inline consent scripts are identical and set ga-disable on Decline" inline_consent_identical

assert "privacy.html says the site sends nothing to Google before Accept" \
  file_has "$page" 'Before that, the site sends nothing to Google.'
assert "privacy.html has no cookieless-signal text" file_lacks "$page" 'signal'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
