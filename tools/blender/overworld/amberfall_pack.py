"""Merge the per-family Amberfall part files into the upload pack manifest + UPLOAD.md (stdlib only, no Blender).

python tools/blender/overworld/amberfall_pack.py

Supersedes: nothing (make_upload_pack.py handles slice/hero only; the Bellwood packs are written by their own scripts). Linked via workers/23a-amber-kit.md
(the lead links it from LEDGER.md). New file because each family run writes only its own parts/<family>.json; this merges them.
Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

Re-reads every GLB in the pack and fails loudly if a sub-mesh is >= 18000 tris, a texture is > 1024 px, or a part entry disagrees with its GLB. Never uploads, never invents IDs.
"""
import json
import shutil
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "assets/source/overworld/amberfall"
UP = ROOT / "assets/source/overworld/upload/amberfall"
CAP = 18000
FAMILIES = ("veg", "rock", "built", "hero")


def glb_json(path):
    data = path.read_bytes()
    assert data[:4] == b"glTF", path
    n = struct.unpack_from("<I", data, 12)[0]
    return json.loads(data[20:20 + n])


def png_size(path):
    with open(path, "rb") as f:
        h = f.read(24)
    return list(struct.unpack(">II", h[16:24]))


pieces, problems = {}, []
for fam in FAMILIES:
    part = SRC / "parts" / f"{fam}.json"
    if part.exists():
        pieces.update(json.loads(part.read_text())["pieces"])
for name, p in pieces.items():
    g = glb_json(UP / p["file"])
    tris = {}
    for node in g["nodes"]:
        if "mesh" in node:
            m = g["meshes"][node["mesh"]]
            tris[node.get("name") or m["name"]] = sum(g["accessors"][pr["indices"]]["count"] // 3 for pr in m["primitives"])
    if tris != p["sub_meshes"]:
        problems.append(f"{name}: manifest sub-meshes differ from GLB")
    for sub, t in tris.items():
        if t >= CAP:
            problems.append(f"{sub} {t} tris >= {CAP}")
    if p["texture_max_px"] > 1024:
        problems.append(f"{name} texture {p['texture_max_px']} > 1024")
(UP / "maps").mkdir(parents=True, exist_ok=True)
mats = sorted({m for p in pieces.values() for m in p["sub_mesh_materials"].values()})
materials = {}
for m in mats:
    maps = {}
    for slot, suf in (("ColorMap", "Color"), ("NormalMap", "Normal"), ("RoughnessMap", "Roughness"), ("MetalnessMap", "Metal")):
        f = SRC / "maps" / f"{m}_{suf}.png"
        if f.exists():
            shutil.copy2(f, UP / "maps" / f.name)
            maps[slot] = {"file": "maps/" + f.name, "size_px": png_size(f)}
            if max(maps[slot]["size_px"]) > 1024:
                problems.append(f"{f.name} > 1024")
    materials[m] = maps
for p in pieces.values():
    p["maps_per_material"] = {m: materials[m] for m in sorted(set(p["sub_mesh_materials"].values()))}
largest = max(((t, f"{n}__{s}" if not s.startswith(n) else s) for n, p in pieces.items() for s, t in p["sub_meshes"].items()))
(UP / "upload_manifest.json").write_text(json.dumps({
    "format": "GLB (glTF 2.0, textures embedded; same maps also loose in maps/)",
    "units": "1 stud = 1 unit, Y up after import",
    "tri_cap_per_sub_mesh": CAP,
    "registry_file": "assets/AMBERFALL_KIT_UPLOADED.json",
    "registry_shape": {"pieces": {"<Piece>": {"<Piece>__<Sub>": {"MeshId": "rbxassetid://...", "ColorMap": "", "NormalMap": "", "RoughnessMap": "", "MetalnessMap": ""}}}},
    "no_ids_yet": True,
    "studio_import_notes": ["3D Importer, Scale 1, one MeshPart per sub-mesh (Piece__Sub), pivot at base centre (Y up)",
                            "One SurfaceAppearance per material from maps/ (Color, Normal OpenGL, Roughness; Amb_Bronze also Metalness)",
                            "Amb_Grass blade strips are single sided: set DoubleSided = true on Amber_Grass_*__Blades",
                            "Amb_Leaf is a 1024 flat-colour atlas (five palette bands), Amb_Sandstone a 1024 four-quadrant atlas: leave StudsPerTile default",
                            "Wind sway from height above the base pivot; Leaves_Detail parts may be dropped beyond ~150 studs",
                            "Amber_Aqueduct_Hero matches the placeholder slot Ravine_Aqueduct_Arch (120 x 82 x 26, sub-meshes Piers / Arches / Deck); aqueduct span sections tile on a 24 stud pitch"],
    "pieces": pieces,
    "materials": materials,
    "manifest_check": "problems: " + (", ".join(problems) if problems else "none"),
}, indent=2) + "\n")

rows = "\n".join(f"| {n} | {p['family']} | {p['tris_total']} | {max(p['sub_meshes'].values())} | {p['texture_max_px']} | {p['file_size_bytes'] // 1024} | "
                f"{p['size_studs_xyz_roblox'][0]} x {p['size_studs_xyz_roblox'][2]} x {p['size_studs_xyz_roblox'][1]} |" for n, p in sorted(pieces.items()))
(UP / "UPLOAD.md").write_text(f"""# Amberfall Ravine kit: by-hand Studio 3D Importer steps

{len(pieces)} GLBs in this folder; per-piece data (sub-mesh tris, bbox, texture size, file size, maps) in `upload_manifest.json`. Regenerate with the four
family scripts (`blender -b -P tools/blender/overworld/amberfall_veg.py | _rock.py | _built.py | _hero.py`) then `python tools/blender/overworld/amberfall_pack.py`.
GLB, not FBX: the importer turns glTF PBR into SurfaceAppearance by itself. Largest sub-mesh {largest[0]} tris ({largest[1]}); cap 18000. Textures <= 1024.
No assets have been uploaded; the registry has no IDs.

1. Open `places/AsurasPath.rbxlx` in Studio. View > Asset Manager > Bulk Import (or Avatar > Import 3D). Creator: Me.
2. Import settings: Scale 1 (1 unit = 1 stud), Import As: Model (one MeshPart per sub-mesh, names `Piece__Sub`), Insert Using Scene Position off, Upload To Roblox on. No auto-fix or mesh simplification.
3. Check each result: MeshParts keep their `Piece__Sub` names, pivot at the base centre (Y up). Each MeshPart has a SurfaceAppearance with Color, Normal, Roughness (Amb_Bronze also Metalness); if one is missing build it from `maps/<Material>_<Color|Normal|Roughness|Metal>.png`.
4. Set DoubleSided = true on `Amber_Grass_*__Blades`. Mark `*__Leaves_Detail` parts as detail (client drops them past ~150 studs).
5. Parent each finished Model to `ServerStorage/AmberfallKit/<Piece>` (the file name without `.glb`).
6. Record IDs in `assets/AMBERFALL_KIT_UPLOADED.json` (new file, same shape as `assets/SLICE_KIT_UPLOADED.json`). IDs come from the MeshPart/SurfaceAppearance properties in Studio; never guess.
7. `Amber_Aqueduct_Hero` is the refined replacement for the `Ravine_Aqueduct_Arch` slot in `src/shared/BiomeDressing.luau` (same size and sub-mesh names). Aqueduct spans (`Amber_Aqueduct_Span_*`) are 24 studs wide with half piers at both ends so they tile edge to edge.

| Piece | Family | Tris | Largest sub-mesh | Texture px | GLB KB | Size X x Z x Y (studs) |
|---|---|---|---|---|---|---|
{rows}
""", encoding="utf-8")
print("pack", len(pieces), "pieces", len(materials), "materials; largest", largest, "; problems:", problems or "none")
sys.exit(1 if problems else 0)
