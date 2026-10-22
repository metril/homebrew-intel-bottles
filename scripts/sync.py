#!/usr/bin/env python3
"""Mirror homebrew-core formulae into this tap, build Intel bottles, publish them.

Per formula (topological order): write the rewritten core formula, build a bottle if the
formula changed or has no sequoia bottle, upload it to a GitHub release, write the bottle
block into the formula, then commit and push. Resumable: stops starting new builds after
STOP_AFTER_MIN minutes and re-dispatches the workflow if work remains.
"""
import json, os, re, shutil, subprocess, sys, time, urllib.parse, urllib.request
from pathlib import Path

REPO = os.environ.get("GITHUB_REPOSITORY", "metril/homebrew-intel-bottles")
TAP = "metril/intel-bottles"
ROOT = Path(__file__).resolve().parent.parent
FORMULA_DIR = ROOT / "Formula"
STOP_AFTER_MIN = int(os.environ.get("STOP_AFTER_MIN", "300"))
START = time.time()


def run(*cmd, check=True, capture=False, cwd=None):
    print("+", " ".join(map(str, cmd)), flush=True)
    r = subprocess.run(cmd, check=check, text=True, cwd=cwd,
                       stdout=subprocess.PIPE if capture else None)
    return r.stdout.strip() if capture else r.returncode


def brew_info(name):
    out = run("brew", "info", "--json=v2", "--formula", name, check=False, capture=True)
    try:
        return json.loads(out)["formulae"][0]
    except Exception:
        return None


def read_list():
    lines = [re.sub(r"#.*", "", l).strip() for l in (ROOT / "formulae.txt").read_text().splitlines()]
    return [l for l in lines if l]


def resolve_all(leaves):
    """Return (ordered names, infos). Mirrored set = leaves + recursive runtime deps.
    Order puts runtime deps, and mirrored build deps, before dependents."""
    infos = {}

    def info_of(name):
        if name not in infos:
            infos[name] = brew_info(f"homebrew/core/{name}")
            if infos[name] is None:
                print(f"::warning::skip {name}: brew cannot resolve it")
            else:
                infos[infos[name]["name"]] = infos[name]
        return infos[name]

    mirrored = set()

    def collect(name):
        info = info_of(name)
        if info is None or info["name"] in mirrored:
            return
        mirrored.add(info["name"])
        for d in info.get("dependencies", []):
            collect(d)

    for leaf in leaves:
        collect(leaf)

    order, done = [], set()

    def visit(name, stack=()):
        if name in done or name in stack:
            return
        info = infos[name]
        for d in info.get("dependencies", []) + [b for b in info.get("build_dependencies", []) if b in mirrored]:
            if d in infos and infos[d] is not None:
                visit(d, stack + (name,))
        done.add(name)
        order.append(name)

    for leaf in leaves:
        if infos.get(leaf):
            visit(infos[leaf]["name"])
    for name in sorted(mirrored):
        visit(name)
    return order, {n: infos[n] for n in order}


BOTTLE_RE = re.compile(r"^  bottle do\n.*?^  end\n", re.S | re.M)
DEP_RE = re.compile(r'^(\s*depends_on\s+)"([^"/]+)"(.*)$', re.M)


def normalize(text):
    return re.sub(r"\n{3,}", "\n\n", BOTTLE_RE.sub("", text))


NOAUTOBUMP_RE = re.compile(r"^[ \t]*no_autobump!(?:.*,[ \t]*\n[ \t]+)*.*\n", re.M)  # official-tap-only DSL


def rewrite(text, mirrored):
    text = NOAUTOBUMP_RE.sub("", BOTTLE_RE.sub("", text))

    def sub(m):
        name, rest = m.group(2), m.group(3)
        if name in mirrored and ":build" not in rest and ":test" not in rest:
            return f'{m.group(1)}"{TAP}/{name}"{rest}'
        return m.group(0)

    return re.sub(r"\n{3,}", "\n\n", DEP_RE.sub(sub, text))


def fetch_source(info):
    path = info.get("ruby_source_path") or f"Formula/{info['name'][0]}/{info['name']}.rb"
    url = f"https://raw.githubusercontent.com/Homebrew/homebrew-core/HEAD/{path}"
    with urllib.request.urlopen(url) as r:
        return r.read().decode()


def has_bottle(text):
    m = BOTTLE_RE.search(text)
    return bool(m and "sequoia:" in m.group(0))


def tap_version(name):
    info = brew_info(f"{TAP}/{name}")
    v = info["versions"]["stable"]
    return f"{v}_{info['revision']}" if info.get("revision") else v


def release_tag(name, ver):
    return f"{name}-{ver}".replace("@", "-").replace("+", "p")


def ensure_installed_deps(name, mirrored):
    """Install all runtime+build deps before building: tap bottles where available (so nothing
    recompiles), otherwise core bottles, otherwise build from source (Homebrew refuses implicit
    source builds on unsupported configurations)."""
    out = run("brew", "deps", "--topological", "--include-build", f"{TAP}/{name}", capture=True)
    for dep in out.split():
        d = dep.rsplit("/", 1)[-1]
        if run("brew", "list", "--versions", d, check=False, capture=True):
            continue
        tapf = FORMULA_DIR / f"{d}.rb"
        if d in mirrored and tapf.exists() and has_bottle(tapf.read_text()):
            run("brew", "install", f"{TAP}/{d}")
        elif run("brew", "install", d, check=False) != 0:
            run("brew", "install", "--build-from-source", d)


def build(name, mirrored):
    f = FORMULA_DIR / f"{name}.rb"
    ver = tap_version(name)
    tag = release_tag(name, ver)
    ensure_installed_deps(name, mirrored)
    run("brew", "uninstall", "--ignore-dependencies", "--force", name, check=False)
    run("brew", "install", "--build-bottle", f"{TAP}/{name}")
    work = ROOT / "bottles" / name
    shutil.rmtree(work, ignore_errors=True)
    work.mkdir(parents=True)
    run("brew", "bottle", "--json", f"--root-url=https://github.com/{REPO}/releases/download/{tag}",
        f"{TAP}/{name}", cwd=work)
    js = next(work.glob("*.json"))
    tags = next(iter(json.loads(js.read_text()).values()))["bottle"]["tags"]
    t = next(iter(tags.values()))
    # Homebrew downloads root_url/<filename> where filename has a single dash (Bottle::Filename#url_encode).
    upload = work / "upload"
    upload.mkdir()
    asset = urllib.parse.unquote(t["filename"])  # json holds the URL-encoded name; the asset keeps the plain name
    shutil.copy(work / t["local_filename"], upload / asset)
    exists = run("gh", "release", "view", tag, "--repo", REPO, check=False) == 0
    if exists:
        for old in run("gh", "release", "view", tag, "--repo", REPO, "--json", "assets", "-q",
                       ".assets[].name", capture=True).split():
            if old != asset:
                run("gh", "release", "delete-asset", tag, old, "--repo", REPO, "-y", check=False)
        run("gh", "release", "upload", tag, str(upload / asset), "--repo", REPO, "--clobber")
    else:
        run("gh", "release", "create", tag, str(upload / asset), "--repo", REPO,
            "--title", f"{name} {ver}", "--notes", f"Intel bottle for {name} {ver} (sequoia).")
    url = f"https://github.com/{REPO}/releases/download/{tag}/{t['filename']}"
    run("curl", "-fsSLI", "-o", "/dev/null", url)  # fail if the asset is not downloadable at the expected URL
    run("brew", "bottle", "--merge", "--write", "--no-commit", str(js))
    run("git", "add", str(f), cwd=ROOT)
    run("git", "commit", "-q", "-m", f"{name}: {ver} bottle", cwd=ROOT)
    run("git", "pull", "-q", "--rebase", "--autostash", "origin", "main", cwd=ROOT)
    run("git", "push", "-q", "origin", "HEAD:main", cwd=ROOT)


def main():
    run("brew", "update")
    os.environ["HOMEBREW_NO_AUTO_UPDATE"] = "1"  # already updated; keep the run stable
    os.environ["HOMEBREW_NO_INSTALL_CLEANUP"] = "1"
    run("git", "config", "user.name", "metril", cwd=ROOT)
    run("git", "config", "user.email", "1517921+metril@users.noreply.github.com", cwd=ROOT)

    order, infos = resolve_all(read_list())
    mirrored = set(order)
    FORMULA_DIR.mkdir(exist_ok=True)

    # Plan: write candidates, decide what needs a build.
    todo = []
    for name in order:
        info = infos[name]
        new = rewrite(fetch_source(info), mirrored)
        f = FORMULA_DIR / f"{name}.rb"
        old = f.read_text() if f.exists() else None
        if old is not None and normalize(old) == normalize(new) and has_bottle(old):
            print(f"up to date: {name}")
            continue
        if old is not None and normalize(old) == normalize(new):
            new = old  # same source, just missing a bottle
        f.write_text(new)
        todo.append(name)
    print("to build:", todo, flush=True)

    # Make the checkout the tap, after `brew update` so it is not touched by it.
    tap_dir = Path(run("brew", "--repository", capture=True)) / "Library/Taps/metril/homebrew-intel-bottles"
    tap_dir.parent.mkdir(parents=True, exist_ok=True)
    if tap_dir.is_symlink():
        tap_dir.unlink()
    elif tap_dir.is_dir():
        shutil.rmtree(tap_dir)
    tap_dir.symlink_to(ROOT)
    run("brew", "trust", TAP, check=False)  # newer Homebrew requires trusting third-party taps

    failed, built, stopped = set(), 0, False
    for name in todo:
        f = FORMULA_DIR / f"{name}.rb"
        if (time.time() - START) / 60 > STOP_AFTER_MIN:
            stopped = True
            break
        bad = [d for d in infos[name].get("dependencies", []) if d in failed]
        print(f"::group::{name}", flush=True)
        try:
            if bad:
                raise RuntimeError(f"dependency failed: {bad}")
            build(name, mirrored)
            built += 1
        except Exception as e:  # noqa: BLE001
            print(f"::error::{name}: {e}")
            failed.add(name)
        print("::endgroup::", flush=True)

    # Drop uncommitted candidates (failed or not reached); only committed formulae stay.
    run("git", "checkout", "--", "Formula", cwd=ROOT, check=False)
    run("git", "clean", "-fdq", "Formula", cwd=ROOT, check=False)

    print(f"built={built} failed={sorted(failed)} stopped_for_time={stopped}")
    if stopped and built:
        run("gh", "workflow", "run", "build.yml", "--repo", REPO, check=False)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
