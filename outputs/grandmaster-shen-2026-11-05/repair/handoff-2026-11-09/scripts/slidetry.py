import sys, importlib.util, numpy as np
sys.path.insert(0, "' + ROOT + '/tools/animation/opening_cast")
import shen_lib as L
spec = importlib.util.spec_from_file_location("shen_clips", sys.argv[1]); SC = importlib.util.module_from_spec(spec); sys.modules["shen_clips"] = SC; spec.loader.exec_module(SC)
clip=[c for c in SC.library() if c.name.endswith("P1_Guandao_Heavy")][0]
baked=clip.bake(); w,p=L.validate(clip,baked)
print(sys.argv[1][-10:], {k: w.get(k) for k in ("weapon_in_arm_left","in_weapon_arm_left","weapon_in_arm_right","in_weapon_arm_right","in_weapon_hands","left_grip","left_reach")}, p)
