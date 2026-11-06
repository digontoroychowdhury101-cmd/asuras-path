"""Cloth and weapon interpenetration report for a baked Grandmaster Shen shot (static review, no Studio).

    python3 tools/qa/shen_cloth_report.py SHOT [SHOT ...]      (shots from tools/animation/opening_cast/cloth_bake.py)

The game's cloth (ClothSim) is a lattice of particles joined by links. Every sampled point - each free particle and the middle of each surface link (edges and diagonals, not bend links) - is tested against
solid volumes: the body capsules the simulation uses (at 85 percent radius, so a robe resting on him is not counted) and the real weapon (haft r 0.06, blade r 0.14 rig units).
A point that was outside a volume at rest and is inside it now is phasing through. Prints, per sheet kind and volume group, the share of frames with any
phasing point and the deepest one (rig units; 1 rig unit = 1.3 studs). Points that start inside a volume at rest are skipped, as the simulation itself does.
"""
import json
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
HAFT_R, BLADE_R, BODY = 0.06, 0.14, 0.85


def seg_dist(P, a, b):
    d = b - a
    u = np.clip((P - a) @ d / max(float(d @ d), 1e-9), 0, 1)
    return np.linalg.norm(P - (a + np.outer(u, d)), axis=1)


def m34(v):
    M = np.eye(4)
    M[:3, :3] = np.array(v[:9]).reshape(3, 3)
    M[:3, 3] = v[9:12]
    return M


def volumes(cloth):
    g = cloth["grip"]
    out = []
    for c in cloth["colliders"]:
        if c["limb"] == "Glaive":
            continue
        group = "legs" if "Leg" in c["limb"] or "Foot" in c["limb"] else "arms" if "Arm" in c["limb"] or "Hand" in c["limb"] else "torso/head"
        out.append((group, "Sk_" + c["limb"], np.array(c["a"]), np.array(c["b"]), c["r"] * BODY))
    out.append(("weapon", "Glaive", np.array(g["butt"]), np.array(g["socket"]), HAFT_R))
    out.append(("weapon", "Glaive", np.array(g["socket"]), np.array(g["tip"]), BLADE_R))
    return out


def report(shot):
    data = json.loads((ROOT / "work/opening_cast_bake/shen_shots" / (shot + ".json")).read_text())
    cloth = json.loads((ROOT / f"work/shen_import/cloth_p{data['phase']}.json").read_text())
    P = cloth["particles"]
    kind = {s["name"]: s["kind"] for s in cloth["sheets"]}
    free = [i for i, p in enumerate(P) if "bone" in p and not p.get("finger") and not p.get("orb")]
    bone_name = {i: cloth["bones"][P[i]["bone"]]["name"] for i in free}
    # the cloth surface between particles: edges and quad diagonals of one sheet. A bend link (two rows apart) spans a fold, so its middle is not on the cloth
    surface = lambda a, b: P[a]["sheet"] == P[b]["sheet"] and abs(P[a]["r"] - P[b]["r"]) <= 1
    links = [(a, b) for a, b, *_ in cloth["links"] if (a in bone_name or b in bone_name) and surface(a, b)]
    rest = np.array([p["at"] for p in P], float)
    vols = volumes(cloth)
    # sample points: free particles, then link midpoints; each tagged with its sheet kind
    tags = np.array([kind[P[i]["sheet"]] for i in free] + [kind[P[a]["sheet"]] for a, b in links])
    owners = [P[i] for i in free] + [P[a] for a, b in links]
    carried = lambda p: {"Sk_" + p["anchor"], "Sk_" + p.get("anchor2", p["anchor"])}
    rest_pts = np.vstack([rest[free], (rest[[a for a, b in links]] + rest[[b for a, b in links]]) / 2])
    # a point is tested against a volume only if it starts outside it and is not carried by that limb
    start_out = np.stack([(seg_dist(rest_pts, a, b) > r + 0.02) & np.array([limb not in carried(p) for p in owners]) for _, limb, a, b, r in vols], 1)
    stats = {}
    frames = data["frames"]
    for fr in frames:
        B = fr["bones"]
        world = rest.copy()
        for i, nm in bone_name.items():
            M = m34(B[nm])
            world[i] = M[:3, :3] @ rest[i] + M[:3, 3]
        for i, p in enumerate(P):     # pinned particles ride their anchor limb
            if i not in bone_name:
                M = m34(B["Sk_" + p["anchor"]]) if ("Sk_" + p["anchor"]) in B else np.eye(4)
                world[i] = M[:3, :3] @ rest[i] + M[:3, 3]
        pts = np.vstack([world[free], (world[[a for a, b in links]] + world[[b for a, b in links]]) / 2])
        seen = {}
        G = fr["props"].get("Glaive")
        Gm = np.array(G).reshape(4, 4) if G else np.eye(4)
        for vi, (group, limb, a, b, r) in enumerate(vols):
            M = Gm if limb == "Glaive" else m34(B[limb])
            A, Bp = M[:3, :3] @ a + M[:3, 3], M[:3, :3] @ b + M[:3, 3]
            depth = r - seg_dist(pts, A, Bp)
            bad = (depth > 0.03) & start_out[:, vi]     # grazing (under 0.03) is not phasing
            for k in set(tags[bad]):
                d = float(depth[bad & (tags == k)].max())
                seen[(k, group)] = max(seen.get((k, group), 0.0), d)
        for key, d in seen.items():
            s = stats.setdefault(key, [0, 0.0])
            s[0] += 1
            s[1] = max(s[1], d)
    n = len(frames)
    print("%s (%d frames, %d points): cloth kind x volume -> frames with phasing, deepest" % (shot, n, len(tags)))
    for (k, group), (c, dmax) in sorted(stats.items()):
        print("  %-8s through %-10s %5.1f%% of frames  deepest %.3f" % (k, group, 100.0 * c / n, dmax))
    return stats


if __name__ == "__main__":
    for s in sys.argv[1:]:
        report(s)
