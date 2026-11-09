import sys, time, os
lib = sys.argv[1]
if lib != "-": sys.path.insert(0, lib)
sys.path.append("' + ROOT + '/tools/animation/opening_cast")
import shen_lib as L, shen_clips as SC
print("lib", L.__file__)
phase, name = int(sys.argv[2]), sys.argv[3]
clip = [c for c in SC.build(phase) if c.name.endswith("_" + name)][0]
t0 = time.time(); clip.bake(); print("BAKE %s %s %.1fs" % (lib, name, time.time() - t0))
