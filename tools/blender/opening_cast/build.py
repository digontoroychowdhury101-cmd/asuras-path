"""Build one opening-cast character (master + game geometry) into a versioned .blend.

    blender -b --factory-startup -P tools/blender/opening_cast/build.py -- monk

Writes assets/source/opening_cast/<key>/<Name>_v<N>.blend with collections <Name>_Master (subdivided
sculpt-level forms the bake reads) and <Name>_Game (the low pieces that ship). Every piece is one R15 limb
with its origin on that limb's centre, so all pieces share the rig's origins. bake.py does the rest.
"""
import importlib
import sys
import time
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
ZHAO = HERE.parent / "zhao_v2"
for p in (str(ZHAO), str(HERE)):
    if p not in sys.path:
        sys.path.insert(0, p)
ROOT = HERE.parents[2]

# key -> (module, object prefix, definition id, version)
CHARS = {
    "monk": ("monk", "Monk", "CorruptWanderingMonk", 1),
}

# R15 limb centres at scale 1 in Roblox coordinates (x, y, z), measured in Studio (the Zhao v1 manifest table)
PIVOT = {
    "Head": (0, 1.586, 0), "UpperTorso": (0, 0.2, 0), "LowerTorso": (0, -0.8, 0),
    "LeftUpperArm": (-1.5, 0.369, 0), "LeftLowerArm": (-1.5, -0.224, 0), "LeftHand": (-1.5, -0.85, 0),
    "RightUpperArm": (1.5, 0.369, 0), "RightLowerArm": (1.5, -0.224, 0), "RightHand": (1.5, -0.85, 0),
    "LeftUpperLeg": (-0.5, -1.421, 0), "LeftLowerLeg": (-0.5, -2.201, 0), "LeftFoot": (-0.5, -2.85, 0),
    "RightUpperLeg": (0.5, -1.421, 0), "RightLowerLeg": (0.5, -2.201, 0), "RightFoot": (0.5, -2.85, 0),
}


def paths(key):
    mod, name, _, ver = CHARS[key]
    out = ROOT / "assets/source/opening_cast" / key
    return out, out / f"{name}_v{ver}.blend"


def blender_pivot(bone):
    x, y, z = PIVOT[bone]
    return Vector((x, -z, y))


def make_collection(name, parent=None):
    c = bpy.data.collections.new(name)
    (parent or bpy.context.scene.collection).children.link(c)
    return c


def finish_pieces(pieces, coll, materials, suffix):
    obs = []
    for pc in pieces:
        pc.name = pc.name + suffix
        ob = pc.finish(coll, materials)
        if suffix == "_Master":
            m = ob.modifiers.new("Subdiv", "SUBSURF")
            m.levels = m.render_levels = 1
            m.boundary_smooth = "PRESERVE_CORNERS"
        piv = blender_pivot(pc.bone)
        ob.data.transform(Matrix.Translation(-piv))
        ob.location = piv
        obs.append(ob)
    return obs


def build(key, save=True):
    import cast_mats
    for m in ("lib", "body", CHARS[key][0]):
        sys.modules.pop(m, None)
    mod = importlib.import_module(CHARS[key][0])
    _, name, defid, ver = CHARS[key]
    t0 = time.time()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    materials = cast_mats.make_all(name)
    master = make_collection(f"{name}_Master")
    game = make_collection(f"{name}_Game")
    finish_pieces(mod.build(True), master, materials, "_Master")
    finish_pieces(mod.build(False), game, materials, "")
    bpy.context.scene["AsuraDefinition"] = defid
    bpy.context.scene["AsuraCastVersion"] = ver
    report = {}
    for c in (master, game):
        rows = {ob.name: sum(len(p.vertices) - 2 for p in ob.data.polygons) for ob in c.all_objects}
        report[c.name] = {"total": sum(rows.values()), "max": max(rows.values()), "pieces": rows}
    if save:
        out, blend = paths(key)
        out.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(blend), compress=True)
    print({k: (v["total"], v["max"]) for k, v in report.items()})
    print("built in %.1fs" % (time.time() - t0))
    return report


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["monk"]
    build(argv[0])
