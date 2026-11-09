# wycheck.py CLIP... : bake each clip up to the end of the wrist_yield rounds (stops at clear_free_arm) and print the contact frames that asked
# wrist_yield for a haft tilt (the frames the 2026-11-09 guard leaves on the keyed line); an empty list means the guard changed nothing there
import sys, os
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
class Stop(Exception): pass
def stop(*a, **k): raise Stop()
L.clear_free_arm = stop
lib = {c.name: c for c in SC.library()}
for name in sys.argv[1:]:
    clip = lib["GrandmasterShen_" + name]
    try: clip.bake()
    except Stop: pass
    print("WY", name, clip.__dict__.get("_wy_contact", []), flush=True)
