#!/usr/bin/env bash
# Guards for the crew hero, the section intros, the self-hosted fonts and the mark (#144),
# and for Hadi, the main thread, on the gate card (#157).
set -uo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
pass=0; fail=0
ok() { echo "  ok    $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL  $1"; fail=$((fail + 1)); }
assert() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }

pages=("$root"/*.html "$root"/apexdock/index.html "$root"/apexdock/onboarding/index.html)

no_font_host() {
  ! grep -lE 'fonts\.(googleapis|gstatic)\.com' "${pages[@]}" "$root/docs-site/astro.config.mjs" 2>/dev/null | grep .
}
assert "no served page or docs config names a public font host" no_font_host

fonts_exist() {
  local f missing=0
  while read -r f; do
    [ -f "$root$f" ] || { echo "    missing $f"; missing=1; }
  done < <(grep -ohE "/fonts/[A-Za-z0-9_.-]+\.woff2" "$root/site.css" "$root/product.css" "$root/docs-site/src/styles/docs.css" "$root/game.html" "$root"/apexdock/index.html "$root"/apexdock/onboarding/index.html | sort -u)
  return "$missing"
}
assert "every font file named in a stylesheet exists" fonts_exist

crew_refs_exist() {
  local f missing=0
  while read -r f; do
    [ -f "$root$f" ] || { echo "    missing $f"; missing=1; }
  done < <(grep -ohE "/img/crew/[A-Za-z0-9_.-]+\.(avif|webp|png)" "$root"/index.html "$root"/build.html "$root"/gate.html | sort -u)
  return "$missing"
}
assert "every crew image named in a page exists" crew_refs_exist

assert "home headline" grep -Fq 'Your agents build. The gate decides what ships.' "$root/index.html"
assert "hero image is preloaded as AVIF" grep -Eq '<link rel="preload" as="image" type="image/avif"[^>]*crew-1152\.avif' "$root/index.html"
assert "gate card holds five rows and a merged footer" bash -c "[ \$(grep -c '<li class=\"gc-row' '$root/index.html') -eq 5 ] && grep -Fq 'fd1b505' '$root/index.html'"
assert "Replay control is a button" grep -Fq '<button class="gc-replay" type="button" data-replay' "$root/index.html"
assert "reduced motion turns the story off" grep -Fq '.is-playing *, .is-playing *::before, .is-playing *::after { animation: none !important; }' "$root/site.css"

hero_avif=$(wc -c < "$root/img/crew/crew-1152.avif")
assert "hero AVIF at 1440 px is 150 KB or less" test "$hero_avif" -le 153600

intro_count=$(cat "$root/index.html" "$root/build.html" "$root/gate.html" | grep -c 'class="crew-intro"')
assert "six section intros" test "$intro_count" -eq 6
assert "intro images have alt text" bash -c "! grep -hE 'pt-[a-z]+-320\.png\" srcset=[^>]*alt=\"\"' '$root'/index.html '$root'/build.html '$root'/gate.html"

no_old_mark() { ! grep -lE '<text[^>]*>AY</text>' "$root"/*.html; }
assert "no page header draws the old AY square" no_old_mark
assert "headers use the new mark and an HTML wordmark" bash -c "for f in '$root'/index.html '$root'/build.html '$root'/gate.html '$root'/pricing.html; do grep -Fq 'class=\"brand__mark\" src=\"/brand/apexyard-mark.svg\"' \$f && grep -Fq '<span class=\"brand__word\">ApexYard</span>' \$f || exit 1; done"
assert "mark SVGs hold no text" bash -c "! grep -l '<text' '$root'/brand/apexyard-mark*.svg '$root'/favicon.svg"
assert "favicon.svg uses a 64 x 64 viewBox" grep -Fq 'viewBox="0 0 64 64"' "$root/favicon.svg"

# Hadi, the main thread (#157). Build the old names from parts so this file does not match itself.
old_names=("Sp""ark" "At""las")
no_old_name() {
  local hits
  hits=$(git -C "$root" grep -I -l -F -e "$1" -- . ':(exclude)docs/screenshots' 2>/dev/null)
  [ -z "$hits" ] || { echo "    $1 in: $hits"; return 1; }
}
for n in "${old_names[@]}"; do
  assert "no tracked site file names the old character ${n:0:2}" no_old_name "$n"
done
hadi_images_exist() {
  local f ext missing=0
  for f in av-hadi-48 av-hadi-96 pt-hadi-160 pt-hadi-320; do
    for ext in avif webp png; do
      [ -f "$root/img/crew/$f.$ext" ] || { echo "    missing img/crew/$f.$ext"; missing=1; }
    done
  done
  return "$missing"
}
assert "the twelve Hadi images exist" hadi_images_exist
assert "the crew intro names Hadi, the main thread" grep -Fq '<p class="crew-intro__role">The main thread</p><p class="crew-intro__name">Hadi</p>' "$root/index.html"
assert "the hero alt text names Hadi, the main thread" grep -Fq 'Hadi, the main thread, routes the work to the crew' "$root/index.html"
hadi_slots() { [ "$(grep -c '<span class="gc-hadi[^"]*" aria-hidden="true"></span>' "$root/index.html")" -eq 6 ]; }
assert "Hadi has a decorative slot in each gate row and beside Merged" hadi_slots
assert "the story waits for the card to scroll into view" grep -Fq 'IntersectionObserver' "$root/crew-hero.js"
assert "the human row waits before its tick" grep -Fq '.is-playing .gc-row--approved, .is-playing .hero-crew__floor i:nth-child(5) { --gc-d: var(--gc-human); }' "$root/site.css"

outside='Vercel|Linear|Stripe|Notion|Figma|Cursor Cloud|Midjourney'
assert "no outside product names in hero or intros" bash -c "! sed -n '/id=\"hero\"/,/<\\/section>/p' '$root/index.html' | grep -Eiq '$outside'"

echo
echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]
