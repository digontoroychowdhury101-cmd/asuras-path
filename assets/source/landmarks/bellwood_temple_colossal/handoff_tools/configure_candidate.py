"""Write the configured assembly only after Studio has read back every candidate piece."""
import json
from pathlib import Path
import sys

ROOT = Path.cwd()
sys.path.insert(0,str(ROOT/"tools/assets"))
import glb_split

RUN = ROOT / "work/sol-bellwood-v20"
REGISTRY = ROOT / "assets/LANDMARK_KIT_UPLOADED.json"
LAYOUT = ROOT / "src/shared/LandmarkLayout.luau"
record = json.loads(REGISTRY.read_text())
main = "Bellwood_ColossalTemple"
guardians = RUN.parent / "sol-bellwood-guardian-pilot"
pieces = {main: RUN / "preserved" / f"{main}.glb",
          "Bellwood_ColossalGuardianEast": guardians / "Bellwood_ColossalGuardianEast.glb",
          "Bellwood_ColossalGuardianWest": guardians / "Bellwood_ColossalGuardianWest.glb"}

def foot(file):
    doc, _ = glb_split.read(file)
    vertices = [doc["accessors"][p["attributes"]["POSITION"]] for mesh in doc["meshes"] for p in mesh["primitives"]]
    lo = [min(a["min"][k] for a in vertices) for k in range(3)]
    hi = [max(a["max"][k] for a in vertices) for k in range(3)]
    return -(lo[0]+hi[0])/2,lo[1],-(lo[2]+hi[2])/2

def piece(name, x=0,y=0,z=0,yaw=0):
    doc, _ = glb_split.read(pieces[name])
    expected = {n["name"] for n in doc["nodes"] if "mesh" in n}
    assert expected == set(record["pieces"][name]), name
    foot_x,foot_y,foot_z=foot(pieces[name])
    return f'{{ Model = "{name}", X = {x:.4f}, Y = {y:.4f}, Z = {z:.4f}, Yaw = {yaw:.3f}, Foot = {{ X = {foot_x:.4f}, Y = {foot_y:.4f}, Z = {foot_z:.4f} }} }}'

def guardian(side, name):
    step = 23 if side==1 else 27
    width = 77-33*step/128
    return piece(name,-side*(width/2+19),.6+.88*step+9.15,257-2.35*step,side*.38)

configuration = f'''			ColossalTemple = {{ Model = "{main}", Across = 30, Along = -115, Lift = 2,
				Pieces = {{
					{piece(main)},
					{guardian(1,"Bellwood_ColossalGuardianEast")},
					{guardian(-1,"Bellwood_ColossalGuardianWest")},
				}},
				Accents = {{ {{ 0, 133, -52, 36, 1.55 }}, {{ -22, 140, -46, 34, 1.35 }},
					{{ 22, 140, -46, 34, 1.35 }}, {{ -47, 124, -47, 30, 1.05 }}, {{ 47, 124, -47, 30, 1.05 }} }},
				Chimes = {{ X = 0, Y = 132, Z = -58 }},
			}},
'''
old = LAYOUT.read_text()
i = old.index("\t\t\t-- The temple's twin gate towers")
assert 'ColossalTemple = {' not in old
LAYOUT.write_text(old[:i]+configuration+old[i:])
