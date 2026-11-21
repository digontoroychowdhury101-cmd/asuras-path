"""Read uploaded Model assets back from the Studio cloud window (read-only: LoadAsset, never parented) and write kit registries.

  python tools/assets/registry_readback.py vesp   <ledger.json> <split_dir> [--cache rb.json]
      -> assets/VESPERHOLD_KIT_UPLOADED.json. Split pieces (glb_split.py): modelAssets = part 1, subs from other parts carry
         their own Asset, every sub of a split piece gets its split.json center. operations.Asset = upload operation ID.
  python tools/assets/registry_readback.py forest <ledger.json> [--cache rb.json]
  python tools/assets/registry_readback.py landmark <ledger.json> <split_dir> [--cache rb.json]
      -> assets/LANDMARK_KIT_UPLOADED.json, same split handling as vesp (ledger keys landmark/<Piece>__pN).
  python tools/assets/registry_readback.py region <ledger.json> [--cache rb.json]
      -> region kits (ledger keys <kit>/<Piece>, kit = amberfall|saltreach|frostmere|ashen) -> assets/<KIT>_KIT_UPLOADED.json; every sub
         gets center = its MeshPart position from the model's bounding-box foot centre (the frame BiomeDressingService places on).
  python tools/assets/registry_readback.py forest <ledger.json> [--cache rb.json]
      -> re-uploads (ledger keys r2/<pack>/<Piece>) replace model, mesh and map IDs in the existing SLICE / HERO / BELLWOOD /
         BELLWOOD_FAR registries; centers are kept (same geometry) and the readback sub names must match the registry.
Then run tools/assets/kit_registry.py for each kit to validate and regenerate the Luau modules.
"""
import json
import os
import subprocess
import sys
from datetime import date
from pathlib import Path

STUDIO = os.environ.get("ASURA_CLOUD_STUDIO", "3a8c18c2-dd52-4834-89ac-3469ff0a5138")  # cloud window id changes per launch
MAPS = ("ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap")
FOREST = {"slice": "SLICE", "hero": "HERO", "bellwood_far": "BELLWOOD_FAR",
          "bellwood_veg": "BELLWOOD", "bellwood_built_a": "BELLWOOD", "bellwood_built_b": "BELLWOOD"}
LUAU = r'''
local HS = game:GetService("HttpService")
local out = {}
for _, id in IDS do
	local ok, m = pcall(function() return game:GetService("InsertService"):LoadAsset(id) end)
	if ok and m then
		local subs = {}
		local bcf, bsize = m:GetBoundingBox()
		local foot = bcf * CFrame.new(0, -bsize.Y / 2, 0)
		for _, d in m:GetDescendants() do
			if d:IsA("MeshPart") then
				local sa = d:FindFirstChildOfClass("SurfaceAppearance")
				local c = foot:PointToObjectSpace(d.Position)
				subs[d.Name] = { center = WITH_CENTER and { math.round(c.X * 100) / 100, math.round(c.Y * 100) / 100, math.round(c.Z * 100) / 100 } or nil, MeshId = d.MeshId, ColorMap = sa and sa.ColorMap or "", NormalMap = sa and sa.NormalMap or "",
					RoughnessMap = sa and sa.RoughnessMap or "", MetalnessMap = sa and sa.MetalnessMap or "" }
			end
		end
		out[tostring(id)] = subs
		m:Destroy()
	else
		out[tostring(id)] = { error = tostring(m) }
	end
	task.wait()
end
return HS:JSONEncode(out)
'''


def readback(ids, cache_path, with_center=False):
    cache = json.load(open(cache_path)) if cache_path and os.path.exists(cache_path) else {}
    need = [i for i in ids if i not in cache]
    if not need:
        return cache
    p = subprocess.Popen([sys.executable, "tools/run_studiomcp.py"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, encoding="utf-8")

    def send(m):
        p.stdin.write(json.dumps(m) + "\n")
        p.stdin.flush()

    def reply(rid):
        for line in p.stdout:
            try:
                m = json.loads(line)
            except ValueError:
                continue
            if m.get("id") == rid:
                return m
        sys.exit("bridge closed")

    send({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "lead-readback", "version": "1"}}})
    reply(1)
    send({"jsonrpc": "2.0", "method": "notifications/initialized"})
    for i in range(0, len(need), 8):
        chunk = need[i:i + 8]
        send({"jsonrpc": "2.0", "id": 100 + i, "method": "tools/call", "params": {"name": "execute_luau", "arguments": {
            "studio_id": STUDIO, "datamodel_type": "Edit", "code": f"local WITH_CENTER = {str(with_center).lower()}\nlocal IDS = {{" + ",".join(chunk) + "}\n" + LUAU}}})
        text = reply(100 + i)["result"]["content"][0]["text"]
        cache.update(json.loads(text[text.index("{"):]))
        if cache_path:
            json.dump(cache, open(cache_path, "w"), indent=1)
        print(f"read back {min(i + 8, len(need))}/{len(need)}")
    p.stdin.close()
    return cache


rid = lambda n: f"rbxassetid://{n}"


def got_for(cache, key, e, errs):
    got = cache.get(e["assetId"], {})
    if not got or "error" in got:
        errs.append(f"{key}: readback failed ({got.get('error')})")
        return None
    return got


def vesp(ledger, split_dir, cache_path, prefix="vesp", kit_stem="VESPERHOLD"):
    """Split-aware readback; also the open-world landmarks (prefix landmark -> assets/LANDMARK_KIT_UPLOADED.json)."""
    entries = {k: v for k, v in ledger.items() if k.startswith(prefix + "/") and v.get("assetId")}
    cache = readback([v["assetId"] for v in entries.values()], cache_path)
    splits = {f.name[:-len(".split.json")]: json.loads(f.read_text()) for f in Path(split_dir).glob("*/*.split.json")}
    models, pieces, errs = {}, {}, []
    reg = Path(f"assets/{kit_stem}_KIT_UPLOADED.json")
    before = json.loads(reg.read_text()).get("modelAssets", {}) if reg.exists() else {}
    for key, e in sorted(entries.items()):
        stem = key.split("/")[-1]
        piece, part = stem.rsplit("__", 1) if "__p" in stem else (stem, "")
        got = got_for(cache, key, e, errs)
        if got is None:
            continue
        # The importer names MeshParts by glTF mesh name; a mesh exported without the Piece__ prefix (Dead_Oak_Gnarled_A's "Chain") gets it back.
        got = {(s if "__" in s else f"{piece}__{s}"): f for s, f in got.items()}
        sm = splits.get(piece) if part else None
        if sm and sorted(got) != sorted(sm["parts"][stem + ".glb"]):
            errs.append(f"{key}: readback subs {sorted(got)} != split part {sm['parts'][stem + '.glb']}")
        if part in ("", "p1"):
            old = before.get(piece, {})  # a re-read keeps the date the asset was first registered
            when = old["uploaded"] if old.get("assetId") == rid(e["assetId"]) and old.get("uploaded") else date.today().isoformat()
            models[piece] = {"assetId": rid(e["assetId"]), "operationId": e["operationId"], "uploaded": when,
                             "moderationState": e.get("moderation")}
        for sub, fields in got.items():
            entry = {k: v for k, v in fields.items() if v}
            entry["operations"] = {"Asset": e["operationId"]}
            if sm:
                entry["center"] = sm["centres"][sub]
                if part != "p1":
                    entry["Asset"] = rid(e["assetId"])
            pieces.setdefault(piece, {})[sub] = entry
    errs += [f"{piece}: no part 1 / model asset" for piece in pieces if piece not in models]
    if errs:
        sys.exit("\n".join(errs))
    reg.write_text(json.dumps({
        "note": "Real IDs only. modelAssets = Assets API Model id (LoadAsset target; part 1 of a split piece). pieces = sub-mesh MeshId/maps "
                "read from a verified LoadAsset; split pieces carry per-sub Asset and center (tools/assets/glb_split.py).",
        "modelAssets": models, "pieces": pieces}, indent=2, sort_keys=True) + "\n")
    print(f"wrote {kit_stem}: {len(models)} pieces, {sum(len(v) for v in pieces.values())} subs")


def region(ledger, cache_path):
    entries = {k: v for k, v in ledger.items() if k.split("/")[0] in ("amberfall", "saltreach", "frostmere", "ashen") and v.get("assetId")}
    cache = readback([v["assetId"] for v in entries.values()], cache_path, with_center=True)
    regs, errs = {}, []
    for key, e in sorted(entries.items()):
        kit, piece = key.split("/")
        got = got_for(cache, key, e, errs)
        if got is None:
            continue
        man = json.load(open(f"assets/source/overworld/upload/{kit}/upload_manifest.json"))["pieces"][piece]["sub_meshes"]
        if sorted(got) != sorted(man):
            errs.append(f"{key}: readback subs {sorted(got)} != manifest {sorted(man)}")
            continue
        reg = regs.setdefault(kit, {"note": "Real IDs only. modelAssets = Assets API Model id (LoadAsset target). pieces = sub-mesh MeshId/maps and "
                                            "foot-centre center read from a verified LoadAsset (tools/assets/registry_readback.py region).",
                                    "modelAssets": {}, "pieces": {}})
        reg["modelAssets"][piece] = {"assetId": rid(e["assetId"]), "operationId": e["operationId"], "uploaded": date.today().isoformat(),
                                     "moderationState": e.get("moderation"), "source": f"assets/source/overworld/upload/{kit}/{piece}.glb"}
        reg["pieces"][piece] = {sub: {**{k: v for k, v in f.items() if v}, "operations": {"Asset": e["operationId"]}} for sub, f in got.items()}
    if errs:
        sys.exit("\n".join(errs))
    for kit, reg in regs.items():
        Path(f"assets/{kit.upper()}_KIT_UPLOADED.json").write_text(json.dumps(reg, indent=2, sort_keys=True) + "\n")
        print(f"wrote {kit.upper()}: {len(reg['modelAssets'])} pieces")


def forest(ledger, cache_path):
    entries = {k: v for k, v in ledger.items() if k.startswith("r2/") and v.get("assetId")}
    cache = readback([v["assetId"] for v in entries.values()], cache_path)
    regs, errs = {}, []
    for key, e in sorted(entries.items()):
        _, pack, piece = key.split("/")
        stem = FOREST[pack]
        reg = regs.setdefault(stem, json.load(open(f"assets/{stem}_KIT_UPLOADED.json")))
        old = reg["pieces"].get(piece)
        got = got_for(cache, key, e, errs)
        if got is None:
            continue
        if old is None or sorted(old) != sorted(got):
            errs.append(f"{key}: readback subs {sorted(got)} != registry {sorted(old or {})}")
            continue
        m = reg["modelAssets"][piece]
        reg["modelAssets"][piece] = dict(m, assetId=rid(e["assetId"]), operationId=e["operationId"], uploaded=date.today().isoformat(),
                                         moderationState=e.get("moderation"), replaces=m.get("assetId"),
                                         source=e["file"].replace("\\", "/").split("asuras-path/")[-1])
        for sub, fields in got.items():
            keep = {k: v for k, v in old[sub].items() if k not in MAPS + ("MeshId",)}
            old[sub] = {**{k: v for k, v in fields.items() if v}, **keep}
    if errs:
        sys.exit("\n".join(errs))
    for stem, reg in regs.items():
        Path(f"assets/{stem}_KIT_UPLOADED.json").write_text(json.dumps(reg, indent=2) + "\n")
        print(f"updated {stem}: {sum(1 for k in entries if FOREST[k.split('/')[1]] == stem)} pieces")


if __name__ == "__main__":
    a = sys.argv[1:]
    cache = a[a.index("--cache") + 1] if "--cache" in a else None
    if a[0] == "vesp":
        vesp(json.load(open(a[1])), a[2], cache)
    elif a[0] == "landmark":
        vesp(json.load(open(a[1])), a[2], cache, "landmark", "LANDMARK")
    elif a[0] == "region":
        region(json.load(open(a[1])), cache)
    else:
        forest(json.load(open(a[1])), cache)
