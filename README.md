# homebrew-intel-bottles

Homebrew no longer builds Intel bottles. This repo builds them on GitHub Actions (`macos-15-intel`, bottle tag `sequoia`) for formulae that lack an upstream Intel bottle, and publishes them as release assets (`<name>-<version>`). Sequoia bottles install on macOS Tahoe 26 without compiling.

## Setup
1. On the Mac: `brew leaves > formulae.txt`, commit and push. Runtime deps are expanded automatically.
2. The workflow runs daily, on `formulae.txt` changes, and via `gh workflow run build.yml`. Existing releases are skipped.

## Use
```sh
./brew-intel-upgrade              # outdated formulae + casks
./brew-intel-upgrade foo bar      # also install these
./brew-intel-upgrade --allow-source --no-cask
```
Order of preference per formula: this repo's bottle, then upstream Intel bottle, otherwise skip (or compile with `--allow-source`). Override the repo with `BOTTLE_REPO=owner/repo`.

## Deadlines
GitHub retires `macos-15-intel` around Aug 2027; Homebrew drops Intel in Sept 2027. Plan a move (e.g. MacPorts) before then.
