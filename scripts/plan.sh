#!/usr/bin/env bash
# Print (and export as $GITHUB_OUTPUT "formulae") the ordered JSON list of formulae needing a build.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
source "$here/lib.sh"
: "${GITHUB_REPOSITORY:?}"

# Expand: runtime deps (topological) first, then the formula; dedupe keeping order.
ordered=()
declare -A seen=()
while read -r f; do
  for d in $(brew deps --topological "$f") "$f"; do
    [[ -n "${seen[$d]:-}" ]] && continue
    seen[$d]=1
    ordered+=("$d")
  done
done < <(read_formulae "$here/../formulae.txt")

todo=()
for f in "${ordered[@]}"; do
  if has_intel_bottle "$f"; then echo "skip $f: upstream Intel bottle"; continue; fi
  ver="$(pkg_version "$f")"; tag="$(tag_for "$f" "$ver")"
  if gh release view "$tag" --repo "$GITHUB_REPOSITORY" >/dev/null 2>&1; then
    echo "skip $f: release $tag exists"; continue
  fi
  echo "build $f ($tag)"
  todo+=("$f")
done

json="$(printf '%s\n' "${todo[@]:-}" | jq -R . | jq -sc 'map(select(length>0))')"
echo "to build: $json"
[[ -n "${GITHUB_OUTPUT:-}" ]] && echo "formulae=$json" >> "$GITHUB_OUTPUT"
exit 0
