import bpy, sys
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=sys.argv[-1])
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
names = [b.name for b in arm.data.bones]
print("BONES", len(names), [n for n in names if not n.startswith("Cl_")])
hand = [o for o in bpy.data.objects if o.type == "MESH" and "LeftHand" in o.name]
for o in hand:
    print("HANDGROUPS", o.name, [g.name for g in o.vertex_groups])
