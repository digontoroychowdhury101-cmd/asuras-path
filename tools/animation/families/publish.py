"""Publish the family clips from the open Studio (Edit) and record the read-back ids.

    python3 tools/animation/families/publish.py STUDIO_NAME_PART [Clip ...]

Each clip goes through jian/studio_luau.py's publish script (CreateAssetAsync under the signed-in Studio user, then
KeyframeSequenceProvider read-back) over the local StudioMCP proxy. A clip counts as published only when the read-back keyframe count
equals the count sent. A clip already recorded with the same content hash is skipped, so an interrupted run resumes; after each clip the
result is saved to assets/animations/families/published.json, and a clip with validator problems is refused.
"""
import json
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "tools/animation/jian"))
from studio_luau import script  # noqa: E402
from studio_mcp import Client  # noqa: E402

BASE = ROOT / "assets/animations/families"
NOTE = ("Published Roblox ids for the weapon-family and universal clips of tools/animation/families (Mac Stage 3), each verified by loading it back. "
        "sha256 is the referent-free content of the uploaded .rbxmx.")


def main():
    want, wanted = sys.argv[1], sys.argv[2:]
    manifest = json.loads((BASE / "manifest.json").read_text())["clips"]
    out_path = BASE / "published.json"
    published = json.loads(out_path.read_text()) if out_path.exists() else {"note": NOTE, "clips": {}}
    client = Client()
    studio = next(s["id"] for s in json.loads(client.call("list_roblox_studios", {})[1])["studios"] if want in (s.get("name") or ""))
    failed = done = skipped = 0
    try:
        for name in wanted or sorted(manifest):
            entry = manifest[name]
            record = published["clips"].get(name)
            if record and record["sha256"] == entry["sha256"]:
                skipped += 1
                continue
            if entry["problems"]:
                print("REFUSED", name, entry["problems"])
                failed += 1
                continue
            code = script(name, True, "assets/animations/families", "Asura's Path combat clip")
            # Asset creation is rate limited (UploadFailed after about 20 quick uploads): pace it, and wait out a refusal.
            for attempt in range(6):
                ok, text = client.call("execute_luau", {"code": code, "datamodel_type": "Edit", "studio_id": studio})
                try:
                    result = json.loads(text[text.index("{"):text.rindex("}") + 1])
                except ValueError:
                    result = {"error": text[:300]}
                if "UploadFailed" not in str(result.get("error")):
                    break
                print("WAIT", name, "attempt", attempt + 1, flush=True)
                time.sleep(45 * (attempt + 1))
            time.sleep(3)
            if not ok or "error" in result or result.get("keyframes") != result.get("sent"):
                failed += 1
                print("FAIL", name, result, flush=True)
                if failed >= 3:
                    break
                continue
            published["clips"][name] = {"asset_id": "rbxassetid://%s" % result["id"], "sha256": entry["sha256"], "slot": entry["slot"], "keyframes": result["keyframes"],
                                        "length": round(result["length"], 4)}
            published["clips"] = dict(sorted(published["clips"].items()))
            out_path.write_text(json.dumps(published, indent=1))
            done += 1
            print("OK", name, result["id"], result["keyframes"], flush=True)
    finally:
        client.close()
    print("published %d, already current %d, failed %d" % (done, skipped, failed))
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
