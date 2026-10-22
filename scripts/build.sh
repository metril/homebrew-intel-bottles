#!/usr/bin/env bash
# Build and release bottles. Usage: build.sh '<json array of formulae, topological order>'
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
source "$here/lib.sh"
: "${GITHUB_REPOSITORY:?}"

out="$PWD/bottles"; mkdir -p "$out"
failed=()

# Install this repo's already-released bottles for deps that are not installed yet,
# so nothing gets recompiled. Deps with upstream bottles are handled by brew itself.
ensure_deps() {
  local d ver tag
  for d in $(brew deps --topological "$1"); do
    brew list --versions "$d" >/dev/null 2>&1 && continue
    has_intel_bottle "$d" && continue
    ver="$(pkg_version "$d")"; tag="$(tag_for "$d" "$ver")"
    if gh release view "$tag" --repo "$GITHUB_REPOSITORY" >/dev/null 2>&1; then
      mkdir -p "$out/dl-$d"
      gh release download "$tag" --repo "$GITHUB_REPOSITORY" --pattern '*.bottle.tar.gz' --dir "$out/dl-$d" --clobber
      brew install "$out"/dl-"$d"/*.bottle.tar.gz
    fi
  done
}

build_one() {
  local f="$1" ver tag
  ver="$(pkg_version "$f")"; tag="$(tag_for "$f" "$ver")"
  ensure_deps "$f"
  brew uninstall --ignore-dependencies --force "$f" || true   # runner image may preinstall it
  brew install --build-bottle "$f"
  local work="$out/$f"; mkdir -p "$work"
  # brew writes <name>--<version>.<tag>.bottle.tar.gz (double dash) and .json; keep names as-is.
  (cd "$work" && brew bottle --json --no-rebuild \
    --root-url="https://github.com/$GITHUB_REPOSITORY/releases/download/$tag" "$f")
  local files=("$work/$f"--*.bottle.tar.gz "$work/$f"--*.bottle.json)
  gh release create "$tag" "${files[@]}" --repo "$GITHUB_REPOSITORY" \
    --title "$f $ver" --notes "Intel bottle for $f $ver, built on macos-15-intel (sequoia)."
}

while read -r f; do
  [[ -z "$f" ]] && continue
  echo "::group::$f"
  if ! build_one "$f"; then echo "::error::build failed: $f"; failed+=("$f"); fi
  echo "::endgroup::"
done < <(jq -r '.[]' <<<"$1")

if ((${#failed[@]})); then echo "Failed: ${failed[*]}"; exit 1; fi
