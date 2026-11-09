"""Trace one particle through every stage of ClothSim steps (debug copy), for given output frames."""
import sys, os, json, math, inspect
import numpy as np
sys.path.insert(0, "' + ROOT + '/tools/animation/opening_cast")
import cloth_bake as cb
name, pi, lo, hi = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
phase = int(name[1])
frames, roots = cb.sequence(phase, [("Idle", 0.6, 0.0, 0.0), (name[3:], None, 0.0, 0.0)])
code = inspect.getsource(cb.run_sim)
code = code.replace("'local s = Sim.new(def, %r)\\n' % SCALE", "'local s = Sim.new(def, %r)\\ns.dbg = %d\\n' % (SCALE, " + str(pi + 1) + ")")
code = code.replace("    lines = res.stdout.strip().split(\"\\n\")", "    global TRACE\n    TRACE = res.stdout.strip().split(\"\\n\")\n    lines = [l for l in TRACE if not l.startswith('DBG')]")
assert "TRACE" in code and "s.dbg" in code
ns = dict(cb.__dict__)
exec(compile(code, "run_sim_trace", "exec"), ns)
ns["run_sim"](phase, frames, roots)
T = ns["TRACE"]
f = 0; prev = None
for l in T:
    if not l.startswith("DBG"):
        f += 1; continue
    if lo <= f <= hi:
        _, tag, x, y, z = l.split(); p = np.array([float(x), float(y), float(z)]) / cb.SCALE
        print("f%-3d %-6s %s %s" % (f, tag, np.round(p, 3), "moved %.3f" % np.linalg.norm(p - prev) if prev is not None else ""))
        prev = p
