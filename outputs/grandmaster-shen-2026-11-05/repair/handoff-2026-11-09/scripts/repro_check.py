# repro_check.py [CLIP] [REF.pkl] : (handoff 2026-11-09) before changing anything on a new computer, prove it reproduces Computer A.
# 1. every pipeline input listed in ../ARCHIVE_MANIFEST.sha256 that the bake reads (work/shen_import, the prepared GLBs) is present with the same
#    SHA-256; 2. CLIP (default P1_GuardHit, a clip in the final set that joint_polish never touches) bakes with the repo code to the same frames as
#    Computer A's saved bake (default ../bakes/dp11/CLIP.pkl): every part's world transform, frame by frame; 3. the validator finds no problem.
# Writes nothing outside work/shen_repair. Exit 0 only if all three hold.
import sys, os, hashlib, pickle, time
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(HERE, "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
name = sys.argv[1] if len(sys.argv) > 1 else "P1_GuardHit"
ref = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "..", "bakes", "dp11", name + ".pkl")
TOL = 1e-6
ok = True

man = os.path.join(HERE, "..", "ARCHIVE_MANIFEST.sha256")
need = [l.split("  ", 1) for l in open(man).read().splitlines() if l and not l.startswith("#")]
need = [(h, p) for h, p in need if p.startswith(("work/shen_import/", "assets/build/grandmaster_shen/"))]
bad = []
for h, p in need:
    fp = os.path.join(ROOT, p)
    if not os.path.isfile(fp):
        bad.append(("missing", p)); continue
    d = hashlib.sha256()
    with open(fp, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            d.update(b)
    if d.hexdigest() != h:
        bad.append(("different", p))
print("inputs: %d checked, %d missing or different" % (len(need), len(bad)))
for k, p in bad[:20]:
    print("   ", k, p)
ok &= not bad

import shen_clips as SC, shen_lib as L, castlib as C
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
t0 = time.time()
out = clip.bake()
ref_out = pickle.load(open(ref, "rb"))
worst = (0.0, None, None)
if len(out) != len(ref_out):
    print("frames: %d baked, %d in the reference" % (len(out), len(ref_out))); ok = False
else:
    for f, (a, b) in enumerate(zip(out, ref_out)):
        for part, M in a[2].items():
            if part in b[2]:
                d = float(np.abs(np.asarray(M) - np.asarray(b[2][part])).max())
                if d > worst[0]:
                    worst = (d, f, part)
print("bake: %s %d frames in %.0f s; largest difference from Computer A's bake %.2e (frame %s, %s); tolerance %.0e"
      % (name, len(out), time.time() - t0, worst[0], worst[1], worst[2], TOL))
ok &= worst[0] <= TOL
val = getattr(SC, "validate", C.validate)
_s, problems = val(clip, out)
print("validator problems:", problems)
ok &= not problems
print("REPRODUCED" if ok else "NOT REPRODUCED: stop and compare inputs, Python/numpy versions (../ENVIRONMENT.txt) before changing anything")
sys.exit(0 if ok else 1)
