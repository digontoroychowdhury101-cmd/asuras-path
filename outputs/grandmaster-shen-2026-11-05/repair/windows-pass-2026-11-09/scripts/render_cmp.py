# render_cmp.py SHOT [SHOT ...] : (Windows pass 2026-11-09) Python port of the handoff's render_cmp.sh / render_pass4.sh (zsh does not run on
# Windows). For each shot, x-ray renders (arm vertices inside PART lit magenta, review.py) of two versions of the shot (shot names SHOT_VA and
# SHOT_VB, made by cloth_bake.py with SHEN_SHOT_SUFFIX), front camera, every frame from the clip's start; then the clashsum line for each and one
# labelled side-by-side video per shot: OUT/<PREFIX>_<shot>_<part>[_<cam>].mp4 (15 fps: half speed). VIDEO_ONLY=1 reuses rendered frames.
# Settings (environment, as the zsh scripts): BLENDER (blender.exe), PAR (2), CAM (front), PART (UpperTorso), VA (pre4), VB (p5), LA, LB (row
# labels), PREFIX (arms_pass5), SHEN_ROOT, SHEN_SCRATCH. render_pass4.sh = VA=pre4 VB=p4 PREFIX=arms_pass4 with the _before_after name (SUFFIX).
# (2026-11-11) FROM=Weapon lights the glaive inside PART instead of arm skin; FRAMES (17::1) picks the frames; SHEN_REVIEW_HIDE leaves garments out.
import os, re, subprocess, sys, shutil, time
from concurrent.futures import ThreadPoolExecutor

H = os.path.dirname(os.path.abspath(__file__))
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(H, "../../../../.."))
S = os.environ.get("SHEN_SCRATCH") or os.path.join(ROOT, "work", "shen_repair")
B = os.environ.get("BLENDER") or shutil.which("blender") or r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
PAR, CAM, PART = int(os.environ.get("PAR", "2")), os.environ.get("CAM", "front"), os.environ.get("PART", "UpperTorso")
VA, VB = os.environ.get("VA", "pre4"), os.environ.get("VB", "p5")
LA = os.environ.get("LA", "BEFORE (export this pass started from)")
LB = os.environ.get("LB", "AFTER (this pass)")
PREFIX, SUFFIX = os.environ.get("PREFIX", "arms_pass5"), os.environ.get("SUFFIX", "_before_after")
# (2026-11-11) FROM: what is lit inside PART, review.py's SHEN_REVIEW_CLASH_FROM (default both arms and hands); FROM=Weapon lights the glaive instead
FROM = os.environ.get("FROM", "LeftUpperArm,LeftLowerArm,LeftHand,RightUpperArm,RightLowerArm,RightHand")
WHAT = "the glaive" if FROM == "Weapon" else "arm skin"
# (2026-11-11) SHEN_REVIEW_HIDE (review.py: garments left out of the render) passes through; its renders and video are named _bare
BARE = "_bare" if os.environ.get("SHEN_REVIEW_HIDE") else ""
FRAMES = os.environ.get("FRAMES", "17::1")     # (2026-11-11) review.py's first:last:step (default: every frame from the shot's frame 17)
OUT = os.path.join(ROOT, "outputs", "grandmaster-shen-2026-11-05", "repair")
REVIEW = os.path.join(ROOT, "tools", "blender", "shen_import", "review.py")
VIDEO = os.path.join(ROOT, "tools", "blender", "shen_import", "compare_video.py")
RV = os.path.join(S, "rv5")
os.makedirs(RV, exist_ok=True)
shots = sys.argv[1:]
if not shots:
    sys.exit(__doc__ if __doc__ else "usage: render_cmp.py SHOT [SHOT ...]")


def job(shot, v):
    d = os.path.join(RV, "%s_%s_%s_%s%s" % (shot, v, PART, CAM, BARE))
    if os.environ.get("VIDEO_ONLY") == "1" and os.path.isdir(d):     # (2026-11-10) remake the video from frames already rendered
        return d
    shutil.rmtree(d, ignore_errors=True)
    env = dict(os.environ, SHEN_REVIEW_CLASH=PART, SHEN_REVIEW_CLASH_FROM=FROM)
    if FROM == "Weapon":     # (2026-11-11) review.py lights the weapon's vertices when no garment list is given
        env.pop("SHEN_REVIEW_CLASH_FROM")
    with open(d + ".log", "w") as log:
        subprocess.run([B, "-b", "--factory-startup", "--threads", "2", "--python", REVIEW, "--", "%s_%s" % (shot, v), d, CAM, FRAMES, "640x360"],
                       cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
    n = len(os.listdir(d)) if os.path.isdir(d) else 0
    print("%s %s %s %d frames" % (time.strftime("%H:%M:%S"), shot, v, n), flush=True)
    return d


def clashsum(log):
    """review.py's CLASH lines: frames with arm vertices inside PART, the most vertices and the deepest (clashsum.sh)."""
    n = lit = mc = 0
    md = 0.0
    for line in open(log, errors="replace"):
        if "CLASH frame" in line:
            parts = line.split()
            n += 1
            c, dd = float(parts[3]), float(parts[-1])
            lit += c > 0
            mc, md = max(mc, int(c)), max(md, dd)
    return "%-38s lit %2d/%2d  max %5d verts  deepest %.3f" % (os.path.basename(log)[:-4], lit, n, mc, md)


with ThreadPoolExecutor(max_workers=PAR) as ex:
    dirs = {(s, v): ex.submit(job, s, v) for s in shots for v in (VA, VB)}
    dirs = {k: f.result() for k, f in dirs.items()}
for shot in shots:
    for v in (VA, VB):
        print(clashsum(dirs[(shot, v)] + ".log"))
    mp4 = os.path.join(OUT, "%s_%s_%s%s%s%s.mp4" % (PREFIX, shot, PART.lower(), "" if CAM == "front" else "_" + CAM, BARE, SUFFIX))     # (2026-11-10) other cameras keep their own file
    with open(os.path.join(RV, "video_%s.log" % shot), "w") as log:
        subprocess.run([B, "-b", "--factory-startup", "--python", VIDEO, "--", mp4, "15", "%s: %s inside the %s lit magenta (x-ray), half speed" % (shot, WHAT, PART),
                        "%s=%s" % (LA, dirs[(shot, VA)]), "%s=%s" % (LB, dirs[(shot, VB)])], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    print("video %s %s" % (shot, os.path.getsize(mp4) if os.path.exists(mp4) else "MISSING"), flush=True)
print("RENDER_CMP_DONE")
