#!/usr/bin/env python3
"""Decide which formulae need a build; emit the ready ones as a matrix and write candidates to cand/."""
import json, os
import tap
from tap import *

brew_update()
order, infos = resolve_all(read_list())
mirrored = set(order)
cand = ROOT / "cand"
cand.mkdir(exist_ok=True)

needs = {}
for name in order:
    new = rewrite(fetch_source(infos[name]), mirrored)
    f = FORMULA_DIR / f"{name}.rb"
    old = f.read_text() if f.exists() else None
    if old is not None and normalize(old) == normalize(new):
        if has_bottle(old):
            print(f"up to date: {name}")
            continue
        new = old  # same source, just missing a bottle
    needs[name] = new
    (cand / f"{name}.rb").write_text(new)

ready, remaining = [], []
for name in needs:
    info = infos[name]
    deps = info.get("dependencies", []) + [b for b in info.get("build_dependencies", []) if b in mirrored]
    (remaining if any(d in needs and d != name for d in deps) else ready).append(name)
print("ready:", ready, "\nremaining:", remaining)

matrix = {"include": [{"name": n, "safe": n.replace("@", "-").replace("+", "p")} for n in ready]}
out = os.environ.get("GITHUB_OUTPUT")
if out:
    with open(out, "a") as fh:
        fh.write(f"ready={json.dumps(matrix)}\nready_count={len(ready)}\nremaining={len(remaining)}\n")
