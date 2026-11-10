# framejson.py BAKEDDIR OUTDIR CLIP... : (Windows pass 2026-11-10) the export's frame JSON (castlib.frames_json, root space) for saved bakes, written
# to OUTDIR instead of work/opening_cast_bake, so popjson.py can compare bakes that are not exported. Writes nothing in the repo.
import os, sys, pickle
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
from pathlib import Path
import castlib as C, shen_clips as SC
src, out, names = sys.argv[1], Path(sys.argv[2]), sys.argv[3:]
out.mkdir(parents=True, exist_ok=True)
lib = {c.name: c for c in SC.library()}
for n in names:
    p = os.path.join(src, n + ".pkl")
    if not os.path.exists(p):
        print("%-24s no bake in %s" % (n, src)); continue
    clip = lib["GrandmasterShen_" + n]
    C.frames_json(clip, pickle.load(open(p, "rb")), out / (clip.name + ".json"))
    print("%-24s ok" % n)
