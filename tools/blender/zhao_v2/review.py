"""Review renders for General Zhao v2 against v1: matched turnarounds, grayscale silhouettes, a rainy arena
at combat distances (Roblox camera, boss scale 1.2), close-ups, attack poses with lightning, and the baked
game mesh.

    Blender -b --factory-startup -P tools/blender/zhao_v2/review.py -- [section ...]

Sections: turn, sil, arena, close, attack, game (default: all). Writes v2_design/review/*.png.
"""
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BASE = ROOT / "assets/source/bosses/general_zhao"
V2 = BASE / "v2_design/GeneralZhao_v2.blend"
V1 = BASE / "GeneralZhao_Master.blend"
OUT = BASE / "v2_design/review"
BOSS_SCALE = 1.2  # BossRoster: TwinSentinels General Zhao, scale 1.2

# R15 joints at scale 1 (Blender coords); each limb rotates about the joint that attaches it to its parent
JOINT = {
    "LowerTorso": (0, 0, -0.6), "UpperTorso": (0, 0, -0.6), "Head": (0, 0, 1.0),
    "RightUpperArm": (1.0, 0, 0.763), "RightLowerArm": (1.5, 0, 0.035), "RightHand": (1.5, 0, -0.725),
    "LeftUpperArm": (-1.0, 0, 0.763), "LeftLowerArm": (-1.5, 0, 0.035), "LeftHand": (-1.5, 0, -0.725),
    "RightUpperLeg": (0.5, 0, -1.0), "RightLowerLeg": (0.5, 0, -1.84), "RightFoot": (0.5, 0, -2.73),
    "LeftUpperLeg": (-0.5, 0, -1.0), "LeftLowerLeg": (-0.5, 0, -1.84), "LeftFoot": (-0.5, 0, -2.73),
}
PARENT = {
    "UpperTorso": "LowerTorso", "Head": "UpperTorso",
    "RightUpperArm": "UpperTorso", "RightLowerArm": "RightUpperArm", "RightHand": "RightLowerArm",
    "LeftUpperArm": "UpperTorso", "LeftLowerArm": "LeftUpperArm", "LeftHand": "LeftLowerArm",
    "RightUpperLeg": "LowerTorso", "RightLowerLeg": "RightUpperLeg", "RightFoot": "RightLowerLeg",
    "LeftUpperLeg": "LowerTorso", "LeftLowerLeg": "LeftUpperLeg", "LeftFoot": "LeftLowerLeg",
}


# ---------------------------------------------------------------------------------------------------------
def scene():
    return bpy.context.scene


def gpu(samples):
    sc = scene()
    sc.render.engine = "CYCLES"
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "METAL"
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
        sc.cycles.device = "GPU"
    except Exception:  # noqa: BLE001
        pass
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Medium High Contrast"


def clear_lights():
    """Remove lights, cameras and environment props, keeping the rig's empties."""
    for o in [o for o in scene().objects if o.type in ("LIGHT", "CAMERA") or (o.name.startswith("Env_") and o.type != "EMPTY")]:
        bpy.data.objects.remove(o)


def area(name, loc, energy, size, col, target=(0, 0, 0.6)):
    L = bpy.data.lights.new(name, "AREA")
    L.energy, L.size, L.color = energy, size, col
    o = bpy.data.objects.new("Env_" + name, L)
    o.location = loc
    o.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scene().collection.objects.link(o)
    return o


def world(col, strength):
    sc = scene()
    w = sc.world or bpy.data.worlds.new("W")
    sc.world = w
    w.use_nodes = True
    nt = w.node_tree
    for n in list(nt.nodes):
        if n.type not in ("BACKGROUND", "OUTPUT_WORLD"):
            nt.nodes.remove(n)
    bg = next(n for n in nt.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (*col, 1)
    bg.inputs[1].default_value = strength
    return w


def studio():
    clear_lights()
    world((.16, .18, .2), 0.35)
    for name, loc, e, s, c in (("Key", (4.5, 6.5, 6.0), 900, 3.0, (1.0, .93, .85)),
                               ("Fill", (-6.0, 4.0, 2.0), 220, 4.0, (.75, .82, 1.0)),
                               ("Rim", (-2.5, -6.5, 6.5), 900, 2.0, (.8, .9, 1.0)),
                               ("Rim2", (4.0, -5.0, 3.0), 400, 2.0, (1.0, .9, .8))):
        area(name, loc, e, s, c)


def camera(target, direction, dist, lens=50, res=(600, 900), ortho=None):
    sc = scene()
    cam = bpy.data.objects.get("Env_Cam")
    if not cam:
        cam = bpy.data.objects.new("Env_Cam", bpy.data.cameras.new("Env_Cam"))
        sc.collection.objects.link(cam)
    cam.data.type = "ORTHO" if ortho else "PERSP"
    if ortho:
        cam.data.ortho_scale = ortho
    cam.data.lens, cam.data.clip_start, cam.data.clip_end = lens, 0.01, 500
    d, t = Vector(direction).normalized(), Vector(target)
    cam.location = t + d * dist
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    return cam


def render(name):
    OUT.mkdir(parents=True, exist_ok=True)
    p = OUT / f"{name}.png"
    scene().render.filepath = str(p)
    bpy.ops.render.render(write_still=True)
    print("wrote", p)
    return p


def tile(paths, out, cols=None, gap=0):
    import numpy as np
    imgs = [bpy.data.images.load(str(p), check_existing=False) for p in paths]
    arrs = [np.array(i.pixels[:]).reshape(i.size[1], i.size[0], 4) for i in imgs]
    h = max(a.shape[0] for a in arrs)
    arrs = [np.pad(a, ((0, h - a.shape[0]), (0, gap), (0, 0)), constant_values=1.0) for a in arrs]
    cols = cols or len(arrs)
    blank = np.ones_like(arrs[0])
    rows = [np.concatenate(arrs[i:i + cols] + [blank] * (cols - len(arrs[i:i + cols])), axis=1)
            for i in range(0, len(arrs), cols)]
    sheet = np.concatenate(rows[::-1], axis=0).astype(np.float32)
    o = bpy.data.images.new("tile", sheet.shape[1], sheet.shape[0])
    o.pixels.foreach_set(sheet.ravel())
    o.filepath_raw, o.file_format = str(OUT / f"{out}.png"), "PNG"
    o.save()
    for i in imgs:
        bpy.data.images.remove(i)
    print("wrote", out)


# ---------------------------------------------------------------------------------------------------------
def load_v2():
    bpy.ops.wm.open_mainfile(filepath=str(V2))


def append_v1(offset):
    """Append v1's master meshes (renamed V1_*) beside v2, shifted by offset."""
    with bpy.data.libraries.load(str(V1)) as (src, dst):
        dst.objects = [n for n in src.objects if n.endswith("_Master")]
    coll = bpy.data.collections.new("V1_Master")
    scene().collection.children.link(coll)
    for o in dst.objects:
        if o is None:
            continue
        o.name = "V1_" + o.name
        coll.objects.link(o)
        o.location += Vector(offset)
    return list(coll.objects)


def v2_objs(game=False):
    out = []
    for o in scene().objects:
        if o.type != "MESH" or o.name.startswith(("V1_", "Env_")):
            continue
        if o.name.endswith("_Master") != game:
            out.append(o)
    return out


def show_only(objs):
    keep = set(o.name for o in objs)
    for o in scene().objects:
        if o.type == "MESH":
            o.hide_render = o.name not in keep


def bone_of(o):
    b = o.get("AsuraBone")
    if b:
        return b
    n = o.name.replace("V1_", "").replace("Zhao_", "").replace("_Master", "")
    return "RightHand" if n.startswith("Guandao") else n


# ---------------------------------------------------------------------------------------------------------
def rig(objs, scale=1.0, origin=(0, 0, 0)):
    """Rigid R15 rig: an empty per joint, parented in the R15 chain, meshes parented to their limb's empty."""
    root = bpy.data.objects.new("Env_Root", None)
    scene().collection.objects.link(root)
    root.location, root.scale = origin, (scale,) * 3
    E = {}
    for b in JOINT:
        e = bpy.data.objects.new("Env_J_" + b, None)
        scene().collection.objects.link(e)
        E[b] = e
    for b, e in E.items():
        par = E.get(PARENT.get(b)) or root
        e.parent = par
        e.location = Vector(JOINT[b]) - (Vector(JOINT[PARENT[b]]) if b in PARENT else Vector())
    for o in objs:
        b = bone_of(o)
        mw = o.matrix_world.copy()
        o.parent = E[b]
        o.matrix_parent_inverse = Matrix.Translation(-Vector(JOINT[b]))
        o.location = mw.translation
        o.rotation_euler = (0, 0, 0)
    return root, E


def pose(E, root, spec, root_off=(0, 0, 0)):
    for b, e in E.items():
        e.rotation_euler = [math.radians(a) for a in spec.get(b, (0, 0, 0))]
    if "base" not in root:
        root["base"] = tuple(root.location)
    root.location = Vector(root["base"]) + Vector(root_off) * root.scale[0]
    bpy.context.view_layer.update()


POSES = {
    # overhead wind-up: guandao raised behind the head, weight back, left hand forward on the haft
    "overhead": ({"UpperTorso": (-8, 0, 18), "Head": (6, 0, -12),
                  "RightUpperArm": (150, 0, 12), "RightLowerArm": (30, 0, 0), "RightHand": (-60, 0, 0),
                  "LeftUpperArm": (120, 0, -35), "LeftLowerArm": (55, 0, 0),
                  "RightUpperLeg": (-22, 0, 4), "RightLowerLeg": (-25, 0, 0), "RightFoot": (15, 0, 0),
                  "LeftUpperLeg": (30, 0, -4), "LeftLowerLeg": (-35, 0, 0), "LeftFoot": (8, 0, 0)}, (0, 0, -0.12)),
    # lunge thrust: right shoulder driven forward, blade level, front knee bent deep
    "thrust": ({"LowerTorso": (8, 0, -18), "UpperTorso": (6, 0, -28), "Head": (-4, 0, 30),
                "RightUpperArm": (82, 0, 8), "RightLowerArm": (8, 0, 0), "RightHand": (-88, 0, 0),
                "LeftUpperArm": (40, 0, 60), "LeftLowerArm": (70, 0, 0),
                "LeftUpperLeg": (62, 0, 0), "LeftLowerLeg": (-70, 0, 0), "LeftFoot": (8, 0, 0),
                "RightUpperLeg": (-35, 0, 0), "RightLowerLeg": (-10, 0, 0), "RightFoot": (30, 0, 0)}, (0, 0.6, -0.55)),
    # wide sweep: torso coiled, arm out to the side, haft horizontal across the body
    "sweep": ({"LowerTorso": (0, 0, 20), "UpperTorso": (5, -8, 45), "Head": (0, 0, -40),
               "RightUpperArm": (0, -78, 25), "RightLowerArm": (0, 0, 15), "RightHand": (0, 0, 0),
               "LeftUpperArm": (35, 30, -10), "LeftLowerArm": (60, 0, 0),
               "RightUpperLeg": (-20, 0, -20), "RightLowerLeg": (-30, 0, 0),
               "LeftUpperLeg": (35, 0, 15), "LeftLowerLeg": (-40, 0, 0)}, (0, 0, -0.3)),
}


# target, view direction, ortho width per attack (thrust from the side so the reach reads)
ATTACK_CAM = {"overhead": ((-0.3, -2.2, 3.4), (0.75, 1, 0.1), 19.0),
              "thrust": ((0.5, 3.8, 0.0), (1, 0.18, 0.1), 16.0),
              "sweep": ((4.0, 1.5, 0.3), (0.35, 1, 0.35), 20.0)}


def fit(tip, name, extra=()):
    """Square ortho frame holding the whole body (feet to plumes) and the blade tip, for the pose's view."""
    d = Vector(ATTACK_CAM[name][1]).normalized()
    pts = [Vector((0, 0, -3.1)), Vector((0, 0, 4.6)), Vector((1.6, 0, 0)), Vector((-1.6, 0, 0)), tip,
           tip + Vector((0, 0, 0.6))] + list(extra)
    side = d.cross(Vector((0, 0, 1))).normalized()
    up = side.cross(d)
    xs = [p.dot(side) for p in pts]
    ys = [p.dot(up) for p in pts]
    c = side * (max(xs) + min(xs)) / 2 + up * (max(ys) + min(ys)) / 2
    return c, d, max(max(xs) - min(xs), max(ys) - min(ys)) * 1.15 + 1.0


def blade_tip():
    o = next(o for o in scene().objects if o.name.startswith("Zhao_GuandaoBlade") and not o.hide_render)
    pts = [o.matrix_world @ Vector(c) for c in o.bound_box]
    hand = next(x for x in scene().objects if x.name.startswith("Zhao_RightHand") and not x.hide_render)
    h = hand.matrix_world.translation
    return max(pts, key=lambda p: (p - h).length), h


# ---------------------------------------------------------------------------------------------------------
def emission_mat(name, col, strength):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    e = nt.nodes.new("ShaderNodeEmission")
    e.inputs[0].default_value = (*col, 1)
    e.inputs[1].default_value = strength
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(e.outputs[0], o.inputs[0])
    return m


def bolt(name, pts, r, seed, branches=3):
    """Jagged lightning: a midpoint-displaced polyline swept as a thin emissive tube, with side forks."""
    rnd = random.Random(seed)

    def jag(a, b, depth, amp):
        if depth == 0:
            return [a, b]
        m = (a + b) / 2 + Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))) * amp
        return jag(a, m, depth - 1, amp * 0.55)[:-1] + jag(m, b, depth - 1, amp * 0.55)

    paths = []
    main = []
    for a, b in zip(pts[:-1], pts[1:]):
        main += jag(Vector(a), Vector(b), 4, (Vector(b) - Vector(a)).length * 0.22)[:-1]
    main.append(Vector(pts[-1]))
    paths.append((main, r))
    for _ in range(branches):
        i = rnd.randrange(1, len(main) - 2)
        d = (main[i + 1] - main[i]).normalized()
        side = d.cross(Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), 1))).normalized()
        end = main[i] + (d + side * 1.4).normalized() * rnd.uniform(0.6, 1.4)
        paths.append((jag(main[i], end, 3, 0.25), r * 0.5))
    bm = bmesh.new()
    for path, rr in paths:
        prev = None
        for k, p in enumerate(path):
            t = path[min(len(path) - 1, k + 1)] - path[max(0, k - 1)]
            t.normalize()
            u = t.cross(Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))).normalized()
            w = t.cross(u)
            ring = [bm.verts.new(p + (u * math.cos(a) + w * math.sin(a)) * rr) for a in [i * math.pi / 3 for i in range(6)]]
            if prev:
                for i in range(6):
                    bm.faces.new((prev[i], prev[(i + 1) % 6], ring[(i + 1) % 6], ring[i]))
            prev = ring
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    ob = bpy.data.objects.new("Env_" + name, me)
    ob.data.materials.append(emission_mat("Env_Lightning", (0.22, 0.55, 1.0), 14.0))
    ob.visible_shadow = False
    scene().collection.objects.link(ob)
    return ob


def point(name, loc, energy, col, radius=0.3):
    L = bpy.data.lights.new(name, "POINT")
    L.energy, L.color, L.shadow_soft_size = energy, col, radius
    o = bpy.data.objects.new("Env_" + name, L)
    o.location = loc
    scene().collection.objects.link(o)


# ---------------------------------------------------------------------------------------------------------
def arena(ground_z):
    """Rain-soaked courtyard at night: wet slate, fog, falling rain, cold moonlight rim and a dim warm brazier."""
    clear_lights()
    w = world((.025, .035, .05), 1.0)
    nt = w.node_tree
    vol = nt.nodes.new("ShaderNodeVolumePrincipled")
    vol.inputs["Density"].default_value = 0.005
    vol.inputs["Color"].default_value = (0.55, 0.65, 0.8, 1)
    nt.links.new(vol.outputs[0], next(n for n in nt.nodes if n.type == "OUTPUT_WORLD").inputs["Volume"])
    # wet slate floor: large flagstones, puddles as low-roughness patches
    bpy.ops.mesh.primitive_plane_add(size=220, location=(0, 0, ground_z))
    fl = bpy.context.object
    fl.name = "Env_Floor"
    m = bpy.data.materials.new("Env_Slate")
    m.use_nodes = True
    t = m.node_tree
    b = next(n for n in t.nodes if n.type == "BSDF_PRINCIPLED")
    tc = t.nodes.new("ShaderNodeTexCoord")
    vor = t.nodes.new("ShaderNodeTexVoronoi")
    vor.feature = "DISTANCE_TO_EDGE"
    vor.inputs["Scale"].default_value = 0.35
    t.links.new(tc.outputs["Object"], vor.inputs["Vector"])
    grout = t.nodes.new("ShaderNodeMapRange")
    grout.inputs[1].default_value, grout.inputs[2].default_value = 0.0, 0.03
    t.links.new(vor.outputs["Distance"], grout.inputs[0])
    nz = t.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 0.08
    nz.inputs["Detail"].default_value = 4
    t.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    pud = t.nodes.new("ShaderNodeMapRange")
    pud.inputs[1].default_value, pud.inputs[2].default_value = 0.5, 0.56
    pud.inputs[3].default_value, pud.inputs[4].default_value = 0.32, 0.03
    t.links.new(nz.outputs["Fac"], pud.inputs[0])
    t.links.new(pud.outputs[0], b.inputs["Roughness"])
    col = t.nodes.new("ShaderNodeMix")
    col.data_type = "RGBA"
    col.inputs["A"].default_value = (0.012, 0.012, 0.013, 1)
    col.inputs["B"].default_value = (0.05, 0.05, 0.055, 1)
    t.links.new(grout.outputs[0], col.inputs["Factor"])
    t.links.new(col.outputs["Result"], b.inputs["Base Color"])
    fl.data.materials.append(m)
    # ring of weathered stone pillars at the arena edge
    stone = bpy.data.materials.new("Env_Stone")
    stone.use_nodes = True
    sb = next(n for n in stone.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    sb.inputs["Base Color"].default_value = (0.05, 0.05, 0.055, 1)
    sb.inputs["Roughness"].default_value = 0.5
    for k in range(12):
        a = 2 * math.pi * k / 12 + 0.2
        bpy.ops.mesh.primitive_cube_add(size=1, location=(math.cos(a) * 34, math.sin(a) * 34, ground_z + 6))
        p = bpy.context.object
        p.name = f"Env_Pillar{k}"
        p.scale = (2.2, 2.2, 12)
        p.data.materials.append(stone)
    # rain: thin pale streaks (motion-blurred drops) filling the volume around the action
    rnd = random.Random(3)
    bm = bmesh.new()
    for _ in range(9000):
        c = Vector((rnd.uniform(-30, 30), rnd.uniform(-50, 20), rnd.uniform(ground_z, ground_z + 22)))
        L = rnd.uniform(0.35, 0.7)
        d = Vector((0.06, 0.03, -1)).normalized() * L
        r = 0.006
        vs = [bm.verts.new(c + Vector((dx, dy, 0))) for dx, dy in ((-r, 0), (r, 0))]
        vs += [bm.verts.new(c + d + Vector((dx, dy, 0))) for dx, dy in ((r, 0), (-r, 0))]
        bm.faces.new(vs)
    me = bpy.data.meshes.new("Env_Rain")
    bm.to_mesh(me)
    rain = bpy.data.objects.new("Env_Rain", me)
    rm = bpy.data.materials.new("Env_RainMat")
    rm.use_nodes = True
    rt = rm.node_tree
    rt.nodes.clear()
    mix = rt.nodes.new("ShaderNodeMixShader")
    mix.inputs[0].default_value = 0.35
    tr_ = rt.nodes.new("ShaderNodeBsdfTransparent")
    em = rt.nodes.new("ShaderNodeEmission")
    em.inputs[0].default_value = (0.6, 0.7, 0.85, 1)
    em.inputs[1].default_value = 0.6
    out = rt.nodes.new("ShaderNodeOutputMaterial")
    rt.links.new(tr_.outputs[0], mix.inputs[1])
    rt.links.new(em.outputs[0], mix.inputs[2])
    rt.links.new(mix.outputs[0], out.inputs[0])
    rain.data.materials.append(rm)
    rain.visible_shadow = False
    scene().collection.objects.link(rain)
    # moonlight from behind-left (cold rim), soft overcast key, a warm brazier glow far right
    sun = bpy.data.lights.new("Moon", "SUN")
    sun.energy, sun.color, sun.angle = 1.6, (0.6, 0.72, 1.0), math.radians(3)
    so = bpy.data.objects.new("Env_Moon", sun)
    so.rotation_euler = (math.radians(55), 0, math.radians(200))
    scene().collection.objects.link(so)
    area("Overcast", (-8, 14, 16), 6500, 14, (0.62, 0.7, 0.85), (0, 0, ground_z + 3))
    point("Brazier", (12, 6, ground_z + 2.5), 2500, (1.0, 0.55, 0.25), 0.5)


def roblox_cam(dist, boss_h, res=(960, 540)):
    """Default Roblox third-person camera: 70 deg vertical FOV, behind the player's shoulder,
    looking toward the boss's chest from roughly eye height + a few studs."""
    sc = scene()
    cam = camera((0, 0, 0), (0, 1, 0), 1, res=res)
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle_y = math.radians(70)
    ground = -3.0 * BOSS_SCALE
    eye = ground + 4.5 + 0.06 * dist
    cam.location = Vector((-1.4, dist, eye))
    look = Vector((0, 0, ground + boss_h * 0.55))
    cam.rotation_euler = (look - cam.location).to_track_quat("-Z", "Y").to_euler()
    return cam


def player(dist):
    """A plain R15-sized stand-in for the player 'dist' studs in front of the boss, 4 studs ahead of the camera."""
    ground = -3.0 * BOSS_SCALE
    m = bpy.data.materials.new("Env_Player")
    m.use_nodes = True
    next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.08, 0.08, 0.09, 1)
    y = dist - 6.0
    if y < 2.0:
        return
    for loc, sc_ in (((-2.2, y, ground + 1.0), (1.0, 0.6, 2.0)), ((-2.2, y, ground + 2.8), (1.9, 0.9, 1.6)),
                     ((-2.2, y, ground + 4.15), (1.1, 1.1, 1.1))):
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
        o = bpy.context.object
        o.name = "Env_Player"
        o.scale = sc_
        o.data.materials.append(m)


# ---------------------------------------------------------------------------------------------------------
VIEWS = (("front", (0, 1, 0.06)), ("three_quarter", (0.75, 1, 0.08)), ("side", (1, 0, 0.06)), ("back", (0, -1, 0.08)))


# target, view direction, resolution, ortho width: side and three-quarter are widened so the whole guandao shows
TURN_FRAME = {"front": ((0, 0, 0.55), VIEWS[0][1], (520, 900), 10.5),
              "three_quarter": ((2.6, 2.6, 0.55), VIEWS[1][1], (900, 900), 16.0),
              "side": ((0, 3.9, 0.55), VIEWS[2][1], (1000, 900), 18.5),
              "back": ((0, 0, 0.55), VIEWS[3][1], (520, 900), 10.5)}


def sec_turn():
    load_v2()
    gpu(48)
    studio()
    v1 = append_v1((0, 0, 0))
    v2 = v2_objs()
    paths = []
    for label, objs in (("v1", v1), ("v2", v2)):
        show_only(objs)
        for name, d in VIEWS:
            camera(*TURN_FRAME[name][:2], 30, 50, TURN_FRAME[name][2], ortho=TURN_FRAME[name][3])
            paths.append(render(f"turn_{label}_{name}"))
    tile(paths, "turn_compare", cols=4)


def flat(objs, col):
    m = emission_mat("Env_Flat", col, 1.0)
    for o in objs:
        for s in o.material_slots:
            s.material = m


def sec_sil():
    load_v2()
    gpu(8)
    clear_lights()
    world((1, 1, 1), 1.0)
    scene().view_settings.view_transform = "Standard"
    scene().view_settings.look = "None"
    v1 = append_v1((0, 0, 0))
    v2 = v2_objs()
    flat(v1 + v2, (0.0, 0.0, 0.0))
    paths = []
    for label, objs in (("v1", v1), ("v2", v2)):
        show_only(objs)
        for name, d in VIEWS:
            camera(*TURN_FRAME[name][:2], 30, 50, TURN_FRAME[name][2], ortho=TURN_FRAME[name][3])
            paths.append(render(f"sil_{label}_{name}"))
    tile(paths, "sil_compare", cols=4)


def sec_arena():
    load_v2()
    gpu(64)
    objs = v2_objs()
    show_only(objs)
    root, E = rig(objs, BOSS_SCALE)
    arena(-3.0 * BOSS_SCALE)
    paths = []
    for d in (6, 12, 20, 40):
        for o in [o for o in scene().objects if o.name == "Env_Player" or o.name.startswith("Env_Player.")]:
            bpy.data.objects.remove(o)
        player(d)
        roblox_cam(d, 7.4 * BOSS_SCALE)
        paths.append(render(f"arena_{d:02d}studs"))
    tile(paths, "arena_distances", cols=2)
    # the same distances in an attack: overhead wind-up with lightning on the blade only
    pose(E, root, POSES["overhead"][0], POSES["overhead"][1])
    tip, hand = blade_tip()
    bolt("BladeArc", [tip + Vector((0, 0, 6)), tip + Vector((0.4, -0.2, 2.5)), tip], 0.03, 7)
    point("Flash", tip, 3000, (0.5, 0.75, 1.0), 0.2)
    paths = []
    for d in (12, 40):
        roblox_cam(d, 7.4 * BOSS_SCALE)
        paths.append(render(f"arena_attack_{d:02d}studs"))
    tile(paths, "arena_attack", cols=2)


def sec_close():
    load_v2()
    gpu(96)
    studio()
    show_only(v2_objs())
    shots = (("face", (0, 0.2, 1.42), (0.45, 1, 0.08), 2.4, 85),
             ("face_profile", (0, 0.1, 1.42), (1, 0.3, 0.05), 2.4, 85),
             ("armour", (0.1, 0.2, 0.4), (0.8, 1, 0.25), 4.6, 70),
             ("armour_back", (0, -0.2, 0.6), (-0.6, -1, 0.3), 5.0, 70),
             ("hands", (1.3, 0.2, -0.85), (0.8, 1, 0.3), 2.0, 70),
             ("guandao_blade", (1.29, 8.1, -0.55), (1, 0.05, 0.05), 3.4, 70),
             ("legs_boots", (0, 0.2, -2.1), (0.6, 1, 0.1), 4.6, 60))
    paths = []
    for name, t, d, dist, lens in shots:
        camera(t, d, dist, lens, (800, 800))
        paths.append(render(f"close_{name}"))
    tile(paths[:4], "close_sheet_a", cols=2)
    tile(paths[4:], "close_sheet_b", cols=3)


def sec_attack():
    load_v2()
    gpu(64)
    studio()
    objs = v2_objs()
    show_only(objs)
    root, E = rig(objs, 1.0)
    paths = []
    for name, (spec, off) in POSES.items():
        for o in [o for o in scene().objects if o.name.startswith(("Env_Bolt", "Env_Flash"))]:
            bpy.data.objects.remove(o)
        pose(E, root, spec, off)
        tip, hand = blade_tip()
        if name == "thrust":
            b = bolt("BoltA", [tip, tip + Vector((0.3, 3.0, 0.2)), tip + Vector((-0.2, 6.0, -0.1))], 0.025, 11)
        elif name == "sweep":
            c = Vector((0, 0, tip.z))
            r = (tip - c).length
            arc = [c + Vector((math.cos(a) * r, math.sin(a) * r, 0.15 * math.sin(3 * a))) for a in
                   [math.atan2(tip.y, tip.x) - k * 0.25 for k in range(8)]]
            b = bolt("BoltA", arc, 0.025, 12, 4)
        else:
            b = bolt("BoltA", [tip + Vector((0, 0, 3)), tip + Vector((0.3, -0.2, 1.4)), tip], 0.03, 13)
        point("Flash", tip, 1200, (0.5, 0.75, 1.0), 0.2)
        ext = [v.co for v in b.data.vertices]
        camera(*fit(tip, name, ext)[:2], 30, 50, (900, 900), ortho=fit(tip, name, ext)[2])
        paths.append(render(f"attack_{name}"))
        print(name, "tip", tuple(round(v, 2) for v in tip), "from hand", round((tip - hand).length, 3))
    tile(paths, "attack_poses", cols=3)
    # grayscale silhouettes of the attack poses at combat scale
    flat(objs, (0, 0, 0))
    for o in [o for o in scene().objects if o.name.startswith(("Env_Bolt", "Env_Flash"))]:
        o.hide_render = True
    clear_lights()
    world((1, 1, 1), 1.0)
    scene().view_settings.view_transform = "Standard"
    scene().view_settings.look = "None"
    sp = []
    for name, (spec, off) in POSES.items():
        pose(E, root, spec, off)
        tip, _ = blade_tip()
        camera(*fit(tip, name)[:2], 30, 50, (450, 450), ortho=fit(tip, name)[2])
        sp.append(render(f"attack_sil_{name}"))
    tile(sp, "attack_silhouettes", cols=3)


def sec_game():
    load_v2()
    gpu(48)
    studio()
    show_only(v2_objs(game=True))
    paths = []
    for name, d in VIEWS[:2]:
        camera((0, 0, 0.55), d, 30, 50, (520, 900), ortho=10.5)
        paths.append(render(f"game_{name}"))
    camera((0, 0.2, 1.42), (0.45, 1, 0.08), 2.4, 85, (700, 900))
    paths.append(render("game_face"))
    tile(paths, "game_mesh", cols=3)


SECTIONS = {"turn": sec_turn, "sil": sec_sil, "arena": sec_arena, "close": sec_close, "attack": sec_attack,
            "game": sec_game}

if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for s in (args or list(SECTIONS)):
        SECTIONS[s]()
