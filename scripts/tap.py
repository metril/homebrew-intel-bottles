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
        # Build deps are mirrored too: upstream has no Intel bottles for them, and the runner
        # image's preinstalled copies are outdated (brew refuses to upgrade them here).
        for d in info.get("dependencies", []) + info.get("build_dependencies", []):
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
    text = re.sub(r'^(\s*depends_on\s+")' + re.escape(TAP) + r'/([^"\n]+".*:(?:build|test).*)$', r"\1\2", text, flags=re.M)
    return re.sub(r"\n{3,}", "\n\n", BOTTLE_RE.sub("", text))


NOAUTOBUMP_RE = re.compile(r"^[ \t]*no_autobump!(?:.*,[ \t]*\n[ \t]+)*.*\n", re.M)  # official-tap-only DSL


def prefix_deps(text, mirrored):
    def sub(m):
        name, rest = m.group(2), m.group(3)
        if name in mirrored:
            return f'{m.group(1)}"{TAP}/{name}"{rest}'
        return m.group(0)

    return DEP_RE.sub(sub, text)


def fix_formulae(mirrored):
    for f in FORMULA_DIR.glob("*.rb"):
        t = f.read_text()
        n = prefix_deps(t, mirrored)
        if n != t:
            f.write_text(n)


def rewrite(text, mirrored):
    text = NOAUTOBUMP_RE.sub("", BOTTLE_RE.sub("", text))
    text = prefix_deps(text, mirrored)
    # tap deps are named "metril/intel-bottles/x"; keep name inspection in formula code working
    text = text.replace("deps.map(&:name)", 'deps.map { |d| d.name.split("/").last }')
    text = re.sub(r"\bdep\.name\.(?=(?:start_with|match)\?)", 'dep.name.split("/").last.', text)
    return re.sub(r"\n{3,}", "\n\n", text)


def fetch_source(info):
    path = info.get("ruby_source_path") or f"Formula/{info['name'][0]}/{info['name']}.rb"
    url = f"https://raw.githubusercontent.com/Homebrew/homebrew-core/HEAD/{path}"
    with urllib.request.urlopen(url) as r:
        return r.read().decode()


def fetch_patches(text, base):
    """Download the `file "Patches/..."` patches a formula references into base/, same relative path."""
    for p in set(re.findall(r'file\s+"(Patches/[^"]+)"', text)):
        dest = Path(base) / p
        dest.parent.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(f"https://raw.githubusercontent.com/Homebrew/homebrew-core/HEAD/{p}") as r:
            dest.write_bytes(r.read())


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
    os.environ["HOMEBREW_NO_INSTALL_UPGRADE"] = "1"  # do not upgrade preinstalled outdated deps (no Intel bottles to pour)


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


def unlink_openssl(keep):
    # Preinstalled openssl variants hold /usr/local/bin/openssl links that block linking ours.
    for f in run("brew", "list", "--formula", "-1", capture=True).split():
        if f.startswith("openssl") and f != keep:
            run("brew", "link", "--force", "--overwrite", f, check=False)  # record stale links so unlink removes them
            run("brew", "unlink", f, check=False)


def ensure_installed_deps(name, mirrored):
    """Install all runtime+build deps at the right version before building. Prefer tap bottles
    (nothing recompiles); fall back to core bottles, then source. Stale preinstalled copies are
    replaced, since brew refuses to upgrade them implicitly on this unsupported config."""
    out = run("brew", "deps", "--topological", "--include-build", f"{TAP}/{name}", capture=True)
    outdated = set(run("brew", "outdated", "--formula", "-q", capture=True).split())
    for dep in out.split():
        d = dep.rsplit("/", 1)[-1]
        cur = run("brew", "list", "--versions", d, check=False, capture=True).split()[1:]
        tapf = FORMULA_DIR / f"{d}.rb"
        if d in mirrored and tapf.exists() and has_bottle(tapf.read_text()):
            if tap_version(d) in cur:
                continue
            run("brew", "fetch", f"{TAP}/{d}", check=False)  # download before uninstall: brewed curl needs libssh2/openssl
            run("brew", "uninstall", "--ignore-dependencies", "--force", d, check=False)
            if d.startswith("openssl"):
                unlink_openssl(d)
            run("brew", "install", f"{TAP}/{d}")
        elif cur and d not in outdated:
            continue
        else:
            if cur:
                run("brew", "fetch", d, check=False)
                run("brew", "uninstall", "--ignore-dependencies", "--force", d, check=False)
            if d.startswith("openssl"):
                unlink_openssl(d)
            if run("brew", "install", d, check=False) != 0:
                run("brew", "install", "--build-from-source", d)


def build(name, mirrored):
    """Build and upload one bottle; leaves bottles/<name>/*.json for the finalize job."""
    ver = tap_version(name)
    tag = release_tag(name, ver)
    ensure_installed_deps(name, mirrored)
    run("brew", "fetch", "--build-from-source", f"{TAP}/{name}")  # fetch first: uninstalling libssh2/openssl@3 breaks brewed curl
    run("brew", "uninstall", "--ignore-dependencies", "--force", name, check=False)
    if name.startswith("openssl"):
        unlink_openssl(name)
    else:  # keep openssl deps linked: non-keg-only deps are found via /usr/local links
        for dep in run("brew", "deps", "--include-build", f"{TAP}/{name}", capture=True).split():
            d = dep.rsplit("/", 1)[-1]
            if d.startswith("openssl"):
                unlink_openssl(d)
                run("brew", "link", "--overwrite", d, check=False)
    if run("brew", "install", "--build-bottle", f"{TAP}/{name}", check=False):
        # keg may be built with only the final link step failing on non-brew files
        if not run("brew", "list", "--versions", name, check=False, capture=True):
            sys.exit(f"brew install failed for {name}")
        run("brew", "link", "--overwrite", name)
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
