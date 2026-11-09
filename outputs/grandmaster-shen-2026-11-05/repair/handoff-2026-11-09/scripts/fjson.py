# fjson.py PKLDIR OUTDIR CLIP...: frame JSON for the cloth shot bake from saved bakes, into OUTDIR (ONEHAND_CLIPS env: build those clips one-handed)
import sys, os, pickle
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
S = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
from pathlib import Path
import castlib as C, shen_clips as lib, shen_lib as L
if os.environ.get("ONEHAND_CLIPS"):
    sys.path.insert(0, S); import onehand  # noqa
src, out = sys.argv[1], Path(sys.argv[2]); names = sys.argv[3:]
for clip in lib.library():
    short = clip.name.replace("GrandmasterShen_", "")
    if short not in names: continue
    baked = pickle.load(open(os.path.join(src, short + ".pkl"), "rb"))
    C.frames_json(clip, baked, out / (clip.name + ".json"))
    stats, problems = lib.validate(clip, baked)
    print(short, "->", out, problems)
