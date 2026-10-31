"""General Zhao's clip library: key poses and every clip, with exact contact timing from the server sources.

Timing sources
- Boss specials: src/shared/BossAttackCatalog.luau (Zhao, Bull) windups and Repeats/Interval; a clip's contact times
  equal the nominal impacts at an undeferred start. Playback re-times to each cue's `impact` (BossAnimations).
- Guandao moves: src/simulation/WeaponSchema.luau through Tempo (scalar 1.4, 60 Hz): contact at StartupSeconds,
  active window to StartupSeconds + ActiveSeconds, clip length TotalSeconds.
- Transform: BossDuo's 2 s cinematic state (Characters.Cinematic(survivor, 2)); Enrage shot 1.1 s + 0.35 s blend.

Controls (clip.py): root/rootR (LowerTorso offset and turn), chest (waist), neck + look (stabilised gaze), grip/dir/edge
(RightHand frame = the guandao), s (front hand along the shaft, negative toward the blade), lf/rf (feet: x, z, lift,
yaw, pitch), elbow and knee poles. Roblox root space: +X right, +Y up, -Z forward, template scale 1.
"""
import math

import numpy as np

import rig
from clip import Clip, merged

FPS = 60
GUANDAO = {  # WeaponSchema.resolveTiming frames at 60 Hz: startup, active, recovery, total
    "Guandao_L1": (9, 4, 11, 24), "Guandao_L2": (9, 4, 12, 25), "Guandao_L3": (11, 4, 16, 31),
    "Guandao_Heavy": (23, 4, 23, 50), "Guandao_Running": (13, 4, 19, 36), "Guandao_Art": (19, 11, 24, 54),
}
LOOK = "GeneralZhao"


def sec(frames):
    return frames / FPS


def unitv(*a):
    v = np.array(a[0] if len(a) == 1 else a, float)
    return tuple(v / np.linalg.norm(v))


def aim(grip, tip):
    return unitv(np.asarray(tip, float) - np.asarray(grip, float))


def yawdir(deg, pitch=0.0):
    """Unit direction yawed `deg` left of forward (-Z) and pitched up `pitch` degrees."""
    y, p = math.radians(deg), math.radians(pitch)
    return (-math.sin(y) * math.cos(p), math.sin(p), -math.cos(y) * math.cos(p))


# ------------------------------------------------------------------------------------------------ key poses
GUARD_GRIP = (1.0, -0.6, -0.1)
GUARD = dict(root=(0.05, -0.34, 0.06), rootR=(3, -30, 0), chest=(6, -26, 0), neck=(0, 0, 0), lookW=0.9,
             grip=GUARD_GRIP, dir=aim(GUARD_GRIP, (-0.35, 1.25, -8.6)), edge=(0.3, 1, 0), roll=0,
             s=-1.6, sMin=-2.6, sMax=-0.7, lroll=0, lfree=0.0, larm=(4, 0, -6), lfore=(10, 0, 0), lhand=(0, 0, 0),
             lf=(-0.62, -0.75, 0, 12, 0), rf=(0.85, 0.72, 0, 42, 0),
             relb=(1, -0.4, 0.8), lelb=(-0.6, -1, 0.3), lknee=(0.1, 0, -1), rknee=(0.4, 0, -1))
FEET = dict(lf=GUARD["lf"], rf=GUARD["rf"])
FREE_LEFT = dict(lfree=1.0, larm=(6, 0, -8), lfore=(14, 0, 0), lhand=(0, 0, 0))


def pose(**kw):
    return merged(GUARD, kw)


def at(base, **kw):
    return merged(base, kw)


def foot(f, dx=0.0, dz=0.0, lift=None, yaw=None, pitch=None):
    return (f[0] + dx, f[1] + dz, f[2] if lift is None else lift, f[3] if yaw is None else yaw,
            f[4] if pitch is None else pitch)


def key_name(action, oath=False):
    return "%s_P1_%s%s" % (LOOK, "Oath_" if oath else "", action)


def melee_markers(contact, active_end, trail_lead=0.06, extra=()):
    return [(max(0.0, contact - trail_lead), "TrailOn", "1"), (contact, "ImpactFX", "1"),
            (active_end, "TrailOff", "1"), (active_end, "Recovery", "")] + list(extra)


# ------------------------------------------------------------------------------------------------ footwork
def gait(length, velocity, duty, phases, lift, neutral, yaw=None, pitch_off=-16.0, samples=30):
    """In-place cycle: a planted foot travels backward at exactly `velocity` (root space, scale 1); the swing foot
    arcs forward. Returns dense lf/rf keys (linear) that loop seamlessly."""
    V = np.array(velocity, float)
    keys = {}
    for side in ("lf", "rf"):
        x0, z0, _, yw, _ = neutral[side]
        p0 = np.array([x0, z0])
        half = V * duty * length / 2
        out = []
        n = int(samples * length / 0.5)
        for i in range(n + 1):
            t = length * i / n
            u = ((t / length) + phases[side]) % 1.0
            if u < duty:
                p = p0 + half - V * (u * length)
                h, pt = 0.0, 0.0
            else:
                w = (u - duty) / (1 - duty)
                e = w * w * (3 - 2 * w)
                p = (p0 - half) + (2 * half) * e
                h = lift * math.sin(math.pi * w)
                pt = pitch_off * math.sin(math.pi * min(1.0, w * 1.6)) if w < 0.62 else 0.0
            out.append((t, {side: (float(p[0]), float(p[1]), h, yw if yaw is None else yaw, pt), "_feet": True}, "linear"))
        keys[side] = out
    return keys["lf"] + keys["rf"]


def footwork(length, steps, start, end=None, theta=None, shift=None, lift=0.32, samples=60):
    """One-shot footwork with planted feet fixed on the ground while the root turns (theta(t), degrees, +left) or
    travels (shift(t) -> (dx, dz) root displacement, scale 1). steps: {side: [(lift_t, plant_t, target_pose)]} where
    the target is the root-space foot at the clip's end root (defaults to `end` or `start`)."""
    theta = theta or (lambda t: 0.0)
    shift = shift or (lambda t: (0.0, 0.0))
    end = end or start

    def to_world(p, t):
        R = rig.ry(theta(t))
        d = shift(t)
        w = R @ np.array([p[0], 0, p[1]])
        return np.array([w[0] + d[0], w[2] + d[1]]), p[3] + theta(t)

    def to_root(w, wyaw, t):
        R = rig.ry(-theta(t))
        d = shift(t)
        r = R @ np.array([w[0] - d[0], 0, w[1] - d[1]])
        return (float(r[0]), float(r[2])), wyaw - theta(t)

    out = []
    n = int(samples * length)
    for side in ("lf", "rf"):
        plan = sorted(steps.get(side, []), key=lambda s: s[0])
        world, wyaw = to_world(start[side], 0.0)
        pitch0 = start[side][4]
        seg = 0
        for i in range(n + 1):
            t = length * i / n
            while seg < len(plan) and t > plan[seg][1]:
                tgt = plan[seg][2] if plan[seg][2] is not None else end[side]
                world, wyaw = to_world(tgt, plan[seg][1])
                seg += 1
            if seg < len(plan) and plan[seg][0] <= t <= plan[seg][1]:
                t0, t1, tgt = plan[seg]
                tgt = tgt if tgt is not None else end[side]
                a, ay = to_root(world, wyaw, t)
                bw, byaw = to_world(tgt, t1)
                b, by = to_root(bw, byaw, t)
                w = (t - t0) / max(t1 - t0, 1e-6)
                e = w * w * (3 - 2 * w)
                p = (a[0] + (b[0] - a[0]) * e, a[1] + (b[1] - a[1]) * e)
                y = ay + (by - ay) * e
                h = lift * math.sin(math.pi * w)
                pt = -14 * math.sin(math.pi * min(1.0, w * 1.6)) if w < 0.62 else 0.0
                out.append((t, {side: (p[0], p[1], h, y, pt), "_feet": True}, "linear"))
            else:
                p, y = to_root(world, wyaw, t)
                out.append((t, {side: (p[0], p[1], 0.0, y, pitch0 if seg == 0 else 0.0), "_feet": True}, "linear"))
    return out


def smooth(a, b, length):
    return lambda t: a + (b - a) * (lambda u: u * u * (3 - 2 * u))(min(1.0, max(0.0, t / length)))


# ------------------------------------------------------------------------------------------------ oath layer
def oath_layer(c, t, clip):
    """Oath of the Fallen posture: lower centre, chest and head pressed forward, tighter grip (front hand closer to
    the rear hand), elbows in. Timing is untouched."""
    c = dict(c)
    c["root"] = (c["root"][0], c["root"][1] - 0.12, c["root"][2] + 0.02)
    c["chest"] = (c["chest"][0] + 5, c["chest"][1], c["chest"][2])
    c["neck"] = (c["neck"][0] + 3, c["neck"][1], c["neck"][2])
    g = c["grip"]
    c["grip"] = (g[0] - 0.05, g[1] - 0.04, g[2] + 0.04)
    c["s"] = min(c["sMax"], c["s"] + 0.3)
    c["relb"] = (0.7, -0.8, 0.6)
    return c


def oath(clip, name_action):
    import copy
    o = Clip(key_name(name_action, oath=True), clip.length, copy.deepcopy(clip.keys), loop=clip.loop, priority=clip.priority,
             markers=clip.markers, contacts=clip.contacts, notes="Oath posture layer over %s: lower centre, chest "
             "and head forward, tighter two-hand grip, elbows in; timing identical." % clip.name,
             hook="NEW: BossAnimationRules tries <Look>_P1_Oath_<Action> first while AsuraBossEnraged is set",
             timing=clip.timing, base=clip.base, layers=clip.layers + [oath_layer], ground=clip.ground,
             velocity=clip.velocity, preview=clip.preview, group="Oath", action=name_action, wiring="needs-hook")
    return o


# ------------------------------------------------------------------------------------------------ resolver clips
def idle():
    inhale = at(GUARD, root=add3(GUARD["root"], (0, 0.025, 0)), chest=(7.5, -26, 0), grip=add3(GUARD_GRIP, (0, 0.02, 0)))
    shift = at(GUARD, root=(0.13, -0.36, 0.08), rootR=(3, -28, 0), chest=(6, -27, 0.8),
               grip=add3(GUARD_GRIP, (0.02, -0.02, 0.02)))
    return Clip(key_name("Idle"), 4.0, [
        (0.0, GUARD, "inout"), (1.0, inhale, "inout"), (2.0, GUARD, "inout"), (2.7, shift, "inout"),
        (3.4, GUARD, "inout"),
    ], loop=True, priority="Idle", group="Resolver", action="Idle", timing="Authored loop (no gameplay timing)",
        hook="BossAnimations.sync -> resolve(Idle); existing", preview=(0, 1.0, 2.7),
        notes="Guarded two-handed stance: breath at 1.0 s, weight onto the rear foot at 2.7 s; the point stays on "
              "the opponent's throat.")


def add3(a, b):
    return tuple(x + y for x, y in zip(a, b))


def strike():
    """Ordinary-attack fallback for any move without its own clip: rising-then-falling diagonal cut, contact 0.5 s."""
    raise_ = pose(root=(0.05, -0.3, 0.12), rootR=(2, -36, 0), chest=(-4, -34, 0), grip=(0.95, 0.65, 0.35),
                  dir=yawdir(-30, 62), edge=(0, 0, -1), s=-1.3)
    cut = pose(root=(0.0, -0.5, -0.2), rootR=(6, -12, 0), chest=(14, 4, 0), grip=(0.55, -0.6, -0.95),
               dir=yawdir(14, -10), edge=(-0.4, -1, 0), s=-1.2,
               lf=foot(GUARD["lf"], dz=-0.35))
    follow = at(cut, dir=yawdir(32, -22), chest=(16, 12, 0), grip=(0.35, -0.75, -0.8))
    return Clip(key_name("Strike"), 1.2, [
        (0.0, GUARD, "inout"), (0.32, raise_, "out"), (0.40, at(raise_, chest=(-6, -38, 0)), "inout"),
        (0.50, cut, "in"), (0.62, follow, "out"), (1.2, GUARD, "inout"),
    ], contacts=(0.5,), group="Resolver", action="Strike", preview=(0, 0.32, 0.5, 0.62, 1.2),
        markers=melee_markers(0.5, 0.58, 0.1, [(0.5, "FootstepL", "Plant")]),
        timing="Fallback: contact 0.5 s; BossAnimations re-times the contact to the cue's impact",
        hook="resolve(<move>) falls back to <Look>_P1_Strike; existing",
        notes="Diagonal cut from high right; returns naturally to guard.")


def lightning_spear():
    """Three perilous thrusts: windup 0.8 s, impacts 0.8 / 1.5 / 2.2 s (Interval 0.7). Counter: Deflect."""
    def coil(depth=0.0):
        g = (0.95, -0.55, 0.55 + depth)
        return pose(root=(0.06, -0.52, 0.18), rootR=(4, -36, 0), chest=(8, -30, 0), grip=g,
                    dir=aim(g, (0.1, 0.55, -8.6)), edge=(0, 1, 0), s=-2.3, sMin=-2.7, sMax=-1.0)

    def thrust(depth, aim_y):
        g = (0.55, -0.42, -1.25 - depth)
        return pose(root=(0.0, -0.66, -0.4 - depth * 0.25), rootR=(6, -18, 0), chest=(12, -14, 0), grip=g,
                    dir=aim(g, (0.0, aim_y, -10.0)), edge=(0, 1, 0), s=-0.9, sMin=-2.7, sMax=-0.75,
                    lf=foot(GUARD["lf"], dz=-0.6 - depth * 0.5), rf=foot(GUARD["rf"], pitch=-12))

    def recoil(y=0.0):
        g = (0.9, -0.55 + y, 0.2)
        return at(coil(), root=(0.05, -0.56, 0.06), grip=g, dir=aim(g, (0.1, 0.95 + y, -8.6)), chest=(9, -26, 0),
                  s=-2.0, lf=foot(GUARD["lf"], dz=-0.6))

    planted = dict(lf=foot(GUARD["lf"], dz=-0.6))
    lunge = dict(lf=foot(GUARD["lf"], dz=-1.1))
    keys = [
        (0.0, GUARD, "inout"),
        (0.32, coil(), "inout"),                                        # point alignment, compressed stance
        (0.62, coil(0.12), "inout"),                                    # tension
        (0.70, at(coil(0.12), lf=foot(GUARD["lf"], dz=-0.35, lift=0.3, pitch=-8)), "in"),
        (0.80, thrust(0.0, 0.5), "snap"),                               # IMPACT 1 (throat), front foot stamps
        (0.96, recoil(), "out"),
        (1.30, at(coil(0.12), **planted), "inout"),
        (1.50, thrust(0.08, 0.05), "snap"),                             # IMPACT 2 (belly)
        (1.66, recoil(-0.05), "out"),
        (2.00, at(coil(0.2), root=(0.06, -0.6, 0.22), **planted), "inout"),
        (2.08, at(coil(0.2), root=(0.06, -0.6, 0.22), lf=foot(GUARD["lf"], dz=-0.85, lift=0.3, pitch=-8)), "in"),
        (2.20, at(thrust(0.3, 0.45), **lunge), "snap"),                 # IMPACT 3, full lunge
        (2.42, at(thrust(0.3, -0.7), chest=(15, -12, 0), **lunge), "out"),  # over-extended: blade dips
        (2.66, at(thrust(0.2, -0.45), **lunge), "inout"),
        (2.82, at(GUARD, lf=foot(GUARD["lf"], dz=-0.5, lift=0.28, pitch=-8), root=(0.05, -0.42, 0.0)), "inout"),
        (3.00, GUARD, "inout"),
    ]
    return Clip(key_name("LightningSpear"), 3.0, keys, contacts=(0.8, 1.5, 2.2), group="Resolver",
                action="LightningSpear", preview=(0.0, 0.32, 0.62, 0.8, 0.96, 1.5, 2.2, 2.42, 3.0),
                markers=[(0.05, "Charge", "Spear"), (0.62, "TrailOn", "1"), (0.8, "ImpactFX", "1"), (0.8, "FootstepL", "Stamp"),
                         (0.96, "TrailOff", "1"), (1.3, "TrailOn", "2"), (1.5, "ImpactFX", "2"), (1.66, "TrailOff", "2"),
                         (2.0, "TrailOn", "3"), (2.2, "ImpactFX", "3"), (2.2, "FootstepL", "Stamp"), (2.42, "TrailOff", "3"),
                         (2.42, "Recovery", "Punish"), (2.94, "FootstepL", "Return")],
                timing="BossAttackCatalog Zhao.LightningSpear: windup 0.8, Repeats 3, Interval 0.7",
                hook="Telegraph cue per pulse -> BossAnimations.action; NEW: one track phase-locked to each pulse's "
                     "impact (no restart on repeats)", wiring="needs-hook",
                notes="Point aligned and stance compressed by 0.32 s; the rear hand drives the shaft through the "
                      "guiding front hand; distinct recoil between impacts; the third thrust over-extends with the "
                      "blade dipping (punishable 2.42-2.8 s).")


def thunder_quickstep():
    """Advancing charge (ShieldCharge kind, Motion Lunge): windup 1.0 s, contact 1.0 s. Counter: Evade."""
    low_g = (1.15, -0.95, 0.75)
    low = pose(root=(0.1, -0.78, 0.25), rootR=(8, -44, 0), chest=(16, -30, 0), grip=low_g,
               dir=aim(low_g, (4.0, -2.4, 7.0)), edge=(0, 0, -1), s=-1.1, sMax=-0.7, lfree=1.0,
               larm=(30, 0, -25), lfore=(40, 0, 0), lhand=(0, 0, 0),
               lf=foot(GUARD["lf"], dx=-0.1, dz=-0.1), rf=foot(GUARD["rf"], dx=0.1, dz=0.25, pitch=-10))
    load = at(low, root=(0.12, -0.84, 0.32), chest=(18, -32, 0), rf=foot(GUARD["rf"], dx=0.1, dz=0.25, pitch=-22))
    drive = at(low, root=(0.0, -0.7, -0.35), rootR=(10, -30, 0), chest=(20, -22, 0),
               grip=(1.0, -0.85, 0.35), dir=aim((1.0, -0.85, 0.35), (3.5, -2.8, 6.0)))
    hit_g = (0.35, -0.2, -1.05)
    hit = pose(root=(-0.05, -0.62, -0.3), rootR=(6, 8, 0), chest=(8, 22, -4), grip=hit_g,
               dir=unitv(-0.5, 0.48, -0.72), edge=(-0.55, 0.6, 0.55), s=-1.2, sMax=-0.7, lfree=0.0)
    follow = at(hit, chest=(4, 34, -6), grip=(0.05, 0.1, -0.85), dir=unitv(-0.8, 0.5, -0.33), edge=(-0.4, 0.4, 0.8))
    stop = at(GUARD, root=(0.05, -0.55, 0.0), chest=(10, -20, 0))
    keys = [(0.0, GUARD, "inout"), (0.35, low, "out"), (0.72, load, "inout"), (0.84, drive, "in"),
            (0.92, {"lfree": 0.0}, "inout"), (1.0, hit, "snap"), (1.16, follow, "out"), (1.45, stop, "inout"), (1.8, GUARD, "inout")]
    feet = footwork(1.8, {"rf": [(0.8, 0.98, foot(GUARD["lf"], dx=1.2, dz=-0.2, yaw=30))],
                          "lf": [(0.98, 1.14, foot(GUARD["lf"], dz=-0.4)), (1.45, 1.62, GUARD["lf"])],
                          }, start=dict(lf=foot(GUARD["lf"], dx=-0.1, dz=-0.1), rf=foot(GUARD["rf"], dx=0.1, dz=0.25)),
                    end=FEET, lift=0.38)
    feet = [k for k in feet if not ("rf" in k[1] and k[0] > 1.62)]
    feet += [(1.62, {"rf": foot(GUARD["lf"], dx=1.2, dz=-0.2, yaw=30), "_feet": True}, "linear"),
             (1.8, {"rf": GUARD["rf"], "_feet": True}, "inout")]
    return Clip(key_name("ThunderQuickstep"), 1.8, keys + feet, contacts=(1.0,), group="Resolver",
                action="ThunderQuickstep", preview=(0, 0.35, 0.72, 0.9, 1.0, 1.16, 1.45, 1.8),
                markers=[(0.35, "Charge", "Quickstep"), (0.8, "FootstepR", "Launch"), (0.84, "TrailOn", "1"),
                         (1.0, "ImpactFX", "1"), (1.0, "FootstepR", "Plant"), (1.14, "FootstepL", "Plant"),
                         (1.2, "TrailOff", "1"), (1.45, "Recovery", "")],
                timing="BossAttackCatalog Zhao.ThunderQuickstep: windup 1.0 (ShieldCharge, Motion Lunge)",
                hook="Telegraph cue -> BossAnimations.action; NEW: contact phase-locked to the cue's impact",
                wiring="needs-hook",
                notes="Lowered centre with the blade trailing low behind, rear foot loads, explosive drive (the server "
                      "carries him), rising diagonal guandao finish across the body, controlled stop. No teleport.")


def transform():
    """Oath of the Fallen: 2.0 s BossDuo cinematic state; Enrage shot 1.1 s + 0.35 s blend; Action4."""
    lowered_g = (0.95, -0.85, -0.45)
    ack = pose(root=(0.02, -0.22, 0.05), rootR=(0, -18, 0), chest=(4, -10, 0), lookW=0.0, neck=(-14, 48, 0),
               grip=lowered_g, dir=aim(lowered_g, (0.6, -3.0, -7.2)), edge=(0, 1, 0), s=-1.5)
    bow = at(ack, neck=(-24, 30, 0), chest=(10, -6, 0))
    grip_g = (0.85, -0.7, -0.5)
    tighten = pose(root=(0.05, -0.6, 0.1), rootR=(4, -24, 0), chest=(12, -18, 0), lookW=0.6, neck=(-6, 0, 0),
                   grip=grip_g, dir=aim(grip_g, (0.0, -1.4, -8.4)), edge=(0, 1, 0), s=-1.1,
                   lf=foot(GUARD["lf"], dx=-0.15, dz=-0.1), rf=foot(GUARD["rf"], dx=0.1))
    up_g = (0.55, -0.35, -0.85)
    gather = pose(root=(0.03, -0.62, 0.05), rootR=(2, -10, 0), chest=(-4, -6, 0), lookW=0.9,
                  grip=up_g, dir=unitv(-0.06, 1, 0.06), edge=(0, 0, -1), s=-0.9, sMax=-0.6,
                  lf=foot(GUARD["lf"], dx=-0.15, dz=-0.1), rf=foot(GUARD["rf"], dx=0.1))
    surge = at(gather, chest=(-7, -6, 0), root=(0.03, -0.56, 0.05))
    ready = at(GUARD, root=(0.05, -0.48, 0.08), chest=(11, -26, 0))
    keys = [(0.0, GUARD, "inout"), (0.3, ack, "inout"), (0.62, bow, "inout"), (0.95, tighten, "inout"),
            (1.25, gather, "inout"), (1.52, surge, "inout"), (1.66, at(ready, chest=(14, -24, 0)), "snap"),
            (2.0, ready, "settle")]
    return Clip(key_name("Transform"), 2.0, keys, priority="Action4", group="Resolver", action="Transform",
                preview=(0, 0.3, 0.62, 0.95, 1.25, 1.52, 1.66, 2.0),
                markers=[(0.3, "Acknowledge", "Partner"), (0.95, "Charge", "Oath"), (1.25, "OathGather", ""),
                         (1.66, "ImpactFX", "OathRelease"), (1.66, "FootstepL", "Stamp"), (2.0, "Recovery", "")],
                timing="BossDuo: Cinematic(survivor, 2); BossHandoff Enrage shot 1.1 s + Blend 0.35 s",
                hook="BossEnrage cue -> BossAnimations.action(transform); existing (Action4)",
                notes="0-0.62 head turns to the fallen partner and bows; 0.95 grip tightens, stance lowers; "
                      "1.25-1.52 guandao upright before the chest diamond, power gathers; 1.66 release into the "
                      "oath guard (seen from the gameplay camera after the 1.45 s shot+blend); ready by 2.0 s.")


def iron_charge():
    """Inherited from the Iron Bull on the oath: windup 1.5 s, contact 1.5 s (ShieldCharge, Lunge). Counter: Evade."""
    bar_g = (1.05, -0.35, -0.55)
    bar = pose(root=(0.05, -0.72, 0.2), rootR=(8, -14, 0), chest=(18, -8, 0), grip=bar_g,
               dir=unitv(-1, 0.06, -0.12), edge=(0, 0, -1), s=-2.2, sMin=-2.6, sMax=-1.4,
               lf=foot(GUARD["lf"], dx=-0.1), rf=foot(GUARD["rf"], dz=0.2, pitch=-14))
    brace = at(bar, root=(0.05, -0.8, 0.3), chest=(22, -10, 0), rf=foot(GUARD["rf"], dz=0.2, pitch=-24))
    ram = at(bar, root=(0.0, -0.66, -0.4), chest=(24, -4, 0), grip=(0.95, -0.25, -1.3), rootR=(10, -6, 0))
    keys = [(0.0, GUARD, "inout"), (0.45, bar, "inout"), (1.1, brace, "inout"), (1.3, at(bar, root=(0.02, -0.7, -0.1)), "in"),
            (1.5, ram, "snap"), (1.75, at(ram, chest=(18, -6, 0), grip=(0.95, -0.35, -1.05)), "out"),
            (2.3, GUARD, "inout")]
    feet = footwork(2.3, {"rf": [(1.22, 1.42, foot(GUARD["lf"], dx=1.25, dz=-0.15, yaw=25))],
                          "lf": [(1.42, 1.58, foot(GUARD["lf"], dz=-0.45)), (1.9, 2.1, GUARD["lf"])],
                          "_": []}, start=dict(lf=foot(GUARD["lf"], dx=-0.1), rf=foot(GUARD["rf"], dz=0.2)), end=FEET)
    feet = [k for k in feet if not ("rf" in k[1] and k[0] > 2.1)]
    feet += [(2.1, {"rf": foot(GUARD["lf"], dx=1.25, dz=-0.15, yaw=25), "_feet": True}, "linear"),
             (2.3, {"rf": GUARD["rf"], "_feet": True}, "inout")]
    return Clip(key_name("IronCharge"), 2.3, keys + feet, contacts=(1.5,), group="Resolver", action="IronCharge",
                preview=(0, 0.45, 1.1, 1.3, 1.5, 1.75, 2.3),
                markers=[(0.2, "Charge", "Iron"), (1.22, "FootstepR", "Launch"), (1.3, "TrailOn", "1"),
                         (1.5, "ImpactFX", "Iron"), (1.42, "FootstepR", "Plant"), (1.58, "FootstepL", "Plant"),
                         (1.75, "TrailOff", "1"), (1.75, "Recovery", "")],
                timing="BossAttackCatalog Bull.IronCharge: windup 1.5 (ShieldCharge, Motion Lunge), via BossDuo enrage",
                hook="Telegraph cue -> resolve(IronCharge) = GeneralZhao_P1_IronCharge; resolver key exists, needs id",
                wiring="needs-id",
                notes="The haft becomes a battering bar across the chest, wide grip; shoulders and haft lead a heavy "
                      "rush; the blade stays to his left so the silhouette remains Zhao's, not the Bull's.")


def colossal_hammer():
    """Inherited: windup 1.8 s, slam at 1.8 s; server shockwave from his position. Counter: Air Glide."""
    lift_g = (0.75, 0.55, -0.55)
    lift = pose(root=(0.03, -0.18, 0.0), rootR=(0, -14, 0), chest=(-8, -10, 0), grip=lift_g,
                dir=unitv(0.02, 1, 0.12), edge=(0, 0, -1), s=-1.0, sMax=-0.7,
                lf=foot(GUARD["lf"], dx=-0.2, dz=0.2), rf=foot(GUARD["rf"], dx=0.05, dz=-0.15))
    apex_g = (0.55, 1.05, -0.45)
    apex = at(lift, grip=apex_g, chest=(-12, -6, 0), root=(0.03, -0.1, 0.0), dir=unitv(0.0, 1, 0.18))
    slam_g = (0.45, -1.55, -0.95)
    slam = pose(root=(0.0, -1.0, -0.15), rootR=(14, -8, 0), chest=(26, -4, 0), lookW=0.7, grip=slam_g,
                dir=unitv(0.0, 1, 0.05), edge=(0, 0, -1), s=-1.0, sMax=-0.7,
                lf=foot(GUARD["lf"], dx=-0.45, dz=-0.05), rf=foot(GUARD["rf"], dx=0.25, dz=0.1))
    keys = [(0.0, GUARD, "inout"), (0.5, lift, "out"), (1.25, apex, "inout"), (1.58, at(apex, chest=(-14, -6, 0)), "inout"),
            (1.8, slam, "whip"), (2.05, at(slam, chest=(28, -4, 0)), "out"), (2.4, at(slam, root=(0.02, -0.8, -0.05), chest=(18, -8, 0)), "inout"),
            (2.8, GUARD, "inout")]
    feet = footwork(2.8, {"lf": [(1.5, 1.78, foot(GUARD["lf"], dx=-0.45, dz=-0.05))],
                          "rf": [(2.45, 2.7, GUARD["rf"])]},
                    start=dict(lf=foot(GUARD["lf"], dx=-0.2, dz=0.2), rf=foot(GUARD["rf"], dx=0.05, dz=-0.15)), end=FEET)
    feet = [k for k in feet if k[0] >= 0.5]
    feet += [(0.0, {"lf": GUARD["lf"], "rf": GUARD["rf"], "_feet": True}, "linear"),
             (0.5, {"lf": foot(GUARD["lf"], dx=-0.2, dz=0.2), "rf": foot(GUARD["rf"], dx=0.05, dz=-0.15), "_feet": True}, "inout")]
    butt_time = 1.8
    return Clip(key_name("ColossalHammer"), 2.8, keys + feet, contacts=(butt_time,), group="Resolver",
                action="ColossalHammer", ground=[(1.75, 2.45)], preview=(0, 0.5, 1.25, 1.58, 1.8, 2.05, 2.8),
                markers=[(0.4, "Charge", "IronThunder"), (1.6, "TrailOn", "1"), (1.8, "ImpactFX", "Hammer"),
                         (1.78, "FootstepL", "Stamp"), (1.9, "TrailOff", "1"), (2.4, "Recovery", "")],
                timing="BossAttackCatalog Bull.ColossalHammer: windup 1.8 (Shockwave, Speed 26, Height 7)",
                hook="Telegraph cue -> resolve(ColossalHammer); resolver key exists, needs id. The traveling wave "
                     "stays server-driven (BossHazard cue)", wiring="needs-id",
                notes="Lifts the guandao upright overhead and drives the iron-shod butt down into the stone beside "
                      "his lead foot: the contact sits at his own position, where the server's shockwave starts. "
                      "No maul is equipped.")


def core():
    base = [idle(), strike(), lightning_spear(), thunder_quickstep(), transform(), iron_charge(), colossal_hammer()]
    return base


# ------------------------------------------------------------------------------------------------ guandao moves
def melee():
    out = []
    # L1 Crescent Reap: horizontal reap right -> left, hands close for reach
    s1, a1, _, t1 = GUANDAO["Guandao_L1"]
    c, e = sec(s1), sec(s1 + a1)
    wind = pose(root=(0.06, -0.38, 0.1), rootR=(3, -40, 0), chest=(6, -40, 0), grip=(0.9, -0.45, -0.35),
                dir=yawdir(-70, 4), edge=(0, 0.2, -1), s=-0.8, sMax=-0.7)
    hit = pose(root=(0.0, -0.44, -0.12), rootR=(5, -14, 0), chest=(9, -2, 0), grip=(0.55, -0.5, -0.85),
               dir=yawdir(4, 0), edge=(-1, 0.1, 0), s=-0.8, sMax=-0.7)
    out_ = at(hit, chest=(9, 20, 0), rootR=(5, -4, 0), grip=(0.25, -0.5, -0.8), dir=yawdir(52, -2), edge=(-0.6, 0, 0.8))
    follow = at(out_, chest=(8, 30, 0), dir=yawdir(80, -6), grip=(0.1, -0.55, -0.6))
    out.append(Clip(key_name("Guandao_L1"), sec(t1), [(0, GUARD, "inout"), (0.07, wind, "out"), (c, hit, "in"),
                                                      (e, out_, "linear"), (0.31, follow, "out"), (sec(t1), GUARD, "inout")],
                    contacts=(c,), group="Melee", action="Guandao_L1", preview=(0, 0.07, c, e, 0.31, sec(t1)),
                    markers=melee_markers(c, e),
                    timing="WeaponSchema Guandao_L1 Crescent Reap: startup 9f, active 4f, total 24f (Tempo 1.4)",
                    hook="NEW: AIService BossSwing for GeneralZhao's Guandao light swings -> resolve(Guandao_L1)",
                    wiring="needs-hook", notes="Horizontal reap from his right across the front at chest height."))
    # L2 Returning Tide: backhand return left -> right, slightly rising
    s2, a2, _, t2 = GUANDAO["Guandao_L2"]
    c, e = sec(s2), sec(s2 + a2)
    wind = pose(root=(0.0, -0.4, 0.05), rootR=(3, -6, 0), chest=(6, 26, 0), grip=(0.35, -0.5, -0.95),
                dir=yawdir(70, -4), edge=(0, 0.1, -1), s=-0.8, sMax=-0.7, lfree=0.7,
                larm=(30, 0, -30), lfore=(50, 0, 0), lhand=(0, 0, 0))
    hit = pose(root=(0.04, -0.44, -0.12), rootR=(5, -20, 0), chest=(8, -6, 0), grip=(0.6, -0.4, -0.85),
               dir=yawdir(-4, 6), edge=(1, 0.1, 0), s=-0.8, sMax=-0.7, lfree=0.0)
    out_ = at(hit, chest=(6, -32, 0), rootR=(4, -30, 0), grip=(0.95, -0.3, -0.45), dir=yawdir(-55, 12), edge=(0.6, 0.2, 0.8))
    out.append(Clip(key_name("Guandao_L2"), sec(t2), [(0, GUARD, "inout"), (0.07, wind, "out"), (c, hit, "in"),
                                                      (e, out_, "linear"), (0.31, at(out_, dir=yawdir(-75, 16)), "out"),
                                                      (sec(t2), GUARD, "inout")],
                    contacts=(c,), group="Melee", action="Guandao_L2", preview=(0, 0.07, c, e, 0.31, sec(t2)),
                    markers=melee_markers(c, e),
                    timing="WeaponSchema Guandao_L2 Returning Tide: startup 9f, active 4f, total 25f (Tempo 1.4)",
                    hook="NEW: AIService BossSwing -> resolve(Guandao_L2)", wiring="needs-hook",
                    notes="Backhand return sweep from his left, rising slightly; edge turned to lead."))
    # L3 Heaven-Splitting Cleave: overhead vertical cleave
    s3, a3, _, t3 = GUANDAO["Guandao_L3"]
    c, e = sec(s3), sec(s3 + a3)
    up = pose(root=(0.04, -0.28, 0.12), rootR=(2, -24, 0), chest=(-8, -20, 0), grip=(0.8, 0.6, 0.05),
              dir=unitv(-0.05, 0.75, 0.66), edge=(0, 0.66, -0.75), s=-1.2)
    hit = pose(root=(0.0, -0.62, -0.3), rootR=(8, -16, 0), chest=(18, -10, 0), grip=(0.55, -0.35, -1.05),
               dir=unitv(-0.05, -0.12, -1), edge=(0, -1, 0.1), s=-1.3, lf=foot(GUARD["lf"], dz=-0.3))
    down = at(hit, dir=unitv(-0.05, -0.3, -1), chest=(22, -10, 0), grip=(0.55, -0.55, -0.95))
    out.append(Clip(key_name("Guandao_L3"), sec(t3), [(0, GUARD, "inout"), (0.11, up, "out"), (c, hit, "in"), (e, down, "linear"),
                                                      (0.36, at(down, chest=(20, -12, 0)), "out"), (sec(t3), GUARD, "inout")],
                    contacts=(c,), group="Melee", action="Guandao_L3", preview=(0, 0.11, c, e, 0.36, sec(t3)),
                    markers=melee_markers(c, e, 0.06, [(c, "FootstepL", "Stamp")]),
                    timing="WeaponSchema Guandao_L3 Heaven-Splitting Cleave: startup 11f, active 4f, total 31f",
                    hook="NEW: AIService BossSwing -> resolve(Guandao_L3)", wiring="needs-hook",
                    notes="Blade rises behind the head and splits straight down the centre line; front foot stamps."))
    # Heavy Green Dragon Reaping: high-right to low-left reaping arc with full-body turn (hyper armour)
    sh, ah, _, th = GUANDAO["Guandao_Heavy"]
    c, e = sec(sh), sec(sh + ah)
    wind = pose(root=(0.08, -0.36, 0.18), rootR=(2, -48, 0), chest=(-4, -46, 0), grip=(0.95, 0.35, 0.1),
                dir=unitv(0.8, 0.45, 0.4), edge=(0, -0.3, -1), s=-1.0, sMax=-0.7,
                lf=foot(GUARD["lf"], dz=0.05), rf=foot(GUARD["rf"], pitch=0))
    hold = at(wind, chest=(-6, -50, 0), root=(0.09, -0.42, 0.22))
    hit = pose(root=(0.0, -0.66, -0.2), rootR=(6, -10, 0), chest=(14, 4, 0), grip=(0.5, -0.45, -0.9),
               dir=yawdir(6, -8), edge=(-1, -0.2, 0), s=-0.9, sMax=-0.7, lf=foot(GUARD["lf"], dz=-0.35))
    out_ = at(hit, chest=(16, 26, 0), rootR=(6, 4, 0), grip=(0.2, -0.6, -0.8), dir=yawdir(55, -16), edge=(-0.6, -0.2, 0.8))
    follow = at(out_, chest=(18, 34, 0), dir=yawdir(85, -20), grip=(0.05, -0.65, -0.6))
    out.append(Clip(key_name("Guandao_Heavy"), sec(th), [(0, GUARD, "inout"), (0.2, wind, "out"), (0.31, hold, "inout"),
                                                         (c, hit, "in"), (e, out_, "linear"), (0.6, follow, "out"),
                                                         (sec(th), GUARD, "inout")],
                    contacts=(c,), group="Melee", action="Guandao_Heavy", preview=(0, 0.2, 0.31, c, e, 0.6, sec(th)),
                    markers=melee_markers(c, e, 0.08, [(0.12, "Charge", "Heavy"), (c, "FootstepL", "Stamp")]),
                    timing="WeaponSchema Guandao_Heavy Green Dragon Reaping: startup 23f, active 4f, total 50f (HyperArmor)",
                    hook="Telegraph cue (Heavy class) -> resolve(Guandao_Heavy); existing cue, needs id", wiring="needs-id",
                    notes="Blade cocked high over the right shoulder, held, then a descending reaping arc through the "
                          "front to his low left with the whole body turning; heavy follow-through."))
    # Running: Charging Dragon Thrust
    sr, ar, _, tr = GUANDAO["Guandao_Running"]
    c, e = sec(sr), sec(sr + ar)
    run_g = (1.0, -0.75, 0.3)
    start = pose(root=(0.0, -0.45, -0.2), rootR=(10, -24, 0), chest=(12, -22, 0), grip=run_g,
                 dir=aim(run_g, (0.0, -0.4, -8.8)), edge=(0, 1, 0), s=-1.8)
    thrust_g = (0.55, -0.4, -1.4)
    th_ = pose(root=(0.0, -0.74, -0.45), rootR=(8, -14, 0), chest=(14, -10, 0), grip=thrust_g,
               dir=aim(thrust_g, (0.0, 0.3, -10)), edge=(0, 1, 0), s=-0.9, sMax=-0.75,
               lf=foot(GUARD["lf"], dz=-0.75), rf=foot(GUARD["rf"], pitch=-16))
    out.append(Clip(key_name("Guandao_Running"), sec(tr), [(0, start, "inout"), (0.1, at(start, grip=(1.05, -0.75, 0.55)), "out"),
                                                           (c, th_, "snap"), (e, th_, "linear"),
                                                           (0.42, at(th_, dir=aim(thrust_g, (0, -0.8, -10))), "out"),
                                                           (sec(tr), GUARD, "inout")]
                    + footwork(sec(tr), {"lf": [(0.06, c, foot(GUARD["lf"], dz=-0.75))], "rf": [(0.44, 0.58, GUARD["rf"])]},
                               start=dict(lf=foot(GUARD["lf"], dz=0.3), rf=GUARD["rf"]), end=FEET),
                    contacts=(c,), group="Melee", action="Guandao_Running", preview=(0, 0.1, c, e, 0.42, sec(tr)),
                    markers=melee_markers(c, e, 0.08, [(c, "FootstepL", "Stamp")]),
                    timing="WeaponSchema Guandao_Running Charging Dragon Thrust: startup 13f, active 4f, total 36f",
                    hook="Telegraph cue (RunningAttack class) -> resolve(Guandao_Running); existing cue, needs id",
                    wiring="needs-id", notes="From the run: rear hand drives a long low-to-level thrust with a lunging stamp."))
    # Weapon art: Crescent Moon Cyclone, a 360 degree horizontal cyclone with a pivot step
    sa, aa, _, ta = GUANDAO["Guandao_Art"]
    c, e = sec(sa), sec(sa + aa)
    keys = [(0, GUARD, "inout")]
    coil = pose(root=(0.05, -0.55, 0.15), rootR=(4, -60, 0), chest=(8, -50, 0), grip=(1.0, -0.4, -0.5),
                dir=yawdir(-120, 2), edge=(0.3, 0, -1), s=-0.8, sMax=-0.7, lfree=0.8,
                larm=(70, 0, -60), lfore=(10, 0, 0), lhand=(0, 0, 0))
    keys.append((0.22, coil, "out"))
    spin = [(0.22, -120), (c, 0), (c + 0.06, 60), (c + 0.12, 120), (e, 240)]
    for t, ang in spin[1:]:
        body = ang * 0.75 - 30
        keys.append((t, pose(root=(0.0, -0.6, -0.05), rootR=(5, body, 0), chest=(8, ang * 0.25, 0),
                             grip=(0.9, -0.3, -0.75), dir=yawdir(ang + 4, 2), edge=tuple(rig.ry(ang) @ np.array([-1.0, 0, 0])),
                             s=-0.8, sMax=-0.7, lfree=1.0, larm=(70, 0, -60), lfore=(10, 0, 0), lhand=(0, 0, 0)),
                     "linear" if t > c else "in"))
    keys += [(0.68, pose(root=(0.03, -0.55, 0.05), rootR=(4, 210, 0), chest=(8, 90, 0), grip=(0.65, -0.55, -0.6),
                         dir=yawdir(330, -4), edge=(0, 1, 0), s=-1.1, lfree=0.5, larm=(70, 0, -60), lfore=(10, 0, 0)), "out")]
    keys += [(sec(ta), GUARD, "inout")]
    # spin on the lead foot drawn in under the hips; the rear foot leaves the ground and orbits, then replants
    body_turn = lambda t: float(np.interp(t, [0, 0.22, c, e, 0.68, sec(ta)], [0, -30, -30, 150, 240, 330]))  # noqa: E731
    pivot = (-0.25, -0.25)
    feet = []
    for i in range(int(round(sec(ta) * 60)) + 1):
        t = i / 60
        rel = body_turn(t) + 30 if t < sec(ta) - 1e-6 else 360.0
        if t <= 0.12:
            w = t / 0.12
            lf = (GUARD["lf"][0] + (pivot[0] - GUARD["lf"][0]) * w, GUARD["lf"][1] + (pivot[1] - GUARD["lf"][1]) * w,
                  0.2 * math.sin(math.pi * w), GUARD["lf"][3], 0.0)
        elif t >= 0.78:
            w = (t - 0.78) / (sec(ta) - 0.78)
            lf = (pivot[0] + (GUARD["lf"][0] - pivot[0]) * w, pivot[1] + (GUARD["lf"][1] - pivot[1]) * w,
                  0.2 * math.sin(math.pi * w), GUARD["lf"][3], 0.0)
        else:
            lf = (pivot[0], pivot[1], 0.0, GUARD["lf"][3] + rel, -8 if 0.22 < t < 0.7 else 0.0)
        r = rig.ry(rel) @ np.array([0.8, 0, 0.55])
        air = 0.22 < t < 0.74
        rf_air = 0.3 * math.sin(math.pi * min(1.0, max(0.0, (t - 0.22) / 0.52)))
        rf = (float(r[0]), float(r[2]), rf_air if air else 0.0, GUARD["rf"][3] + rel, -12 if air else 0.0)
        if t >= 0.78:
            w = (t - 0.78) / (sec(ta) - 0.78)
            r0 = rig.ry(360.0) @ np.array([0.8, 0, 0.55])
            rf = (float(r0[0] + (GUARD["rf"][0] - r0[0]) * w), float(r0[2] + (GUARD["rf"][1] - r0[2]) * w),
                  0.18 * math.sin(math.pi * w), GUARD["rf"][3], 0.0)
        feet.append((t, {"_feet": True, "lf": lf, "rf": rf}, "linear"))
    out.append(Clip(key_name("Guandao_Art"), sec(ta), [(t, at(p, rootR=(p["rootR"][0], p["rootR"][1] - 0, 0)), es) for t, p, es in keys] + feet,
                    contacts=(c,), group="Melee", action="Guandao_Art", preview=(0, 0.22, c, c + 0.12, e, 0.68, sec(ta)),
                    markers=melee_markers(c, e, 0.1, [(0.05, "Charge", "Art"), (0.3, "FootstepR", "Pivot"), (0.75, "FootstepR", "Plant")]),
                    timing="WeaponSchema Guandao_Art Crescent Moon Cyclone: startup 19f, active 11f, total 54f, Arc 360",
                    hook="Telegraph cue (WeaponArt class) -> resolve(Guandao_Art); existing cue, needs id", wiring="needs-id",
                    notes="Coils left, then a full horizontal cyclone at chest height pivoting on the lead foot; the "
                          "active window covers the turn from the front through his right side. Feet pivot with the "
                          "hips (in-place spin)."))
    return out


def library():
    from states import states  # noqa: E402  (locomotion, guard, reactions, intro, death)
    base = core() + melee()
    st = states()
    oath_set = [c for c in base + st if c.action in OATH_VARIANTS]
    return base + st + [oath(c, c.action) for c in oath_set]


OATH_VARIANTS = {"Idle", "Strike", "LightningSpear", "ThunderQuickstep", "Guandao_L1", "Guandao_L2", "Guandao_L3",
                 "Guandao_Heavy", "Guandao_Running", "Guandao_Art", "WalkForward", "RunForward", "GuardLoop"}


def manifest_header():
    return {
        "boss": "GeneralZhao", "look_key": LOOK, "rig": "R15 (AnimationConstraint joints, measured live), template scale 1",
        "runtime_scale": rig.BOSS_SCALE, "fps_baked": FPS, "space": "HumanoidRootPart, +X right +Y up -Z forward",
        "weapon_binding": "LooksDuelists RightHand pieces; tip 9.40 studs from the RightHand centre at scale 1 "
                          "(target 9.2 +/- 0.5); animation never moves the binding",
        "in_place": "Root translation only shifts weight and height; the server owns all travel and facing",
        "upload_status": "No clip is uploaded. Every asset_id is null until a genuine published id exists.",
    }
