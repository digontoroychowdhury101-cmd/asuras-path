# fetch_boss_inputs.py [--branch REF] [--dest DIR] [--apply] : (2026-11-09) copy the boss prompt pack and the nine source GLBs from the
# data-only Git branch boss-inputs-2026-11-05 into work/boss_inputs/ (gitignored), so any computer has them without USB.
# Fetch first:  git fetch origin boss-inputs-2026-11-05:refs/remotes/origin/boss-inputs-2026-11-05
# Reads the files straight out of Git (no checkout; this branch is untouched) and checks each against the branch's MANIFEST.sha256.
# Default is a dry run listing "add" (missing), "same" (identical) or "DIFFERENT" (a file is already there and differs). --apply writes
# only the missing files; a DIFFERENT file is never overwritten.
import sys, os, hashlib, subprocess
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
args = sys.argv[1:]
def opt(name, default):
    return args[args.index(name) + 1] if name in args and args.index(name) + 1 < len(args) else default
BRANCH = opt("--branch", "origin/boss-inputs-2026-11-05")
DEST = os.path.abspath(opt("--dest", os.path.join(ROOT, "work", "boss_inputs")))
APPLY = "--apply" in args


def git(*a):
    r = subprocess.run(["git"] + list(a), cwd=ROOT, capture_output=True)
    if r.returncode:
        sys.exit("STOP: git %s failed: %s\nFetch first: git fetch origin boss-inputs-2026-11-05:refs/remotes/origin/boss-inputs-2026-11-05"
                 % (" ".join(a[:2]), r.stderr.decode(errors="replace").strip()))
    return r.stdout


man = [l.split("  ", 1) for l in git("show", BRANCH + ":MANIFEST.sha256").decode().splitlines() if l.strip()]
if not man:
    sys.exit("STOP: the manifest on %s is empty" % BRANCH)
plan = {"add": [], "same": [], "DIFFERENT": []}
blobs = {}
for h, rel in man:
    data = git("cat-file", "blob", "%s:%s" % (BRANCH, rel))
    if hashlib.sha256(data).hexdigest() != h:
        sys.exit("STOP: %s on %s does not match its SHA-256 in MANIFEST.sha256" % (rel, BRANCH))
    dest = os.path.join(DEST, *rel.split("/"))
    if not os.path.exists(dest):
        plan["add"].append(rel); blobs[rel] = data
    else:
        with open(dest, "rb") as f:
            plan["same" if hashlib.sha256(f.read()).hexdigest() == h else "DIFFERENT"].append(rel)
print("%d files on %s, all match the manifest; destination %s" % (len(man), BRANCH, DEST))
for k in ("add", "same", "DIFFERENT"):
    print("%-9s %d" % (k, len(plan[k])))
    for rel in plan[k] if k != "same" else []:
        print("    ", rel)
if not APPLY:
    print("dry run: nothing written. Re-run with --apply to add the missing files.")
    sys.exit(0)
for rel in plan["add"]:
    dest = os.path.join(DEST, *rel.split("/"))
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with open(dest, "wb") as f:
        f.write(blobs[rel])
print("wrote %d files; %d DIFFERENT left as they were" % (len(plan["add"]), len(plan["DIFFERENT"])))
