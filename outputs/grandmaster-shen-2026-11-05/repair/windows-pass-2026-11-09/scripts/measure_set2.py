# measure_set2.py TAG SIM CLOTHDIR [PAR] : (Windows pass 2026-11-09) Python port of the handoff's measure_set2.sh. Bake every clip of BDIR (env,
# default work/opening_cast_bake/shen: GrandmasterShen_P<n>_<clip>.json frame files) as the shot c<n>_<clip>_TAG with that cloth sim and cloth data
# (cloth_bake.py), PAR groups side by side, then mesh-clash each group in Blender (mesh_clash.py, bind-pose baseline) into
# $SHEN_SCRATCH/mset_TAG_<k>.json. Compare tags with the handoff's msetcmp.py. BLENDER: blender.exe.
import os, re, subprocess, sys, glob, shutil

H = os.path.dirname(os.path.abspath(__file__))
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(H, "../../../../.."))
S = os.environ.get("SHEN_SCRATCH") or os.path.join(ROOT, "work", "shen_repair")
B = os.environ.get("BLENDER") or shutil.which("blender") or r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
os.makedirs(S, exist_ok=True)
tag, sim, cdir = sys.argv[1], sys.argv[2], sys.argv[3]
par = int(sys.argv[4]) if len(sys.argv) > 4 else 6
bdir = os.environ.get("BDIR", "work/opening_cast_bake/shen")
names = []
for f in sorted(glob.glob(os.path.join(ROOT, bdir, "GrandmasterShen_P*.json"))):
    m = re.match(r"GrandmasterShen_P([12])_(.*)\.json$", os.path.basename(f))
    if m:
        names.append("c%s_%s" % (m.group(1), m.group(2)))
groups = [names[k::par] for k in range(par)]
env = dict(os.environ, SHEN_BAKE_DIR=bdir, SHEN_CLOTH_SIM=sim, SHEN_CLOTH_DIR=cdir, SHEN_SHOT_SUFFIX="_" + tag)
procs = []
for k, grp in enumerate(groups):
    if grp:
        log = open(os.path.join(S, "mset_bake_%s_%d.log" % (tag, k)), "w")
        procs.append((subprocess.Popen([sys.executable, os.path.join(ROOT, "tools/animation/opening_cast/cloth_bake.py")] + grp, cwd=ROOT, env=env,
                                       stdout=log, stderr=subprocess.STDOUT), log))
for p, log in procs:
    p.wait()
    log.close()
print("BAKED", tag, flush=True)
procs = []
for k, grp in enumerate(groups):
    if grp:
        log = open(os.path.join(S, "mset_clash_%s_%d.log" % (tag, k)), "w")
        procs.append((subprocess.Popen([B, "-b", "--factory-startup", "--python", os.path.join(ROOT, "tools/blender/shen_import/mesh_clash.py"), "--",
                                        os.path.join(S, "mset_%s_%d.json" % (tag, k)), "2"] + [g + "_" + tag for g in grp], cwd=ROOT,
                                       stdout=log, stderr=subprocess.STDOUT), log))
for p, log in procs:
    p.wait()
    log.close()
print("MEASURED", tag)
