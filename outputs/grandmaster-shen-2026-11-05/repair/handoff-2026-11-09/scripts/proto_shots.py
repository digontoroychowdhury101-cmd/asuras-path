# proto_shots.py CLIP TAG=PKL [TAG=PKL ...] : frame JSON for each saved bake in its own folder ($S/shotsrc_TAG, beside the current Idle), then the
# game's cloth bake of shot cK_CLIP_TAG from it (cloth_bake.py, SHEN_BAKE_DIR / SHEN_SHOT_SUFFIX), for the x-ray renders that compare them
import sys, os, shutil, pickle, subprocess
from pathlib import Path
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
S = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, castlib as C
name = sys.argv[1]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
ph = name[1]
for spec in sys.argv[2:]:
    tag, pk = spec.split("=", 1)
    d = Path(S) / ("shotsrc_" + tag)
    d.mkdir(exist_ok=True)
    shutil.copy(Path(ROOT) / "work/opening_cast_bake/shen" / ("GrandmasterShen_P%s_Idle.json" % ph), d)
    C.frames_json(clip, pickle.load(open(pk, "rb")), d / (clip.name + ".json"))
    env = dict(os.environ, SHEN_BAKE_DIR=str(d), SHEN_SHOT_SUFFIX="_" + tag, VECLIB_MAXIMUM_THREADS="1", OMP_NUM_THREADS="1")
    r = subprocess.run([sys.executable, "tools/animation/opening_cast/cloth_bake.py", "c%s_%s" % (ph, name.split("_", 1)[1])], env=env, capture_output=True, text=True)
    print(tag, "->", "c%s_%s_%s" % (ph, name.split("_", 1)[1], tag), "ok" if r.returncode == 0 else r.stderr[-600:])
