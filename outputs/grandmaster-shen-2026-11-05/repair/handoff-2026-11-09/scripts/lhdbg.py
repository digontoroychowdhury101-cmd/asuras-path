import sys, os, inspect, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name, lo, hi = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
out = clip.bake()
ZR = L.ZR
def ang(A, B): return float(np.degrees(np.arccos(np.clip((np.trace(A.T @ B) - 1) / 2, -1, 1))))
src = inspect.getsource(type(clip).solve)
src = src.replace("""            c["_lvis"] = ""","""            DBGL.append((hold, reach, mix, None, ik[0][3], ik[1][3] if len(ik) == 2 else None, ik[0][2], ik[1][2] if len(ik) == 2 else None))
            c["_lvis"] = """)
assert "DBGL.append" in src
src = "\n".join(l[4:] if l.startswith("    ") else l for l in src.split("\n"))
ns = dict(L.__dict__); ns["DBGL"] = []
exec(compile(src, "solve_dbg", "exec"), ns)
prevH = None; prev = None
for i in range(lo, hi + 1):
    c = dict(out[i][4]); ns["DBGL"].clear()
    clip._side = {}
    local, world, diag = ns["solve"](clip, c)
    clip._side = None
    hold, reach, mix, rot, Rg, Rr, Fg, Fr = ns["DBGL"][-1] if ns["DBGL"] else (0, 0, 0, None, None, None, None, None)
    H = world["LeftHand"][:3, :3]; Fa = world["LeftLowerArm"][:3, :3]
    print("f%d hold %.2f reach %.2f mix %.2f rot %s | grip-vs-reach hand %s forearm %s | hand turn %s forearm turn %s" % (i, hold, reach, mix, "%.2f" % rot if rot is not None else "-",
          "%.0f" % ang(Rg, Rr) if Rr is not None else "-", "%.0f" % ang(Fg, Fr) if Fr is not None else "-", "%.0f" % ang(prevH, H) if prevH is not None else "-", "%.0f" % ang(prev, Fa) if prev is not None else "-"))
    if Rr is not None and prev is not None:
        print("      grip hand vs prev %.0f  reach hand vs prev %.0f" % (ang(prevH, Rg), ang(prevH, Rr)))
    prevH, prev = H, Fa
