"""Headless material comparison; offline asset review, not running-game evidence.

Blender -b CANDIDATE.blend -P tools/blender/review_fused_root_detail.py -- RECOVERY NEW_OUTPUT
"""
import gzip
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

source, out = map(Path, sys.argv[sys.argv.index("--")+1:])
assert bpy.app.background
out.mkdir(parents=True, exist_ok=False)
objects = [o for o in bpy.context.scene.objects if o.type == "MESH"]
obj = next(o for o in objects if o.name == "Titan_Canopy_14")
for other in objects:
    other.hide_render = other != obj
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 24
scene.render.resolution_x, scene.render.resolution_y, scene.render.resolution_percentage = 1100, 800, 100
world = bpy.data.worlds.new("RootDetailReview")
world.use_nodes = True
next(n for n in world.node_tree.nodes if n.type == "BACKGROUND").inputs["Color"].default_value = (.08,.09,.11,1)
scene.world = world
center = obj.matrix_world.translation
camera = bpy.data.objects.new("RootDetailReviewCamera", bpy.data.cameras.new("RootDetailReviewCamera"))
scene.collection.objects.link(camera)
scene.camera = camera
camera.location = center + Vector((45,-70,45))
camera.rotation_euler = (center-camera.location).to_track_quat("-Z","Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 48
for energy, rotation in [(3,(35,-20,-35)),(.8,(65,20,135))]:
    light = bpy.data.objects.new("ReviewSun", bpy.data.lights.new("ReviewSun","SUN"))
    light.data.energy = energy
    light.rotation_euler = tuple(math.radians(a) for a in rotation)
    scene.collection.objects.link(light)
scene.render.filepath = str(out / "after_offline_material.png")
bpy.ops.render.render(write_still=True)
report = {"kind":"offline material review; uninstalled candidate; no game acceptance claim", "parts":[]}
for part in objects:
    data = part.data
    density = []
    for face in data.polygons:
        a,b,c = [data.vertices[i].co for i in face.vertices]
        u,v,w = [data.uv_layers[0].data[i].uv for i in face.loop_indices]
        area = (b-a).cross(c-a).length*.5*1.5**2
        uvarea = abs((v.x-u.x)*(w.y-u.y)-(v.y-u.y)*(w.x-u.x))*.5
        if area>1e-9:
            density.append((2048*math.sqrt(uvarea/area),area))
    density.sort()
    total, accumulated, median = sum(a for _,a in density),0,None
    for d,a in density:
        accumulated += a
        if accumulated>=total*.5:
            median=d
            break
    report["parts"].append({"name":part.name,"density2048PixelsPerProductionStudMedian":median})
data = json.loads(gzip.decompress((source / "Titan_Canopy_14.json.gz").read_bytes()))
uv = obj.data.uv_layers[0]
uv.data.foreach_set("uv", [x for f in data["faces"] for i in f[6:9] for x in (data["uvs"][i][0],1-data["uvs"][i][1])])
material = bpy.data.materials.new("OriginalUploadedRootReadback")
material.use_nodes = True
nodes, links = material.node_tree.nodes, material.node_tree.links
shader = next(n for n in nodes if n.type=="BSDF_PRINCIPLED")
for key, socket in [("ColorMapContent","Base Color"),("RoughnessMapContent","Roughness"),("NormalMapContent","Normal")]:
    texture=nodes.new("ShaderNodeTexImage")
    texture.image=bpy.data.images.load(str(source / "maps" / (data["maps"][key].split("//")[-1]+".png")),check_existing=True)
    if key!="ColorMapContent":
        texture.image.colorspace_settings.name="Non-Color"
    if socket=="Normal":
        normal=nodes.new("ShaderNodeNormalMap")
        links.new(texture.outputs["Color"],normal.inputs["Color"])
        links.new(normal.outputs["Normal"],shader.inputs[socket])
    else:
        links.new(texture.outputs["Color"],shader.inputs[socket])
obj.data.materials.clear()
obj.data.materials.append(material)
scene.render.filepath=str(out / "before_offline_material.png")
bpy.ops.render.render(write_still=True)
(out / "report.json").write_text(json.dumps(report,indent=2)+"\n")
print("REVIEW_WRITTEN",out)
