# cmppkl.py DIR_A DIR_B [CLIP ...] : (Windows pass 2026-11-09) whether two saved bakes of a clip are the same, value for value (every frame's
# solved locals, world poses and controls; numpy arrays compared exactly), and the largest difference where they are not. Proves a clip baked
# with a test overlay is what the repo code bakes.
import sys, os, glob, pickle, numpy as np


def walk(a, b, path, out):
    if isinstance(a, dict) and isinstance(b, dict):
        if set(a) != set(b):
            out.append((float("inf"), path + " keys differ"))
            return
        for k in a:
            walk(a[k], b[k], "%s.%s" % (path, k), out)
    elif isinstance(a, (list, tuple)) and isinstance(b, (list, tuple)):
        if len(a) != len(b):
            out.append((float("inf"), path + " length differs"))
            return
        for i, (x, y) in enumerate(zip(a, b)):
            walk(x, y, "%s[%d]" % (path, i), out)
    elif isinstance(a, np.ndarray) or isinstance(b, np.ndarray):
        x, y = np.asarray(a), np.asarray(b)
        if x.shape != y.shape:
            out.append((float("inf"), path + " shape differs"))
        elif x.dtype.kind in "fc" or y.dtype.kind in "fc":
            d = float(np.max(np.abs(x - y))) if x.size else 0.0
            if d > 0:
                out.append((d, path))
        elif not np.array_equal(x, y):
            out.append((float("inf"), path))
    elif isinstance(a, float) or isinstance(b, float):
        try:
            d = abs(float(a) - float(b))
        except (TypeError, ValueError):
            d = float("inf")
        if d > 0 or (a != a) != (b != b):
            out.append((d, path))
    elif a != b:
        out.append((float("inf"), path))


A, B = sys.argv[1], sys.argv[2]
names = sys.argv[3:] or sorted(os.path.basename(p)[:-4] for p in glob.glob(A + "/P*.pkl") if os.path.exists(os.path.join(B, os.path.basename(p))))
for name in names:
    a = pickle.load(open("%s/%s.pkl" % (A, name), "rb"))
    b = pickle.load(open("%s/%s.pkl" % (B, name), "rb"))
    out = []
    walk(a, b, "", out)
    if not out:
        print("%-24s identical" % name)
    else:
        worst = max(out)
        print("%-24s DIFFERS in %d values, largest %.3g at %s" % (name, len(out), worst[0], worst[1]))
