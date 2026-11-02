"""Bakes the visible blade of every published weapon clip into shared, server-sampleable data.

    python3 tools/animation/bake_trajectories.py

Writes src/shared/StrikeTrajectoryData.luau: per move, phase times, the presentation step along the facing and the
hilt/tip path in root space at each server tick of the active frames. The server sweeps these samples; the client
draws trails from them and plays the step. A clip whose .rbxmx no longer matches its published hash is left out, so
the data never describes a clip the game does not play.

The step: a move's design reach (Reach + Lunge x 0.35) was set by the combat tuning and is kept. Where a clip's blade
falls short of it, the fighter's body presents a step forward during the swing (no root motion: spacing, standoff and
arena clamps are unchanged), up to STEP_CAP. Any reach still missing is removed from the volume and reported, so the
blade and the volume agree (TIMING_CONTRACT A4); it is not hidden by a longer invisible hitbox.
"""
import importlib.util
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/animation/general_zhao"))
sys.path.insert(0, str(ROOT / "tools/animation/jian"))
sys.path.insert(0, str(ROOT / "tools/animation/families"))
import clips  # noqa: E402
import families as F  # noqa: E402
import jianlib as J  # noqa: E402
import numpy as np  # noqa: E402

_spec = importlib.util.spec_from_file_location("zhao_export", ROOT / "tools/animation/general_zhao/export.py")
zx = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(zx)

OUT = ROOT / "src/shared/StrikeTrajectoryData.luau"
REPORT = ROOT / "outputs/combat-recovery-2026-11-02/mac-stage3/blade_vs_volume.json"
PUBLISHED = ROOT / "assets/animations/jian/published.json"
FAMILY_PUBLISHED = ROOT / "assets/animations/families/published.json"
# Families whose visible weapon meets the move's design reach. The Odachi, Cleaver and Heaven-Piercing Guandao blades are 3+ studs shorter than their
# hit volumes even with the full presented step, and the chain, censer and staff reach is not body motion: baking those would silently cut
# their reach, a balance call. They keep the generic volume, and ANIMATION_COVERAGE.md lists the gap.
BAKED_FAMILIES = {"Dao", "Guandao", "TwinDaggers", "WarFan"}
TICK = 1 / 60
STEP_CAP = 3.5  # studs of presented step; beyond this a body visibly detaches from its feet
STEP_IN = 0.75  # the step arrives over this share of the windup, by the first active frame
# A family move whose clip shows much less than its volume stays generic: its clip is the thing to revise, not its balance.
MAX_REACH_LOSS = 1.0  # studs of design reach the clip does not visibly cover
MIN_ARC_SHARE = 0.5  # share of a design arc of 90 degrees or more the clip must visibly sweep


def smooth(a):
    a = min(max(a, 0.0), 1.0)
    return a * a * (3 - 2 * a)


def step_curve(step, contact, active_end, length):
    """(clip time, studs) keys: rises through the windup, holds through the active frames, settles over recovery."""
    if step <= 0:
        return []
    start = contact * (1 - STEP_IN)
    keys = []
    for i in range(0, 7):
        t = start + (contact - start) * i / 6
        keys.append((t, step * smooth(i / 6)))
    settle = max(length - active_end, TICK)
    for i in range(1, 7):
        t = active_end + settle * i / 6
        keys.append((t, step * (1 - smooth(i / 6))))
    return keys


def step_at(keys, t):
    if not keys or t <= keys[0][0]:
        return 0.0
    for (a, x), (b, y) in zip(keys, keys[1:]):
        if t <= b:
            return x + (y - x) * (t - a) / max(b - a, 1e-6)
    return keys[-1][1]


def bake_move(clip, spec, move_id, blade, moves, report):
    baked = clip.bake()
    times = np.array([b[0] for b in baked])

    def blade_at(t):
        i = int(np.argmin(np.abs(times - t)))
        _, guard, tip = blade(baked[i][2])
        return guard, tip

    contact = clip.active[0]
    active = spec["active"]
    end = contact + active
    design = spec["reach"] + spec["lunge"] * 0.35
    count = max(int(round(active / TICK)), 1)
    raw = []
    for k in range(count + 1):
        raw.append(blade_at(contact + active * k / count))
    reach_of = lambda p: float(math.hypot(p[0], p[2]))
    baked_reach = max(reach_of(tip) for _, tip in raw)
    step = min(max(design - baked_reach, 0.0), STEP_CAP)
    keys = step_curve(step, contact, end, clip.length)
    samples = []
    for k, (guard, tip) in enumerate(raw):
        t = contact + active * k / count
        z = step_at(keys, t)
        samples.append([guard[0], guard[1], guard[2] - z, tip[0], tip[1], tip[2] - z])
    moves[move_id] = {
        "Clip": clip.name, "Startup": spec["startup"], "Active": active, "Total": spec["total"],
        "ClipContact": contact, "ClipActiveEnd": end, "ClipLength": clip.length,
        "Step": keys, "Samples": samples,
    }
    visible = max(reach_of(s[3:]) for s in samples)
    yaws = [math.degrees(math.atan2(s[3], -s[5])) for s in samples]
    report[move_id] = {
        "design_reach": round(design, 2), "clip_tip_reach": round(baked_reach, 2), "step": round(step, 2),
        "visible_reach": round(visible, 2), "reach_removed_from_volume": round(max(design - visible, 0), 2),
        "design_arc": spec["arc"], "visible_sweep_deg": round(yaws[-1] - yaws[0], 1), "active_ticks": count,
    }


def main():
    timing = J.timing()
    published = json.loads(PUBLISHED.read_text())["clips"]
    moves, report = {}, {}
    for clip in clips.library():
        if not clip.move or clip.active is None:
            continue
        record = published.get(clip.name)
        path = ROOT / "assets/animations/jian" / (clip.name + ".rbxmx")
        if not record or zx.content_hash(path) != record["sha256"]:
            print("SKIP %s: not published or stale" % clip.name)
            continue
        bake_move(clip, timing[clip.move], clip.move, J.blade, moves, report)
    family_timing = F.timing()
    family_published = json.loads(FAMILY_PUBLISHED.read_text())["clips"] if FAMILY_PUBLISHED.exists() else {}
    for family, clip in F.library(family_timing, BAKED_FAMILIES):
        if not clip.move or clip.active is None or not getattr(clip, "move_id", None):
            continue
        record = family_published.get(clip.name)
        path = ROOT / "assets/animations/families" / (clip.name + ".rbxmx")
        if not record or not path.exists() or zx.content_hash(path) != record["sha256"]:
            print("SKIP %s: not published or stale" % clip.name)
            continue
        bake_move(clip, family_timing[family.weapon]["moves"][clip.move_id], clip.move_id, family.blade, moves, report)
        row = report[clip.move_id]
        if row["reach_removed_from_volume"] > MAX_REACH_LOSS or (row["design_arc"] >= 90 and row["visible_sweep_deg"] < row["design_arc"] * MIN_ARC_SHARE):
            del moves[clip.move_id]
            row["kept_generic"] = True
    lines = ["--!strict",
             "-- GENERATED by tools/animation/bake_trajectories.py from the published clips' bakes. Do not edit.",
             "-- Per move: phase times (server and clip seconds), the presented step {clip time, studs} and the visible blade",
             "-- {hilt x, y, z, tip x, y, z} in root space (forward is -Z) at each server tick of the active frames.",
             "return {"]
    fmt = lambda v: ("%.3f" % v).rstrip("0").rstrip(".") if abs(v) > 5e-4 else "0"
    for name in sorted(moves):
        m = moves[name]
        lines.append('\t%s = {' % name)
        lines.append('\t\tClip = "%s", Startup = %.5f, Active = %.5f, Total = %.5f, ClipContact = %.5f, ClipActiveEnd = %.5f, ClipLength = %.5f,' % (
            m["Clip"], m["Startup"], m["Active"], m["Total"], m["ClipContact"], m["ClipActiveEnd"], m["ClipLength"]))
        lines.append('\t\tStep = { %s },' % ", ".join("{ %s, %s }" % (fmt(a), fmt(b)) for a, b in m["Step"]))
        lines.append('\t\tSamples = {')
        for s in m["Samples"]:
            lines.append('\t\t\t{ %s },' % ", ".join(fmt(float(x)) for x in s))
        lines.append('\t\t},')
        lines.append('\t},')
    lines.append("}")
    OUT.write_text("\n".join(lines) + "\n")
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps(report, indent=1))
    for name, row in sorted(report.items()):
        print(name, row)


if __name__ == "__main__":
    main()
