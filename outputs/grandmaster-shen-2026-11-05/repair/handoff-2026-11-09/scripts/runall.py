# runall.py TAG CLIP [CLIP ...] | TAG @LISTFILE : (handoff 2026-11-09) runall10.sh for any OS (Windows has no zsh/pgrep): bake and validate each
# clip with the repo code (torsotest_patch.py on CLIP), JOBS at a time (env, default 7), single-threaded maths. Saves each bake to
# $SHEN_SCRATCH/baked_TAG/CLIP.pkl and its log to $SHEN_SCRATCH/ttTAG_CLIP.log; a clip whose log already ends in a verdict is skipped.
# Use the Python that has SciPy (joint_polish needs it).
import sys, os, subprocess, time
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(HERE, "../../../../.."))
SCR = os.environ.get("SHEN_SCRATCH") or os.path.join(ROOT, "work", "shen_repair")
tag, rest = sys.argv[1], sys.argv[2:]
clips = [l.strip() for l in open(rest[0][1:]) if l.strip()] if rest and rest[0].startswith("@") else rest
jobs = int(os.environ.get("JOBS", "7"))
os.makedirs(SCR, exist_ok=True)
env = dict(os.environ, TAG="_" + tag, SHEN_SAVE_BAKED=os.path.join(SCR, "baked_" + tag), OMP_NUM_THREADS="1", OPENBLAS_NUM_THREADS="1",
           MKL_NUM_THREADS="1", VECLIB_MAXIMUM_THREADS="1")
running = []
for c in clips:
    log = os.path.join(SCR, "tt%s_%s.log" % (tag, c))
    if os.path.isfile(log) and "problems" in open(log, errors="replace").read():
        print("skip", c, "(done)"); continue
    while len([p for p in running if p[0].poll() is None]) >= jobs:
        time.sleep(5)
    f = open(log, "w")
    running.append((subprocess.Popen([sys.executable, os.path.join(HERE, "torsotest_patch.py"), "on", c], cwd=ROOT, env=env, stdout=f, stderr=subprocess.STDOUT), f, c))
    print("start", c, flush=True)
for p, f, c in running:
    p.wait(); f.close()
    verdict = [l for l in open(f.name, errors="replace") if "problems:" in l]
    print("%-28s %s" % (c, verdict[-1].split("problems:", 1)[1].strip()[:200] if verdict else "NO VERDICT (see %s)" % f.name))
print("RUNALL_DONE_" + tag)
