#!/usr/bin/env bash
# Shared helpers. Source this file; requires brew and jq.

# Strip comments/blank lines from formulae.txt
read_formulae() { sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e 's/^[[:space:]]*//' "$1" | grep -v '^$' || true; }

# Package version incl. revision, e.g. 1.2_1 (matches Homebrew bottle naming)
pkg_version() {
  brew info --json=v2 "$1" | jq -r '.formulae[0] | .versions.stable + (if (.revision // 0) > 0 then "_\(.revision)" else "" end)'
}

# Release tag: <name>-<version>, with @ and + made tag-safe
tag_for() { printf '%s-%s' "$1" "$2" | tr '@+' '-p'; }

# True if upstream ships an Intel bottle (bare tahoe/sequoia/all key; arm ones are arm64_*)
has_intel_bottle() {
  brew info --json=v2 "$1" | jq -e '(.formulae[0].bottle.stable.files // {}) | has("tahoe") or has("sequoia") or has("all")' >/dev/null
}
