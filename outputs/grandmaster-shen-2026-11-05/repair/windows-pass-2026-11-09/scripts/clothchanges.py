# clothchanges.py TAGA TAGB : (Windows pass 2026-11-10, saved as a script 11-11) per cloth pair, how the rendered-mesh clash changed between two
# mesh_clash.py measurements ($SHEN_SCRATCH/mset_<TAG>_*.json, as msetcmp.py reads them): a cloth piece inside a body part or the weapon, kept where
# it is 0.05 deep or more on either side; deeper (by 0.01) or more of it (share x depth up by 0.003) after, or shallower or less. This is the script
# that wrote results/cloth_changes.txt (pre4L -> finL, every other frame); 11-11 it also ran on the every-frame measurements (pre4L1 -> finL1).
# clothchanges.py TAGA TAGB rest : the same for every pair that is NOT cloth (arms and hands in the glaive, the glaive in him, beard, beads,
# sleeves and hair in his body) -> results/rest_changes_every.txt.
import json, glob, os, sys
H = os.path.dirname(os.path.abspath(__file__))
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(H, "../../../../.."))
S = os.environ.get("SHEN_SCRATCH") or os.path.join(ROOT, "work", "shen_repair")
CLOTH = ("Robe", "Ribbon", "Sash", "Skirt", "Tassel", "Sleeve")


def load(tag):
    out = {}
    for f in glob.glob(os.path.join(S, "mset_%s_*.json" % tag)):
        for k, v in json.load(open(f)).items():
            out[k.rsplit("_", 1)[0]] = v
    return out


ta, tb = sys.argv[1], sys.argv[2]
REST = sys.argv[3:4] == ["rest"]     # (2026-11-11) the pairs that are not cloth
A, B = load(ta), load(tb)
clips = sorted(set(A) & set(B))
rise, fall = [], []
for c in clips:
    pa, pb = A[c]["pairs"], B[c]["pairs"]
    for p in sorted(set(pa) | set(pb)):
        if p.split(" in ")[0].startswith(CLOTH) == REST:
            continue
        a, b = pa.get(p, {"share": 0, "deepest": 0, "frame": -1}), pb.get(p, {"share": 0, "deepest": 0, "frame": -1})
        if max(a["deepest"], b["deepest"]) < 0.05:
            continue
        sa, sb = a["share"] * a["deepest"], b["share"] * b["deepest"]
        row = (sb - sa, c, p, a, b)
        if b["deepest"] > a["deepest"] + 0.01 or sb > sa + 0.003:
            rise.append(row)
        elif b["deepest"] < a["deepest"] - 0.01 or sb < sa - 0.003:
            fall.append(row)
fmt = lambda r: "%-22s %-32s before %3.0f%% %.3f f%-3d after %3.0f%% %.3f f%d" % (r[1], r[2], 100 * r[3]["share"], r[3]["deepest"], r[3]["frame"],
                                                                                100 * r[4]["share"], r[4]["deepest"], r[4]["frame"])
print("%s, rendered mesh, deepest >= 0.05 either side), %s -> %s, %d clips" % (
    "pairs msetcmp.py does not call cloth (an arm or hand in the glaive, the glaive in him, and LeftSleeve, Beard, Beads, HairBack and the "
    "mantles, which are simulated cloth (mesh_clash.py's CLOTH) but fall outside msetcmp.py's name prefixes" if REST else
    "cloth pairs (robe or ribbon inside a body part or the weapon", ta, tb, len(clips)))
print("\nDEEPER or more frames after (%d):" % len(rise))
for r in sorted(rise, key=lambda r: -max(r[4]["deepest"] - r[3]["deepest"], r[0])):
    print("  " + fmt(r))
print("\nSHALLOWER or fewer frames after (%d):" % len(fall))
for r in sorted(fall, key=lambda r: r[0]):
    print("  " + fmt(r))
