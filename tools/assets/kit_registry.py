"""Validate an uploaded overworld kit registry and write the Luau module the game requires. Never uploads or invents IDs.
python3 tools/assets/kit_registry.py slice [--check] [--allow-missing Piece | Piece__Sub ...] [--root DIR]
Reads assets/<KIT>_UPLOADED.json (vesperhold: absent = empty module) ({"modelAssets": {Piece: {assetId}}, "pieces": {Piece: {Piece__Sub: {MeshId, ColorMap, NormalMap, RoughnessMap[, MetalnessMap], center?, operations?}}}})
and the pack's upload_manifest.json; each sub entry also gets Asset = the piece's modelAssets assetId (the LoadAsset target). Writes src/shared/<Module>.luau (siblings of SliceDressing / BiomeDressing, which pcall-require them).
"""
import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BELLWOOD = ("bellwood_veg", "bellwood_built_a", "bellwood_built_b")
# kit -> (json stem, module, packs validated together). The three Bellwood packs share one JSON and one module, so any of them validates/writes all three.
KITS = {
    "slice": ("SLICE", "SliceKitRegistry", ("slice",)),
    "bellwood_far": ("BELLWOOD_FAR", "BellwoodFarKitRegistry", ("bellwood_far",)),
    "hero": ("HERO", "HeroKitRegistry", ("hero",)),
    **{k: ("BELLWOOD", "BellwoodKitRegistry", BELLWOOD) for k in BELLWOOD},
    **{k: (k.upper(), k.capitalize() + "KitRegistry", (k,)) for k in ("amberfall", "saltreach", "frostmere", "ashen")},
    # Vesperhold kit/props/trees: one JSON (assets/VESPERHOLD_KIT_UPLOADED.json), manifests at assets/source/vesperhold/<pack>/manifest.json.
    "vesperhold": ("VESPERHOLD", "VesperholdKitRegistry", ("kit", "props", "trees")),
    # Open-world landmarks (LANDMARK-BUILD-SPEC): one JSON, generator manifests at assets/source/landmarks/<pack>/manifest.json.
    "landmark": ("LANDMARK", "LandmarkKitRegistry", ("bellwood_face", "bellwood_temple", "bellwood_gate", "bellwood_temple_colossal",
                                              "bellwood_colonnade", "bellwood_lotus")),
}
# Kits whose registry may not exist yet (nothing uploaded): validate() returns an empty registry and the module is written empty.
OPTIONAL = {"vesperhold", "landmark"}
# Kits whose manifest is the Vesperhold generator's (pieces -> sub_meshes), not an importer upload_manifest.
VESP_MANIFEST = "assets/source/vesperhold/{pack}/manifest.json"
# Kits whose uploaded GLBs may carry maps their upload manifest does not list (Vesperhold maps travel in the model; the far
# atlases gained Normal + metallicRoughness in the mac-26/mac-30 re-tone).
EXTRA_MAPS = {"vesperhold", "bellwood_far", "landmark"}
# Required today: SliceKitRegistry (SliceDressing.luau pcall-require), Amberfall/SaltreachKitRegistry (BiomeDressing.luau). The rest have no consumer yet.
ID = re.compile(r"rbxassetid://[1-9][0-9]{5,19}")
MAPS = ("ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap")


def load(path):
    try:
        return json.loads(Path(path).read_text())
    except (OSError, ValueError) as e:
        raise SystemExit(f"cannot read {path}: {e}")


def validate(kit, root, allow_missing=(), vesp_manifests=None):
    """Return (errors, pieces) where pieces = {piece: {key: entry}} ready to write (allowed-missing subs omitted)."""
    stem, _, packs = KITS[kit]
    path = root / f"assets/{stem}_KIT_UPLOADED.json"
    if kit in OPTIONAL and not path.exists():
        return [], {}
    data = load(path)
    reg = data.get("pieces") if isinstance(data, dict) else None
    if not isinstance(reg, dict):
        return [f"{stem}_KIT_UPLOADED.json: no 'pieces' object"], {}
    errs, out, expected, seen = [], {}, set(), {}
    models = data.get("modelAssets") if isinstance(data.get("modelAssets"), dict) else {}
    for pack in packs:
        if kit in ("vesperhold", "landmark"):
            man = load(Path(vesp_manifests) / pack / "manifest.json" if vesp_manifests
                       else root / (VESP_MANIFEST if kit == "vesperhold" else "assets/source/landmarks/{pack}/manifest.json").format(pack=pack))
            # Textures travel inside the uploaded model (SurfaceAppearance), so only MeshId is required per sub-mesh.
            for pm in man["pieces"].values():
                pm["sub_mesh_materials"] = {k: "" for k in pm["sub_meshes"]}
        else:
            man = load(root / f"assets/source/overworld/upload/{pack}/upload_manifest.json")
        for piece, pm in man["pieces"].items():
            mats = man.get("materials", {})
            for key, mat in pm["sub_mesh_materials"].items():
                expected.add(key)
                if key.split("__")[0] != piece:
                    errs.append(f"{pack}: manifest key {key} does not start with {piece}__")
                entry = (reg.get(piece) or {}).get(key)
                if entry is None:
                    if key not in allow_missing and piece not in allow_missing:
                        errs.append(f"missing sub-mesh {key} (use --allow-missing to omit)")
                    continue
                need = ("MeshId",) + tuple(m for m in MAPS if m in mats.get(mat, pm.get("maps_per_material", {}).get(mat, {})))
                bad = [k for k in entry if k not in MAPS + ("MeshId", "center", "operations", "Asset")]
                errs += [f"{key}: unknown field {k}" for k in bad]
                # No SurfaceAppearance (far trees): every map empty is accepted; otherwise each listed map must be present.
                bare = not any(entry.get(m) for m in MAPS)
                for f in MAPS + ("MeshId",):
                    v = entry.get(f)
                    if v:
                        if not (isinstance(v, str) and ID.fullmatch(v)):
                            errs.append(f"{key}.{f}: not a rbxassetid://<positive integer> string ({v!r})")
                        elif f not in need and f != "MetalnessMap" and kit not in EXTRA_MAPS:  # importer derives MetalnessMap from packed metallicRoughness
                            errs.append(f"{key}.{f}: material {mat} has no such map")
                    elif f in need and not (bare and f != "MeshId"):
                        errs.append(f"{key}.{f}: not a rbxassetid://<positive integer> string ({v!r})")
                    if f == "MeshId" and isinstance(v, str):
                        # Roblox dedupes identical images, so map IDs may repeat; mesh IDs may not, except across Vesperhold pieces
                        # (identical geometry dedupes too, and VesperholdKit resolves each piece inside its own model by name).
                        prev = seen.setdefault((piece, v) if kit == "vesperhold" else v, key)
                        if prev != key:
                            errs.append(f"{key}.MeshId: ID {v} already used by {prev}")
                c = entry.get("center")
                if c is not None and not (isinstance(c, list) and len(c) == 3 and all(isinstance(n, (int, float)) and not isinstance(n, bool) for n in c)):
                    errs.append(f"{key}.center: want [x, y, z] numbers")
                ops = entry.get("operations")
                if ops is not None and not (isinstance(ops, dict) and all(isinstance(v, (str, int)) and str(v) for v in ops.values())):
                    errs.append(f"{key}.operations: want {{field: operation id}}")
                # A piece over the 20 MB upload limit is split (tools/assets/glb_split.py); its later parts name their own Asset.
                asset = entry.get("Asset") or (models.get(piece) or {}).get("assetId")
                if not (isinstance(asset, str) and ID.fullmatch(asset)):
                    errs.append(f"{key}: modelAssets.{piece}.assetId is not a rbxassetid://<positive integer> string ({asset!r})")
                out.setdefault(piece, {})[key] = dict(entry, Asset=asset)
    for piece, subs in out.items():
        if len({e["Asset"] for e in subs.values()}) > 1:
            errs += [f"{k}: {piece} spans several model assets, so every sub needs a center" for k, e in subs.items() if e.get("center") is None]
    for piece, subs in reg.items():
        for key in subs if isinstance(subs, dict) else ():
            if key not in expected:
                errs.append(f"{key}: not a sub-mesh in the {'/'.join(packs)} manifest")
    return errs, out


def luau(kit, pieces):
    stem, module, _ = KITS[kit]
    lines = [f"-- Generated by tools/assets/kit_registry.py from assets/{stem}_KIT_UPLOADED.json. Do not edit by hand.", "return {"]
    for piece in sorted(pieces):
        lines.append(f"\t[{json.dumps(piece)}] = {{")
        for key in sorted(pieces[piece]):
            e = pieces[piece][key]
            f = [f"{k} = {json.dumps(e[k])}" for k in ("MeshId", "Asset") + MAPS if e.get(k)]
            if e.get("center"):
                f.append("center = { " + ", ".join(repr(float(n)) for n in e["center"]) + " }")
            lines.append(f"\t\t[{json.dumps(key)}] = {{ " + ", ".join(f) + " },")
        lines.append("\t},")
    return "\n".join(lines + ["}", ""])


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("kit", choices=sorted(KITS))
    ap.add_argument("--check", action="store_true", help="validate only, write nothing")
    ap.add_argument("--allow-missing", action="append", default=[], metavar="PIECE|PIECE__SUB")
    ap.add_argument("--root", type=Path, default=ROOT)
    ap.add_argument("--vesp-manifests", type=Path, help="folder with kit/props/trees/manifest.json (default assets/source/vesperhold)")
    a = ap.parse_args(argv)
    errs, pieces = validate(a.kit, a.root, set(a.allow_missing), a.vesp_manifests)
    if errs:
        print("\n".join(errs), file=sys.stderr)
        print(f"REFUSED: {len(errs)} problem(s); nothing written", file=sys.stderr)
        return 1
    if not a.check:
        (a.root / "src/shared" / f"{KITS[a.kit][1]}.luau").write_text(luau(a.kit, pieces))
    print(f"{'OK' if a.check else 'wrote ' + KITS[a.kit][1] + '.luau'}: {sum(map(len, pieces.values()))} sub-meshes in {len(pieces)} pieces")
    return 0


if __name__ == "__main__":
    sys.exit(main())
