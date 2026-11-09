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
src = src.replace("""            w = min(1.0, hold + reach)""", """            DBG.append((hold, reach, mix, [tuple(x) for x in ik], (u_ik, f_ik, Rp), SL))
            w = min(1.0, hold + reach)""")
src = "\n".join(l[4:] if l.startswith("    ") else l for l in src.split("\n"))
ns = dict(L.__dict__); ns["DBG"] = []
exec(compile(src, "solve_dbg", "exec"), ns)
rg = clip.rig
P = None
for i in range(lo, hi + 1):
    c = dict(out[i][4]); ns["DBG"].clear()
    clip._side = {}
    ns["solve"](clip, c)
    clip._side = None
    hold, reach, mix, ik, fin, SL = ns["DBG"][-1]
    rows = []
    for tag, (u, f, H) in [("grip" if len(ik) == 2 or hold > 0 else "reach", ik[0][1:])] + ([("reach", ik[1][1:])] if len(ik) == 2 else []) + [("final", fin)]:
        e = SL + u @ rg.LARM_U; w = e + f @ rg.LARM_L
        rows.append((tag, e, w, u, f, H))
    s = "f%d hold %.2f reach %.2f mix %.2f | " % (i, hold, reach, mix) + "  ".join("%s elbow %s wrist %s" % (t, np.round(e, 2), np.round(w, 2)) for t, e, w, u, f, H in rows)
    if P is not None:
        s += " | final upper turn %.0f fore %.0f hand %.0f" % (ang(P[3], rows[-1][3]), ang(P[4], rows[-1][4]), ang(P[5], rows[-1][5]))
    P = rows[-1]
    print(s)
print("--- poles")
prevU = None
for i in range(lo, hi + 1):
    c = dict(out[i][4]); ns["DBG"].clear()
    clip._side = {}
    ns["solve"](clip, c)
    clip._side = None
    hold, reach, mix, ik, fin, SL = ns["DBG"][-1]
    if len(ik) < 2: continue
    A, B = ik[0][1:], ik[1][1:]
    u0, l0 = rg.LARM_U, rg.LARM_L
    E = []
    for X in (A, B):
        e = SL + X[0] @ u0; w = e + X[1] @ l0; E.append((e, w, L.orth(e - SL, L.unit(w - SL))))
    T = E[0][1] * (1 - mix) + E[1][1] * mix; ax = L.unit(T - SL)
    qA, qB = L.orth(E[0][2], ax), L.orth(E[1][2], ax)
    import math
    phi = math.degrees(math.atan2(float(np.cross(qA, qB) @ ax), float(qA @ qB)))
    U = fin[0]; ue = U @ u0
    El = E[0][0] * (1 - mix) + E[1][0] * mix - SL
    po = L.orth(El, ax)
    c0 = L.two_bone(SL, T, u0, l0, rg.LELBOW0, El, "h", {})
    print("   elbow-lerp off-axis %.3f  canon upper turn vs final %.0f  final upper y %s" % (np.linalg.norm(El - ax * (El @ ax)), ang(c0[0], U := fin[0]), np.round(U[:, 1], 2)))
    print("f%d mix %.2f |T-S| %.2f armlen %.2f  pA.ax %.2f pB.ax %.2f  phi %.0f  upper dir %s  turn %s" % (i, mix, np.linalg.norm(T - SL), np.linalg.norm(u0) + np.linalg.norm(l0), E[0][2] @ ax, E[1][2] @ ax, phi, np.round(L.unit(ue), 2), "%.0f" % ang(prevU, U) if prevU is not None else "-"))
    print("   U cols", np.round(U, 2).tolist(), "det %.3f orth err %.3f" % (np.linalg.det(U), np.abs(U.T @ U - np.eye(3)).max()))
    prevU = U
