# shots_fade.py SHOT... : (Windows pass 2026-11-10) cloth_bake.py shots named f<phase>_<Clip>: Idle 0.6 s, the clip once, Idle 0.8 s, so a review
# shows the clip's fade in from Idle and its fade back out to Idle (cloth_bake's joint-by-joint fade, 0.2 s smoothstep; the game's is 0.1-0.2 s
# linear, fadecheck3.py). The same environment as cloth_bake.py: SHEN_BAKE_DIR (frame JSON to shoot), SHEN_SHOT_SUFFIX, SHEN_CLOTH_SIM, SHEN_CLOTH_DIR.
# render_cmp.py renders them like c<phase>_ shots (from frame 17, the end of the first Idle, to the end).
import os, sys
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast")
import cloth_bake as CB

for name in sys.argv[1:]:
    assert name[0] == "f" and name[1] in "12" and name[2] == "_", name
    CB.bake_shot(name, int(name[1]), [("Idle", 0.6, 0.0, 0.0), (name[3:], None, 0.0, 0.0), ("Idle", 0.8, 0.0, 0.0)])
