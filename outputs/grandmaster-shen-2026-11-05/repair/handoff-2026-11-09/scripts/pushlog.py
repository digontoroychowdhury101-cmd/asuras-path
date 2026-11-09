import sys, os, json, inspect, collections
import numpy as np
sys.path.insert(0, "' + ROOT + '/tools/animation/opening_cast")
os.environ["SHEN_CLOTH_SIM"] = sys.argv[3]
import cloth_bake as cb
name = sys.argv[1]; frames_of_interest = [int(x) for x in sys.argv[2].split(",")]
phase = int(name[1])
frames, roots = cb.sequence(phase, [("Idle", 0.6, 0.0, 0.0), (name[3:], None, 0.0, 0.0)])
code = inspect.getsource(cb.run_sim)
code = code.replace("    Sim.step(s, mid, h, wind, 3)\n    Sim.step(s, b, h, wind, 3)", "    Sim.LOG = {}\n    Sim.step(s, mid, h, wind, 3)\n    Sim.step(s, b, h, wind, 3)\n    print('LOG ' .. table.concat(Sim.LOG, ' '))")
code = code.replace("lines = res.stdout.strip().split(\"\\n\")", "lines = [l for l in res.stdout.strip().split(\"\\n\") if not l.startswith('LOG')]; ns_log.extend(l for l in res.stdout.strip().split(\"\\n\") if l.startswith('LOG'))")
code = code.replace("assert len(lines) == len(frames), (len(lines), len(frames))", "pass")
ns = dict(cb.__dict__); ns["ns_log"] = []
exec(compile(code, "rs", "exec"), ns)
ns["run_sim"](phase, frames, roots)
log = ns["ns_log"]
cloth = json.load(open("' + ROOT + '/work/shen_import/cloth_p%d.json" % phase))
sk = cloth["skin"]; parts = cloth["particles"]; cols = cloth["colliders"]
smp = json.load(open("' + ROOT + '/work/shen_import/clothskin_p%d.json" % phase))["samples"]
gpos = {tuple(s["v"]): s["g"] for s in smp}
for f in frames_of_interest:
    ent = log[f].split()[1:]
    c = collections.Counter()
    for e in ent:
        k, ci, d = e.split(":")
        s = sk[int(k) - 1]
        sheets = {parts[w[1]]["sheet"] for w in s["w"] if w[0] == 0}
        c[(gpos.get(tuple(s["v"]), "?"), "/".join(sorted(sheets)), cols[int(ci) - 1]["limb"])] += 1
    big = sorted(((float(e.split(":")[2]), e) for e in ent), reverse=True)[:4]
    print("frame", f, "pushes", len(ent), "biggest", big, dict(c.most_common(5)))
