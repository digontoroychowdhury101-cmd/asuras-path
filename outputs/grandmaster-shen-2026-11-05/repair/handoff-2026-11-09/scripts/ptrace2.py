import sys, inspect, numpy as np
sys.path.insert(0, "' + ROOT + '/tools/animation/opening_cast")
import cloth_bake as cb
name, pi, lo, hi = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
phase = int(name[1])
frames, roots = cb.sequence(phase, [("Idle", 0.6, 0.0, 0.0), (name[3:], None, 0.0, 0.0)])
code = inspect.getsource(cb.run_sim)
code = code.replace("'local s = Sim.new(def, %r)\\n' % SCALE", "'local s = Sim.new(def, %r)\\ns.dbg = %d\\n' % (SCALE, " + str(pi + 1) + ")")
code = code.replace("    lines = res.stdout.strip().split(\"\\n\")", "    global TRACE\n    TRACE = res.stdout.strip().split(\"\\n\")\n    lines = [l for l in TRACE if not l.startswith('DBG')]")
ns = dict(cb.__dict__); exec(compile(code, "x", "exec"), ns); ns["run_sim"](phase, frames, roots)
f = 0
for l in ns["TRACE"]:
    if not l.startswith("DBG"): f += 1; continue
    if lo <= f <= hi: print("f%d %s" % (f, l[4:]))
