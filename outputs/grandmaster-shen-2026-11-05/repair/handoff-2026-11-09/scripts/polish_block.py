def _polish_sweep(clip, ctrl):
    """The export's own solve, every frame in order: the haft-side memory each frame starts from (clip._side before it), each frame's world, and how
    deep the deeper arm is in his torso on every skin sample, on each frame and halfway to the next (joint_mix: what the game draws between them)."""
    rg = clip.rig
    clip._side = {}
    sides, worlds, depth = [], [], []
    try:
        for c in ctrl:
            sides.append(dict(clip._side))
            _local, world, _diag = clip.solve(dict(c))
            worlds.append(world)
            depth.append(max(arm_torso_world(rg, world, dense=True).values()))
    finally:
        clip._side = None
    mids = [max(arm_torso_world(rg, joint_mix(rg, worlds[i], worlds[i + 1], 0.5), dense=True).values()) for i in range(len(ctrl) - 1)]
    return sides, worlds, depth, mids


def joint_polish(clip, ctrl, times):
    """(2026-11-09) Every pass before this one optimizes its own measure, one after another, and a later one can undo an earlier one: phase 2's
    Crimson Embrace kept its right arm 0.07 in his chest after the keys, the swivel put it 0.34 in, clear_torso took it to 0.27 and slide_fist put
    it back to 0.34; Deathblow Victim's went 0.17 -> 0.14 -> 0.15 -> 0.20 (swivel, clear_torso, slide_fist, depop). Here the frames of each run
    where an arm is still past the wall, on a frame or halfway between two (validate judges both), with POLISH_PAD held frames either side, are
    solved together with SciPy's SLSQP: per frame the fist point (3), a tilt of the haft about the fist with both grips riding it (2) and a swing
    of the right elbow about its shoulder-wrist line (1). Every measure is the pipeline's own, from the same solve the export does: both arms
    POLISH_MARGIN under the wall in his torso on every skin sample (arm_torso_world dense, as validate), on each frame and halfway to the next;
    the arms and weapon no deeper in each other (held_clash); the solver's reach and grip misses, both wrists and the weapon's lowest point no
    worse than the bake left them. Frames at a contact keep the weapon exactly as keyed and may only swing the elbow. The objective is the least
    change and its second difference, so it eases in and out. A window is kept only when it ends shallower with no other constraint worse.
    Without SciPy the stage is skipped and validate still flags the arm. The offline prototypes on the dp11 bakes (thinned measure, frames only):
    Crimson Embrace f44-52 0.351 -> 0.171, Deathblow Victim f35-43 0.202 -> 0.170, no pop, grip or wrist worse; the mesh still had 0.219 at
    Crimson Embrace f48, between the thinned samples, hence every sample and the margin here."""
    n = len(ctrl)
    if n < 4 or os.environ.get("SHEN_JOINT_POLISH") == "0":
        return []
    wall = ARM_TORSO_REST + TORSO_WALL
    sides, worlds, depth, mids = _polish_sweep(clip, ctrl)
    bad = sorted({i for i in range(1, n - 1) if depth[i] > wall} | {j for i in range(n - 1) if mids[i] > wall for j in (i, i + 1) if 0 < j < n - 1})
    if not bad:
        return []
    try:
        from scipy.optimize import minimize
    except ImportError:
        print("joint_polish: SciPy is not installed (python3 -m pip install scipy); %d frames past the wall left for validate" % len(bad))
        return []
    runs = []
    for i in bad:
        if runs and i - runs[-1][1] <= 2 * POLISH_PAD:
            runs[-1][1] = i
        else:
            runs.append([i, i])
    report = []
    for a, b in runs:
        if report:
            sides, worlds, depth, mids = _polish_sweep(clip, ctrl)     # after the window before it
        report.append(_polish_window(clip, ctrl, times, max(0, a - POLISH_PAD), min(n - 1, b + POLISH_PAD), sides, worlds, depth, mids,
                                     wall - POLISH_MARGIN, minimize))
        print("joint_polish %s" % report[-1], flush=True)
    clip._polish = report
    return report


def _polish_window(clip, ctrl, times, A, B, sides, worlds, depth, mids, target, minimize):
    import time as _time
    rg = clip.rig
    frames = list(range(A + 1, B))
    nf, NV, NC = len(frames), 6, 9
    pos = {i: k for k, i in enumerate(frames)}
    pairs = [(i, i + 1) for i in range(A, B)]     # every step from A to B, the held ends' included
    NP = len(pairs)
    contact = [k for k, i in enumerate(frames) if any(abs(times[i] - t) < TILT_NEAR_CONTACT for t in clip.contacts)]
    ctrl0 = {i: dict(ctrl[i]) for i in frames}
    axes = {}
    for i in frames:
        w = worlds[i]
        sh = (w["RightUpperArm"] @ np.append(rg.JOINT["RightUpperArm"], 1))[:3]
        wr = (w["RightHand"] @ np.append(rg.JOINT["RightHand"], 1))[:3]
        h = unit(ctrl0[i]["haft"])
        e1 = unit(np.cross(h, (0.0, 1.0, 0.0)) if abs(h[1]) < 0.95 else np.cross(h, (1.0, 0.0, 0.0)))
        axes[i] = (unit(wr - sh), e1, np.cross(h, e1))

    def apply(i, x):
        c = dict(ctrl0[i])
        sw, e1, e2 = axes[i]
        c["rp"] = tuple(np.asarray(c["rp"], float) + x[0:3])
        rv = (e1 * x[3] + e2 * x[4]) * (math.pi / 180.0)
        if np.linalg.norm(rv) > 1e-9:
            Rt = rodrigues(rv)
            c["haft"], c["face"] = tuple(Rt @ unit(c["haft"])), tuple(Rt @ unit(c["face"]))
            for hk in ("rhand", "lhand"):     # the grips ride the haft
                if hk in c and np.shape(c[hk]) == (3, 3):
                    c[hk] = Rt @ np.asarray(c[hk], float)
        if abs(x[5]) > 1e-9 and "rpole" in c:
            c["rpole"] = tuple(rodrigues(sw * math.radians(x[5])) @ np.asarray(c["rpole"], float))
        return c

    def measure(i, c):
        clip._side = dict(sides[i])
        local, world, diag = clip.solve(dict(c))
        tor = arm_torso_world(rg, world, dense=True)
        return dict(R=tor["Right"], L=tor["Left"], clash=float(held_clash(clip, c)), arm_reach=float(diag.get("arm_reach", 0.0)),
                    left_grip=float(diag.get("left_grip", 0.0)), left_reach=float(diag.get("left_reach", 0.0)),
                    wrist=float(ZR.angle_of(local["RightHand"][:3, :3])), lwrist=float(ZR.angle_of(local["LeftHand"][:3, :3])),
                    lowest=float(place(rg, world, "Weapon")[:, 1].min())), world

    base = {i: measure(i, ctrl0[i])[0] for i in frames}
    lim = {i: dict(clash=max(CLASH_GRAZE, b["clash"]) + 0.005, arm_reach=max(0.02, b["arm_reach"]) + 0.02, left_grip=max(0.05, b["left_grip"]) + 0.02,
                   left_reach=max(0.05, b["left_reach"]) + 0.02, wrist=max(95.0, b["wrist"]), lwrist=max(95.0, b["lwrist"]),
                   lowest=min(GROUND - 0.05, b["lowest"])) for i, b in base.items()}

    def cons_frame(i, m):
        l = lim[i]
        return np.array([target - m["R"], target - m["L"], (l["clash"] - m["clash"]) * 4, l["arm_reach"] - m["arm_reach"], l["left_grip"] - m["left_grip"],
                         l["left_reach"] - m["left_reach"], (l["wrist"] - m["wrist"]) / 100.0, (l["lwrist"] - m["lwrist"]) / 100.0, m["lowest"] - l["lowest"]])
    cache, mcache = {}, {}

    def frame_eval(i, xi):
        key = (i, tuple(np.round(xi, 9)))
        if key not in cache:
            m, world = measure(i, apply(i, xi))
            cache[key] = (cons_frame(i, m), world)
        return cache[key]

    def xs(x, i):
        return x[pos[i] * NV:(pos[i] + 1) * NV] if i in pos else None

    def mid_eval(p, xa, xb):     # halfway between the pair's frames, as the game draws it; a held end keeps its baked pose
        a, b = pairs[p]
        key = (p, None if xa is None else tuple(np.round(xa, 9)), None if xb is None else tuple(np.round(xb, 9)))
        if key not in mcache:
            wa = worlds[a] if xa is None else frame_eval(a, xa)[1]
            wb = worlds[b] if xb is None else frame_eval(b, xb)[1]
            t = arm_torso_world(rg, joint_mix(rg, wa, wb, 0.5), dense=True)
            mcache[key] = np.array([target - t["Right"], target - t["Left"]])
        return mcache[key]
    slack = np.zeros(nf * NC + NP * 2)

    def raw(x):
        return np.concatenate([frame_eval(i, xs(x, i))[0] for i in frames] + [mid_eval(p, xs(x, a), xs(x, b)) for p, (a, b) in enumerate(pairs)])

    def cons(x):
        return raw(x) + slack

    def cons_jac(x):     # a frame's measures depend on its own controls, a halfway pose on its two frames': forward differences per frame
        J = np.zeros((nf * NC + NP * 2, nf * NV))
        for k, i in enumerate(frames):
            xi = xs(x, i)
            g0 = frame_eval(i, xi)[0]
            near = [p for p, (a, b) in enumerate(pairs) if i in (a, b)]
            m0 = {p: mid_eval(p, xs(x, pairs[p][0]), xs(x, pairs[p][1])) for p in near}
            for j in range(NV):
                xp = xi.copy()
                xp[j] += POLISH_STEP[j]
                J[k * NC:(k + 1) * NC, k * NV + j] = (frame_eval(i, xp)[0] - g0) / POLISH_STEP[j]
                for p in near:
                    a, b = pairs[p]
                    m1 = mid_eval(p, xp if a == i else xs(x, a), xp if b == i else xs(x, b))
                    J[nf * NC + 2 * p:nf * NC + 2 * p + 2, k * NV + j] = (m1 - m0[p]) / POLISH_STEP[j]
        return J
    D2 = np.zeros(((nf + 2) * NV, nf * NV))
    for k in range(nf + 2):
        for j, wgt in ((k - 2, 1.0), (k - 1, -2.0), (k, 1.0)):
            if 0 <= j < nf:
                D2[k * NV:(k + 1) * NV, j * NV:(j + 1) * NV] += wgt * np.eye(NV)
    Wsc = np.diag(np.tile(1.0 / POLISH_SCALE, nf))
    Q = Wsc @ (np.eye(nf * NV) + POLISH_SMOOTH * D2.T @ D2) @ Wsc
    bounds = []
    for k in range(nf):
        held = k in contact     # attack timing: the weapon stays as keyed at a contact
        bounds += [(0.0, 0.0) if held else (-0.6, 0.6)] * 3 + [(0.0, 0.0) if held else (-25.0, 25.0)] * 2 + [(-120.0, 120.0)]
    x0 = np.zeros(nf * NV)
    c0 = raw(x0)
    J0 = cons_jac(x0)
    for r in range(len(c0)):     # a measure no control here moves (a free left arm, an end held) is not asked to change: it is left as it is
        if c0[r] < 0 and np.abs(J0[r]).max() < 1e-6:
            slack[r] = 1e-3 - c0[r]
    track = {"best": None, "hist": []}

    def feasible(x):
        return float(cons(x).min()) >= -1e-4

    def callback(intermediate_result):     # stop once feasible and settled
        x, f = intermediate_result.x, float(intermediate_result.fun)
        if feasible(x) and (track["best"] is None or f < track["best"][0]):
            track["best"] = (f, x.copy())
        track["hist"].append(f)
        h = track["hist"]
        if track["best"] is not None and len(h) > 6 and abs(h[-6] - h[-1]) <= 1e-3 * max(abs(h[-1]), 1e-6):
            raise StopIteration
    t0 = _time.time()
    res = minimize(lambda x: float(x @ Q @ x), x0, jac=lambda x: 2.0 * Q @ x, method="SLSQP", bounds=bounds,
                   constraints=[{"type": "ineq", "fun": cons, "jac": cons_jac}], callback=callback, options={"maxiter": POLISH_ITERS, "ftol": 1e-6})
    if feasible(res.x) and (track["best"] is None or float(res.fun) <= track["best"][0]):
        track["best"] = (float(res.fun), res.x.copy())
    x = track["best"][1] if track["best"] is not None else res.x
    c1 = raw(x)
    tor_rows = [k * NC + s for k in range(nf) for s in (0, 1)] + list(range(nf * NC, nf * NC + NP * 2))
    deep0 = max([depth[i] for i in frames] + [mids[a] for a, _b in pairs])
    deep1 = max(target - float(c1[r]) for r in tor_rows)
    worse = [j for j in range(2, NC) if min(0.0, float(c0[:nf * NC][j::NC].min())) - float(c1[:nf * NC][j::NC].min()) > 1e-3]
    keep = deep1 < deep0 - 0.005 and not worse
    if keep:
        for k, i in enumerate(frames):
            ctrl[i].clear()
            ctrl[i].update(apply(i, x[k * NV:(k + 1) * NV]))
    clip._side = None
    X = x.reshape(nf, NV)
    return dict(window=(A, B), status=int(res.status), message=str(res.message), nit=int(res.nit), runtime_s=round(_time.time() - t0, 1),
                frame_evals=len(cache), feasible=track["best"] is not None, depth=(round(deep0, 3), round(float(deep1), 3)), kept=keep, worse=worse,
                change=(round(float(np.abs(X[:, :3]).max()), 3), round(float(np.abs(X[:, 3:5]).max()), 1), round(float(np.abs(X[:, 5]).max()), 1)))


