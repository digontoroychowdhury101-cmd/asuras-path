# shots_gamefade.py SECONDS CLIPNAME... : (Windows pass 2026-11-11) cloth_bake.py c-shots (Idle 0.6 s, then the clip) with the fade into the clip
# shortened from cloth_bake's 0.2 s to SECONDS (the game's: 0.1 s for a planned attack's Play, 0.15 s otherwise; BossAnimations.luau), for
# mesh_clash.py. CLIPNAME as c<phase>_<Clip>; the shot is written as <CLIPNAME><SHEN_SHOT_SUFFIX>. cloth_bake's fade curve (smoothstep, from the
# last Idle pose held) is kept; only its length changes. Same environment as cloth_bake.py.
import os, sys
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast")
import cloth_bake as CB

sec = float(sys.argv[1])
for name in sys.argv[2:]:
    assert name[0] == "c" and name[1] in "12" and name[2] == "_", name
    CB.bake_shot(name, int(name[1]), [("Idle", 0.6, 0.0, 0.0), (name[3:], None, 0.0, 0.0)], fade=sec)
