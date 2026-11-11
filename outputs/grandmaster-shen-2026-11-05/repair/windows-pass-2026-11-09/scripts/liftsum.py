# liftsum.py TAG... : (Windows pass 2026-11-11) one block per P2 Skyfall fist-lift bake (runall.py TAG with a DEV overlay of shen_clips.py):
# the overlay's second carry and legs_guard, every joint_polish try, the final verdict, and the deepest weapon point in a leg over f40-78
# (thighdir.py's measure, every weapon sample). Reads the bake logs, overlays and saved bakes in SHEN_SCRATCH (work/shen_repair).
import ast, os, re, subprocess, sys
H = os.path.dirname(os.path.abspath(__file__))
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(H, "../../../../.."))
W = os.environ.get("SHEN_SCRATCH") or os.path.join(ROOT, "work", "shen_repair")
P = os.path.join(H, "thighdir.py")
DEV = {"lfB": "liftB", "lfD": "liftD", "lfE": "liftE", "lfG": "liftG", "lfH": "liftH", "lfI": "liftI", "lfJ": "liftJ", "lfK": "liftK", "lfL": "liftL",
       "lfM": "liftM", "knA": "kneeA", "knB": "kneeB", "knC": "kneeC", "knD": "kneeD", "knE": "kneeE", "knF": "kneeF", "knG": "kneeG",
       "knH": "kneeH", "knI": "kneeI",     # (11-11) kn*: the right knee turned in instead
       "rsA": "spikeA", "rsB": "spikeB", "rsC": "spikeC",     # (11-11) rs*: knI, plus a per-degree price on a hand's turn on the haft
       "rsD": "spikeD"}     # (11-11) rsC with the cut's edge carried up from the guard (shen_clips.arc carry_edge)
STOPPED = {"knF", "knG", "knH"}     # (11-11) stopped by hand before their verdicts (clear_torso deeper than knI's); their last readings are printed
for tag in sys.argv[1:]:
    src = open(os.path.join(W, DEV[tag], "shen_clips.py"), encoding="utf-8").read()
    m = re.search(r"1\.5, 1\.62, 1\.92, 2\.0, \(0\.4, 0\.0, -0\.1\)\), ([0-9., ]+), (\([-0-9., ]+\))\)", src)
    k = re.search(r'K\(1\.42, "io", rknee=(\([-0-9., ]+\))\)', src) or re.search(r"kin = (\([-0-9., ]+\))", src)     # the repo names it kin
    guard = 'c.legs_guard = phase == 2 and short == "GuandaoSkyfall"' in src
    held = "2.3 s (READY's at 1.2 and 2.6)" if "**low, hov=H0 * 0.35, rknee=" in src else "1.92 s (READY's at 1.2 and 2.15)"
    what = "second carry %s, offset %s" % (m.group(1), m.group(2)) if m else "right knee pole %s from 1.42 s to %s" % (k.group(1), held)
    for attr in ("recheck_spike", "walk_spike"):     # the overlay's own per-clip expression, read for phase 2 Skyfall
        s = re.search(r"c\.%s = (.*)" % attr, src)
        v = eval(s.group(1), {"__builtins__": {}}, {"phase": 2, "short": "GuandaoSkyfall"}) if s else None
        what += ", %s %g" % (attr, v) if v else ""
    what += ", the cut's edge carried up from the guard" if "carry_edge=True), 1.5" in src else ""
    print("## %s (%s): %s, legs_guard %s" % (tag, DEV[tag], what, "on" if guard else "off"))
    log = os.path.join(W, "tt%s_P2_GuandaoSkyfall.log" % tag)
    verdict, last = None, []
    for line in open(log, encoding="utf-8", errors="replace"):
        if line.startswith("torso:"):
            last = ["clear_torso " + line.split(";")[1].strip().split(",")[0]]
        elif line.startswith("   stage depop"):
            last.append("pops after depop: " + line.split("depop", 1)[1].strip())
        if line.startswith("joint_polish "):
            d = ast.literal_eval(line[len("joint_polish "):].strip())
            kind = "seeded" if d["seeded"] else "elbows only" if d["elbows_only"] else "first try"
            print("  polish f%d-%d %-11s %.3f -> %.3f  %s, %s%s (%.0f s)" % (d["window"][0], d["window"][1], kind, d["depth"][0], d["depth"][1],
                  "feasible" if d["feasible"] else "infeasible", "kept" if d["kept"] else "not kept",
                  ", worse %s" % d["worse"] if d["worse"] else "", d["runtime_s"]))
        elif line.startswith("P2_GuandaoSkyfall on"):
            verdict = line
    if not verdict:
        print("  stopped by hand, no verdict; last readings: %s" % "; ".join(last) if tag in STOPPED else "  (still running)")
        continue
    g = lambda k: re.search(k + r"=([0-9.]+)", verdict).group(1)
    print("  verdict: torso R %s L %s, pops fist %s blade %s slide %s | %s" % (g("torso_right"), g("torso_left"), g("pop_fist"), g("pop_blade"),
          g("pop_slide"), verdict.split("|")[-1].strip()))
    out = subprocess.run([sys.executable, P, os.path.join(W, "baked_" + tag), "P2_GuandaoSkyfall", "40", "78"], capture_output=True, text=True).stdout
    hits = [l for l in out.splitlines()[1:] if "clear" not in l]
    worst = max(hits, key=lambda l: float(l.split()[2])) if hits else None
    print("  legs f40-78: %s" % ("clear on every frame" if not hits else "%d frames, deepest %s %s at %s" % (len(hits), worst.split()[2], worst.split()[1], worst.split()[0])))
