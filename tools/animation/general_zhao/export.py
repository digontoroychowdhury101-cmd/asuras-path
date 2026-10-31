"""Bake every Zhao clip, validate it and write the deliverables.

    python3 tools/animation/general_zhao/export.py [--bake-dir DIR] [clip ...]

Writes assets/animations/general_zhao/<Clip>.rbxmx (KeyframeSequence, 60 Hz keys decimated within 0.25 degrees and
0.004 studs, Linear pose easing), manifest.json (timing, markers, contacts, hooks, upload status, validation) and, for
previews, one JSON of root-space part frames per clip in the bake directory.
"""
import argparse
import json
import math
import sys
from pathlib import Path
from xml.sax.saxutils import escape

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import clip as cliplib  # noqa: E402
import clips  # noqa: E402
import rig  # noqa: E402

ROOT = HERE.parents[2]
OUT = ROOT / "assets/animations/general_zhao"
PRIORITY = {"Idle": 0, "Movement": 1, "Action": 2, "Action2": 3, "Action3": 4, "Action4": 5, "Core": 1000}
TOL_DEG, TOL_POS = 0.25, 0.004
BODY = ["Head", "UpperTorso", "LowerTorso", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg"]


# ------------------------------------------------------------------------------------------------ rbxmx
_ref = [0]


def ref():
    _ref[0] += 1
    return "RBX%08X" % _ref[0]


def cframe(M):
    R, p = M[:3, :3], M[:3, 3]
    vals = [p[0], p[1], p[2]] + [R[i, j] for i in range(3) for j in range(3)]
    tags = ["X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"]
    return "".join("<%s>%.6f</%s>" % (t, 0.0 if abs(x) < 5e-7 else x, t) for t, x in zip(tags, vals))


CHILDREN = {}
for part, (parent, *_rest) in rig.JOINTS.items():
    CHILDREN.setdefault(parent, []).append(part)


def pose_xml(part, local, indent):
    pad = "\t" * indent
    M = local.get(part, np.eye(4))
    kids = "".join(pose_xml(k, local, indent + 1) for k in CHILDREN.get(part, []))
    return ('%s<Item class="Pose" referent="%s"><Properties><string name="Name">%s</string>'
            '<CoordinateFrame name="CFrame">%s</CoordinateFrame><float name="Weight">1</float>'
            '<token name="EasingStyle">0</token><token name="EasingDirection">0</token></Properties>\n%s%s</Item>\n'
            % (pad, ref(), part, cframe(M) if part != "HumanoidRootPart" else cframe(np.eye(4)), kids, pad))


def keyframe_xml(t, local, markers):
    marks = "".join('\t\t<Item class="KeyframeMarker" referent="%s"><Properties><string name="Name">%s</string>'
                    '<string name="Value">%s</string></Properties></Item>\n' % (ref(), escape(n), escape(v))
                    for n, v in markers)
    return ('\t<Item class="Keyframe" referent="%s"><Properties><string name="Name">Keyframe</string>'
            '<float name="Time">%.6f</float></Properties>\n%s%s\t</Item>\n' % (ref(), t, pose_xml("HumanoidRootPart", local, 2), marks))


def decimate(baked, keep_times):
    """Drop interior keys that linear interpolation between the kept neighbours reproduces within tolerance."""
    keep = [0]
    n = len(baked)
    i = 0
    while i < n - 1:
        j = i + 2
        while j < n:
            ok = True
            for k in range(i + 1, j):
                t = (baked[k][0] - baked[i][0]) / (baked[j][0] - baked[i][0])
                for part in rig.ORDER:
                    a, b, m = baked[i][1].get(part, np.eye(4)), baked[j][1].get(part, np.eye(4)), baked[k][1].get(part, np.eye(4))
                    q = rig.slerp(rig.quat(a[:3, :3]), rig.quat(b[:3, :3]), t)
                    err = rig.angle_of(rig.mat(q).T @ m[:3, :3])
                    perr = np.linalg.norm(a[:3, 3] + (b[:3, 3] - a[:3, 3]) * t - m[:3, 3])
                    if err > TOL_DEG or perr > TOL_POS:
                        ok = False
                        break
                if not ok:
                    break
                if any(abs(baked[k][0] - kt) < 1e-6 for kt in keep_times):
                    ok = False
                    break
            if not ok:
                break
            j += 1
        i = j - 1
        keep.append(i)
    return sorted(set(keep + [n - 1]))


def write_rbxmx(clip, baked, path):
    marker_at = {}
    for t, name, val in clip.markers:
        f = int(round(t * clips.FPS))
        marker_at.setdefault(f, []).append((name, val))
    must = [f / clips.FPS for f in marker_at] + clip.contacts
    idx = decimate([(b[0], b[1]) for b in baked], must)
    for f in marker_at:  # markers sit on their exact frame
        if f not in idx:
            idx.append(min(f, len(baked) - 1))
    idx = sorted(set(idx))
    body = "".join(keyframe_xml(baked[i][0], baked[i][1], marker_at.get(i, [])) for i in idx)
    xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" version="4">\n'
           '<Item class="KeyframeSequence" referent="%s"><Properties><string name="Name">%s</string>'
           '<bool name="Loop">%s</bool><token name="Priority">%d</token><float name="AuthoredHipHeight">2.192423</float>'
           '</Properties>\n%s</Item>\n</roblox>\n' % (ref(), clip.name, "true" if clip.loop else "false",
                                                    PRIORITY[clip.priority], body))
    path.write_text(xml)
    return len(idx)


# ------------------------------------------------------------------------------------------------ validation
HAND_JERK = 0.35  # a 1.6-stud thrust over 6 frames peaks near 0.27 even when eased rest-to-rest


def pop(a, b, c):
    """A hand's second difference across three frames, counted only where it kinks the path (at least POP_KINK of
    its speed): a fast arc (a spinning cyclone) bends steadily and is not a pop."""
    jerk = float(np.linalg.norm(a - 2 * b + c))
    speed = max(float(np.linalg.norm(b - a)), float(np.linalg.norm(c - b)))
    return jerk if jerk >= POP_KINK * speed else 0.0


POP_KINK = 0.75
ARM_IN_BODY = 0.08  # contact allowed: a front arm reaching across to the shaft presses on the boxy R15 chest


def validate(clip, baked):
    worst = {"grip_error": 0.0, "right_reach": 0.0, "leg_reach": 0.0, "sole_below_ground": 0.0, "planted_slide": 0.0,
             "blade_below_ground": 0.0, "shaft_in_body": 0.0, "tip_distance_min": 99.0, "tip_distance_max": 0.0,
             "wrist_bend_max": 0.0, "loop_seam_deg": 0.0, "right_pull": 0.0, "hand_jerk": 0.0, "arm_in_body": 0.0}
    frames_shaft = []
    hands = []
    prev_soles = None
    for t, local, world, diag, c in baked:
        if diag.get("grip_error") is not None:
            worst["grip_error"] = max(worst["grip_error"], diag["grip_error"])
        worst["right_reach"] = max(worst["right_reach"], diag["right_excess"])
        worst["right_pull"] = max(worst["right_pull"], diag["right_pull"])
        worst["leg_reach"] = max(worst["leg_reach"], diag["left_leg_excess"], diag["right_leg_excess"])
        soles = {}
        for foot in ("LeftFoot", "RightFoot"):
            pts = rig.obb_points(world, foot)
            low = min(p[1] for p in pts)
            worst["sole_below_ground"] = max(worst["sole_below_ground"], rig.GROUND - low)
            k = int(np.argmin([p[1] for p in pts]))
            soles[foot] = (np.array(pts[k]), low, k, pts)
        if prev_soles:
            for foot in soles:
                p, low, k, pts = soles[foot]
                q = prev_soles[foot][3][k]  # the same sole corner in the previous frame
                low0 = prev_soles[foot][1]
                if low - rig.GROUND < 0.01 and low0 - rig.GROUND < 0.01 and not clip.root_motion:
                    # a planted foot should travel backward at exactly the cycle's ground speed (zero when standing)
                    vel = (p - q)[[0, 2]] * clips.FPS
                    expect = -np.array(clip.velocity, float)
                    worst["planted_slide"] = max(worst["planted_slide"], float(np.linalg.norm(vel - expect)))
        prev_soles = soles
        hand = world["RightHand"]
        hands.append(hand[:3, 3].copy())
        tip = (hand @ np.append(rig.TIP, 1))[:3]
        edge = (hand @ np.append(rig.EDGE, 1))[:3]
        allow_ground = clip.ground_contact(t)
        if not allow_ground:
            worst["blade_below_ground"] = max(worst["blade_below_ground"], rig.GROUND - min(tip[1], edge[1]))
        dist = float(np.linalg.norm(tip - hand[:3, 3]))
        worst["tip_distance_min"] = min(worst["tip_distance_min"], dist)
        worst["tip_distance_max"] = max(worst["tip_distance_max"], dist)
        butt = rig.shaft_point(hand, rig.BUTT_Z)
        for part in BODY:
            clearance = rig.segment_obb_distance(world, part, butt, tip, inflate=0.05)
            if clearance < -0.02:
                worst["shaft_in_body"] = max(worst["shaft_in_body"], -clearance)
                frames_shaft.append((round(t, 3), part))
        worst["arm_in_body"] = max(worst["arm_in_body"], cliplib.arm_in_body(world, "Right"), cliplib.arm_in_body(world, "Left"))
        for side in ("Right", "Left"):  # flexion/deviation: hand +Y against the forearm's axis (twist excluded)
            if side == "Left" and diag.get("grip_s") is None:
                continue
            hy, fy = world[side + "Hand"][:3, 1], world[side + "LowerArm"][:3, 1]
            worst["wrist_bend_max"] = max(worst["wrist_bend_max"], math.degrees(math.acos(max(-1, min(1, float(np.dot(hy, fy)))))))
    # a hand that zigzags between 60 Hz frames (second difference, studs per frame squared) reads as a pop on screen
    # (the hard stop on a contact frame is the hit itself, so frames within 2 of a contact are exempt)
    times = [f[0] for f in baked]
    for k, (a, b, c2) in enumerate(zip(hands, hands[1:], hands[2:])):
        if any(abs(times[k + 1] - ct) < 0.035 for ct in clip.contacts):
            continue
        worst["hand_jerk"] = max(worst["hand_jerk"], pop(a, b, c2))
    if clip.loop:
        a, b = baked[0][1], baked[-1][1]
        worst["loop_seam_deg"] = max(rig.angle_of(a[p][:3, :3].T @ b[p][:3, :3]) for p in rig.ORDER)
    worst = {k: round(float(v), 4) for k, v in worst.items()}
    worst["shaft_in_body_frames"] = frames_shaft[:12]
    problems = []
    if worst["grip_error"] > 0.08:
        problems.append("left hand leaves the shaft by %.2f" % worst["grip_error"])
    if worst["right_reach"] > 0.03:
        problems.append("right arm short of the grip by %.2f" % worst["right_reach"])
    if worst["right_pull"] > 0.3:
        problems.append("grip pulled in %.2f from its key (overreach)" % worst["right_pull"])
    if worst["leg_reach"] > 0.05:
        problems.append("leg short of its foot target by %.2f" % worst["leg_reach"])
    if worst["sole_below_ground"] > 0.06:
        problems.append("foot %.2f below ground" % worst["sole_below_ground"])
    if worst["blade_below_ground"] > 0.05:
        problems.append("blade %.2f below ground" % worst["blade_below_ground"])
    if worst["shaft_in_body"] > 0.0:
        problems.append("shaft passes %.2f into the body (%s)" % (worst["shaft_in_body"], frames_shaft[:3]))
    if worst["arm_in_body"] > ARM_IN_BODY:
        problems.append("forearm passes %.2f into the body" % worst["arm_in_body"])
    if worst["wrist_bend_max"] > 80:
        problems.append("wrist bent %.0f degrees" % worst["wrist_bend_max"])
    if worst["hand_jerk"] > HAND_JERK:
        problems.append("hand pops %.2f between frames" % worst["hand_jerk"])
    if clip.loop and worst["loop_seam_deg"] > 1.0:
        problems.append("loop seam %.1f degrees" % worst["loop_seam_deg"])
    return worst, problems


def frames_json(clip, baked, path):
    frames = []
    for t, local, world, diag, c in baked:
        frames.append({"t": round(t, 4), "parts": {p: [round(float(x), 5) for x in M.ravel()] for p, M in world.items()}})
    path.write_text(json.dumps({"name": clip.name, "length": clip.length, "contacts": clip.contacts,
                                "preview": clip.preview, "markers": clip.markers, "frames": frames}))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bake-dir", default=str(ROOT / "work/zhao_anim_bake"))
    ap.add_argument("names", nargs="*")
    a = ap.parse_args()
    bake = Path(a.bake_dir)
    bake.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    library = clips.library()
    chosen = [c for c in library if not a.names or c.name in a.names]
    manifest_path = OUT / "manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() and a.names else {"clips": {}}
    for clip in chosen:
        fixes = []
        clip.repair(fixes)
        if not clip.loop:  # a loop's corrections would have to wrap; the loops are clean without them
            clip.fields(log=fixes)
        baked = clip.bake()
        stats, problems = validate(clip, baked)
        keys = write_rbxmx(clip, baked, OUT / (clip.name + ".rbxmx"))
        frames_json(clip, baked, bake / (clip.name + ".json"))
        manifest["clips"][clip.name] = clip.manifest(keys, stats, problems)
        manifest["clips"][clip.name]["key_repairs"] = fixes
        flag = "OK " if not problems else "FIX"
        print("%s %-44s %5.2fs keys %3d grip %.3f slide %.2f %s" % (flag, clip.name, clip.length, keys,
                                                                   stats["grip_error"], stats["planted_slide"],
                                                                   "; ".join(problems)))
    manifest.update(clips.manifest_header())
    manifest["clips"] = dict(sorted(manifest["clips"].items()))
    manifest_path.write_text(json.dumps(manifest, indent=1))


if __name__ == "__main__":
    main()
