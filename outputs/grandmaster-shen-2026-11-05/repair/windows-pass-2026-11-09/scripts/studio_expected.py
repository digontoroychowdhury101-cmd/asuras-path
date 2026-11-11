# studio_expected.py OUT.rbxmx CLIP... : (Windows pass 2026-11-10) the exported frame JSON (work/opening_cast_bake/shen/<clip>.json: every baked
# frame, each part's 4x4 in root space, rig units) as a Roblox model file Studio can load locally (game:GetObjects from its content folder): a
# Folder "ShenExpected" holding one StringValue per clip, its Value a JSON list of [t, {part: [x, y, z, R00..R22]}] for the parts the Studio
# check compares (hands, forearms, glaive, torso, head, feet). The Studio side plays the exported KeyframeSequence on the live boss rig, pauses at
# each t and measures the same parts against its HumanoidRootPart, so any difference is the engine's playback of the export (keyframe reduction,
# rig joints, scale), not the solver. Nothing is uploaded.
import json, os, sys
from xml.sax.saxutils import escape

ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../.."))
BAKE = os.path.join(ROOT, "work/opening_cast_bake/shen")
PARTS = ("LowerTorso", "UpperTorso", "Head", "RightLowerArm", "RightHand", "LeftLowerArm", "LeftHand", "Glaive", "RightFoot", "LeftFoot")
if os.environ.get("LEGS"):     # (2026-11-11) LEGS=1: the thighs and shins too (P2 Skyfall's right knee turns in; the default set has only the feet)
    PARTS += ("RightUpperLeg", "RightLowerLeg", "LeftUpperLeg", "LeftLowerLeg")

out, names = sys.argv[1], sys.argv[2:]
items = []
for n in names:
    j = json.load(open(os.path.join(BAKE, n + ".json")))
    rows = []
    for f in j["frames"]:
        parts = {}
        for p in PARTS:
            if p in f["parts"]:
                m = f["parts"][p]          # row-major 4x4: [R00 R01 R02 X; R10 R11 R12 Y; R20 R21 R22 Z; 0 0 0 1]
                parts[p] = [round(v, 5) for v in (m[3], m[7], m[11], m[0], m[1], m[2], m[4], m[5], m[6], m[8], m[9], m[10])]
        rows.append([round(f["t"], 5), parts])
    items.append('<Item class="StringValue"><Properties><string name="Name">%s</string><string name="Value">%s</string></Properties></Item>'
                 % (escape(n), escape(json.dumps(rows, separators=(",", ":")))))
xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" version="4"><Item class="Folder"><Properties><string name="Name">ShenExpected</string>'
       '</Properties>%s</Item></roblox>' % "".join(items))
open(out, "w", encoding="utf-8").write(xml)
print(out, len(names), "clips", len(xml), "bytes")
