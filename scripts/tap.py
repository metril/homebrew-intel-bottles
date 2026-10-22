#!/usr/bin/env python3
"""Shared helpers for the plan/build/finalize scripts."""
import json, os, re, shutil, subprocess, sys, time, urllib.parse, urllib.request
from pathlib import Path

REPO = os.environ.get("GITHUB_REPOSITORY", "metril/homebrew-intel-bottles")
TAP = "metril/intel-bottles"
ROOT = Path(__file__).resolve().parent.parent
FORMULA_DIR = ROOT / "Formula"


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


def brew_update():
    run("brew", "update")
    os.environ["HOMEBREW_NO_AUTO_UPDATE"] = "1"  # already updated; keep the run stable
    os.environ["HOMEBREW_NO_INSTALL_CLEANUP"] = "1"


def setup_tap():
    """Make the checkout the tap (after `brew update`, which would otherwise touch it)."""
    tap_dir = Path(run("brew", "--repository", capture=True)) / "Library/Taps/metril/homebrew-intel-bottles"
    tap_dir.parent.mkdir(parents=True, exist_ok=True)
    if tap_dir.is_symlink():
        tap_dir.unlink()
    elif tap_dir.is_dir():
        shutil.rmtree(tap_dir)
    tap_dir.symlink_to(ROOT)
    run("brew", "trust", TAP, check=False)  # newer Homebrew requires trusting third-party taps


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
    """Build and upload one bottle; leaves bottles/<name>/*.json for the finalize job."""
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
    t = next(iter(next(iter(json.loads(js.read_text()).values()))["bottle"]["tags"].values()))
    # json holds the URL-encoded name (what Homebrew requests); the asset keeps the plain name.
    asset = urllib.parse.unquote(t["filename"])
    upload = work / "upload"
    upload.mkdir()
    shutil.copy(work / t["local_filename"], upload / asset)
    if run("gh", "release", "view", tag, "--repo", REPO, check=False) == 0:
        for old in run("gh", "release", "view", tag, "--repo", REPO, "--json", "assets", "-q",
                       ".assets[].name", capture=True).split():
            if old != asset:
                run("gh", "release", "delete-asset", tag, old, "--repo", REPO, "-y", check=False)
        run("gh", "release", "upload", tag, str(upload / asset), "--repo", REPO, "--clobber")
    else:
        run("gh", "release", "create", tag, str(upload / asset), "--repo", REPO,
            "--title", f"{name} {ver}", "--notes", f"Intel bottle for {name} {ver} (sequoia).")
    run("curl", "-fsSLI", "-o", "/dev/null",
        f"https://github.com/{REPO}/releases/download/{tag}/{t['filename']}")  # must be downloadable
    out = ROOT / "out"
    out.mkdir(exist_ok=True)
    shutil.copy(js, out / f"{name}.json")
