#!/usr/bin/env bash
#
# Fail when a pull request title, body or commit message holds a private
# term (#102). The tracked-file check does not see this text.
#
# Usage: check-pr-text.sh <event-json> <base-sha> <head-sha>
#
# Terms come from the PRIVATE_TERMS environment variable, as in
# check-private-terms.sh, which does the term loading and masking. This
# script only collects the text into a temp directory. It never prints the
# text. A hit prints the field (title, body or commit <short sha>) and the
# term index. Without PRIVATE_TERMS (fork PR) it skips with a notice.
# Never add `set -x` to this script.

set -euo pipefail

event=${1:?event json}
base=${2:?base sha}
head=${3:?head sha}
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if [ -z "${PRIVATE_TERMS:-}" ]; then
  echo "::notice::check-pr-text: no private terms secret in this run (fork PR or local run). Skipped."
  exit 0
fi

dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT

jq -r '.pull_request.title // ""' "$event" > "$dir/title"
jq -r '.pull_request.body // ""' "$event" > "$dir/body"
# Fail closed: a range that cannot resolve, or an empty range for a PR that
# differs from its base, must not pass as "no hits".
if ! shas=$(git log --format=%H "$base..$head" 2>/dev/null); then
  echo "::error::check-pr-text: the commit range cannot be resolved. The check failed closed."
  exit 1
fi
if [ -z "$shas" ] && [ "$base" != "$head" ]; then
  echo "::error::check-pr-text: the commit range is empty for a non-empty PR. The check failed closed."
  exit 1
fi
for sha in $shas; do
  git log -1 --format=%B "$sha" > "$dir/commit-${sha:0:7}"
done

"$here/check-private-terms.sh" --text-dir "$dir"
