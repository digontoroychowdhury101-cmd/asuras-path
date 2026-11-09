"""Time ClothSim on real shots (cloth_bake's own motion): python3 realbench.py SIM CLOTHDIR shot..."""
import sys, os, re, subprocess, time
from pathlib import Path
ROOT = Path("' + ROOT + '")
sys.path.insert(0, str(ROOT / "tools/animation/opening_cast"))
os.environ["SHEN_CLOTH_SIM"], os.environ["SHEN_CLOTH_DIR"] = sys.argv[1], sys.argv[2]
import cloth_bake as cb
real = subprocess.run
out = {}
def timed(cmd, **kw):
    p = Path(cmd[-1]); t = p.read_text()
    t = t.replace("local out = {}\nfor f = 1, #rows do", "local out = {}\nlocal T0 = os.clock()\nlocal NS = 0\nfor f = 1, #rows do")
    t = t.replace("    Sim.step(s, mid, h, wind, 3)\n    Sim.step(s, b, h, wind, 3)\n", "    local c0 = os.clock()\n    Sim.step(s, mid, h, wind, 3)\n    Sim.step(s, b, h, wind, 3)\n    T1 = (T1 or 0) + os.clock() - c0\n    NS += 2\n    if f == #rows then print(string.format('TIME %.1f', T1 / NS * 1e6)) end\n")
    p.write_text(t)
    r = real(cmd, **kw)
    lines = r.stdout.strip().split("\n")
    tl = [l for l in lines if l.startswith("TIME")]
    out["t"] = float(tl[0].split()[1])
    r.stdout = "\n".join(l if not l.startswith("TIME") else "" for l in lines)
    # keep the frame count right: drop the TIME text from the last frame line
    r.stdout = re.sub(r"TIME [0-9.]+", "", "\n".join(lines)).replace("\n\n", "\n")
    return r
cb.subprocess.run = timed
for name in sys.argv[3:]:
    frames, roots = cb.sequence(int(name[1]), [("Idle", 0.6, 0.0, 0.0), (name[3:], None, 0.0, 0.0)]) if name.startswith(("c1_", "c2_")) else cb.sequence(*cb.SHOTS[name])
    try:
        cb.run_sim(int(name[1]) if name.startswith("c") else cb.SHOTS[name][0], frames, roots)
    except Exception as e:
        pass
    print("%-16s %.0f us/step" % (name, out.get("t", -1)))
