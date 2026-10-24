#!/usr/bin/env python3
"""Write bottle blocks for built formulae (jsons/*.json + cand/*.rb), commit once, push."""
import shutil, sys
from tap import *

jsons = sorted((ROOT / "jsons").glob("*.json"))
print("built:", [j.stem for j in jsons])
if not jsons:
    sys.exit(0)
brew_update()
FORMULA_DIR.mkdir(exist_ok=True)
for j in jsons:
    shutil.copy(ROOT / "cand" / f"{j.stem}.rb", FORMULA_DIR / f"{j.stem}.rb")
if (ROOT / "cand/Patches").exists():
    shutil.copytree(ROOT / "cand/Patches", ROOT / "Patches", dirs_exist_ok=True)
mirrored = {p.stem for p in FORMULA_DIR.glob("*.rb")} | {p.stem for p in (ROOT / "cand").glob("*.rb")}
fix_formulae(mirrored)
setup_tap()
for j in jsons:
    run("brew", "bottle", "--merge", "--write", "--no-commit", str(j))
run("git", "config", "user.name", "metril", cwd=ROOT)
run("git", "config", "user.email", "1517921+metril@users.noreply.github.com", cwd=ROOT)
run("git", "add", "Formula", *(["Patches"] if (ROOT / "Patches").exists() else []), cwd=ROOT)
run("git", "commit", "-q", "-m", "Add bottles: " + ", ".join(j.stem for j in jsons), cwd=ROOT)
for attempt in range(5):
    run("git", "pull", "-q", "--rebase", "origin", "main", cwd=ROOT)
    if run("git", "push", "-q", "origin", "HEAD:main", cwd=ROOT, check=False) == 0:
        break
else:
    sys.exit("push failed")
