# homebrew-intel-bottles

A Homebrew tap (`metril/intel-bottles`) with Intel bottles for Homebrew formulae, since Homebrew no longer builds them. GitHub Actions (`macos-15-intel`, bottle tag `sequoia`) mirrors each formula in `formulae.txt` and its runtime dependencies from homebrew-core, builds a bottle, and publishes it as a release asset. Sequoia bottles install on macOS Tahoe 26 without compiling.

## Setup (CI)
`brew leaves > formulae.txt`, commit and push. The workflow runs daily, on `formulae.txt` changes, and via `gh workflow run build.yml`. Each formula is committed only after its bottle is uploaded, so the tap never advertises a version without a bottle. Long runs stop after about 5 hours and re-dispatch themselves.

## Use (Mac)
One time:
```sh
./migrate-to-tap [--dry-run]
```
It taps and trusts the repo, then reinstalls bottled formulae from it in dependency order. After that, plain `brew update && brew upgrade` works. Formulae not yet bottled in the tap are skipped; re-run later.

## Deadlines
GitHub retires `macos-15-intel` around Aug 2027; Homebrew drops Intel in Sept 2027. Plan a move (e.g. MacPorts) before then.
