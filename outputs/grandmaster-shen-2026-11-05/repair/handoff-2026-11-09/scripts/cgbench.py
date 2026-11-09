"""ClothSim step cost on the Luau CLI at -O2, with and without native codegen, on one real shot's motion (cloth_bake's script, timed)."""
import sys, os, re, subprocess
from pathlib import Path
ROOT = Path("' + ROOT + '")
sys.path.insert(0, str(ROOT / "tools/animation/opening_cast"))
os.environ["SHEN_CLOTH_SIM"], os.environ["SHEN_CLOTH_DIR"] = sys.argv[1], sys.argv[2]
import cloth_bake as cb
real = subprocess.run
res = {}
def timed(cmd, **kw):
    p = Path(cmd[-1]); t = p.read_text()
    t = t.replace("local out = {}\nfor f = 1, #rows do", "local out = {}\nfor f = 1, #rows do")
    t = t.replace("    Sim.step(s, mid, h, wind, 3)\n    Sim.step(s, b, h, wind, 3)\n", "    local c0 = os.clock()\n    Sim.step(s, mid, h, wind, 3)\n    Sim.step(s, b, h, wind, 3)\n    T1 = (T1 or 0) + os.clock() - c0\n    NS = (NS or 0) + 2\n    if f == #rows then print(string.format('TIME %.1f', T1 / NS * 1e6)) end\n")
    p.write_text(t)
    for flags in (["-O2"], ["-O2", "--codegen"]):
        r = real([cmd[0]] + flags + [str(p)], capture_output=True, text=True)
        tl = [l for l in r.stdout.split("\n") if l.startswith("TIME")]
        res[" ".join(flags)] = tl[0].split()[1] if tl else r.stderr[-200:]
    r = real(cmd, **kw)
    r.stdout = re.sub(r"TIME [0-9.]+", "", r.stdout).replace("\n\n", "\n")
    return r
cb.subprocess.run = timed
name = sys.argv[3]
frames, roots = cb.sequence(int(name[1]), [("Idle", 0.6, 0.0, 0.0), (name[3:], None, 0.0, 0.0)])
try:
    cb.run_sim(int(name[1]), frames, roots)
except Exception:
    pass
print(name, res)
