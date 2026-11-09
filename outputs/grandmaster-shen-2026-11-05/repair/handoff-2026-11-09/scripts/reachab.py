import sys
sys.path.insert(0, "' + ROOT + '/tools/animation/opening_cast")
import shen_lib as L, shen_clips as SC
m = sys.argv[1]
if "noclash" in m: L.CLASH_COST = 0.0
if "noclear" in m: L.CLEAR_MARGIN = 99.0
for clip in SC.library():
    if not clip.name.endswith(sys.argv[2]): continue
    if "norelease" in m:
        clip.keys = [k for k in clip.keys if not (0.43 < k[0] < 0.81 and ("ltw" in k[1] or "lt" in k[1]))]
    b = clip.bake(); w, p = L.validate(clip, b)
    print(m, w["strike"]["game_radius_during_active"], p, flush=True)
