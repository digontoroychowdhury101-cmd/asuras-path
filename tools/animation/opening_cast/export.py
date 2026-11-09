"""Bake, validate and export an opening-cast character's clips.

    python tools/animation/opening_cast/export.py monk [clip ...]

Writes assets/animations/opening_cast/<key>/<Clip>.rbxmx (KeyframeSequence, the Zhao/Jian export format),
manifest.json (timing, contacts, strike checks, validation, upload status from published.json) and one root-space
frame JSON per clip in work/opening_cast_bake/<key>/ for the Blender preview of the production mesh.
"""
import contextlib
import importlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import castlib as C  # noqa: E402
import jianlib as J  # noqa: E402

SETS = {"monk": "monk_clips", "swordsman": "swordsman_clips", "warden": "warden_clips", "bull": "bull_clips", "shen": "shen_clips"}



@contextlib.contextmanager
def manifest_lock(path):
    """(2026-11-09) An exclusive lock while several exports merge into one manifest: fcntl on macOS/Linux, msvcrt on Windows (the other
    computer has no fcntl)."""
    with open(path, "w") as f:
        try:
            import fcntl
        except ImportError:
            import msvcrt
            f.write(" ")
            f.flush()
            f.seek(0)
            msvcrt.locking(f.fileno(), msvcrt.LK_LOCK, 1)
            try:
                yield
            finally:
                f.seek(0)
                msvcrt.locking(f.fileno(), msvcrt.LK_UNLCK, 1)
            return
        fcntl.flock(f, fcntl.LOCK_EX)
        yield


def main(key, names):
    import export as zx  # general_zhao/export.py: content_hash
    lib = importlib.import_module(SETS[key])
    if hasattr(lib, "check_rigs"):
        lib.check_rigs()
    out = C.ROOT / "assets/animations/opening_cast" / key
    bake = C.ROOT / "work/opening_cast_bake" / key
    out.mkdir(parents=True, exist_ok=True)
    bake.mkdir(parents=True, exist_ok=True)
    manifest_path, published_path = out / "manifest.json", out / "published.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {"clips": {}}
    published = json.loads(published_path.read_text()) if published_path.exists() else {}
    published = published.get("clips", published)   # publish.py writes {clip: record}
    failed = 0
    for clip in lib.library():
        if names and clip.name not in names:
            continue
        baked = clip.bake()
        stats, problems = getattr(lib, "validate", C.validate)(clip, baked)
        path = out / (clip.name + ".rbxmx")
        keys = getattr(lib, "write_rbxmx", J.write_rbxmx)(clip, baked, path)
        C.frames_json(clip, baked, bake / (clip.name + ".json"))
        entry = {"slot": clip.slot, "length": round(clip.length, 4), "loop": clip.loop, "priority": clip.priority, "move": clip.move,
                 "contacts": [round(c, 4) for c in clip.contacts], "keyframes": keys, "notes": clip.notes,
                 "validation": stats, "problems": problems, "uploaded": False, "asset_id": None}
        record = published.get(clip.name)
        if record and "sha256" not in record:   # publish.py's record: the id the slot plays, no content hash
            entry["asset_id"] = record["id"]
        elif record:
            if zx.content_hash(path) == record["sha256"]:
                entry["uploaded"], entry["asset_id"] = True, record["asset_id"]
            else:
                entry["stale_asset_id"] = record["asset_id"]
        manifest["clips"][clip.name] = entry
        failed += 1 if problems else 0
        print("%s %-20s %5.3fs keys %3d %s" % ("FIX" if problems else "OK ", clip.name, clip.length, keys,
                                              "; ".join(problems) or json.dumps(stats.get("strike", {}))))
    with manifest_lock(str(manifest_path) + ".lock"):   # several exports may run at once: merge this run's clips into the manifest as it is now
        mine = {k: v for k, v in manifest["clips"].items() if not names or k in names}
        manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {"clips": {}}
        manifest["clips"].update(mine)
        manifest["clips"] = dict(sorted(manifest["clips"].items()))
        manifest_path.write_text(json.dumps(manifest, indent=1))
    return failed


if __name__ == "__main__":
    sys.exit(1 if main(sys.argv[1], sys.argv[2:]) else 0)
