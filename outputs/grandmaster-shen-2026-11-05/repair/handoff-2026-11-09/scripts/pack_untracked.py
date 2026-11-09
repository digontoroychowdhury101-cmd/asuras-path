# pack_untracked.py OUTDIR : (handoff 2026-11-09) the Shen files Git does not carry, in one zip at their project-relative paths, with a SHA-256
# manifest. Takes every file under the folders below that `git ls-files` does not list (tracked ones come with the branch), except the
# Blender autosave backup (*.blend1) and work/shen_import/preview (review renders the pipeline never reads). Writes OUTDIR/<zip>,
# OUTDIR/ARCHIVE_MANIFEST.sha256 (sha256sum -c format, paths relative to the repo root) and copies the manifest beside this folder.
import sys, os, hashlib, subprocess, zipfile, shutil
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(HERE, "../../../../.."))
OUT = os.path.abspath(sys.argv[1])
FOLDERS = ["assets/source/bosses/grandmaster_shen", "assets/build/grandmaster_shen", "work/shen_import", "work/opening_cast_bake/shen"]
SKIP_DIRS = {"work/shen_import/preview"}
os.makedirs(OUT, exist_ok=True)
tracked = set(subprocess.run(["git", "ls-files"] + FOLDERS, cwd=ROOT, capture_output=True, text=True, check=True).stdout.splitlines())
files = []
for top in FOLDERS:
    for d, dirs, names in os.walk(os.path.join(ROOT, top)):
        rel_d = os.path.relpath(d, ROOT).replace(os.sep, "/")
        dirs[:] = sorted(x for x in dirs if rel_d + "/" + x not in SKIP_DIRS)
        for n in sorted(names):
            rel = rel_d + "/" + n
            if n.endswith(".blend1") or n == ".DS_Store" or rel in tracked:
                continue
            files.append(rel)
lines, total = [], 0
zpath = os.path.join(OUT, "shen-untracked-2026-11-09.zip")
with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED, compresslevel=6, allowZip64=True) as z:
    for rel in files:
        fp = os.path.join(ROOT, rel)
        h = hashlib.sha256()
        with open(fp, "rb") as f:
            for b in iter(lambda: f.read(1 << 20), b""):
                h.update(b)
        lines.append("%s  %s" % (h.hexdigest(), rel))
        total += os.path.getsize(fp)
        z.write(fp, rel)
    head = "# Shen untracked files, %d files, %.1f MB uncompressed; paths relative to the repo root; sha256sum -c compatible\n" % (len(files), total / 1e6)
    z.writestr("ARCHIVE_MANIFEST.sha256", head + "\n".join(lines) + "\n")
man = os.path.join(OUT, "ARCHIVE_MANIFEST.sha256")
open(man, "w").write(head + "\n".join(lines) + "\n")
shutil.copy(man, os.path.join(HERE, "..", "ARCHIVE_MANIFEST.sha256"))
zh = hashlib.sha256()
with open(zpath, "rb") as f:
    for b in iter(lambda: f.read(1 << 20), b""):
        zh.update(b)
open(zpath + ".sha256", "w").write("%s  %s\n" % (zh.hexdigest(), os.path.basename(zpath)))
print(len(files), "files", round(total / 1e6, 1), "MB ->", zpath, round(os.path.getsize(zpath) / 1e6, 1), "MB sha256", zh.hexdigest())
