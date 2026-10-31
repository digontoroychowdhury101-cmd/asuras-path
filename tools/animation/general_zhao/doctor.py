"""Clip diagnosis for hand polishing: per frame, where the shaft enters the body (which end, which part, how deep), the
wrist bends, the arm's overreach, the left hand's gap, the blade in the floor and hand pops (flagged a frame late), printed as windows between the clip's grip keys.

    python3 tools/animation/general_zhao/doctor.py GeneralZhao_P1_Guandao_L1 [--raw]

--raw diagnoses the authored keys alone (no key repair, no correction fields)."""
import sys

import numpy as np

import clip
import export
import clips
import rig


def main():
    name, raw = sys.argv[1], "--raw" in sys.argv
    c = next(k for k in clips.library() if k.name == name)
    if not raw:
        c.repair([])
        if not c.loop:
            c.fields()
    print("grip keys:", [round(k[0], 3) for k in c.keys if "grip" in k[1]], "contacts:", c.contacts)
    hands = []
    for t in c.frames():
        ctl = c.controls(t)
        _, w, d = c.solve(ctl)
        hand = w["RightHand"]
        tip = (hand @ np.append(rig.TIP, 1))[:3]
        butt = rig.shaft_point(hand, rig.BUTT_Z)
        mid = rig.shaft_point(hand, -3.0)
        hits = []
        for p in clip.CLEAR_PARTS:
            for label, a, b in (("butt", butt, hand[:3, 3]), ("haft", hand[:3, 3], mid), ("head", mid, tip)):
                k = rig.segment_obb_distance(w, p, a, b, 0.05, 12)
                if k < -0.02:
                    hits.append("%s>%s %.2f" % (label, p, -k))
        flags = []
        if hits:
            flags.append(" ".join(hits))
        arm = max(clip.arm_in_body(w, "Right"), clip.arm_in_body(w, "Left"))
        if arm > 0.08:
            flags.append("arm%s %.2f" % ("R" if clip.arm_in_body(w, "Right") >= arm else "L", arm))
        rb = clip.wrist_bend(w, "Right")
        if rb > 80:
            flags.append("Rwrist %d" % rb)
        if d["right_pull"] > 0.1:
            flags.append("pull %.2f" % d["right_pull"])
        if d.get("grip_error") and d["grip_error"] > 0.08:
            flags.append("Lgap %.2f" % d["grip_error"])
        if not c.ground_contact(t):
            edge = (hand @ np.append(rig.EDGE, 1))[:3]
            low = rig.GROUND - min(tip[1], edge[1])
            if low > 0.05:
                flags.append("floor %.2f" % low)
        hands.append(hand[:3, 3].copy())
        if len(hands) >= 3 and not any(abs(t - 1 / 60 - k) < 0.035 for k in c.contacts):
            jerk = export.pop(*hands[-3:])
            if jerk > 0.35:
                flags.append("pop %.2f" % jerk)
        if flags:
            print("%.3f grip %s dir %s | %s" % (t, np.round(ctl["grip"], 2), np.round(ctl["dir"], 2), "; ".join(flags)))


if __name__ == "__main__":
    main()
