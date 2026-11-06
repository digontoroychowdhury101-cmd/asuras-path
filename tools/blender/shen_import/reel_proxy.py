"""Render the Shen motion reel (shen_reel.py shots) on any computer, without the skinned GLBs.

    Blender -b --factory-startup --python tools/blender/shen_import/reel_proxy.py -- OUTDIR [shot ...] [--step N] [--size WxH]

His body is the committed surface samples (work/shen_import/samples_p<n>.npz, 1500 points per part) drawn as dots:
limbs and weapon ride their own bones exactly; hair, beard, beads, mantles and robes are blended over the nearest
simulated cloth bones, so cloth shape is approximate (not the real skin weights) but its motion is the game's.
Writes OUTDIR/<view>/f_<global frame>.png for the views "front" (combat quarter) and "side", and OUTDIR/frames.json.
"""
import json
import math
import os
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "../../.."))
SHOTS = os.path.join(ROOT, "work/opening_cast_bake/shen_shots")
argv = sys.argv[sys.argv.index("--") + 1:]
out = argv.pop(0)
step, size, only = 1, (960, 540), []
while argv:
    a = argv.pop(0)
    if a == "--step":
        step = int(argv.pop(0))
    elif a == "--size":
        size = tuple(int(v) for v in argv.pop(0).split("x"))
    else:
        only.append(a)
index = json.load(open(os.path.join(SHOTS, "reel_index.json")))
if only:
    index = [e for e in index if e["shot"] in only or e["clip"] in only]

FLOOR = -3.1924
RADIUS = 0.045
COLOURS = {   # part -> RGB, chosen to separate hands, sleeves, robe and weapon at a glance
    "Head": (0.86, 0.68, 0.55), "UpperTorso": (0.80, 0.76, 0.66), "LowerTorso": (0.62, 0.60, 0.55),
    "RightUpperArm": (0.75, 0.72, 0.62), "RightLowerArm": (0.70, 0.67, 0.58), "RightHand": (0.95, 0.45, 0.20),
    "LeftUpperArm": (0.75, 0.72, 0.62), "LeftLowerArm": (0.70, 0.67, 0.58), "LeftHand": (0.20, 0.65, 0.95),
    "RightUpperLeg": (0.25, 0.25, 0.28), "RightLowerLeg": (0.22, 0.22, 0.25), "RightFoot": (0.55, 0.15, 0.15),
    "LeftUpperLeg": (0.25, 0.25, 0.28), "LeftLowerLeg": (0.22, 0.22, 0.25), "LeftFoot": (0.15, 0.40, 0.20),
    "HairBack": (0.15, 0.13, 0.12), "Beard": (0.93, 0.93, 0.90), "Beads": (0.45, 0.25, 0.12),
    "RightMantle": (0.55, 0.30, 0.25), "LeftMantle": (0.55, 0.30, 0.25),
    "RobeBack": (0.85, 0.82, 0.72), "RobeRight": (0.82, 0.79, 0.69), "RobeLeft": (0.82, 0.79, 0.69),
    "RobeInner": (0.60, 0.58, 0.52), "RobeFront": (0.88, 0.85, 0.75), "Weapon": (0.95, 0.78, 0.25),
}
CLOTH = {   # cloth part -> bone name prefixes it may follow
    "HairBack": ("Cl_Hair", "Sk_Head"), "Beard": ("Cl_Beard", "Sk_Head"), "Beads": ("Cl_Beads", "Sk_UpperTorso"),
    "RightMantle": ("Cl_RMantle", "Cl_RSleeve", "Sk_UpperTorso", "Sk_RightUpperArm"),
    "LeftMantle": ("Cl_LMantle", "Cl_LSleeve", "Sk_UpperTorso", "Sk_LeftUpperArm"),
}
for _p in ("RobeBack", "RobeRight", "RobeLeft", "RobeInner", "RobeFront"):
    CLOTH[_p] = ("Cl_Coat", "Cl_Under", "Sk_LowerTorso")


def rig_to_blender(p):
    return np.stack([p[:, 0], -p[:, 2], p[:, 1]], 1)


class Body:
    """One phase's dot body: rest points, and how each follows the shot's bones."""

    def __init__(self, phase):
        z = np.load(os.path.join(ROOT, "work/shen_import/samples_p%d.npz" % phase))
        cloth = json.load(open(os.path.join(ROOT, "work/shen_import/cloth_p%d.json" % phase)))
        bones = {b["name"]: np.array(b["at"], float) for b in cloth["bones"][1:]}
        self.parts = []
        for part in z.files:
            pts = z[part].astype(float)
            if part == "Weapon":
                self.parts.append((part, pts, ("prop", "Glaive")))
            elif part in CLOTH:
                names = [n for n in bones if n.startswith(CLOTH[part])]
                at = np.stack([bones[n] for n in names])
                d = np.linalg.norm(pts[:, None, :] - at[None], axis=2)
                k = min(4, len(names))
                near = np.argsort(d, 1)[:, :k]
                w = 1.0 / (np.take_along_axis(d, near, 1) + 0.05) ** 2
                w /= w.sum(1, keepdims=True)
                self.parts.append((part, pts, ("blend", [names[i] for i in range(len(names))], near, w)))
            else:
                self.parts.append((part, pts, ("bone", "Sk_" + part)))
        self.objs = []   # one object per part, coloured by object colour (Workbench keeps no per-point colour through instancing)
        for part, pts, _ in self.parts:
            mesh = bpy.data.meshes.new("P%d_%s" % (phase, part))
            mesh.vertices.add(len(pts))
            ob = bpy.data.objects.new(mesh.name, mesh)
            ob.color = COLOURS.get(part, (0.7, 0.7, 0.7)) + (1.0,)
            bpy.context.scene.collection.objects.link(ob)
            ob.modifiers.new("dots", "NODES").node_group = dot_nodes()
            self.objs.append(ob)
        self.show(False)

    def show(self, on):
        for ob in self.objs:
            ob.hide_render = not on

    def pose(self, fr):
        x, y, zz, yaw = fr["root"]
        c, s = math.cos(yaw), math.sin(yaw)
        Ry = np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
        for ob, (part, pts, how) in zip(self.objs, self.parts):
            if how[0] in ("bone", "prop"):
                v = (fr["bones"] if how[0] == "bone" else fr["props"]).get(how[1])
                if v is None:
                    p = pts
                elif how[0] == "bone":
                    R, t = np.array(v[:9]).reshape(3, 3), np.array(v[9:12])
                    p = pts @ R.T + t
                else:
                    M = np.array(v).reshape(4, 4)
                    p = pts @ M[:3, :3].T + M[:3, 3]
            else:
                names, near, w = how[1], how[2], how[3]
                Ms = np.stack([np.array(fr["bones"][n][:9]).reshape(3, 3) for n in names])
                Ts = np.stack([np.array(fr["bones"][n][9:12]) for n in names])
                p = np.zeros_like(pts)
                for j in range(near.shape[1]):
                    idx = near[:, j]
                    p += w[:, j:j + 1] * (np.einsum("nij,nj->ni", Ms[idx], pts) + Ts[idx])
            P = p @ Ry.T + np.array([0, y, 0])
            ob.data.vertices.foreach_set("co", rig_to_blender(P).ravel())
            ob.data.update()


_nodes = None


def dot_nodes():
    global _nodes
    if _nodes:
        return _nodes
    g = bpy.data.node_groups.new("Dots", "GeometryNodeTree")
    g.interface.new_socket("Geometry", in_out="INPUT", socket_type="NodeSocketGeometry")
    g.interface.new_socket("Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry")
    gi, go = g.nodes.new("NodeGroupInput"), g.nodes.new("NodeGroupOutput")
    m2p = g.nodes.new("GeometryNodeMeshToPoints")
    m2p.inputs["Radius"].default_value = RADIUS
    ico = g.nodes.new("GeometryNodeMeshIcoSphere")
    ico.inputs["Radius"].default_value = RADIUS
    ico.inputs["Subdivisions"].default_value = 1
    inst = g.nodes.new("GeometryNodeInstanceOnPoints")
    real = g.nodes.new("GeometryNodeRealizeInstances")
    setm = g.nodes.new("GeometryNodeSetMaterial")
    setm.inputs["Material"].default_value = dot_material()
    g.links.new(gi.outputs[0], m2p.inputs["Mesh"])
    g.links.new(m2p.outputs[0], inst.inputs["Points"])
    g.links.new(ico.outputs["Mesh"], inst.inputs["Instance"])
    g.links.new(inst.outputs[0], real.inputs[0])
    g.links.new(real.outputs[0], setm.inputs["Geometry"])
    g.links.new(setm.outputs[0], go.inputs[0])
    _nodes = g
    return g


def dot_material():
    return bpy.data.materials.new("dots")


def floor():
    """A 2-stud checker in two objects (Workbench colours by object here), parented to one empty that scrolls."""
    root = bpy.data.objects.new("floor", None)
    bpy.context.scene.collection.objects.link(root)
    for parity, tone in ((0, (0.30, 0.30, 0.33, 1)), (1, (0.42, 0.42, 0.45, 1))):
        verts, faces = [], []
        for i in range(-20, 20):
            for j in range(-20, 20):
                if (i + j) % 2 != parity:
                    continue
                k = len(verts)
                verts += [(i * 2, j * 2, 0), (i * 2 + 2, j * 2, 0), (i * 2 + 2, j * 2 + 2, 0), (i * 2, j * 2 + 2, 0)]
                faces.append((k, k + 1, k + 2, k + 3))
        me = bpy.data.meshes.new("tiles%d" % parity)
        me.from_pydata(verts, [], faces)
        ob = bpy.data.objects.new(me.name, me)
        ob.color = tone
        ob.parent = root
        bpy.context.scene.collection.objects.link(ob)
    return root


def main():
    sc = bpy.context.scene
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    try:
        sc.render.engine = "BLENDER_WORKBENCH"
    except TypeError:
        sc.render.engine = "BLENDER_WORKBENCH_NEXT"
    sh = sc.display.shading
    sh.light, sh.color_type = "STUDIO", "OBJECT"
    sh.show_shadows, sh.show_cavity = True, True
    sc.display.shadow_focus = 0.6
    sc.display.render_aa = "8"
    w = bpy.data.worlds.new("w")
    w.color = (0.55, 0.57, 0.62)
    sc.world = w
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.render.image_settings.file_format = "PNG"
    fl = floor()
    cam = bpy.data.cameras.new("c")
    cam.lens = 55
    cam.sensor_fit, cam.sensor_height = "VERTICAL", 36
    co = bpy.data.objects.new("c", cam)
    sc.collection.objects.link(co)
    sc.camera = co
    from mathutils import Vector
    VIEWS = {"front": ((9.0, 11.5, 1.6), (0, 0, -0.45)), "side": ((12.0, 0.0, -0.2), (0, 0, -0.45))}
    bodies = {p: Body(p) for p in (1, 2)}
    for v in VIEWS:
        os.makedirs(os.path.join(out, v), exist_ok=True)
    g = 0
    log = []
    for e in index:
        data = json.load(open(os.path.join(SHOTS, e["shot"] + ".json")))
        body = bodies[data["phase"]]
        for b in bodies.values():
            b.show(b is body)
        first = g
        for f in range(0, len(data["frames"]), step):
            fr = data["frames"][f]
            body.pose(fr)
            x, y, z, _ = fr["root"]
            fl.location = (-(x % 2.0), z % 2.0, FLOOR)
            lift = (1.55 if data["phase"] == 2 else 0.0) + y * 0.9
            for v, (at, look) in VIEWS.items():
                base = Vector(at) + Vector((0, 0, lift))
                co.location = base
                co.rotation_euler = (Vector(look) + Vector((0, 0, lift)) - base).to_track_quat("-Z", "Y").to_euler()
                bpy.context.view_layer.update()
                sc.render.filepath = os.path.join(out, v, "f_%05d.png" % g)
                bpy.ops.render.render(write_still=True)
            g += 1
        log.append(dict(e, first=first, last=g - 1, step=step))
        print("REEL", e["shot"], first, g - 1, flush=True)
    json.dump(log, open(os.path.join(out, "frames.json"), "w"), indent=1)


main()
