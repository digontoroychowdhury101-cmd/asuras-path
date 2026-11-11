# keymatch.py OVERLAY CLIP... : (Windows pass 2026-11-11) do the repo's shen_clips.py / shen_lib.py give these clips the same keys and the same
# per-clip options as a DEV overlay (a dir under SHEN_SCRATCH, default work/shen_repair, holding its own copies of the two files) that a bake was
# made with? Every control (Clip.controls) at every frame, and every plain per-clip option (hold_start, walk_spike, roll_edges, ...). Prints one
# line per clip: "same" or the first differences. Runs each side in its own process (the two files share their module names).
import os, sys, pickle, subprocess, math
import numpy as np

ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../.."))
S = os.environ.get("SHEN_SCRATCH") or os.path.join(ROOT, "work", "shen_repair")


def dump(overlay, clips):
    sys.path.insert(0, os.path.join(ROOT, "tools/animation/general_zhao"))
    sys.path.insert(0, os.path.join(ROOT, "tools/animation/opening_cast"))
    if overlay != "repo":
        sys.path.insert(0, os.path.join(S, overlay))
    import shen_clips as R
    out = {}
    want = {"GrandmasterShen_" + c for c in clips}
    for c in R.library():
        if c.name not in want:
            continue
        ctl = [{k: (None if v is None else np.asarray(v, dtype=float)) for k, v in c.controls(t).items()} for t in c.frames()]
        opts = {}
        for k in dir(c):
            if k.startswith("_"):
                continue
            v = getattr(c, k)
            if callable(v) or k in ("keys", "name"):
                continue
            if isinstance(v, (bool, int, float, str, type(None), dict, list, tuple)):
                opts[k] = v
        out[c.name[len("GrandmasterShen_"):]] = (ctl, opts)
    return out


def same(a, b):
    if isinstance(a, np.ndarray) or isinstance(b, np.ndarray):
        return a is not None and b is not None and np.shape(a) == np.shape(b) and np.allclose(a, b, atol=1e-12, rtol=0)
    if isinstance(a, dict) and isinstance(b, dict):
        return a.keys() == b.keys() and all(same(a[k], b[k]) for k in a)
    if isinstance(a, (list, tuple)) and isinstance(b, (list, tuple)):
        return len(a) == len(b) and all(same(x, y) for x, y in zip(a, b))
    if isinstance(a, float) and isinstance(b, float):
        return a == b or (math.isnan(a) and math.isnan(b))
    return a == b


if __name__ == "__main__":
    if sys.argv[1] == "--dump":
        pickle.dump(dump(sys.argv[2], sys.argv[4:]), open(sys.argv[3], "wb"))
        sys.exit(0)
    overlay, clips = sys.argv[1], sys.argv[2:]
    env = dict(os.environ, OMP_NUM_THREADS="1", OPENBLAS_NUM_THREADS="1", MKL_NUM_THREADS="1")
    tmp = {}
    for side in ("repo", overlay):
        p = os.path.join(S, "keymatch_%s.pkl" % side)
        subprocess.run([sys.executable, os.path.abspath(__file__), "--dump", side, p] + clips, check=True, env=env)
        tmp[side] = pickle.load(open(p, "rb"))
        os.remove(p)
    a, b = tmp["repo"], tmp[overlay]
    for c in clips:
        if c not in a or c not in b:
            print("%-26s missing (repo %s, %s %s)" % (c, c in a, overlay, c in b))
            continue
        (ca, oa), (cb, ob) = a[c], b[c]
        keys = []
        if len(ca) != len(cb):
            keys.append("frames %d vs %d" % (len(ca), len(cb)))
        else:
            for i, (x, y) in enumerate(zip(ca, cb)):
                bad = sorted(k for k in set(x) | set(y) if not same(x.get(k), y.get(k)))
                if bad:
                    keys.append("f%d %s" % (i, ",".join(bad)))
                    if len(keys) >= 3:
                        break
        opts = ["%s: repo %r, %s %r" % (k, oa.get(k), overlay, ob.get(k)) for k in sorted(set(oa) | set(ob)) if not same(oa.get(k), ob.get(k))]
        print("%-26s keys %s | options %s" % (c, "same on all %d frames" % len(ca) if not keys else "DIFFER: " + "; ".join(keys),
                                             "same" if not opts else "differ: " + "; ".join(opts)))
