"""Re-run a c1_/c2_ shot through ClothSim exactly as cloth_bake does, and save every particle's position per frame (root space, rig units)."""
import sys, os, json, math, subprocess
import numpy as np
sys.path.insert(0, "' + ROOT + '/tools/animation/opening_cast")
import cloth_bake as cb
name = sys.argv[1]; out = sys.argv[2]
phase = int(name[1])
frames, roots = cb.sequence(phase, [("Idle", 0.6, 0.0, 0.0), (name[3:], None, 0.0, 0.0)])
cloth = json.loads((cb.CLOTH_DIR / f"cloth_p{phase}.json").read_text())
orig = cb.CLOTH_SIM.read_text()
# same code as run_sim, plus every particle's position after the bones
src = cb.run_sim.__code__
import inspect
code = inspect.getsource(cb.run_sim)
code = code.replace('    print(table.concat(parts, " "))', '    for i = 1, s.n do parts[#parts + 1] = string.format("%.5f %.5f %.5f", s.x[i], s.y[i], s.z[i]) end\n    print(table.concat(parts, " "))')
code = code.replace("assert len(lines) == len(frames), (len(lines), len(frames))", "pass")
ns = dict(cb.__dict__)
exec(compile(code, "run_sim_dump", "exec"), ns)
cl, sim = ns["run_sim"](phase, frames, roots)
nb = len([p for p in cloth["particles"] if "bone" in p])
n = len(cloth["particles"])
P = sim[:, nb * 12:].reshape(len(frames), n, 3)
# back to root space at scale 1
W = []
for f, (x, y, z, yaw) in enumerate(roots):
    c, s_ = math.cos(yaw), math.sin(yaw)
    Ry = np.array([[c, 0, s_], [0, 1, 0], [-s_, 0, c]])
    W.append(((P[f] - np.array([x, y, z])) @ Ry) / cb.SCALE)
np.save(out, np.array(W))
print("dumped", np.array(W).shape)
