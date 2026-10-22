#!/usr/bin/env python3
"""Build one bottle. Usage: build.py <formula>. Expects cand/<formula>.rb from the plan job."""
import shutil, sys
from tap import *

name = sys.argv[1]
brew_update()
mirrored = {p.stem for p in FORMULA_DIR.glob("*.rb")} | {p.stem for p in (ROOT / "cand").glob("*.rb")}
FORMULA_DIR.mkdir(exist_ok=True)
shutil.copy(ROOT / "cand" / f"{name}.rb", FORMULA_DIR / f"{name}.rb")
setup_tap()
build(name, mirrored)
