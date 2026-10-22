"""QA renders of the lobby kit (run after lobby_kit.py).

Blender -b --python-exit-code 1 -P tools/blender/lobby_kit_preview.py [-- nature]
Writes assets/build/lobby_kit/preview_sheet.png (every piece, textured, studio light) and
preview_bay.png: a pavilion bay assembled from the kit at its Roblox proportions - base, columns,
brackets, architrave, hall roof, balustrade, lantern, basin coping, paving - to check fit and scale.
"""
import json
import math
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

OUT = Path(__file__).resolve().parents[2] / "assets" / "build" / "lobby_kit"


def setup(width, height):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.display.shading.cavity_type = "BOTH"
    scene.render.resolution_x, scene.render.resolution_y = width, height
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("QA") if not scene.world else scene.world
    scene.world = world
    world.color = (0.62, 0.55, 0.48)


def camera(location, target, ortho=None, lens=40):
    cam = bpy.data.cameras.new("QA")
    if ortho:
        cam.type, cam.ortho_scale = "ORTHO", ortho
    cam.lens = lens
    cam.clip_end = 4000
    ob = bpy.data.objects.new("QA", cam)
    bpy.context.scene.collection.objects.link(ob)
    direction = Vector(target) - Vector(location)
    ob.location = location
    ob.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = ob
    return ob


def render(path):
    bpy.context.scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def instance(name, manifest, at, yaw=0.0, scale=(1, 1, 1), collection=None):
    """Duplicates a piece (all its material parts) from its layout slot to `at` (Blender coords)."""
    piece = manifest["pieces"][name]
    ox, oy, oz = piece["layoutOrigin"]
    origin = Vector((ox, -oz, oy))
    M = Matrix.Translation(at) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Diagonal((*scale, 1)) @ Matrix.Translation(-origin)
    for part in piece["parts"]:
        src = bpy.data.objects[part]
        ob = bpy.data.objects.new(part + ".bay", src.data)
        ob.matrix_world = M
        (collection or bpy.context.scene.collection).objects.link(ob)


def nature():
    """Second batch sheet: clouds, maples, shrub and banner in a row, warm key light."""
    bpy.ops.wm.open_mainfile(filepath=str(OUT / "AsuraLobbyNature.blend"))
    setup(2400, 1100)
    bpy.context.scene.world.color = (0.55, 0.62, 0.78)
    camera((118, -160, 34), (118, 0, 8), ortho=250)
    render(OUT / "preview_nature.png")


def main():
    import sys
    if "nature" in sys.argv:
        return nature()
    bpy.ops.wm.open_mainfile(filepath=str(OUT / "AsuraLobbyKit.blend"))
    manifest = json.loads((OUT / "manifest.json").read_text())
    setup(2400, 1350)
    camera((130, -260, 210), (130, 40, 10), ortho=300)
    render(OUT / "preview_sheet.png")

    kit = bpy.data.collections["AsuraLobbyKit"]
    kit.hide_render = True
    bay = bpy.data.collections.new("Bay")
    bpy.context.scene.collection.children.link(bay)
    base = Vector((0, -400, 0))
    # Floor slab (paving medallion texture is tiled on a plane for scale).
    floor = bpy.data.meshes.new("QA_Floor")
    floor.from_pydata([(-40, -30, 0), (40, -30, 0), (40, 30, 0), (-40, 30, 0)], [], [(0, 1, 2, 3)])
    ob = bpy.data.objects.new("QA_Floor", floor)
    ob.location = base
    ob.data.materials.append(bpy.data.materials["Kit_Paving"])
    uv = floor.uv_layers.new()
    for loop in floor.loops:
        co = floor.vertices[loop.vertex_index].co
        uv.data[loop.index].uv = (co.x / 16, co.y / 16)
    bay.objects.link(ob)
    for x in (-11, 11):
        for y in (-5, 5):
            p = base + Vector((x, y, 0))
            instance("Column_Base", manifest, p, collection=bay)
            instance("Column_Lacquer", manifest, p + Vector((0, 0, 0.9)), scale=(1, 1, 1.0), collection=bay)
            instance("Bracket_Set", manifest, p + Vector((0, 0, 10.9)), collection=bay)
    for y in (-5, 5):
        for x in (-7, 0, 7):
            instance("Beam_Architrave", manifest, base + Vector((x, y, 9.3)), scale=(0.9, 1, 1), collection=bay)
    instance("Roof_Hall", manifest, base + Vector((0, 0, 13.6)), collection=bay)
    for k in range(-3, 4):
        instance("Rail_Bay", manifest, base + Vector((k * 6 + 3, -16, 0)), collection=bay)
        instance("Rail_Post", manifest, base + Vector((k * 6, -16, 0)), collection=bay)
    instance("Lantern_Stone", manifest, base + Vector((-6, -22, 0)), collection=bay)
    instance("Lantern_Hanging", manifest, base + Vector((0, -5.2, 10.6)), collection=bay)
    instance("Dais_Bonfire", manifest, base + Vector((14, -24, 0)), collection=bay)
    instance("Stele_Dragon", manifest, base + Vector((-22, -10, 0)), yaw=0.3, collection=bay)
    instance("Ruin_Pillar", manifest, base + Vector((-30, 4, 0)), collection=bay)
    instance("Pool_Rim", manifest, base + Vector((-24, -26, 0)), collection=bay)
    instance("Cliff_Ledge", manifest, base + Vector((0, 0, -0.2)), scale=(1.8, 1.4, 1), collection=bay)
    camera(base + Vector((-26, -62, 16)), base + Vector((0, 0, 7)), lens=32)
    render(OUT / "preview_bay.png")
    camera(base + Vector((0, -14, 3)), base + Vector((0, 0, 12)), lens=24)
    render(OUT / "preview_bay_under.png")


main()
