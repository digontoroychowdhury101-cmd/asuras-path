"""Zhao's non-attack clips: neutral/alert, locomotion, turns, guard, reactions, posture break, deathblow, death, intro.
None of these is requested by the current boss pipeline (BossAnimations only plays Idle, attacks and Transform);
each carries the hook it needs (manifest `wiring`: needs-hook)."""
import math

import numpy as np

import rig
from clip import Clip
from clips import (FEET, FREE_LEFT, GUARD, GUARD_GRIP, aim, at, foot, footwork, gait, key_name, pose, smooth, unitv,
                   yawdir)

LOCO_HOOK = ("NEW: client locomotion layer (Movement priority) chosen from the boss root's planar velocity relative to "
             "its facing; playback speed = measured ground speed / (nominal speed x 1.2)")


def neutral_pose():
    upright_g = (1.25, -0.25, -0.5)  # far enough forward that the butt clears the right thigh
    return pose(root=(0.0, -0.06, 0.0), rootR=(0, -6, 0), chest=(-2, -4, 0), lookW=0.8,
                grip=upright_g, dir=unitv(0.0, 1, 0.06), edge=(0, 0, -1), s=-1.0,
                lf=(-0.52, -0.08, 0, 6, 0), rf=(0.52, 0.06, 0, -4, 0), **FREE_LEFT,
                relb=(1, -0.2, 0.5))


NEUTRAL = neutral_pose()


def clip(name, length, keys, **kw):
    kw.setdefault("group", "State")
    kw.setdefault("wiring", "needs-hook")
    return Clip(key_name(name), length, keys, action=name, **kw)


def states():
    out = []
    # ------------------------------------------------------------------ neutral idle and alert
    breath = at(NEUTRAL, chest=(-3.2, -4, 0), root=(0.0, -0.04, 0.0), grip=(1.25, -0.23, -0.5))
    out.append(clip("IdleNeutral", 4.6, [(0, NEUTRAL, "inout"), (1.4, breath, "inout"), (2.6, NEUTRAL, "inout"),
                                         (3.5, at(NEUTRAL, neck=(-4, 8, 0)), "inout")],
                    loop=True, priority="Idle", preview=(0, 1.4, 3.5), timing="Authored loop",
                    hook="NEW: out-of-combat state (before BossIntro / after BossReset) plays IdleNeutral",
                    notes="Upright, guandao standing beside him in the right hand, left hand at his side; slow breath "
                          "and a glance."))
    alert_mid = at(NEUTRAL, lfree=0.6, grip=(1.1, -0.35, -0.4), dir=yawdir(-10, 55), chest=(2, -12, 0), root=(0.03, -0.18, 0.03))
    out.append(clip("AlertTransition", 0.8, [(0, NEUTRAL, "inout"), (0.3, alert_mid, "out"),
                                             (0.55, at(GUARD, chest=(4, -30, 0)), "inout"), (0.8, GUARD, "settle")]
                    + footwork(0.8, {"lf": [(0.25, 0.45, GUARD["lf"])], "rf": [(0.38, 0.58, GUARD["rf"])]},
                               start=dict(lf=NEUTRAL["lf"], rf=NEUTRAL["rf"]), end=FEET),
                    priority="Action", preview=(0, 0.3, 0.55, 0.8), timing="Authored 0.8 s",
                    markers=[(0.45, "FootstepL", ""), (0.58, "FootstepR", "")],
                    hook="NEW: first aggro / BossIntro end plays AlertTransition, then Idle",
                    notes="The guandao tips down from upright into the point-forward guard as the feet blade."))
    # ------------------------------------------------------------------ locomotion (in place)
    walk_base = at(GUARD, root=(0.05, -0.48, 0.04))
    walk_feet = dict(lf=(-0.6, -0.42, 0, 12, 0), rf=(0.8, 0.42, 0, 40, 0))
    walk = gait(1.1, (0, -2.2), 0.6, {"lf": 0.0, "rf": 0.5}, 0.26, walk_feet)
    bob = [(t, {"root": (0.05, -0.48 - 0.03 * math.cos(4 * math.pi * t / 1.1), 0.04)}, "linear")
           for t in np.linspace(0, 1.1, 23)]
    out.append(clip("WalkForward", 1.1, [(0, walk_base, "linear")] + walk + bob, loop=True, priority="Movement",
                    velocity=(0, -2.2), preview=(0, 0.275, 0.55, 0.825), timing="Authored cycle 1.1 s at 2.2 studs/s (scale 1)",
                    markers=[(0.0, "FootstepL", ""), (0.55, "FootstepR", "")], hook=LOCO_HOOK,
                    notes="Guarded stalking walk: the point stays on the target while the feet shuffle in the bladed "
                          "stance (feet never cross)."))
    run_g = (1.05, -0.7, 0.35)
    run_base = pose(root=(0.0, -0.5, -0.1), rootR=(12, -20, 0), chest=(10, -18, 0), grip=run_g,
                    dir=aim(run_g, (0.2, -0.6, -8.8)), edge=(0, 1, 0), s=-1.8, lfree=1.0, lhand=(0, 0, 0),
                    larm=(-30, 0, -10), lfore=(55, 0, 0))
    run_feet = dict(lf=(-0.5, -0.3, 0, 10, 0), rf=(0.6, 0.3, 0, 20, 0))
    run = gait(0.66, (0, -8.0), 0.36, {"lf": 0.0, "rf": 0.5}, 0.5, run_feet, pitch_off=-24)
    bob = [(t, {"root": (0.0, -0.5 - 0.07 * math.cos(4 * math.pi * t / 0.66), -0.1)}, "linear") for t in np.linspace(0, 0.66, 23)]
    # the haft is carried low at his right side, out of the front hand's reach at a sprint: the left arm pumps
    # instead, back as the left foot lands, forward as the right does
    pump = [(t, {"larm": (-30, 0, -10) if k % 2 == 0 else (25, 0, -8), "lfore": (55, 0, 0) if k % 2 == 0 else (75, 0, 0)},
             "inout") for k, t in enumerate(np.linspace(0, 0.66, 3)) if k]  # k = 0 is run_base
    out.append(clip("RunForward", 0.66, [(0, run_base, "linear")] + run + bob + pump, loop=True, priority="Movement",
                    velocity=(0, -8.0), preview=(0, 0.165, 0.33, 0.5), timing="Authored cycle 0.66 s at 8.0 studs/s (scale 1)",
                    markers=[(0.0, "FootstepL", ""), (0.33, "FootstepR", "")], hook=LOCO_HOOK,
                    notes="Charging run with the blade carried low and forward in the right hand, the left arm "
                          "pumping. Nominal 9.6 studs/s at scale 1.2; the "
                          "boss WalkSpeed (about 20 studs/s) needs playback speed ~2.1 or the feet slide."))
    out.append(clip("WalkBackward", 1.3, [(0, walk_base, "linear")] + gait(1.3, (0, 1.9), 0.6, {"lf": 0.0, "rf": 0.5}, 0.22, walk_feet),
                    loop=True, priority="Movement", velocity=(0, 1.9), preview=(0, 0.33, 0.65, 1.0),
                    timing="Authored cycle 1.3 s at 1.9 studs/s backward", hook=LOCO_HOOK,
                    markers=[(0.0, "FootstepR", ""), (0.65, "FootstepL", "")],
                    notes="Backward steps keeping guard; rear foot reaches first."))
    for name, vx in (("StrafeLeft", -2.0), ("StrafeRight", 2.0)):
        out.append(clip(name, 1.2, [(0, walk_base, "linear")]
                        + gait(1.2, (vx, 0), 0.6, {"lf": 0.0 if vx < 0 else 0.5, "rf": 0.5 if vx < 0 else 0.0}, 0.22, walk_feet),
                        loop=True, priority="Movement", velocity=(vx, 0), preview=(0, 0.3, 0.6, 0.9),
                        timing="Authored cycle 1.2 s at 2.0 studs/s sideways", hook=LOCO_HOOK,
                        markers=[(0.0, "FootstepL" if vx < 0 else "FootstepR", ""), (0.6, "FootstepR" if vx < 0 else "FootstepL", "")],
                        notes="Circling sidestep in guard; leading foot opens, trailing foot closes, point on target."))
    for name, deg in (("TurnLeft", 90), ("TurnRight", -90)):
        th = smooth(0.0, float(deg), 0.7)
        keys = [(0, GUARD, "inout"), (0.25, at(GUARD, chest=(6, -26 + deg * 0.25, 0)), "inout"), (0.7, GUARD, "inout")]
        first, second = ("lf", "rf") if deg > 0 else ("rf", "lf")
        out.append(clip(name, 0.7, keys + footwork(0.7, {first: [(0.08, 0.36, None)], second: [(0.32, 0.62, None)]},
                                                   start=FEET, end=FEET, theta=th),
                        priority="Movement", preview=(0, 0.2, 0.36, 0.5, 0.7), root_motion=True,
                        timing="Authored 0.7 s for a %d degree turn by the server" % abs(deg), hook=
                        "NEW: play when the server turns the boss more than 45 degrees while standing (facing delta)",
                        markers=[(0.36, "FootstepL" if first == "lf" else "FootstepR", ""), (0.62, "FootstepR" if first == "lf" else "FootstepL", "")],
                        notes="Feet stay planted on the ground while the server turns the root, then re-step; guard held."))
    # approach / stop / retreat (one-shot, nominal travel assumed)
    adv = smooth(0.0, -1.6, 0.6)
    out.append(clip("Approach", 0.6, [(0, GUARD, "inout"), (0.3, at(GUARD, root=(0.05, -0.44, -0.08)), "inout"), (0.6, GUARD, "inout")]
                    + footwork(0.6, {"lf": [(0.04, 0.28, None)], "rf": [(0.26, 0.52, None)]}, start=FEET, end=FEET,
                               shift=lambda t: (0.0, adv(t))),
                    priority="Movement", preview=(0, 0.2, 0.3, 0.45, 0.6), velocity=(0, 0), root_motion=True,
                    timing="Authored 0.6 s for a 1.6-stud (scale 1) advance", hook="NEW: short advance when the server "
                    "closes under 4 studs in one step", markers=[(0.28, "FootstepL", ""), (0.52, "FootstepR", "")],
                    notes="Front foot slides in, rear foot follows (yori-ashi), guard steady."))
    brake = at(GUARD, root=(0.02, -0.5, 0.12), chest=(-2, -24, 0))
    out.append(clip("Stop", 0.5, [(0, at(GUARD, root=(0.0, -0.5, -0.1), rootR=(12, -20, 0), chest=(10, -18, 0)), "inout"),
                                  (0.18, brake, "out"), (0.5, GUARD, "inout")]
                    + footwork(0.5, {"lf": [(0.0, 0.12, None)]}, start=dict(lf=foot(FEET["lf"], dz=0.3), rf=FEET["rf"]), end=FEET),
                    priority="Movement", preview=(0, 0.18, 0.5), timing="Authored 0.5 s",
                    markers=[(0.12, "FootstepL", "Brake")], hook="NEW: run -> stand transition (velocity drops below 2)",
                    notes="Plants the lead foot and sinks back into guard."))
    back = smooth(0.0, 2.0, 0.7)
    out.append(clip("Retreat", 0.7, [(0, GUARD, "inout"), (0.25, at(GUARD, root=(0.05, -0.38, 0.18), chest=(2, -26, 0)), "out"),
                                     (0.7, GUARD, "inout")]
                    + footwork(0.7, {"rf": [(0.02, 0.3, None)], "lf": [(0.28, 0.56, None)]}, start=FEET, end=FEET,
                               shift=lambda t: (0.0, back(t))),
                    priority="Movement", preview=(0, 0.25, 0.45, 0.7), root_motion=True, timing="Authored 0.7 s for a 2-stud retreat",
                    markers=[(0.3, "FootstepR", ""), (0.56, "FootstepL", "")],
                    hook="NEW: backward hop-step when the server retreats the boss", notes="Rear foot first, guard kept."))
    # ------------------------------------------------------------------ equip and intro
    over = pose(root=(0.02, -0.15, 0.0), rootR=(0, -12, 0), chest=(-4, -10, 0), grip=(0.9, 0.55, -0.4),
                dir=unitv(-0.9, 0.35, -0.2), edge=(0, 1, 0), **FREE_LEFT)
    spin_mid = at(over, dir=unitv(-0.2, -0.3, -0.95), grip=(1.0, 0.2, -0.6), edge=(0, 0, 1))
    out.append(clip("Equip", 0.9, [(0, NEUTRAL, "inout"), (0.22, at(over, dir=unitv(0.1, 0.9, 0.42)), "out"),
                                   (0.42, over, "linear"), (0.58, spin_mid, "linear"),
                                   (0.72, at(GUARD, lfree=0.3), "out"), (0.9, GUARD, "settle")]
                    + footwork(0.9, {"lf": [(0.4, 0.62, GUARD["lf"])], "rf": [(0.55, 0.78, GUARD["rf"])]},
                               start=dict(lf=NEUTRAL["lf"], rf=NEUTRAL["rf"]), end=FEET),
                    priority="Action", preview=(0, 0.22, 0.42, 0.58, 0.72, 0.9), timing="Authored 0.9 s",
                    markers=[(0.2, "TrailOn", "Flourish"), (0.66, "TrailOff", "Flourish"), (0.62, "FootstepL", ""),
                             (0.78, "FootstepR", "")],
                    hook="NEW: ready/equip on aggro or after the intro", notes="One-handed overhead wheel of the guandao "
                    "into the two-handed guard; the left hand catches the shaft at 0.72 s."))
    intro_low = at(NEUTRAL, neck=(-22, 0, 0), lookW=0.2, chest=(4, -4, 0))
    intro_rise = at(NEUTRAL, neck=(-4, 0, 0), lookW=0.9, chest=(-4, -4, 0))
    out.append(clip("Intro", 2.4, [(0, intro_low, "inout"), (0.9, intro_low, "inout"), (1.4, intro_rise, "out"),
                                   (1.9, at(intro_rise, chest=(-6, -6, 0)), "inout"), (2.4, at(intro_rise, chest=(-5, -6, 0)), "inout")],
                    priority="Action4", preview=(0, 0.9, 1.4, 1.9, 2.4), timing="BossHandoff Intro shot 2.4 s",
                    markers=[(0.2, "CrestGlow", "Dim"), (1.4, "CrestGlow", "Full"), (1.4, "PlumeSway", "")],
                    hook="NEW: BossIntro cue -> play Intro on the boss for the 2.4 s shot (EncounterHandoffController)",
                    notes="Head bowed, guandao upright: the helmet and plumes read as a silhouette; the head lifts at "
                          "1.4 s so the crest and chest diamond face the camera; holds for the shot."))
    out.append(clip("IntroReady", 0.6, [(0, at(intro_rise, chest=(-5, -6, 0)), "inout"), (0.25, at(NEUTRAL, lfree=0.5, dir=yawdir(-12, 45), grip=(1.2, -0.25, -0.75)), "out"),
                                        (0.6, GUARD, "settle")]
                    + footwork(0.6, {"lf": [(0.12, 0.34, GUARD["lf"])], "rf": [(0.26, 0.48, GUARD["rf"])]},
                               start=dict(lf=NEUTRAL["lf"], rf=NEUTRAL["rf"]), end=FEET),
                    priority="Action", preview=(0, 0.25, 0.6), timing="BossHandoff Blend 0.35 s + Lead 0.9 s window",
                    markers=[(0.34, "FootstepL", ""), (0.48, "FootstepR", "")],
                    hook="NEW: after the intro shot, before the first impact (inside the 0.9 s lead)",
                    notes="Snaps from the presentation pose into guard inside the handoff's readable lead."))
    # ------------------------------------------------------------------ guard
    block_g = (0.95, -0.15, -0.6)
    block = pose(root=(0.03, -0.48, 0.1), rootR=(3, -20, 0), chest=(4, -16, 0), grip=block_g,
                 dir=unitv(-0.9, 0.42, -0.12), edge=(0, 0.3, -1), s=-2.3, sMin=-2.6, sMax=-1.6)
    out.append(clip("GuardEnter", 0.25, [(0, GUARD, "inout"), (0.25, block, "snap")], priority="Action",
                    preview=(0, 0.12, 0.25), timing="Authored 0.25 s",
                    hook="NEW: GuardHeld true (fighter state replicated as an attribute) -> GuardEnter then GuardLoop",
                    notes="Haft raised diagonally across the body as a bar, wide grip."))
    out.append(clip("GuardLoop", 1.6, [(0, block, "inout"), (0.8, at(block, root=(0.03, -0.46, 0.1), chest=(5, -16, 0)), "inout")],
                    loop=True, priority="Action", preview=(0, 0.8), timing="Authored loop",
                    hook="NEW: held while GuardHeld", notes="Braced block, small breath."))
    out.append(clip("GuardExit", 0.3, [(0, block, "inout"), (0.3, GUARD, "inout")], priority="Action",
                    preview=(0, 0.15, 0.3), timing="Authored 0.3 s", hook="NEW: GuardHeld false",
                    notes="Returns the point to the opponent."))
    pushed = at(block, root=(0.05, -0.52, 0.32), chest=(-6, -18, 0), grip=(0.95, -0.1, -0.35))
    out.append(clip("GuardHit", 0.45, [(0, block, "inout"), (0.07, pushed, "snap"), (0.45, block, "inout")]
                    + footwork(0.45, {"rf": [(0.06, 0.2, foot(GUARD["rf"], dz=0.25))]}, start=FEET, end=dict(lf=FEET["lf"], rf=foot(GUARD["rf"], dz=0.25))),
                    priority="Action2", preview=(0, 0.07, 0.2, 0.45), timing="Authored 0.45 s",
                    markers=[(0.0, "ImpactFX", "Blocked"), (0.2, "FootstepR", "Brace")],
                    hook="NEW: Hit cue with result Blocked on the boss -> GuardHit (Action2 over the guard loop)",
                    notes="The haft is driven back toward his chest, rear foot braces a quarter step."))
    # ------------------------------------------------------------------ deflect recoil and reactions
    thrown = pose(root=(0.06, -0.3, 0.3), rootR=(-4, -34, 0), chest=(-12, -30, 0), grip=(1.15, 0.3, 0.35),
                  dir=unitv(0.15, 0.85, -0.5), edge=(0, 0.4, 0.9), s=-1.2, lookW=0.6, neck=(-8, 0, 0))
    out.append(clip("DeflectRecoil", 0.6, [(0, GUARD, "inout"), (0.08, thrown, "snap"), (0.3, at(thrown, chest=(-8, -30, 0)), "out"),
                                           (0.6, GUARD, "inout")]
                    + footwork(0.6, {"lf": [(0.1, 0.3, foot(GUARD["lf"], dz=0.35))], "rf": [(0.38, 0.54, None)]},
                               start=FEET, end=dict(lf=foot(GUARD["lf"], dz=0.35), rf=FEET["rf"])),
                    priority="Action2", preview=(0, 0.08, 0.3, 0.6), timing="Authored 0.6 s",
                    markers=[(0.0, "ImpactFX", "Deflected"), (0.3, "FootstepL", ""), (0.54, "FootstepR", "")],
                    hook="NEW: player Deflect cue against the boss -> DeflectRecoil (stops the attack track)",
                    notes="The guandao is knocked up and back over his right shoulder; he gives ground a half step."))
    hits = {"Front": ((-10, 0, 0), (0, 0, 0.25)), "Back": ((10, 0, 0), (0, 0, -0.2)),
            "Left": ((0, -12, -9), (0.2, 0, 0)), "Right": ((0, 12, 9), (-0.2, 0, 0))}
    for side, (bend, push) in hits.items():
        light = at(GUARD, chest=(6 + bend[0], -26 + bend[1], bend[2]), root=(0.05 + push[0] * 0.5, -0.38, 0.06 + push[2] * 0.5),
                   neck=(bend[0] * 0.8, bend[1] * 0.6, bend[2]))
        out.append(clip("HitLight" + side, 0.4, [(0, GUARD, "inout"), (0.06, light, "snap"), (0.4, GUARD, "inout")],
                        priority="Action2", preview=(0, 0.06, 0.2, 0.4), timing="Authored 0.4 s",
                        markers=[(0.0, "ImpactFX", "Flesh")],
                        hook="NEW: Hit cue on the boss with direction relative to its facing -> HitLight<dir>",
                        notes="Light flinch from the %s; guard and grip hold." % side.lower()))
        heavy = at(GUARD, chest=(6 + bend[0] * 2, -26 + bend[1] * 2, bend[2] * 2), root=(0.05 + push[0], -0.5, 0.06 + push[2]),
                   neck=(bend[0] * 1.4, bend[1], bend[2] * 1.5), lfree=0.35)
        step = {"Front": ("lf", foot(GUARD["lf"], dz=0.5)), "Back": ("rf", foot(GUARD["rf"], dz=-0.5)),
                "Left": ("lf", foot(GUARD["lf"], dx=0.4)), "Right": ("rf", foot(GUARD["rf"], dx=-0.35))}[side]
        end = dict(FEET)
        end[step[0]] = step[1]
        out.append(clip("HitHeavy" + side, 0.8, [(0, GUARD, "inout"), (0.08, heavy, "snap"), (0.4, at(heavy, lfree=0.0), "out"),
                                                 (0.8, at(GUARD, **{step[0]: step[1]}), "inout")]
                        + footwork(0.8, {step[0]: [(0.08, 0.32, step[1])]}, start=FEET, end=end),
                        priority="Action2", preview=(0, 0.08, 0.32, 0.8), timing="Authored 0.8 s",
                        markers=[(0.0, "ImpactFX", "FleshHeavy"), (0.32, "FootstepL" if step[0] == "lf" else "FootstepR", "Stagger")],
                        hook="NEW: heavy Hit cue on the boss with direction -> HitHeavy<dir>",
                        notes="Stumbles from the %s with a recovery step; front hand slips and re-grips." % side.lower()))
    # ------------------------------------------------------------------ posture break, stagger, recovery
    slump_g = (1.15, -1.05, -0.25)
    broken = pose(root=(0.05, -0.92, 0.18), rootR=(14, -16, 0), chest=(30, -8, 6), lookW=0.1, neck=(-30, 0, 0),
                  grip=slump_g, dir=aim(slump_g, (1.6, -3.1, -7.4)), edge=(0, 1, 0), s=-1.4,
                  lf=foot(GUARD["lf"], dx=0.1, dz=0.1), rf=foot(GUARD["rf"], dx=-0.05), **FREE_LEFT)
    broken["larm"], broken["lfore"] = (20, 0, -12), (30, 0, 0)
    out.append(clip("PostureBreak", 1.0, [(0, GUARD, "inout"), (0.1, at(broken, chest=(-6, -20, 0), root=(0.05, -0.4, 0.3), lfree=0.6), "snap"),
                                          (0.45, broken, "in"), (1.0, at(broken, chest=(32, -8, 6)), "inout")],
                    priority="Action3", preview=(0, 0.1, 0.45, 1.0), ground=[(0.35, 1.0)], timing="Authored 1.0 s",
                    markers=[(0.0, "ImpactFX", "PostureBreak"), (0.1, "Charge", "Discharge"), (0.45, "FootstepR", "Buckle")],
                    hook="NEW: fighter state StanceBroken -> PostureBreak then StaggerLoop (Action3; stops the attack)",
                    notes="Jolted upright by the discharge, then the knees buckle; the blade drops to the stone and the "
                          "front hand falls away."))
    out.append(clip("StaggerLoop", 1.4, [(0, broken, "inout"), (0.7, at(broken, chest=(28, -8, 4), root=(0.05, -0.88, 0.18)), "inout")],
                    loop=True, priority="Action3", preview=(0, 0.7), ground=[(0, 1.4)], timing="Authored loop",
                    markers=[(0.0, "StaggerAura", "On")], hook="NEW: held while StanceBroken",
                    notes="Heaving breath, head down, guandao point resting on the ground (deathblow window)."))
    out.append(clip("StaggerRecover", 0.8, [(0, broken, "inout"), (0.35, at(GUARD, lfree=0.4, root=(0.05, -0.55, 0.1)), "out"),
                                            (0.8, GUARD, "inout")], priority="Action3", preview=(0, 0.35, 0.8),
                    ground=[(0, 0.1)], timing="Authored 0.8 s", markers=[(0.0, "StaggerAura", "Off"), (0.35, "Recovery", "")],
                    hook="NEW: StanceBroken ends without a deathblow", notes="Regrips and resets the guard."))
    # ------------------------------------------------------------------ deathblow and death
    kneel_g = (1.0, -1.25, -0.6)
    kneel = pose(root=(0.05, -1.3, 0.3), rootR=(10, -10, 0), chest=(24, -6, 0), lookW=0.0, neck=(-26, 0, 0),
                 grip=kneel_g, dir=unitv(0.05, 1, 0.08), edge=(0, 0, -1), s=-0.9,
                 lf=(-0.6, -0.6, 0, 8, 0), rf=(0.6, 1.25, 0.12, 10, -70), rknee=(0, -0.4, -1), **FREE_LEFT)
    kneel["larm"], kneel["lfore"] = (40, 0, -6), (50, 0, 0)
    jolt = at(GUARD, chest=(-14, -20, 0), root=(0.05, -0.36, 0.25), lookW=0.3, neck=(-14, 0, 0), lfree=0.8)
    out.append(clip("DeathblowVictim", 2.2, [(0, at(broken, lfree=1.0), "inout"), (0.15, jolt, "snap"), (0.55, at(jolt, chest=(-18, -18, 0)), "out"),
                                             (1.2, kneel, "in"), (2.2, at(kneel, chest=(28, -6, 0)), "settle")]
                    + footwork(2.2, {"rf": [(0.7, 1.15, (0.6, 1.25, 0, 10, -70))]}, start=dict(lf=broken["lf"], rf=broken["rf"]),
                               end=dict(lf=(-0.6, -0.6, 0, 8, 0), rf=(0.6, 1.25, 0, 10, -70)), lift=0.15),
                    priority="Action4", preview=(0, 0.15, 0.55, 1.2, 2.2), ground=[(0.0, 2.2)], timing="Authored 2.2 s",
                    markers=[(0.15, "ImpactFX", "Deathblow"), (1.15, "FootstepR", "Knee")],
                    hook="NEW: fighter state DeathblowVictim -> DeathblowVictim (Action4); holds the last frame",
                    notes="Rigid jolt at the blow, a breath, then he sinks to his right knee with the guandao planted "
                          "upright as a support."))
    slump = at(kneel, chest=(40, -4, 8), neck=(-34, 0, 6), root=(0.05, -1.42, 0.25), grip=(1.05, -1.5, -0.65),
               dir=unitv(0.25, 0.95, 0.15))
    out.append(clip("Death", 3.0, [(0, kneel, "inout"), (0.8, at(kneel, neck=(-6, 0, 0), lookW=0.5, chest=(16, -6, 0)), "inout"),
                                   (1.6, slump, "in"), (3.0, at(slump, chest=(44, -4, 10)), "settle")],
                    priority="Action4", preview=(0, 0.8, 1.6, 3.0), ground=[(0, 3.0)], timing="Authored 3.0 s; holds",
                    markers=[(0.8, "FinalBreath", ""), (1.6, "CrestGlow", "Dim"), (2.4, "Dissipate", "")],
                    hook="NEW: KO -> Death (Action4) on the corpse; EnemyDissolve still owns removal and BossDefeated "
                         "timing is unchanged", notes="Lifts his head once toward the victor, then slumps over the "
                         "planted guandao, still kneeling: a general who does not fall."))
    for c in out:
        if not c.ground:
            pass
    return out
