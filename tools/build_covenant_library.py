#!/usr/bin/env python3
"""Write assets/models/AsuraCovenantKit.rbxmx from the uploaded ids in assets/COVENANT_KIT_UPLOADED.json (AR01).

Same format as tools/build_foundry_library.py: each piece is a Model pivoted at its ground centre holding one decorative
MeshPart (no collision, query or touch) with a SurfaceAppearance. Rerun after a re-upload.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = json.loads((ROOT / "assets/COVENANT_KIT_UPLOADED.json").read_text())
_ref = 0


def ref():
    global _ref
    _ref += 1
    return str(_ref)


def vec(name, v):
    return f'<Vector3 name="{name}"><X>{v[0]}</X><Y>{v[1]}</Y><Z>{v[2]}</Z></Vector3>'


def frame(tag, name, p):
    return (f'<{tag} name="{name}"><X>{p[0]}</X><Y>{p[1]}</Y><Z>{p[2]}</Z><R00>1</R00><R01>0</R01><R02>0</R02>'
            f'<R10>0</R10><R11>1</R11><R12>0</R12><R20>0</R20><R21>0</R21><R22>1</R22></{tag}>')


def content(name, asset):
    return f'<Content name="{name}"><uri>rbxassetid://{asset}</uri></Content>'


def piece(name, d):
    pivot = (f'<OptionalCoordinateFrame name="WorldPivotData"><CFrame><X>0</X><Y>0</Y><Z>0</Z><R00>1</R00><R01>0</R01><R02>0</R02>'
             f'<R10>0</R10><R11>1</R11><R12>0</R12><R20>0</R20><R21>0</R21><R22>1</R22></CFrame></OptionalCoordinateFrame>')
    return f'''<Item class="Model" referent="{ref()}"><Properties><string name="Name">{name}</string>{pivot}</Properties>
<Item class="MeshPart" referent="{ref()}"><Properties><string name="Name">{name}__Covenant</string>
<bool name="Anchored">true</bool><bool name="CanCollide">false</bool><bool name="CanQuery">false</bool><bool name="CanTouch">false</bool>
{frame("CoordinateFrame", "CFrame", d["centre"])}
{vec("InitialSize", d["size"])}{vec("size", d["size"])}
{content("MeshContent", d["mesh"])}
<token name="CollisionFidelity">2</token><token name="RenderFidelity">1</token>
</Properties>
<Item class="SurfaceAppearance" referent="{ref()}"><Properties><string name="Name">SurfaceAppearance</string><token name="AlphaMode">0</token>
{content("ColorMapContent", d["color"])}{content("NormalMapContent", d["normal"])}{content("RoughnessMapContent", d["roughness"])}{content("MetalnessMapContent", d["metalness"])}
</Properties></Item></Item></Item>'''


body = "\n".join(piece(n, d) for n, d in DATA["pieces"].items())
xml = f'''<roblox version="4"><Item class="Folder" referent="{ref()}"><Properties><string name="Name">{DATA["library"]}</string></Properties>
{body}
</Item></roblox>
'''
(ROOT / "assets/models/AsuraCovenantKit.rbxmx").write_text(xml)
print("wrote", len(DATA["pieces"]), "pieces")
