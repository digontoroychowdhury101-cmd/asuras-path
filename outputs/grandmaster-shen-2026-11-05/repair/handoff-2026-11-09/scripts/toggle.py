import sys
sys.path.insert(0, "tools/animation/opening_cast")
import shen_clips as SC, shen_lib as L, rig as ZR
mode = sys.argv[2]
if "noyield" in mode: L.wrist_yield = lambda clip, ctrl: False
if "settle2" in mode:
    orig = L.settle
    L.settle = lambda clip, ctrl, sigma=2.0, passes=2: orig(clip, ctrl, sigma, 2)
clip = [c for c in SC.library() if c.name.endswith(sys.argv[1])][0]
b = clip.bake()
print(sys.argv[1], mode, L.validate(clip, b)[1])
