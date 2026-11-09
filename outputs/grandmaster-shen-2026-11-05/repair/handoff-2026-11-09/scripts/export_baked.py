# export_baked.py DIR CLIP...: write rbxmx, frame JSON and manifest entries from bakes torsotest saved (SHEN_SAVE_BAKED=DIR): the same calls export.py makes after clip.bake()
import sys, os, json, pickle, fcntl
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
from pathlib import Path
import castlib as C, jianlib as J, shen_clips as lib
import export as zx
src = sys.argv[1]; names = sys.argv[2:]
out = C.ROOT / "assets/animations/opening_cast/shen"; bake = C.ROOT / "work/opening_cast_bake/shen"
manifest_path, published_path = out / "manifest.json", out / "published.json"
published = json.loads(published_path.read_text()) if published_path.exists() else {}
published = published.get("clips", published)
mine = {}
for clip in lib.library():
    short = clip.name.replace("GrandmasterShen_", "")
    if short not in names: continue
    baked = pickle.load(open(os.path.join(src, short + ".pkl"), "rb"))
    stats, problems = getattr(lib, "validate", C.validate)(clip, baked)
    path = out / (clip.name + ".rbxmx")
    keys = getattr(lib, "write_rbxmx", J.write_rbxmx)(clip, baked, path)
    C.frames_json(clip, baked, bake / (clip.name + ".json"))
    entry = {"slot": clip.slot, "length": round(clip.length, 4), "loop": clip.loop, "priority": clip.priority, "move": clip.move,
             "contacts": [round(c, 4) for c in clip.contacts], "keyframes": keys, "notes": clip.notes,
             "validation": stats, "problems": problems, "uploaded": False, "asset_id": None}
    record = published.get(clip.name)
    if record and "sha256" not in record:
        entry["asset_id"] = record["id"]
    elif record:
        if zx.content_hash(path) == record["sha256"]:
            entry["uploaded"], entry["asset_id"] = True, record["asset_id"]
        else:
            entry["stale_asset_id"] = record["asset_id"]
    mine[clip.name] = entry
    print("%s %-20s %5.3fs keys %3d %s" % ("FIX" if problems else "OK ", clip.name, clip.length, keys, "; ".join(problems) or json.dumps(stats.get("strike", {}))), flush=True)
with open(str(manifest_path) + ".lock", "w") as lock:
    fcntl.flock(lock, fcntl.LOCK_EX)
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {"clips": {}}
    manifest["clips"].update(mine)
    manifest["clips"] = dict(sorted(manifest["clips"].items()))
    manifest_path.write_text(json.dumps(manifest, indent=1))
