# slsqp_proto.py CLIP A B [PKL] : offline SciPy SLSQP prototype (2026-11-09). Starts from a finished bake (PKL, default baked__dp11) and solves the
# frames strictly between A and B together, A and B held, instead of one pass after another. Per frame: the weapon's fist point (rp, 3), a tilt of the
# haft about the fist (2, degrees, as tilt_haft) and a swing of the right elbow about its shoulder-wrist line (1, degrees). Every measure is the
# pipeline's own: clip.solve (FK, two-bone arms, lead-hand reach), arm_torso_world (skinned arm points in the torso distance fields), held_clash
# (arms in the dense weapon surface), the solver's reach/grip diagnostics, the right wrist angle and the weapon's lowest point. Objective: the least
# change, and the change's second difference over the window (A and B count as zero) so it eases in and out. Writes PKL_slsqp.pkl and a report line.
import sys, os, time, json, pickle, math, numpy as np
from scipy.optimize import minimize
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
S = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L, castlib as C

name, A, B = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
pk = sys.argv[4] if len(sys.argv) > 4 else S + "/baked__dp11/" + name + ".pkl"
WALL = L.ARM_TORSO_REST + L.TORSO_WALL if hasattr(L, "TORSO_WALL") else L.ARM_TORSO_REST + 0.03     # 0.17: the validator flags 0.18
LAM = float(os.environ.get("LAM", "4.0"))
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
rg = clip.rig
out = pickle.load(open(pk, "rb"))
ctrl0 = [dict(o[4]) for o in out]
times = [o[0] for o in out]
win = list(range(A + 1, B))
near = [i for i in win if any(abs(times[i] - k) < L.TILT_NEAR_CONTACT for k in clip.contacts)]
var_frames = [i for i in win if i not in near]     # attack timing: frames at a contact keep the weapon as baked
NV = 6
clip._side = {}

def unit(v):
    v = np.asarray(v, float); return v / max(np.linalg.norm(v), 1e-9)

# per frame, the baked shoulder-wrist line (the elbow swings about it) and the haft's tilt axes
base_world = {i: out[i][2] for i in win}
axes = {}
for i in var_frames:
    w = base_world[i]
    sh = (w["RightUpperArm"] @ np.append(rg.JOINT["RightUpperArm"], 1))[:3]
    wr = (w["RightHand"] @ np.append(rg.JOINT["RightHand"], 1))[:3]
    h = unit(ctrl0[i]["haft"])
    e1 = unit(np.cross(h, (0.0, 1.0, 0.0)) if abs(h[1]) < 0.95 else np.cross(h, (1.0, 0.0, 0.0)))
    axes[i] = (unit(wr - sh), e1, np.cross(h, e1))

def apply(i, x):
    c = dict(ctrl0[i])
    sw_axis, e1, e2 = axes[i]
    c["rp"] = tuple(np.asarray(c["rp"], float) + x[0:3])
    rv = (e1 * x[3] + e2 * x[4]) * (math.pi / 180.0)
    if np.linalg.norm(rv) > 1e-9:
        R = L.rodrigues(rv)
        c["haft"], c["face"] = tuple(R @ unit(c["haft"])), tuple(R @ unit(c["face"]))
        for hk in ("rhand", "lhand"):     # the grips ride the haft
            if hk in c and np.shape(c[hk]) == (3, 3):
                c[hk] = R @ np.asarray(c[hk], float)
    if abs(x[5]) > 1e-9 and "rpole" in c:
        c["rpole"] = tuple(L.rodrigues(sw_axis * math.radians(x[5])) @ np.asarray(c["rpole"], float))
    return c

def measure(c):
    local, world, diag = clip.solve(dict(c))[:3]
    tor = L.arm_torso_world(rg, world)
    lowest = float(L.place(rg, world, "Weapon")[:, 1].min())
    return dict(R=tor["Right"], L=tor["Left"], clash=float(L.held_clash(clip, c)), arm_reach=float(diag.get("arm_reach", 0.0)),
                left_grip=float(diag.get("left_grip", 0.0)), left_reach=float(diag.get("left_reach", 0.0)),
                wrist=float(L.ZR.angle_of(local["RightHand"][:3, :3])), lowest=lowest)

base = {i: measure(ctrl0[i]) for i in var_frames}
lim = {}
for i in var_frames:
    b = base[i]
    lim[i] = dict(clash=max(L.CLASH_GRAZE, b["clash"]) + 0.005, arm_reach=max(0.02, b["arm_reach"]) + 0.02, left_grip=max(0.05, b["left_grip"]) + 0.02,
                  left_reach=max(0.05, b["left_reach"]) + 0.02, wrist=max(95.0, b["wrist"]), lowest=min(L.GROUND - 0.05, b["lowest"]))

def cons_frame(i, m):
    l = lim[i]
    return np.array([WALL - m["R"], WALL - m["L"], (l["clash"] - m["clash"]) * 4, l["arm_reach"] - m["arm_reach"], l["left_grip"] - m["left_grip"],
                     l["left_reach"] - m["left_reach"], (l["wrist"] - m["wrist"]) / 100.0, m["lowest"] - l["lowest"]])
NC = 8
cache = {}
def frame_eval(i, xi):
    key = (i, tuple(np.round(xi, 9)))
    if key not in cache:
        cache[key] = cons_frame(i, measure(apply(i, xi)))
    return cache[key]

nf = len(var_frames)
SC_ = np.array([float(v) for v in os.environ.get("SCALES", "0.1,0.1,0.1,6,6,30").split(",")])     # equal cost: 0.1 rig units of fist, 6 deg of haft tilt, 30 deg of elbow swing
# objective: x^T Q x
I = np.eye(nf * NV)
D2 = np.zeros(((nf + 2) * NV, nf * NV))     # second differences over A, the frames, B (A and B fixed at zero)
for k in range(nf + 2):
    for j, wgt in ((k - 2, 1.0), (k - 1, -2.0), (k, 1.0)):
        if 0 <= j < nf:
            D2[k * NV:(k + 1) * NV, j * NV:(j + 1) * NV] += wgt * np.eye(NV)
Wsc = np.diag(np.tile(1.0 / SC_, nf))
Q = Wsc @ (I + LAM * D2.T @ D2) @ Wsc
fun = lambda x: float(x @ Q @ x)
jac = lambda x: 2.0 * Q @ x
H = np.array([0.01, 0.01, 0.01, 1.0, 1.0, 3.0])
def cons(x):
    return np.concatenate([frame_eval(i, x[k * NV:(k + 1) * NV]) for k, i in enumerate(var_frames)])
def cons_jac(x):
    J = np.zeros((nf * NC, nf * NV))
    for k, i in enumerate(var_frames):
        xi = x[k * NV:(k + 1) * NV]
        g0 = frame_eval(i, xi)
        for j in range(NV):
            xp = xi.copy(); xp[j] += H[j]
            J[k * NC:(k + 1) * NC, k * NV + j] = (frame_eval(i, xp) - g0) / H[j]
    return J
bounds = [(-0.6, 0.6)] * 3 + [(-25, 25)] * 2 + [(-120, 120)]
bounds = bounds * nf
x0 = np.zeros(nf * NV)
c0 = cons(x0)
t0 = time.time()
evals = {"n": 0}
res = minimize(fun, x0, jac=jac, method="SLSQP", bounds=bounds, constraints=[{"type": "ineq", "fun": cons, "jac": cons_jac}],
               options={"maxiter": int(os.environ.get("MAXITER", "60")), "ftol": 1e-6})
dt = time.time() - t0
c1 = cons(res.x)
names = ["torso_R", "torso_L", "clash", "arm_reach", "left_grip", "left_reach", "wrist", "floor"]
def viol(cv):
    v = {}
    for k, i in enumerate(var_frames):
        for j in range(NC):
            if cv[k * NC + j] < -1e-4:
                v.setdefault(names[j], []).append((i, round(float(-cv[k * NC + j]) / (4 if j == 2 else 100 if j == 6 else 1), 3)))
    return v
ctrl1 = [dict(c) for c in ctrl0]
for k, i in enumerate(var_frames):
    ctrl1[i] = apply(i, res.x[k * NV:(k + 1) * NV])
# the bake's own last step: solve every frame, derive the helpers, validate the clip as export.py does
def final(ctrl):
    clip._side = {}
    o = []
    for t, c in zip(times, ctrl):
        local, world, diag = clip.solve(c)
        o.append([t, local, world, diag, c])
    clip._side = None
    L.derive_helpers(clip, o)
    return o
o0 = final([dict(c) for c in ctrl0])
o1 = final(ctrl1)
val = getattr(SC, "validate", C.validate)
s0, p0 = val(clip, o0)
s1, p1 = val(clip, o1)
TAG = os.environ.get("TAG", "")
pickle.dump(o1, open(S + "/slsqp_%s_%d_%d%s.pkl" % (name, A, B, TAG), "wb"))
keys = ["arm_in_torso_right", "arm_in_torso_left", "in_weapon_arm_right", "in_weapon_arm_left", "weapon_in_arm_right", "weapon_in_arm_left", "wrist_right",
        "wrist_left", "left_grip", "left_off_haft", "right_off_haft", "pop_fist", "pop_blade", "pop_slide", "pop_edge", "pop_lead_reach", "weapon_low"]
per = {i: (round(base[i]["R"], 3), round(measure(ctrl1[i])["R"], 3), round(base[i]["L"], 3), round(measure(ctrl1[i])["L"], 3)) for i in var_frames}
rep = dict(clip=name, window=[A, B], frames=var_frames, held_at_contact=near, vars=len(res.x), success=bool(res.success), status=int(res.status),
           message=str(res.message), iterations=int(res.nit), fun_evals=int(res.nfev), jac_evals=int(res.njev), runtime_s=round(dt, 1),
           frame_evals=len(cache), objective=round(float(res.fun), 4), violations_before=viol(c0), violations_after=viol(c1),
           max_change=dict(rp=round(float(np.abs(res.x.reshape(nf, NV)[:, :3]).max()), 3), tilt_deg=round(float(np.abs(res.x.reshape(nf, NV)[:, 3:5]).max()), 1),
                           elbow_deg=round(float(np.abs(res.x.reshape(nf, NV)[:, 5]).max()), 1)),
           per_frame_R_L=per, validator_before={k: s0.get(k) for k in keys}, validator_after={k: s1.get(k) for k in keys}, problems_before=p0, problems_after=p1,
           strike_before=s0.get("strike"), strike_after=s1.get("strike"))
json.dump(rep, open(S + "/slsqp_%s_%d_%d%s.json" % (name, A, B, TAG), "w"), indent=1, default=str)
print(json.dumps(rep, indent=1, default=str))
