"""Publish an opening-cast character's clips from the open Studio (Edit) and record the read-back ids.

    python tools/animation/opening_cast/publish.py monk STUDIO_ID [Clip ...]

Each clip goes through studio_luau.py --publish (CreateAssetAsync, then KeyframeSequenceProvider read-back) over the
local StudioMCP proxy, so the 30-90 KB keyframe scripts never pass through a chat. A clip counts as published only
when the read-back keyframe count equals the count sent. Results merge into
assets/animations/opening_cast/<key>/published.json as {clip: {slot, id, keyframes, length}}.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(Path(__file__).resolve().parent))
from studio_luau import script  # noqa: E402
from studio_mcp import Client  # noqa: E402


def main():
    key, studio, wanted = sys.argv[1], sys.argv[2], sys.argv[3:]
    base = ROOT / "assets/animations/opening_cast" / key
    manifest = json.loads((base / "manifest.json").read_text())["clips"]
    out_path = base / "published.json"
    published = json.loads(out_path.read_text()) if out_path.exists() else {}
    client = Client()
    failed = 0
    try:
        for clip in wanted or sorted(manifest):
            ok, text = client.call("execute_luau", {"code": script(key, clip, "publish"), "datamodel_type": "Edit", "studio_id": studio})
            try:
                start = text.index("{")
                result = json.loads(text[start:text.rindex("}") + 1])
            except ValueError:
                result = {"error": text[:300]}
            if not ok or "error" in result or result.get("keyframes") != result.get("sent"):
                failed += 1
                print("FAIL", clip, result)
                continue
            published[clip] = {"slot": manifest[clip]["slot"], "id": "rbxassetid://%s" % result["id"],
                               "keyframes": result["keyframes"], "length": result["length"]}
            out_path.write_text(json.dumps(published, indent=2, sort_keys=True) + "\n")
            print("OK", clip, published[clip]["id"], result["keyframes"], "keyframes")
    finally:
        client.close()
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
