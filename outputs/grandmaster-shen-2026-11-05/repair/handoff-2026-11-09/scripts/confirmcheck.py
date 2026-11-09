# confirmcheck.py DIR LOG... : for each kept joint_polish window in a bake's log, the arms' depth over its frames and the halfway poses (and the fade
# in when it starts at f0) in the saved final bake, against the window's starting depth: what the in-order acceptance would have seen
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
import sys, os, re, ast, pickle
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
lib = {c.name: c for c in SC.library()}
d = sys.argv[1]
for log in sys.argv[2:]:
    name = re.search(r"tt\w+?_(P\d_\w+)\.log", log).group(1)
    wins = [ast.literal_eval(m) for m in re.findall(r"joint_polish (\{.*\})", open(log).read().replace("'message'", "'msg'"))]
    out = pickle.load(open(os.path.join(d, name + ".pkl"), "rb")); W = [o[2] for o in out]; rg = lib["GrandmasterShen_" + name].rig
    pops = L.bake_pops(lib["GrandmasterShen_" + name], out)
    for w in wins:
        if not w["kept"]: continue
        A, B = w["window"]; fr = range(A + 1, B)
        pairs = [(i, i + 1, 0.5, 1.0) for i in range(A, B)] + ([sp for sp in L.entry_specs(len(W)) if sp[1] <= B] if A == 0 else [])
        real = max([max(L.arm_torso_world(rg, W[i], dense=True).values()) for i in fr] + [max(L.arm_torso_world(rg, L.blend_pose(rg, W[0], W[a], W[b], s, u), dense=True).values()) for a, b, s, u in pairs])
        print(name, w["window"], "start", w["depth"][0], "planned", w["depth"][1], "final bake", round(real, 3), "OK" if real < w["depth"][0] else "WOULD REJECT", "pops", {k: round(v[0], 2) for k, v in pops.items()})
