"""Bake, validate and export the Jian clips.

    python tools/animation/jian/export.py [clip ...]

Writes assets/animations/jian/<Clip>.rbxmx (KeyframeSequence, Zhao export format), manifest.json (timing, contacts,
strike checks, validation, upload status from published.json) and one root-space frame JSON per clip in
work/jian_anim_bake/ for the Blender preview and the Studio playback check.
"""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import clips  # noqa: E402
import jianlib as J  # noqa: E402

OUT = J.ROOT / "assets/animations/jian"
BAKE = J.ROOT / "work/jian_anim_bake"
PUBLISHED = OUT / "published.json"


def main(names):
    import export as zx  # general_zhao/export.py: content_hash
    OUT.mkdir(parents=True, exist_ok=True)
    BAKE.mkdir(parents=True, exist_ok=True)
    manifest_path = OUT / "manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {"clips": {}}
    published = json.loads(PUBLISHED.read_text())["clips"] if PUBLISHED.exists() else {}
    failed = 0
    for clip in clips.library():
        if names and clip.name not in names:
            continue
        baked = clip.bake()
        stats, problems = J.validate(clip, baked)
        path = OUT / (clip.name + ".rbxmx")
        keys = J.write_rbxmx(clip, baked, path)
        J.frames_json(clip, baked, BAKE / (clip.name + ".json"))
        entry = {"slot": clip.slot, "length": round(clip.length, 4), "loop": clip.loop, "priority": clip.priority, "move": clip.move,
                 "contacts": [round(c, 4) for c in clip.contacts], "keyframes": keys, "notes": clip.notes,
                 "validation": stats, "problems": problems, "uploaded": False, "asset_id": None}
        record = published.get(clip.name)
        if record:
            if zx.content_hash(path) == record["sha256"]:
                entry["uploaded"], entry["asset_id"] = True, record["asset_id"]
            else:
                entry["stale_asset_id"] = record["asset_id"]
        manifest["clips"][clip.name] = entry
        failed += 1 if problems else 0
        print("%s %-22s %5.3fs keys %3d %s" % ("FIX" if problems else "OK ", clip.name, clip.length, keys,
                                              "; ".join(problems) or json.dumps(stats.get("strike", {}))))
    manifest["clips"] = dict(sorted(manifest["clips"].items()))
    manifest_path.write_text(json.dumps(manifest, indent=1))
    return failed


if __name__ == "__main__":
    sys.exit(1 if main(sys.argv[1:]) else 0)
