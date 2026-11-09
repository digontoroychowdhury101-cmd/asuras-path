# restore_untracked.py ZIP [--apply] [--replace-different] : (handoff 2026-11-09) put the Shen files Git does not carry back at their
# project-relative paths. Every entry is checked against the SHA-256 manifest inside the zip first; a zip that does not match stops here.
# Default is a dry run: it lists, per file, "add" (missing here), "same" (already identical) or "DIFFERENT" (a file is already there and
# differs). --apply writes only the "add" files. A DIFFERENT file is never touched unless --replace-different is also given, and then the
# existing file is first renamed to <name>.before-handoff-2026-11-09 beside it. Nothing outside the repo is written.
import sys, os, hashlib, zipfile
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(HERE, "../../../../.."))
args = [a for a in sys.argv[1:] if not a.startswith("--")]
APPLY, REPLACE = "--apply" in sys.argv, "--replace-different" in sys.argv
if not args:
    sys.exit(__doc__ or "usage: restore_untracked.py ZIP [--apply] [--replace-different]")
zpath = args[0]


def sha(read):
    h = hashlib.sha256()
    for b in iter(lambda: read(1 << 20), b""):
        h.update(b)
    return h.hexdigest()


with zipfile.ZipFile(zpath) as z:
    man = [l.split("  ", 1) for l in z.read("ARCHIVE_MANIFEST.sha256").decode().splitlines() if l and not l.startswith("#")]
    repo_man = os.path.join(HERE, "..", "ARCHIVE_MANIFEST.sha256")
    if os.path.isfile(repo_man) and open(repo_man).read().split("\n", 1)[1] != z.read("ARCHIVE_MANIFEST.sha256").decode().split("\n", 1)[1]:
        sys.exit("STOP: the zip's manifest differs from the one committed in Git (%s): wrong or altered archive" % repo_man)
    broken = []
    for h, rel in man:
        with z.open(rel) as f:
            if sha(f.read) != h:
                broken.append(rel)
    if broken:
        sys.exit("STOP: %d archive entries do not match their SHA-256: %s" % (len(broken), broken[:5]))
    plan = {"add": [], "same": [], "DIFFERENT": []}
    for h, rel in man:
        dest = os.path.join(ROOT, *rel.split("/"))
        if not os.path.exists(dest):
            plan["add"].append(rel)
        else:
            with open(dest, "rb") as f:
                plan["same" if sha(f.read) == h else "DIFFERENT"].append(rel)
    for k in ("add", "same", "DIFFERENT"):
        print("%-9s %d" % (k, len(plan[k])))
        for rel in plan[k] if k != "same" else []:
            print("    ", rel)
    if not APPLY:
        print("dry run: nothing written. Re-run with --apply to add the missing files%s." % (" (DIFFERENT files are left alone unless you also pass --replace-different)" if plan["DIFFERENT"] else ""))
        sys.exit(0)
    todo = plan["add"] + (plan["DIFFERENT"] if REPLACE else [])
    for rel in todo:
        dest = os.path.join(ROOT, *rel.split("/"))
        if os.path.exists(dest):
            os.replace(dest, dest + ".before-handoff-2026-11-09")
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with z.open(rel) as src, open(dest, "wb") as out:
            while True:
                b = src.read(1 << 20)
                if not b:
                    break
                out.write(b)
    print("wrote %d files; %d DIFFERENT left as they were" % (len(todo), 0 if REPLACE else len(plan["DIFFERENT"])))
