"""Preview renders of baked Zhao clips in Blender 5.x Workbench, on the v2 production mesh (default: the ZhaoV2_Game
collection of assets/source/bosses/general_zhao/v2_design/GeneralZhao_v2.blend, each piece welded to its R15 limb the
way BossSkin welds it in game) or, with --costume, on the blocky LooksDuelists fallback costume (costume.py).

    Blender -b --factory-startup -P tools/animation/general_zhao/preview_blender.py -- BAKE_DIR OUT_DIR [clip ...] [--video] [--costume]

Per clip: a contact sheet of key frames from the front, the right side and the gameplay camera (Roblox 70 degree FOV,
boss at runtime scale 1.2, player stand-in 8 studs away (melee range)); with --video, an MP4 from the gameplay camera.
Roblox root space (+X right, +Y up, -Z forward) maps to Blender as (x, -z, y), so Zhao faces Blender +Y.
"""
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import costume  # noqa: E402
import rig  # noqa: E402

C = np.array([[1, 0, 0], [0, 0, -1], [0, 1, 0]], float)
SCALE = rig.BOSS_SCALE
LIFT = -rig.GROUND  # raise the rig so its soles sit on z = 0
PLAYER_DIST = 8.0  # melee range: the guandao reaches about 9 studs
SHEET_W, SHEET_H = int(__import__("os").environ.get("SW", 400)), int(__import__("os").environ.get("SH", 400))
GAME_W, GAME_H = 640, 360


def to_blender(M, scale=1.0, lift=LIFT):
    R = C @ M[:3, :3] @ C.T
    p = C @ (M[:3, 3] + np.array([0, lift, 0])) * scale
    out = Matrix.Identity(4)
    for i in range(3):
        for j in range(3):
            out[i][j] = R[i, j] * scale
        out[i][3] = p[i]
    return out


def srgb(c):
    return tuple(((x / 255) ** 2.2) for x in c) + (1,)


def material(name, color, emit=False):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.diffuse_color = srgb(color)
    if emit:
        m.diffuse_color = srgb(tuple(min(255, int(x * 1.5 + 40)) for x in color))
    return m


def box_mesh(name, shape):
    me = bpy.data.meshes.get(name)
    if me:
        return me
    import bmesh
    bm = bmesh.new()
    if shape == "Cylinder":
        bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=0.5, radius2=0.5, depth=1.0,
                              matrix=Matrix.Rotation(math.pi / 2, 4, "Y"))
    elif shape == "Ball":
        bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=0.5)
    elif shape == "Wedge":
        # Roblox wedge: full at the bottom and back, sloping from top-back to bottom-front (-Z). Blender y = -Roblox z.
        vs = [bm.verts.new(p) for p in [(-.5, .5, -.5), (.5, .5, -.5), (-.5, -.5, -.5), (.5, -.5, -.5),
                                       (-.5, -.5, .5), (.5, -.5, .5)]]
        # bottom (z=-.5): 0,1,3,2 ; back face (y=-.5 is Roblox +z back): 2,3,5,4 ; slope 0,1,5,4 ; sides
        for f in [(0, 2, 3, 1), (2, 4, 5, 3), (0, 1, 5, 4), (0, 4, 2), (1, 3, 5)]:
            bm.faces.new([vs[i] for i in f])
    else:
        bmesh.ops.create_cube(bm, size=1.0)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return me


def piece_local(p):
    rot = p.get("rot", (0, 0, 0))
    M = np.eye(4)
    M[:3, :3] = rig.euler(rot)
    M[:3, 3] = p["at"]
    return M


def build():
    objs = {}
    for part, size in rig.SIZES.items():
        if part == "HumanoidRootPart":
            continue
        o = bpy.data.objects.new("B_" + part, box_mesh("box", "Block").copy())
        o.data.materials.clear()
        o.data.materials.append(material("body_" + part, costume.BODY_COLOR.get(part, costume.DEFAULT_BODY)))
        bpy.context.scene.collection.objects.link(o)
        objs[o.name] = (part, np.diag(list(size) + [1.0]))
    for p in costume.pieces():
        size = np.asarray(p["size"], float)
        if p.get("fit"):
            size = np.asarray(rig.SIZES[p["bone"]], float) + size
        o = bpy.data.objects.new("C_" + p["name"], box_mesh("shape_" + p.get("shape", "Block"), p.get("shape", "Block")))
        mat = material("m_%s_%d_%d_%d" % ((p["material"],) + tuple(p["color"])), p["color"], p.get("glow", False))
        o.data = o.data.copy()
        o.data.materials.append(mat)
        bpy.context.scene.collection.objects.link(o)
        sz = np.eye(4)
        if p.get("shape") == "Cylinder":
            sz[:3, :3] = np.diag([size[0], size[1], size[2]])
        else:
            sz[:3, :3] = np.diag(size)
        objs[o.name] = (p["bone"], piece_local(p) @ sz)
    return objs


V2_BLEND = Path(__file__).resolve().parents[3] / "assets/source/bosses/general_zhao/v2_design/GeneralZhao_v2.blend"


def build_v2():
    """Appends the v2 game pieces. Each sits at its limb centre with identity rotation and Blender-local geometry, so its
    world matrix is simply the limb's (BossSkin: part.CFrame = limb.CFrame * AsuraBind:Inverse(), bind at the centre)."""
    with bpy.data.libraries.load(str(V2_BLEND), link=False) as (src, dst):
        dst.collections = ["ZhaoV2_Game"]
    objs = {}
    for o in dst.collections[0].all_objects:
        bpy.context.scene.collection.objects.link(o)
        o.parent = None
        objs[o.name] = (o["AsuraBone"], np.eye(4))
        for m in o.data.materials:
            tex = [n for n in m.node_tree.nodes if n.type == "TEX_IMAGE" and "_Color_" in n.image.name] if m and m.node_tree else []
            if tex:
                m.node_tree.nodes.active = tex[0]
    return objs


# Box meshes are unit cubes in Blender space; Roblox part-local scale (sx, sy, sz) must be applied in Roblox axes
# before conversion, which to_blender does when given world @ local @ size.
def place(objs, frame, scale=1.0, offset=(0, 0, 0)):
    for name, (part, local) in objs.items():
        M = np.asarray(frame[part]).reshape(4, 4) @ local
        B = to_blender(M, scale)
        B.translation += Vector(offset)
        bpy.data.objects[name].matrix_world = B


def player_standin():
    """A neutral grey R15 block figure at the player's position, facing Zhao, for scale in the gameplay view."""
    world = rig.fk({})
    mat = material("player", (150, 154, 160))
    out = []
    for part, size in rig.SIZES.items():
        if part == "HumanoidRootPart":
            continue
        o = bpy.data.objects.new("P_" + part, box_mesh("box", "Block"))
        o.data = o.data.copy()
        o.data.materials.clear()
        o.data.materials.append(mat)
        bpy.context.scene.collection.objects.link(o)
        M = world[part] @ np.diag(list(size) + [1.0])
        B = to_blender(M, 1.0)
        B = Matrix.Translation((-4.2, PLAYER_DIST, 0)) @ Matrix.Rotation(math.pi, 4, "Z") @ B
        o.matrix_world = B
        out.append(o)
    return out


def stage():
    sc = bpy.context.scene
    for o in list(sc.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light, sh.color_type = "STUDIO", "MATERIAL"
    sh.show_shadows, sh.shadow_intensity = True, 0.45
    sh.show_cavity, sh.cavity_type = True, "WORLD"
    sh.show_object_outline, sh.object_outline_color = True, (0.02, 0.02, 0.03)
    sh.background_type, sh.background_color = "VIEWPORT", (0.11, 0.12, 0.14)
    sc.display.light_direction = (0.35, -0.55, 0.75)
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.exposure = 0.9
    # stone ground with a 1-stud grid so planted feet and sliding read
    import bmesh
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=60, y_segments=60, size=30)
    me = bpy.data.meshes.new("ground")
    bm.to_mesh(me)
    bm.free()
    g = bpy.data.objects.new("Ground", me)
    g.data.materials.append(material("stone", (70, 72, 76)))
    sc.collection.objects.link(g)
    grid_mat = material("grid", (52, 54, 58))
    for i in range(-12, 13):
        for axis in (0, 1):
            o = bpy.data.objects.new("grid", box_mesh("box", "Block"))
            o.data = o.data.copy()
            o.data.materials.clear()
            o.data.materials.append(grid_mat)
            sc.collection.objects.link(o)
            o.scale = (0.03, 24, 0.002) if axis == 0 else (24, 0.03, 0.002)
            o.location = (i, 0, 0.002) if axis == 0 else (0, i, 0.002)
    return g


def camera(name, loc, target, ortho=None, lens_fov=None):
    cam = bpy.data.cameras.new(name)
    o = bpy.data.objects.new(name, cam)
    bpy.context.scene.collection.objects.link(o)
    o.location = loc
    d = Vector(target) - Vector(loc)
    o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    if ortho:
        cam.type, cam.ortho_scale = "ORTHO", ortho
    if lens_fov:
        cam.sensor_fit = "VERTICAL"
        cam.angle_y = math.radians(lens_fov)
    cam.clip_end = 400
    return o


def render(path, cam, w, h):
    sc = bpy.context.scene
    sc.camera = cam
    sc.render.resolution_x, sc.render.resolution_y, sc.render.resolution_percentage = w, h, 100
    sc.render.image_settings.file_format = "PNG"
    sc.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def load_png(path):
    img = bpy.data.images.load(str(path))
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    bpy.data.images.remove(img)
    return px


def save_png(px, path):
    h, w, _ = px.shape
    img = bpy.data.images.new("sheet", w, h, alpha=True)
    img.pixels = px.ravel().tolist()
    img.filepath_raw = str(path)
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def sample_indices(data, n=6):
    frames = data["frames"]
    times = [f["t"] for f in frames]
    picks = set(data.get("preview", []))
    if not picks:
        L = times[-1]
        picks = {round(L * i / (n - 1), 4) for i in range(n)}
        picks |= set(data.get("contacts", []))
    idx = sorted({min(range(len(times)), key=lambda i: abs(times[i] - t)) for t in picks})
    return idx[:9]


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    video, blocky = "--video" in argv, "--costume" in argv
    argv = [a for a in argv if a not in ("--video", "--costume")]
    bake_dir, out_dir = Path(argv[0]), Path(argv[1])
    names = argv[2:] or sorted(p.stem for p in bake_dir.glob("*.json"))
    out_dir.mkdir(parents=True, exist_ok=True)
    tmp = out_dir / "_tmp"
    tmp.mkdir(exist_ok=True)
    stage()
    objs = build() if blocky else build_v2()
    if not blocky:
        bpy.context.scene.display.shading.color_type = "TEXTURE"
        bpy.context.scene.view_settings.exposure = 1.6  # v2 lacquer is near-black; lift it so the form reads
    players = player_standin()
    lift_z = 0.0
    front = camera("Front", (0, 60, 11.0), (0, 0, 2.9), ortho=12)
    side = camera("Side", (60, 3.6, 11.0), (0, 3.6, 2.9), ortho=15)
    eye = Vector((-2.0, PLAYER_DIST + 6.0, 6.2))  # a third-person camera just behind the player's shoulder
    game = camera("Game", eye, (0, 1.0, 4.4), lens_fov=70)
    for name in names:
        data = json.loads((bake_dir / (name + ".json")).read_text())
        frames = data["frames"]
        rows = []
        for i in sample_indices(data):
            f = frames[i]["parts"]
            cols = []
            for o in players:
                o.hide_render = True
            for cam in (front, side):
                place(objs, f)
                p = tmp / ("%s_%s_%d.png" % (name, cam.name, i))
                render(p, cam, SHEET_W if cam is front else int(SHEET_W * 1.5), SHEET_H)
                cols.append(load_png(p))
            for o in players:
                o.hide_render = False
            place(objs, f, SCALE)
            p = tmp / ("%s_game_%d.png" % (name, i))
            render(p, game, int(SHEET_H * 4 / 3), SHEET_H)
            cols.append(load_png(p))
            rows.append(np.concatenate(cols, axis=1))
        # rows are top-to-bottom in reading order; Blender pixel rows start at the bottom
        sheet = np.concatenate(rows[::-1], axis=0)
        save_png(sheet, out_dir / (name + "_sheet.png"))
        if video:
            sc = bpy.context.scene
            for o in players:
                o.hide_render = False
            step = 2  # 60 Hz bake -> 30 fps video
            for k, fr in enumerate(frames[::step]):
                place(objs, fr["parts"], SCALE)
                for oname in objs:
                    bpy.data.objects[oname].keyframe_insert("location", frame=k + 1)
                    bpy.data.objects[oname].keyframe_insert("rotation_euler", frame=k + 1)
                    bpy.data.objects[oname].keyframe_insert("scale", frame=k + 1)
            sc.frame_start, sc.frame_end = 1, len(frames[::step])
            sc.render.fps = 30
            sc.camera = game
            sc.render.resolution_x, sc.render.resolution_y = GAME_W, GAME_H
            sc.render.image_settings.file_format = "FFMPEG"
            sc.render.ffmpeg.format, sc.render.ffmpeg.codec = "MPEG4", "H264"
            sc.render.ffmpeg.constant_rate_factor = "HIGH"
            sc.render.filepath = str(out_dir / (name + "_game.mp4"))
            bpy.ops.render.render(animation=True)
            for oname in objs:
                bpy.data.objects[oname].animation_data_clear()
            sc.render.image_settings.file_format = "PNG"
    for p in tmp.glob("*.png"):
        p.unlink()
    tmp.rmdir()


main()
