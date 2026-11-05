"""Build one armour set (master + game geometry) into a fresh .blend.

    Blender -b --factory-startup -P tools/blender/armour/build.py -- cinnabar

Writes assets/source/armour/<set>/<set>.blend. Baking and export are bake.py. Sets are python modules beside this one.
"""
import importlib
import sys
import time
from pathlib import Path

import bpy
from mathutils import Matrix

HERE = Path(__file__).resolve().parent
sys.path[:0] = [str(HERE), str(HERE.parent / "zhao_v2")]
import armour_mats  # noqa: E402
import kit  # noqa: E402

ROOT = HERE.parents[2]
SET = sys.argv[sys.argv.index("--") + 1]
OUT = ROOT / "assets/source/armour" / SET
LIMIT = 18000


def finish(pieces, coll, materials, suffix):
    obs = []
    for pc in pieces:
        pc.name += suffix
        ob = pc.finish(coll, materials)
        piv = kit.PIVOT[pc.bone]
        ob.data.transform(Matrix.Translation(-piv))
        ob.location = piv
        if suffix == "_Master":
            ob.data.update()
        obs.append(ob)
    return obs


def main():
    t0 = time.time()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    materials = armour_mats.make_all()
    set_mod = importlib.import_module(SET)
    master = bpy.data.collections.new("Master")
    game = bpy.data.collections.new("Game")
    for c in (master, game):
        bpy.context.scene.collection.children.link(c)
    finish(set_mod.build(True), master, materials, "_Master")
    print("master %.0fs" % (time.time() - t0), flush=True)
    finish(set_mod.build(False), game, materials, "")
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / f"{SET}.blend"), compress=True)
    total = 0
    for c in (master, game):
        n = {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in c.all_objects}
        print(c.name, sum(n.values()), "max", max(n.values()))
        if c is game:
            for k, v in sorted(n.items()):
                print(f"  {k:28s} {v:7d}" + ("  OVER LIMIT" if v > LIMIT else ""))
            assert max(n.values()) <= LIMIT, "a game piece is over the per-mesh limit: split it, do not decimate"
    print("built in %.0fs" % (time.time() - t0))


main()
