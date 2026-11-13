#!/usr/bin/env bash
# Guards for the crew hero, the section intros, the self-hosted fonts and the mark (#144),
# for Hadi, the main thread, on the gate card (#157), and for the hero motion, the blocked example,
# the row evidence and the buyer's question (#160).
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

# The headline is one h1 with one span per sentence (#176). The tags go, the text stays exact.
headline_text() { grep -o '<h1 id="hero-title">.*</h1>' "$root/index.html" | sed -e 's/<[^>]*>//g'; }
assert "home headline" test "$(headline_text)" = 'Your agents build. The gate decides what ships.'
assert "home headline is two sentence lines" test "$(grep -o 'class="hero-crew__line"' "$root/index.html" | wc -l | tr -d ' ')" = 2
assert "hero image is preloaded as AVIF" grep -Eq '<link rel="preload" as="image" type="image/avif"[^>]*crew-base-1152\.avif' "$root/index.html"
assert "gate card holds two examples of five rows, each with a merged footer" bash -c "[ \$(grep -c '<li class=\"gc-row' '$root/index.html') -eq 10 ] && grep -Fq 'fa4bf37' '$root/index.html' && grep -Fq '8d0df1b' '$root/index.html'"
assert "Replay control is a button" grep -Fq '<button class="gc-replay" type="button" data-replay' "$root/index.html"
assert "reduced motion turns the story off" grep -Fq '.is-playing *, .is-playing *::before, .is-playing *::after { animation: none !important; }' "$root/site.css"

hero_avif=$(wc -c < "$root/img/crew/crew-base-1152.avif")
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
hadi_slots() { [ "$(grep -c '<span class="gc-hadi[^"]*" aria-hidden="true"></span>' "$root/index.html")" -eq 12 ]; }
assert "Hadi has a decorative slot in each gate row and beside Merged, in both examples" hadi_slots
assert "the story waits for the card to scroll into view" grep -Fq 'IntersectionObserver' "$root/crew-hero.js"
assert "the human row waits before its tick" grep -Fq '.is-playing .gc-row--approved, .is-playing .hero-crew__floor i:nth-child(5) { --gc-d: var(--gc-human); }' "$root/site.css"

# ---- #160: large Hadi on the crew picture ----
css="$root/site.css"
js="$root/crew-hero.js"
home="$root/index.html"

large_hadi_images() {
  local f ext missing=0
  for f in crew-base-768 crew-base-1152 crew-base-1536 hadi-lg-150 hadi-lg-300; do
    for ext in avif webp png; do
      [ -f "$root/img/crew/$f.$ext" ] || { echo "    missing img/crew/$f.$ext"; missing=1; }
    done
  done
  return "$missing"
}
assert "the picture without Hadi and the large Hadi cut-out exist in three formats" large_hadi_images
no_old_picture() { ! grep -lE '/img/crew/crew-(768|1152|1536)\.' "$root"/*.html; }
assert "no page still names the old crew picture" no_old_picture

sprite_line() { grep 'class="hero-crew__hadi"' "$home"; }
one_sprite() { [ "$(sprite_line | wc -l)" -eq 1 ] && sprite_line | grep -Fq 'aria-hidden="true"' && sprite_line | grep -Fq 'alt=""'; }
assert "one large Hadi sprite, hidden from screen readers, with empty alt text" one_sprite
sprite_is_plain() { ! sprite_line | grep -Eiq 'gc-state|Passed|Approved|<svg'; }
assert "large Hadi never carries text, a tick or a state" sprite_is_plain
for k in 0 1 2 3 4; do
  assert "large Hadi has a stop $k beside a crew member" grep -Eq -- "--lh-s$k: [0-9.]+;" "$css"
done
hop_block() { sed -n '/^\.is-playing \.hero-crew__hadi {/,/^}/p' "$css"; }
hops_use_timeline() {
  local v
  for v in r0 r1 r2 r3 r4 human; do
    hop_block | grep -Fq "var(--gc-$v)" || { echo "    no var(--gc-$v) in the large Hadi hops"; return 1; }
  done
}
assert "large Hadi hops use the card timeline, not their own clock" hops_use_timeline
one_clock() { [ "$(grep -c -- '--gc-t0: 1s;' "$css")" -eq 1 ] && grep -Fq '.is-playing[data-run="blocked"] {' "$css"; }
assert "the timeline variables are set in one place for both examples" one_clock
stack_block() { sed -n '/^@media (max-width: 899px)/,/^}/p' "$css"; }
stack_home() { stack_block | grep -Fq '.is-playing .hero-crew__hadi'; }
assert "large Hadi stays at home where the picture stacks under the card" stack_home
home_block() { sed -n '/^\.hero-crew__hadi {/,/^}/p' "$css"; }
behind_at_rest() { grep -Fq '@keyframes gc-lh-z' "$css" && home_block | grep -Fq 'z-index: 0'; }
assert "large Hadi sits behind the boot at rest and moves in front only while it walks" behind_at_rest
no_layout_motion() { ! sed -n '/^@keyframes gc-lh-/p' "$css" | grep -Eq '(left|top|margin|width|height):'; }
assert "large Hadi moves by transform only, so it causes no layout shift" no_layout_motion

# ---- #160: the blocked example (me2resh/apexyard#2010), nothing invented ----
assert "the blocked example names pull request 2010 and its ticket" bash -c "grep -Fq 'me2resh/apexyard#2010' '$home' && grep -Fq 'issues/2006' '$home'"
real_commits() {
  local c
  for c in c809c6e 22e1b67 8d0df1bf65b648d28e542e9c309bed733342781d; do
    grep -Fq "$c" "$home" || { echo "    missing $c"; return 1; }
  done
}
assert "the blocked example uses the real commits" real_commits
assert "the blocked example links the real security block and the final approval" bash -c "grep -Fq 'pull/2010#pullrequestreview-5818250332' '$home' && grep -Fq 'pull/2010#pullrequestreview-5819187528' '$home'"
card_html() { sed -n '/class="gate-card"/,/<\/section>/p' "$home"; }
foreign_links() { card_html | grep -o 'href="[^"]*"' | grep -v 'href="https://github.com/me2resh/apexyard/' | grep .; }
only_public_links() { ! foreign_links; }
assert "every link in the hero card points at the public ApexYard repository" only_public_links
blocked_layers() { [ "$(grep -c 'class="gc-bad" aria-hidden="true"' "$home")" -eq 4 ] && [ "$(grep -c 'gc-state--block' "$home")" -eq 2 ]; }
assert "the blocked rows hold a blocked layer and a final layer" blocked_layers
assert "the final layer is the resting state, so reduced motion shows the whole story" bash -c "sed -n '/^\.gc-swap \.gc-bad {/p' '$css' | grep -Fq 'opacity: 0'"
assert "a fix note links the changes between the block and the approval" grep -Fq 'compare/c809c6e...22e1b67' "$home"

# ---- #160: tabs, Replay and row evidence ----
tabs_ok() {
  [ "$(grep -c 'class="gc-tab"' "$home")" -eq 2 ] &&
    grep -Fq 'data-run="clean" aria-pressed="true"' "$home" &&
    grep -Fq 'data-run="blocked" aria-pressed="false"' "$home"
}
assert "two example buttons, one pressed" tabs_ok
evidence_ok() {
  local h n
  h=$(card_html)
  n=$(echo "$h" | grep -o 'class="gc-more" type="button" aria-expanded="false" aria-controls="ev-' | wc -l)
  [ "$n" -eq 10 ] || { echo "    $n evidence buttons"; return 1; }
  n=$(echo "$h" | grep -o '<div class="gc-ev" id="ev-[a-z]-[0-4]" hidden>' | wc -l)
  [ "$n" -eq 10 ] || { echo "    $n hidden panels"; return 1; }
  n=$(echo "$h" | grep -o '<dt>Evidence</dt><dd><a href="https://github.com/me2resh/apexyard/' | wc -l)
  [ "$n" -eq 10 ] || { echo "    $n evidence links"; return 1; }
  n=$(echo "$h" | grep -c '<dt>Checked</dt>')
  [ "$n" -eq 10 ] || { echo "    $n checked lines"; return 1; }
  n=$(echo "$h" | grep -c '<dt>By</dt>')
  [ "$n" -eq 10 ]
}
assert "each row has an evidence button and a hidden panel: what was checked, by whom, a link" evidence_ok
controls_real() {
  local id
  while IFS= read -r id; do
    grep -Fq "id=\"$id\"" "$home" || { echo "    no panel $id"; return 1; }
  done < <(grep -o 'aria-controls="ev-[a-z]-[0-4]"' "$home" | cut -d'"' -f2)
}
assert "every aria-controls value names a real panel" controls_real
assert "the script opens evidence with aria-expanded and closes it on Escape" bash -c "grep -Fq 'aria-expanded' '$js' && grep -Fq \"'Escape'\" '$js' && grep -Fq 'btn.focus()' '$js'"
assert "the script switches examples through data-run and replays the active one" bash -c "grep -Fq \"hero.setAttribute('data-run'\" '$js' && grep -Fq 'replays[r].addEventListener' '$js'"
assert "the row evidence has a visible focus ring" grep -Fq '.gc-more:focus-visible::after { outline: 3px solid var(--focus)' "$css"
assert "evidence links stay above the row's click area" bash -c "sed -n '/^\.gc-fact {/p' '$css' | grep -Fq 'z-index: 2'"

# ---- #160: the buyer's question ----
assert "the buyer's question leads the hero" bash -c "sed -n '/<div class=\"hero-crew__copy\">/,/<h1/p' '$home' | grep -Fq 'An agent wrote it. Who approved it?'"
assert "the supporting lines stay as they were" bash -c "grep -Fq 'Use AI coding agents with a controlled engineering process.' '$home' && grep -Fq 'Every merge leaves a record: what was checked, who approved it, and the exact commit.' '$home'"
hero_html() { sed -n '/id="hero"/,/<\/section>/p' "$home"; }
no_price() { ! hero_html | grep -Eq '(\$|\xC2\xA3|\xE2\x82\xAC)[0-9]'; }
assert "no price in the hero" no_price

outside='Vercel|Linear|Stripe|Notion|Figma|Cursor Cloud|Midjourney'
assert "no outside product names in hero or intros" bash -c "! sed -n '/id=\"hero\"/,/<\\/section>/p' '$root/index.html' | grep -Eiq '$outside'"

# ---- #174: a complete passed example (me2resh/apexyard#934, ticket #914) and new-tab links ----
clean_html() { sed -n '/class="gc-run gc-run--clean/,/class="gc-run gc-run--blocked"/p' "$home"; }
assert "the passed example names pull request 934 and its ticket 914" bash -c "grep -Fq 'me2resh/apexyard#934' '$home' && grep -Fq 'issues/914\"' '$home' && grep -Fq 'feat(#914)' '$home'"
old_run_gone() { ! grep -Eq 'apexyard#1925|issues/1919|pull/1925|pull/1923|fd1b505|apexyard#1584|issues/1576|pull/1578|c40c4c7' "$home"; }
assert "the earlier passed examples (#1925, #1584) are gone" old_run_gone
passed_records() {
  local h c
  h=$(clean_html)
  for c in pull/934#pullrequestreview-4712910975 pull/934#pullrequestreview-4712906106 pull/934#pullrequestreview-4712973274 pull/930#pullrequestreview-4712404847 commit/fa4bf376474b5553f8c3711e40e6ae3f541ad1f5; do
    echo "$h" | grep -Fq "$c" || { echo "    missing $c"; return 1; }
  done
}
assert "the passed example links the real reviews, the approval and the merge commit" passed_records
links_open_new_tab() {
  local a bad=0 n=0
  while IFS= read -r a; do
    n=$((n + 1))
    echo "$a" | grep -Fq 'target="_blank"' || { echo "    no target: $a"; bad=1; }
    echo "$a" | grep -Eq 'rel="[^"]*noopener' || { echo "    no noopener: $a"; bad=1; }
  done < <(card_html | grep -o '<a [^>]*>')
  [ "$n" -eq 29 ] || { echo "    $n links, expected 29"; bad=1; }
  return "$bad"
}
assert "every link in the gate card opens in a new tab with rel noopener" links_open_new_tab
new_tab_hint() {
  [ "$(card_html | grep -o '</a>' | wc -l)" -eq "$(card_html | grep -o '<span class="vh"> (opens in a new tab)</span></a>' | wc -l)" ]
}
assert "every link in the gate card tells screen readers it opens in a new tab" new_tab_hint

# The finale (#190): Hadi rolls in from the right when the story's last element ends.
assert "the finale starts on the animationend of the last story element, not a timer" bash -c "grep -q \"addEventListener('animationend'\" '$root/crew-hero.js' && grep -q \"'gc-merged'\" '$root/crew-hero.js' && ! grep -Eq 'setTimeout|setInterval' '$root/crew-hero.js'"
assert "the finale is skipped when the visitor prefers reduced motion" grep -q "prefers-reduced-motion: reduce" "$root/crew-hero.js"
assert "the finale animates only transform and opacity" bash -c "! sed -n '/@keyframes gc-finale-roll/,/^}/p;/@keyframes gc-finale-glow/p' '$root/site.css' | grep -Eq '(left|right|top|bottom|width|height|margin|filter):'"
assert "the finale runs once: it ends with finale-done and never repeats" bash -c "grep -q 'finale-done' '$root/crew-hero.js' && ! grep -Eq 'infinite' <(sed -n '/THE FINALE (#190)/,/The story waits until/p' '$root/site.css')"
assert "the reduced-motion block shows Hadi at rest" grep -q "has-finale .hero-crew__hadi, .has-finale .hero-crew__floor i.idle { opacity: 1 !important" "$root/site.css"

echo
echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]
