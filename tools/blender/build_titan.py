"""Procedural "Veiled Ascetic" colossus for the Sanctuary (headless Blender).

A seated, meditating female titan: skin-modifier body, cloth-simulated hood-mantle drawn down
over her eyes, a robe pooled over her crossed legs, an angular crown before a broken halo,
pale roots that crawl and coil up her body, and a dead canopy shedding crimson leaves.

Usage:
  Blender -b --python-exit-code 1 -P tools/blender/build_titan.py -- <out.blend> [--stage body|full]

Units are metres at human scale (seated height ~1 m); SanctuaryDressing scales on mount.
Front faces -Y.
"""
import math
import random
import sys
import time
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "/tmp/titan.blend"
STAGE = ARGS[ARGS.index("--stage") + 1] if "--stage" in ARGS else "full"
random.seed(11)

HEAD = Vector((0.0, -0.035, 0.735))


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def mesh_obj(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return link(bpy.data.objects.new(name, me))


def apply_mods(obj):
    bpy.context.view_layer.objects.active = obj
    for o in bpy.context.selected_objects:
        o.select_set(False)
    obj.select_set(True)
    for m in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


# --------------------------------------------------------------------------- body
META_K = 1.72  # metaball surface sits at ~0.58 x radius (threshold 0.6, stiffness 2)


def capsule(mb, p1, p2, r, stiff=2.0):
    p1, p2 = Vector(p1), Vector(p2)
    d = p2 - p1
    el = mb.elements.new(type="CAPSULE")
    el.co = (p1 + p2) / 2
    el.radius = r * META_K
    el.size_x = max(d.length / 2, 1e-4)
    el.rotation = Vector((1, 0, 0)).rotation_difference(d.normalized())
    el.stiffness = stiff


def blob(mb, p, r, scale=(1, 1, 1), stiff=2.0):
    el = mb.elements.new(type="ELLIPSOID")
    el.co = p
    el.radius = r * META_K
    el.size_x, el.size_y, el.size_z = scale
    el.stiffness = stiff


def build_body():
    """Metaball figure (blends like carved stone), seated in lotus, hands in dhyana mudra."""
    mbd = bpy.data.metaballs.new("TitanMeta")
    mbd.resolution = mbd.render_resolution = 0.009
    mbd.threshold = 0.6
    mb = link(bpy.data.objects.new("TitanMeta", mbd))
    data = mbd
    # torso: hips wide, waist narrow, ribcage, bust
    blob(data, (0, 0.03, 0.16), 0.17, (1.0, 0.75, 0.6))
    blob(data, (0, 0.03, 0.29), 0.12, (0.85, 0.62, 0.7))
    blob(data, (0, 0.03, 0.42), 0.14, (0.95, 0.62, 0.75))
    for s in (1, -1):
        blob(data, (s * 0.06, -0.035, 0.435), 0.055, (1, 0.9, 0.9), 2.2)        # bust
        capsule(data, (s * 0.04, 0.03, 0.53), (s * 0.165, 0.035, 0.525), 0.05)   # shoulder girdle
        capsule(data, (s * 0.175, 0.035, 0.52), (s * 0.235, 0.0, 0.33), 0.042)  # upper arm
        capsule(data, (s * 0.235, -0.005, 0.33), (s * 0.075, -0.165, 0.215), 0.034)  # forearm
        capsule(data, (s * 0.075, -0.165, 0.215), (s * 0.005, -0.2, 0.205), 0.027)  # hand
        capsule(data, (s * 0.1, 0.0, 0.12), (s * 0.36, -0.2, 0.085), 0.075)     # thigh
        z = 0.07 if s > 0 else 0.115
        capsule(data, (s * 0.36, -0.21, 0.085), (-s * 0.1, -0.31, z), 0.05)    # shin (crossed)
        capsule(data, (-s * 0.1, -0.31, z), (-s * 0.21, -0.26, z + 0.01), 0.032)  # foot
    capsule(data, (0, 0.025, 0.5), (0, 0.0, 0.66), 0.045)                      # neck
    bpy.context.view_layer.objects.active = mb
    mb.select_set(True)
    bpy.ops.object.convert(target="MESH")
    body = bpy.context.view_layer.objects.active
    body.name = "TitanBody"
    sm = body.modifiers.new("Smooth", "CORRECTIVE_SMOOTH")
    sm.iterations = 4
    dec = body.modifiers.new("Dec", "DECIMATE")
    dec.ratio = 0.35
    apply_mods(body)

    # Head: an egg tapering to a chin, tilted down in meditation; nose ridge and lips.
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=24, radius=1.0)
    for v in bm.verts:
        x, y, z = v.co
        push = 0.0
        if y < -0.55:
            fx = max(0.0, 1 - abs(x) / 0.2)
            push += 0.26 * fx * max(0.0, 1 - abs(z + 0.36) / 0.2)            # nose
            push += 0.06 * max(0.0, 1 - abs(x) / 0.34) * max(0.0, 1 - abs(z + 0.64) / 0.08)  # lips
            push -= 0.03 * max(0.0, 1 - abs(x) / 0.3) * max(0.0, 1 - abs(z + 0.56) / 0.03)   # philtrum line
        if z < -0.74 and y < -0.3:
            push += 0.07 * min(1.0, (-0.74 - z) / 0.15)                          # chin
        taper = 1.0 - 0.3 * max(0.0, -z) ** 1.5                              # narrower jaw
        v.co = Vector((x * 0.08 * taper, y * 0.095 - push * 0.095, z * 0.112))
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(-14), 3, "X"))
    bmesh.ops.translate(bm, verts=bm.verts, vec=HEAD)
    head = mesh_obj("TitanHead", bm)
    return [body, head]


# --------------------------------------------------------------------------- cloth
def cloth_sim(obj, colliders, frames, pin_group=None, mass=0.4, stiff=15.0, shrink=0.0, bend=0.6, selfcol=True, quality=8):
    for c in colliders:
        if not any(m.type == "COLLISION" for m in c.modifiers):
            col = c.modifiers.new("Col", "COLLISION")
            c.collision.thickness_outer = 0.006
            c.collision.cloth_friction = 8.0
    mod = obj.modifiers.new("Cloth", "CLOTH")
    s = mod.settings
    s.quality = quality
    s.mass = mass
    s.tension_stiffness = s.compression_stiffness = stiff
    s.bending_stiffness = bend
    s.air_damping = 2.0
    s.shrink_min = shrink
    if pin_group:
        s.vertex_group_mass = pin_group
    mod.collision_settings.distance_min = 0.006
    mod.collision_settings.use_self_collision = selfcol
    mod.collision_settings.self_distance_min = 0.004
    mod.point_cache.frame_start = 1
    mod.point_cache.frame_end = frames
    scene = bpy.context.scene
    scene.frame_start, scene.frame_end = 1, frames
    t0 = time.time()
    for f in range(1, frames + 1):
        scene.frame_set(f)
        if f % 10 == 0:
            print(f"  cloth {obj.name} frame {f} {time.time() - t0:.1f}s", flush=True)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    scene.frame_set(1)


def grid_rings(rings, closed=True):
    """rings: list of lists of Vector -> quad mesh bmesh, returns (bm, rows of verts)."""
    bm = bmesh.new()
    rows = [[bm.verts.new(p) for p in r] for r in rings]
    n = len(rows[0])
    for i in range(len(rows) - 1):
        for j in range(n if closed else n - 1):
            k = (j + 1) % n
            bm.faces.new((rows[i][j], rows[i][k], rows[i + 1][k], rows[i + 1][j]))
    return bm, rows


def wrap_target(objs):
    """Temporary joined copy of the given meshes, used as a shrinkwrap target."""
    me = bpy.data.meshes.new("WrapTarget")
    bm = bmesh.new()
    for o in objs:
        bm.from_mesh(o.data)
    bm.to_mesh(me)
    bm.free()
    return link(bpy.data.objects.new("WrapTarget", me))


def build_mantle(colliders, body, head):
    """Hood drawn low over the eyes (only nose, lips and chin show), cloak falling from the shoulders."""
    nu, nv = 56, 44
    top, bottom = HEAD.z + 0.15, 0.36
    rings = []
    for i in range(nv + 1):
        t = i / nv
        z = top - t * (top - bottom)
        if z > HEAD.z - 0.02:                       # skull dome
            k = min(1.0, (top - z) / 0.1)
            rx, ry = 0.02 + 0.08 * math.sin(k * math.pi / 2), 0.02 + 0.095 * math.sin(k * math.pi / 2)
        elif z > 0.56:                              # around the jaw/neck, flaring to the shoulders
            k = (HEAD.z - 0.02 - z) / (HEAD.z - 0.02 - 0.56)
            rx, ry = 0.10 + 0.17 * k ** 1.6, 0.115 + 0.04 * k
        else:                                       # cloak hanging from the shoulders
            k = (0.56 - z) / (0.56 - bottom)
            rx, ry = 0.27 + 0.03 * k, 0.155 + 0.03 * k
        rings.append([Vector((math.cos(a) * rx, 0.02 + math.sin(a) * ry, z))
                      for a in (2 * math.pi * j / nu - math.pi / 2 for j in range(nu))])
    bm, rows = grid_rings(rings)
    eye_z = HEAD.z - 0.018   # hood brow falls just below the eyes
    kill = []
    for f in bm.faces:
        c = f.calc_center_median()
        front = Vector((c.x, c.y - 0.02, 0)).normalized().dot(Vector((0, -1, 0)))
        if (HEAD.z - 0.125 < c.z < eye_z and front > 0.72) or (0.45 < c.z <= HEAD.z - 0.125 and front > 0.9) \
                or (c.z <= 0.45 and front > 0.55):
            kill.append(f)
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    mantle = mesh_obj("TitanMantle", bm)
    wrap = mantle.vertex_groups.new(name="wrap")
    pin = mantle.vertex_groups.new(name="pin")
    for v in mantle.data.vertices:
        z = v.co.z
        wrap.add([v.index], max(0.0, min(1.0, (z - 0.47) / 0.08)), "REPLACE")
        pin.add([v.index], max(0.0, min(1.0, (z - 0.5) / 0.06)), "REPLACE")
    target = wrap_target([body, head])
    sw = mantle.modifiers.new("Wrap", "SHRINKWRAP")
    sw.target = target
    sw.wrap_method = "NEAREST_SURFACEPOINT"
    sw.wrap_mode = "OUTSIDE_SURFACE"
    sw.offset = 0.022
    sw.vertex_group = "wrap"
    apply_mods(mantle)
    bpy.data.objects.remove(target)
    # Brow lip: the hood's front edge overhangs the eyes.
    for v in mantle.data.vertices:
        c = v.co
        if c.z > eye_z - 0.01 and c.y < HEAD.y - 0.02:
            # front of the hood drapes forward and down like a heavy cowl, shadowing the eyes
            w = max(0.0, 1 - (c.z - eye_z) / 0.09)
            c.y -= 0.028 * w * w
            c.z -= 0.012 * w
        if c.z > HEAD.z + 0.05 and c.y > HEAD.y:
            # cowl peak drawn up and back
            k = (c.z - HEAD.z - 0.05) / 0.1
            c.y += 0.05 * k * k
            c.z += 0.015 * k
        # soft drapery wrinkles over the skull
        c.x += 0.003 * math.sin(c.z * 90 + c.y * 40)
    cloth_sim(mantle, colliders, 30, "pin", mass=0.6, stiff=40.0, bend=6.0, selfcol=False)
    sol = mantle.modifiers.new("Thick", "SOLIDIFY")
    sol.thickness = 0.008
    sol.offset = 1.0
    sub = mantle.modifiers.new("Sub", "SUBSURF")
    sub.levels = 1
    apply_mods(mantle)
    return mantle


def build_bodice(body):
    """Wrapped stone garment over the torso: shrinkwrapped rings with folds and a crossing sash."""
    nu, nv = 48, 26
    rings = []
    for i in range(nv + 1):
        z = 0.56 - i * (0.56 - 0.2) / nv
        rings.append([Vector((math.cos(a) * 0.3, 0.03 + math.sin(a) * 0.25, z))
                      for a in (2 * math.pi * j / nu for j in range(nu))])
    bm, _ = grid_rings(rings)
    bodice = mesh_obj("TitanBodice", bm)
    sw = bodice.modifiers.new("Wrap", "SHRINKWRAP")
    sw.target = body
    sw.wrap_method = "NEAREST_SURFACEPOINT"
    sw.wrap_mode = "OUTSIDE_SURFACE"
    sw.offset = 0.007
    apply_mods(bodice)
    bodice.data.update()
    for v in bodice.data.vertices:
        c = v.co
        n = v.normal
        a = math.atan2(c.y - 0.03, c.x)
        fold = 0.004 * math.sin(a * 14 + c.z * 30) * (0.5 + 2 * max(0.0, 0.42 - c.z))
        sash = 0.012 * max(0.0, 1 - abs((c.z - 0.25) - (c.x + 0.2) * 0.9) / 0.035) if c.y < 0.03 else 0.0
        v.co = c + n * (fold + sash + 0.003)
    sub = bodice.modifiers.new("Sub", "SUBSURF")
    sub.levels = 1
    sol = bodice.modifiers.new("Thick", "SOLIDIFY")
    sol.thickness = 0.006
    apply_mods(bodice)
    return bodice


def build_robe(colliders):
    """Annulus pinned at the waist, pooling over the crossed legs onto the dais."""
    nu, nv = 72, 26
    rings = []
    for i in range(nv + 1):
        t = i / nv
        r = 0.135 + t * 0.6
        z = 0.30 - t * 0.02
        rings.append([Vector((math.cos(2 * math.pi * j / nu) * r * 1.05,
                              0.02 + math.sin(2 * math.pi * j / nu) * r - 0.05 * t, z)) for j in range(nu)])
    bm, rows = grid_rings(rings)
    r0, r1 = [v.index for v in rows[0]], [v.index for v in rows[1]]
    robe = mesh_obj("TitanRobe", bm)
    vg = robe.vertex_groups.new(name="pin")
    vg.add(r0, 1.0, "REPLACE")
    vg.add(r1, 0.6, "REPLACE")
    ground = bpy.data.objects.new("Ground", bpy.data.meshes.new("Ground"))
    gbm = bmesh.new()
    bmesh.ops.create_grid(gbm, x_segments=1, y_segments=1, size=2.0)
    gbm.to_mesh(ground.data)
    gbm.free()
    link(ground)
    cloth_sim(robe, colliders + [ground], 70, "pin", mass=0.6, stiff=12.0, bend=1.5, selfcol=False, quality=5)
    bpy.data.objects.remove(ground)
    sol = robe.modifiers.new("Thick", "SOLIDIFY")
    sol.thickness = 0.01
    sub = robe.modifiers.new("Sub", "SUBSURF")
    sub.levels = 1
    apply_mods(robe)
    return robe


def tris(o):
    o.data.calc_loop_triangles()
    return len(o.data.loop_triangles)


def stamp(label, t0=[time.time()]):
    print(f"STAGE {label:10s} {time.time() - t0[0]:6.1f}s", flush=True)


def build_cloth():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    body, head = build_body()
    stamp("body")
    bodice = build_bodice(body)
    stamp("bodice")
    robe = build_robe([body, bodice])
    stamp("robe")
    mantle = build_mantle([body, head, bodice, robe], body, head)
    stamp("mantle")
    for o in (body, head, bodice, robe, mantle):
        for m in [m for m in o.modifiers if m.type == "COLLISION"]:
            o.modifiers.remove(m)
        print("TRIS", o.name, tris(o))


def dress():
    import titan_dressing as td
    sc = bpy.context.scene.objects
    figure = [sc[n] for n in ("TitanBody", "TitanHead", "TitanBodice", "TitanRobe", "TitanMantle")]
    for o in (td.crown(HEAD), td.halo(HEAD), td.swords()):
        apply_mods(o)
    stamp("regalia")
    roots, _ = td.roots(figure, HEAD)
    stamp("roots")
    canopy, tips = td.canopy(HEAD)
    stamp("canopy")
    rest = td.statue_bvh(figure + [roots, sc["TitanSwords"]])
    td.leaves(tips, rest)
    stamp("leaves")
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            print("TRIS", o.name, tris(o))


def main():
    sys.path.insert(0, str(Path(__file__).parent))
    if "--from" in ARGS:
        bpy.ops.wm.open_mainfile(filepath=ARGS[ARGS.index("--from") + 1])
    else:
        build_cloth()
    if STAGE in ("full", "dress"):
        dress()
    bpy.ops.wm.save_as_mainfile(filepath=OUT)
    print("BUILD_TITAN_OK", STAGE, OUT)


main()
