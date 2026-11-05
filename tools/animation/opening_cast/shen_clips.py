"""Grandmaster Shen's clip library on both supplied sculpts (shen_lib.py). The guandao is the weapon he was modelled with, so both forms fight with the Guandao family and true two-handed polearm work.

Phase 1 is unsettling control: planted heel-to-toe footwork, shoulders quiet until the release, economical cuts. Phase 2 is the same technique corrupted (Clip.corrupt): lower, forward, wound further, heavier recovery.
Timing comes from BossAttackCatalog (windups, repeats) and WeaponSchema via the boss-shared Guandao contacts; contact = the server's first active frame or impact. Attacks that sweep travel left to right because StrikeGeometry fans the server's blow that way.
"""
import math

import numpy as np

import shen_lib as L
from shen_lib import Clip, check_rigs, validate, write_rbxmx  # noqa: F401  (export.py takes these from the set's module)

RIGS = {1: L.Rig(1), 2: L.Rig(2)}
REVEAL = 0.9      # WorldDefinitions Transition.Reveal: the phase 1 clip reaches the handoff pose here and holds; phase 2 starts from it
MELEE = {  # Rules.Contacts: the boss-shared Guandao times. (length, contact, active, arc, reach, lunge)
    "Guandao_L1": (0.4, 0.15, 0.067, 120, 10.5, 1.0), "Guandao_L2": (0.4167, 0.15, 0.067, 120, 10.5, 1.0), "Guandao_L3": (0.5167, 0.183, 0.067, 30, 11.0, 2.0),
    "Guandao_Heavy": (0.8333, 0.383, 0.067, 160, 12.0, 2.0), "Guandao_Running": (0.6, 0.217, 0.083, 15, 12.5, 8.0), "Guandao_Art": (0.9, 0.317, 0.2, 360, 11.5, 1.5),
}


def H(yaw, pitch=0.0):
    y, p = math.radians(yaw), math.radians(pitch)
    return (math.sin(y) * math.cos(p), math.sin(p), -math.cos(y) * math.cos(p))


def SIDE(yaw):
    y = math.radians(yaw)
    return (math.cos(y), 0.0, math.sin(y))


def AIM(yaw, pitch=0.0, ext=1.72):
    """Fist from shoulder along a direction; the haft continues the arm's line, the cutting edge turned into a rightward sweep."""
    d = H(yaw, pitch)
    return dict(rh=tuple(ext * v for v in d), haft=H(yaw, pitch), face=SIDE(yaw))


def SAG(e, x=0.0, ext=None, off=(0.0, 0.0, 0.0)):
    """A vertical swing: elevation e degrees from straight ahead toward up; the cutting edge turned down the swing."""
    c, s = math.cos(math.radians(e)), math.sin(math.radians(e))
    out = dict(haft=(x, s, -c), face=(0.0, -c, -s))
    if ext is not None:
        out["rh"] = (x * ext + off[0], s * ext + off[1], -c * ext + off[2])
    return out


def K(t, ease="io", **kw):
    return (t, kw, ease)


def build(phase):
    rg = RIGS[phase]
    P = "GrandmasterShen_P%d_" % phase
    rest = rg.REST
    READY = dict(pel=(0, -0.04, 0), pelR=(0, 0, 0), chest=(0, 0, 0), neck=(0, 0, 0), rf=(0, 0, 0, 0, 0), lf=(0, 0, 0, 0, 0), lua=(0, 0, 0), lfa=(0, 0, 0), lha=(0, 0, 0), lhw=0.0, ltw=0.0, rgw=0.0, lsl=-1.1,
                 rh=rest["rh"], haft=rest["haft"], face=rest["face"], relb=rest["relb"], rknee=rest["rknee"], lknee=rest["lknee"], lelb=rest["lelb"])
    GUARD = dict(pel=(0.0, -0.3, 0.06), pelR=(4, 14, 0), chest=(6, 16, 0), neck=(-6, -14, 0), rf=(0.0, -0.32, 0, 6, 0), lf=(0.0, 0.26, 0, -6, 0), lhw=1.0, lsl=-1.35,
                 rh=(-0.62, -0.72, -0.82), haft=H(-25, 34), face=(0.3, 0.5, -0.8), relb=(0.8, -0.5, 0.2), lelb=(-0.8, -0.6, 0.1))
    TWO = dict(lhw=1.0, lelb=(-0.6, -0.7, 0.3))

    def melee(name, keys, notes, feet_free=()):
        length, contact, active, arc, reach, lunge = MELEE[name]
        return Clip(rg, P + name, length, keys, contacts=[contact], move=name, notes=notes, active=(contact, active, arc, reach, lunge), feet_free=feet_free)

    def melee_pivot(name, keys, notes, feet_free=()):
        c = melee(name, keys, notes, feet_free)
        c.authored_feet = True
        return c

    # ---------------------------------------------------------------- ordinary guandao swings
    def crescent_reap():
        return melee("Guandao_L1", [
            K(0, **READY),
            K(0.08, "out", pel=(-0.04, -0.2, 0.1), pelR=(2, 22, 0), chest=(4, 28, 0), neck=(-2, -26, 0), relb=(0.25, -0.5, 0.8), rh=(-1.45, -0.1, -0.6), haft=H(-122, 4), face=SIDE(-122), lhw=0.5, lsl=-1.1),
            K(0.15, "whip", pel=(-0.08, -0.4, -0.72), pelR=(7, 16, 0), chest=(7, 20, 0), neck=(-4, -22, 0), rf=(-0.2, -0.85, 0, -8, 0), relb=(0.2, -0.75, 0.6), lhw=1.0, **AIM(-60, -2)),
            K(0.217, "lin", pel=(0.06, -0.44, -0.86), pelR=(8, -14, 0), chest=(8, -30, 0), neck=(-4, 22, 0), rf=(-0.2, -0.85, 0, -8, 0), relb=(0.2, -0.9, 0.35), **AIM(24, -3)),
            K(0.3, "out", pel=(0.06, -0.38, -0.66), pelR=(5, -22, 0), chest=(5, -40, 0), neck=(-2, 26, 0), relb=(0.1, -0.9, -0.2), lhw=0.1, **AIM(98, -8, 1.6)),
            K(0.4, "io", **READY),
        ], "Crescent Reap: a short backhand with the lead hand, the rear hand driving off the hip: left to right across the server's 120 degree fan.")

    def returning_tide():
        return melee("Guandao_L2", [
            K(0, **READY),
            K(0.08, "out", pel=(0.04, -0.3, 0.05), pelR=(3, 28, 0), chest=(2, 26, 0), neck=(0, -24, 0), relb=(0.3, -0.7, 0.6), rh=(-1.3, -0.5, -0.55), haft=H(-118, -12), face=SIDE(-118), lhw=0.6, lsl=-1.0),
            K(0.15, "whip", pel=(-0.02, -0.34, -0.7), pelR=(4, 12, 0), chest=(2, 14, 0), neck=(-2, -14, 0), lf=(0.02, -0.72, 0, 6, 0), relb=(0.2, -0.8, 0.5), lhw=1.0, **AIM(-58, 7)),
            K(0.217, "lin", pel=(0.05, -0.28, -0.84), pelR=(1, -16, 0), chest=(-2, -30, 0), neck=(0, 24, 0), lf=(0.02, -0.72, 0, 6, 0), relb=(0.2, -0.9, 0.3), **AIM(26, 14)),
            K(0.3, "out", pel=(0.06, -0.24, -0.62), pelR=(-1, -22, 0), chest=(-5, -38, 0), neck=(2, 26, 0), lhw=0.2, relb=(0.1, -0.8, -0.2), **AIM(96, 22, 1.6)),
            K(0.4167, "io", **READY),
        ], "Returning Tide: the same technique rising, off a left step; the blade climbs through the fan.")

    def heaven_cleave():
        return melee("Guandao_L3", [
            K(0, **READY),
            K(0.045, "io", rh=(0.62, -0.5, -0.95), haft=H(4, 10), face=(0.05, -0.2, -0.98), lhw=0.4),
            K(0.1, "out", pel=(0.02, -0.1, 0.18), pelR=(-7, 6, 0), chest=(-11, 10, 0), neck=(7, -8, 0), relb=(0.9, 0.2, 0.3), rh=(0.34, 1.25, 0.1), lhw=0.8, lsl=-1.2, **SAG(112, -0.22)),
            K(0.15, "in", pel=(0, -0.3, -0.45), rh=(0.12, 0.8, -1.2), lhw=0.5, **SAG(66, -0.12)),
            K(0.183, "whip", pel=(0, -0.48, -0.95), pelR=(10, -2, 0), chest=(15, -5, 0), neck=(-9, 3, 0), rf=(-0.08, -1.0, 0, -4, 0), relb=(0.8, -0.3, 0.45), rh=(-0.12, -0.15, -1.62), lhw=1.0, **SAG(12, -0.06)),
            K(0.25, "lin", pel=(0, -0.66, -1.05), pelR=(15, -3, 0), chest=(20, -6, 0), neck=(-14, 4, 0), rf=(-0.08, -1.0, 0, -4, 0), rh=(-0.05, -0.6, -1.52), **SAG(-18, 0.0)),
            K(0.36, "out", pel=(0, -0.7, -1.0), pelR=(16, -3, 0), chest=(21, -6, 0), rf=(-0.08, -1.0, 0, -4, 0), rh=(-0.05, -0.68, -1.45), **SAG(-22, 0.0)),
            K(0.5167, "io", **READY),
        ], "Heaven-Splitting Cleave: up over the head, a long step and a straight two-handed drop down the server's 30 degree line.")

    def green_dragon():
        return melee("Guandao_Heavy", [
            K(0, **READY),
            K(0.1, "io", rh=(-0.5, -0.45, -1.2), haft=H(-70, 8), face=SIDE(-70), lhw=0.3, relb=(0.4, -0.5, 0.6)),
            K(0.2, "out", pel=(0.05, -0.32, 0.22), pelR=(0, 36, 0), chest=(-3, 42, 0), neck=(2, -38, 0), relb=(0.1, 0.1, 0.9), rh=(-1.25, 0.25, 0.7), haft=H(-160, 16), face=SIDE(-160), lhw=0.7, lsl=-1.3),
            K(0.32, "io", pel=(0.07, -0.34, 0.28), pelR=(-1, 42, 0), chest=(-5, 50, 0), neck=(3, -44, 0), relb=(0.1, 0.15, 0.9), rh=(-1.2, 0.3, 0.8), haft=H(-168, 18), face=SIDE(-168), lhw=0.7, lsl=-1.3),
            K(0.383, "whip", pel=(-0.1, -0.56, -0.95), pelR=(11, 22, 0), chest=(11, 26, 0), neck=(-7, -22, 0), rf=(-0.25, -1.1, 0, -10, 0), relb=(0.2, -0.75, 0.6), lhw=1.0, **AIM(-78, -3)),
            K(0.45, "lin", pel=(0.06, -0.6, -1.08), pelR=(13, -8, 0), chest=(14, -24, 0), neck=(-8, 18, 0), rf=(-0.25, -1.1, 0, -10, 0), relb=(0.2, -0.9, 0.3), **AIM(6, -5)),
            K(0.56, "out", pel=(0.1, -0.62, -1.0), pelR=(15, -24, 0), chest=(16, -46, 0), neck=(-8, 30, 0), rf=(-0.25, -1.1, 0, -10, 0), relb=(0.1, -0.9, -0.25), lhw=0.15, **AIM(92, -10, 1.62)),
            K(0.7, "io", pel=(0.03, -0.32, -0.45), pelR=(5, -6, 0), chest=(5, -10, 0), neck=(-3, 6, 0), rf=(-0.1, -0.45, 0, -4, 0), rh=(0.75, -1.25, -0.72), haft=H(55, -40), face=SIDE(55), relb=rest["relb"], lhw=0.0),
            K(0.8333, "io", **READY),
        ], "Green Dragon Reaping: loads until his back shows, then the whole body drives the blade through 160 degrees and carries his weight past it.")

    def charging_thrust():
        start = dict(pel=(-0.04, -0.28, 0.0), pelR=(12, 8, 0), chest=(10, 12, 0), neck=(-12, -10, 0), rh=(0.16, -0.92, -0.62), haft=H(-4, 6), face=(0, -1, 0), relb=(0.8, -0.3, 0.5), lhw=1.0, lsl=-1.1, rf=(0, -0.45, 0, 0, 0), lf=(0, 0.45, 0.22, 0, 0), lelb=(-0.6, -0.7, 0.3))
        return melee("Guandao_Running", [
            K(0, "lin", **start),
            K(0.11, "io", pel=(-0.05, -0.3, -0.3), rh=(0.16, -0.94, -0.55), lsl=-0.8, rf=(0, 0.05, 0, 0, 0), lf=(0, -0.4, 0.4, 0, 0)),
            K(0.217, "whip", pel=(-0.06, -0.5, -1.25), pelR=(15, 10, 0), chest=(13, 16, 0), neck=(-14, -14, 0), rh=(0.2, -0.85, -1.42), haft=H(-3, 6), lsl=-2.0, rf=(0, -0.2, 0, 0, 0), lf=(-0.05, -1.4, 0, 0, 0)),
            K(0.3, "out", pel=(-0.06, -0.52, -1.42), rh=(0.2, -0.85, -1.5), lsl=-2.1, rf=(0, -0.45, 0.25, 0, 0), lf=(-0.05, -1.4, 0, 0, 0)),
            K(0.45, "io", pel=(-0.04, -0.34, -0.75), pelR=(6, 8, 0), chest=(5, 12, 0), neck=(-5, -8, 0), rh=(0.5, -1.15, -0.8), haft=H(6, -22), face=(0.1, -0.9, 0.3), lhw=0.3, rf=(0, -0.65, 0, 0, 0), lf=(0, -0.72, 0, 0, 0)),
            K(0.6, "io", **READY),
        ], "Charging Dragon Thrust: out of the run, the haft sliding through the rear hand into a straight line down the server's lunge.", feet_free=[(0, 0.6)])

    def cyclone():
        def spin(a, extra=None):
            RA, LA = L.ry(math.radians(a)) @ rg.LEGS["Right"]["ankle"] - rg.LEGS["Right"]["ankle"], L.ry(math.radians(a)) @ rg.LEGS["Left"]["ankle"] - rg.LEGS["Left"]["ankle"]
            d = dict(pelR=(5, a, 0), rf=(RA[0], RA[2], 0, a, 0), lf=(LA[0], LA[2], 0, a, 0))
            d.update(extra or {})
            return d

        def lean(yaw):
            d = H(yaw)
            return (d[0] * 0.7, -0.5, d[2] * 0.7)
        return melee_pivot("Guandao_Art", [
            K(0, **READY),
            K(0.2, "out", pel=(0.02, -0.42, 0.12), chest=(4, 28, 0), neck=(-2, -24, 0), lhw=0.8, lsl=-1.4, relb=(0.3, -0.6, 0.7), **spin(40), rh=(-1.3, -0.2, 0.55), haft=H(-150, 4), face=SIDE(-150)),
            K(0.317, "whip", pel=lean(-52), chest=(6, 20, 0), neck=(-3, -14, 0), lhw=1.0, relb=(0.2, -0.85, 0.5), **spin(0), **AIM(-52, -2)),
            K(0.4, "lin", pel=lean(38), chest=(6, -4, 0), lhw=0.6, **spin(-30), **AIM(38, -2)),
            K(0.46, "lin", pel=lean(128), chest=(6, -4, 0), **spin(-120), **AIM(128, -2)),
            K(0.52, "lin", pel=lean(218), chest=(6, -4, 0), **spin(-210), **AIM(218, -2)),
            K(0.62, "out", pel=(0, -0.46, -0.2), chest=(5, -2, 0), neck=(-2, 0, 0), lhw=0.5, **spin(-282), **AIM(290, -6, 1.6)),
            K(0.78, "io", pel=(0, -0.2, -0.05), chest=(2, 0, 0), neck=(0, 0, 0), lhw=0.0, **spin(-360), rh=rest["rh"], haft=rest["haft"], face=rest["face"], relb=rest["relb"]),
            K(0.9, "io", pel=READY["pel"], chest=(0, 0, 0), **spin(-360)),
        ], "Crescent Moon Cyclone: the body pivots a full turn on the balls of the feet with the blade at the end of both arms; the server's 360 degree blow.", feet_free=[(0, 0.9)])  # noqa

    def strike():
        return Clip(rg, P + "Strike", 1.1, [
            K(0, **READY),
            K(0.13, "io", rh=(0.62, -0.5, -0.95), haft=H(4, 10), face=(0.05, -0.2, -0.98), lhw=0.4),
            K(0.3, "out", pel=(0.02, -0.08, 0.14), pelR=(-6, 7, 0), chest=(-9, 11, 0), neck=(6, -9, 0), relb=(0.9, 0.2, 0.3), rh=(0.34, 1.23, 0.1), lhw=0.8, lsl=-1.2, **SAG(110, -0.22)),
            K(0.42, "in", pel=(0, -0.24, -0.35), rh=(0.12, 0.8, -1.2), lhw=0.5, **SAG(66, -0.12)),
            K(0.5, "whip", pel=(0, -0.42, -0.8), pelR=(10, -3, 0), chest=(15, -6, 0), neck=(-9, 4, 0), rf=(-0.08, -0.88, 0, -4, 0), relb=(0.8, -0.3, 0.45), rh=(-0.12, -0.15, -1.62), lhw=1.0, **SAG(10, -0.06)),
            K(0.62, "lin", pel=(0, -0.6, -0.92), pelR=(15, -3, 0), chest=(19, -6, 0), neck=(-14, 4, 0), rf=(-0.08, -0.88, 0, -4, 0), rh=(-0.05, -0.6, -1.5), **SAG(-20, 0.0)),
            K(0.86, "io", pel=(0, -0.3, -0.45), pelR=(5, -1, 0), chest=(7, -2, 0), neck=(-4, 1, 0), rf=(-0.04, -0.42, 0, -2, 0), rh=(0.55, -1.25, -0.6), haft=H(30, -42), face=(0, -0.8, -0.5), lhw=0.0),
            K(1.1, "io", **READY),
        ], contacts=[0.5], move="Strike", notes="Fallback overhead cut for any move without its own slot.")

    # ---------------------------------------------------------------- signature attacks
    def flowing_thrust():
        def thrust(t, low, step, head=0.0):
            return K(t, "whip", pel=(-0.05, -0.44, -0.72 - step * 0.2), pelR=(11, 13, 0), chest=(10, 26, 0), neck=(-9 + head, -22, 0), relb=(0.75, -0.45, 0.35), rh=(0.02, low, -1.46), haft=H(-3, 7 + head * 0.5), face=(0, -1, 0), lsl=-2.0, rf=(-0.08, -0.72 - step, 0, -4, 0), lf=(0, 0.05, 0, 0, 0))

        def recoil(t, step):
            return K(t, "out", pel=(-0.02, -0.32, -0.34 - step * 0.2), pelR=(5, 20, 0), chest=(3, 30, 0), neck=(-3, -26, 0), relb=(0.7, -0.2, 0.65), rh=(0.12, -0.78, -0.72), haft=H(-4, 5), face=(0, -1, 0), lsl=-1.0, rf=(-0.08, -0.42 - step, 0, -2, 0), lf=(0, 0.05, 0, 0, 0))
        return Clip(rg, P + "FlowingJian", 3.5, [
            K(0, **READY),
            K(0.4, "out", pel=(-0.02, -0.26, 0.12), pelR=(3, 22, 0), chest=(2, 32, 0), neck=(-2, -28, 0), relb=(0.7, -0.2, 0.65), rh=(0.14, -0.8, -0.6), haft=H(-4, 5), face=(0, -1, 0), lhw=1.0, lsl=-0.9, rf=(0, -0.1, 0, 0, 0), lf=(0, 0.05, 0, 0, 0), lelb=(-0.6, -0.7, 0.3)),
            K(0.62, "io", pel=(-0.01, -0.3, 0.18), rh=(0.14, -0.78, -0.48), lsl=-0.8),
            thrust(0.8, -0.82, 0.0), recoil(1.12, 0.0),
            K(1.3, "io", rh=(0.12, -0.66, -0.66), lsl=-0.9),
            thrust(1.45, -0.62, 0.08, 2.0), recoil(1.77, 0.08),
            K(1.95, "io", rh=(0.12, -0.88, -0.66), lsl=-0.9),
            thrust(2.1, -0.92, 0.14, -2.0), recoil(2.42, 0.14),
            K(2.6, "io", rh=(0.12, -0.62, -0.62), lsl=-0.8),
            thrust(2.75, -0.54, 0.28, 4.0),
            K(2.95, "out", rh=(0.14, -0.62, -1.5), pel=(-0.05, -0.46, -0.84)),
            K(3.06, "io", rh=(0.42, -1.0, -1.15), haft=H(14, -14), face=(0, -0.9, -0.3)),
            K(3.2, "io", pel=(-0.02, -0.2, -0.3), pelR=(3, 6, 0), chest=(3, 10, 0), neck=(-2, -8, 0), rh=(0.45, -1.25, -0.72), haft=H(28, -38), face=(0, -0.8, -0.5), lhw=0.0, rf=(-0.04, -0.3, 0, 0, 0)),
            K(3.5, "io", **READY),
        ], contacts=[0.8, 1.45, 2.1, 2.75], move="FlowingJian", feet_free=[(0, 0.9)], notes="Four straight polearm thrusts from the hip on the server's pulses (0.8, then every 0.65): recoil, a planted counter-step, and the haft sliding through the free hand each time. Stable id FlowingJian; displayed as Flowing Glaive.")

    def prayer_beads():
        gather = dict(ltw=1.0, lt=(0.72, 0.1, -0.5), lelb=(-0.8, -0.5, 0.3))
        return Clip(rg, P + "PrayerBeads", 2.1, [
            K(0, **READY),
            K(0.35, "io", pel=(0.0, -0.1, 0.08), pelR=(-1, -5, 0), chest=(-2, -8, 0), neck=(4, 6, 0), **gather),
            K(0.75, "io", pel=(0.02, -0.08, 0.14), pelR=(-3, -12, 0), chest=(-6, -18, 0), neck=(-3, 14, 0), ltw=1.0, lt=(-0.5, 0.95, -0.82), lelb=(-0.9, -0.4, -0.2)),
            K(1.02, "in", pel=(0.02, -0.1, 0.18), pelR=(-4, -16, 0), chest=(-8, -24, 0), neck=(-5, 18, 0), lt=(-0.45, 1.15, -0.5)),
            K(1.1, "whip", pel=(-0.02, -0.24, -0.2), pelR=(5, 6, 0), chest=(9, 10, 0), neck=(-5, -6, 0), lt=(0.1, 0.5, -1.46), lf=(0.02, -0.28, 0, 0, 0)),
            K(1.32, "out", pel=(-0.02, -0.24, -0.26), pelR=(6, 8, 0), chest=(11, 12, 0), lt=(0.1, 0.1, -1.46)),
            K(1.7, "io", pel=(0, -0.1, -0.1), pelR=(2, 2, 0), chest=(3, 3, 0), neck=(-2, -2, 0), ltw=0.0, lf=(0, -0.1, 0, 0, 0)),
            K(2.1, "io", **READY),
        ], contacts=[1.1], move="PrayerBeads", notes="The glaive stays planted in the right hand; the left gathers seven beads off the necklace into a crescent, draws them overhead and flings them on the server's release.")

    def abbot_sweep():
        return Clip(rg, P + "AbbotSweep", 1.95, [
            K(0, **READY),
            K(0.55, "io", pel=(0.1, -0.5, 0.25), pelR=(4, 34, 0), chest=(3, 38, 0), neck=(0, -34, 0), relb=(0.2, -0.7, 0.7), rh=(-1.25, -0.95, 0.5), haft=H(-150, -24), face=SIDE(-150), lhw=0.8, lsl=-1.25, lf=(0.02, 0.15, 0, 10, 0), lelb=(-0.6, -0.7, 0.3)),
            K(0.88, "io", pel=(0.12, -0.6, 0.3), pelR=(5, 40, 0), chest=(4, 46, 0), neck=(0, -40, 0), rh=(-1.2, -1.02, 0.56), haft=H(-158, -26), face=SIDE(-158)),
            K(1.0, "whip", pel=(-0.02, -0.74, -0.5), pelR=(10, 20, 0), chest=(9, 22, 0), neck=(-4, -18, 0), rf=(-0.2, -0.65, 0, -10, 0), relb=(0.2, -0.85, 0.55), lhw=1.0, **AIM(-92, -27)),
            K(1.1, "lin", pel=(0.08, -0.78, -0.62), pelR=(12, -8, 0), chest=(11, -26, 0), neck=(-5, 18, 0), rf=(-0.2, -0.65, 0, -10, 0), relb=(0.2, -0.9, 0.3), **AIM(-2, -28)),
            K(1.22, "lin", pel=(0.14, -0.78, -0.58), pelR=(13, -28, 0), chest=(12, -50, 0), neck=(-5, 32, 0), rf=(-0.2, -0.65, 0, -10, 0), relb=(0.1, -0.9, -0.2), lhw=0.4, **AIM(82, -26, 1.65)),
            K(1.4, "out", pel=(0.16, -0.72, -0.5), pelR=(12, -36, 0), chest=(10, -60, 0), neck=(-3, 36, 0), rf=(-0.2, -0.65, 0, -10, 0), lhw=0.0, **AIM(135, -18, 1.55)),
            K(1.7, "io", pel=(0.04, -0.3, -0.2), pelR=(4, -10, 0), chest=(3, -14, 0), neck=(-2, 8, 0), rf=(-0.08, -0.26, 0, -4, 0), rh=(0.75, -1.25, -0.5), haft=H(60, -38), face=SIDE(60), relb=rest["relb"]),
            K(1.95, "io", **READY),
        ], contacts=[1.0], move="AbbotSweep", notes="Abbot's Sweep: the weight sinks into the hip, then a wide low arc at shin height with a committed follow-through; jump it.")

    def blood_wave():
        return Clip(rg, P + "BloodWave", 2.15, [
            K(0, **READY),
            K(0.3, "io", pel=(0.02, -0.5, 0.05), pelR=(8, 24, 0), chest=(14, 26, 0), neck=(-14, -22, 0), relb=(0.2, -0.8, 0.5), rh=(-1.05, -1.05, -0.72), haft=H(-112, -36), face=SIDE(-112), lhw=0.4, lsl=-1.2, lelb=(-0.6, -0.7, 0.3)),
            K(0.75, "io", pel=(0.0, -0.62, -0.25), pelR=(11, 6, 0), chest=(17, 6, 0), neck=(-16, -4, 0), rf=(-0.1, -0.35, 0, -4, 0), relb=(0.2, -0.85, 0.5), rh=(-0.5, -1.25, -1.05), haft=H(-30, -40), face=SIDE(-30), lhw=0.8),
            K(1.0, "in", pel=(-0.02, -0.68, -0.42), pelR=(13, -8, 0), chest=(19, -18, 0), neck=(-18, 12, 0), rf=(-0.1, -0.5, 0, -4, 0), relb=(0.15, -0.9, 0.4), rh=(0.35, -1.28, -1.05), haft=H(22, -40), face=SIDE(22), lhw=1.0),
            K(1.1, "whip", pel=(-0.04, -0.34, -0.72), pelR=(0, -16, 0), chest=(-8, -22, 0), neck=(6, 24, 0), rf=(-0.1, -0.65, 0, -4, 0), relb=(0.1, -0.8, -0.1), rh=(0.94, -0.15, -1.29), haft=H(88, 4), face=(0.5, 0.8, -0.3), lhw=0.4),
            K(1.3, "out", pel=(-0.04, -0.3, -0.72), pelR=(-3, -18, 0), chest=(-12, -26, 0), neck=(10, 26, 0), rh=(1.1, 0.35, -1.24), haft=H(92, 22), face=(0.4, 0.9, -0.2), lhw=0.0, relb=(0.1, -0.7, -0.3)),
            K(1.5, "io", pelR=(2, -14, 0), chest=(-2, -14, 0), rh=(0.72, -0.55, -1.42), haft=H(82, -8), face=(0.3, 0.7, -0.6)),
            K(1.62, "io", rh=(0.72, -1.1, -1.05), haft=H(45, -52), face=(0.2, 0.2, -0.9)),
            K(1.75, "io", pel=(0.0, -0.38, -0.3), pelR=(6, -8, 0), chest=(9, -12, 0), neck=(-6, 8, 0), rf=(-0.04, -0.25, 0, -2, 0), rh=rest["rh"], haft=rest["haft"], face=rest["face"], relb=rest["relb"]),
            K(2.15, "io", **READY),
        ], contacts=[1.1], move="BloodWave", scrape=True, notes="The glaive's edge scrapes the floor from his left to his front, the chest and arms hauling it, then whips up and casts the low wave on the server's start.")

    def skyfall():
        return Clip(rg, P + "GuandaoSkyfall", 2.6, [
            K(0, **READY),
            K(0.14, "snap", pel=(0, -0.55, 0.1), pelR=(14, 14, 0), chest=(18, 18, 0), neck=(-14, -14, 0), relb=(0.6, -0.4, 0.5), rh=(-0.8, -0.9, 0.45), haft=H(-140, -30), face=SIDE(-140), lhw=0.8, lsl=-1.2, rf=(0, 0, 0, 0, 0), lf=(0, 0, 0, 0, 0)),
            K(0.25, "io", rh=(0.25, -0.1, -1.1), haft=H(-20, 62), face=(0.0, -0.5, -0.8), relb=(0.8, -0.3, 0.4), lhw=0.45),
            K(0.42, "out", pel=(0, -0.05, 0.1), pelR=(-14, 8, 0), chest=(-18, 10, 0), neck=(12, -8, 0), relb=(0.9, 0.3, 0.2), rh=(0.15, 1.2, 0.35), lhw=1.0, lsl=-1.3, rf=(0.05, 0.4, 0.75, 0, -35), lf=(-0.05, 0.62, 1.05, 0, -45), rknee=(0.3, 0.1, -1), lknee=(-0.3, 0.1, -1), **SAG(135, 0.05)),
            K(0.78, "io", pel=(0, 0.02, 0.1), pelR=(-20, 6, 0), chest=(-24, 8, 0), neck=(18, -6, 0), rh=(0.15, 1.3, 0.48), rf=(0.05, 0.25, 1.1, 0, -40), lf=(-0.05, 0.5, 1.35, 0, -50), **SAG(158, 0.05)),
            K(1.2, "io", pel=(0, -0.02, 0.0), pelR=(-8, 2, 0), chest=(-12, 4, 0), neck=(4, -2, 0), rh=(0.1, 1.3, 0.22), rf=(0.03, -0.1, 0.72, 0, -18), lf=(-0.03, 0.1, 0.8, 0, -20), **SAG(128, 0.03)),
            K(1.42, "in", pel=(0, -0.1, -0.1), pelR=(6, 0, 0), chest=(10, 0, 0), neck=(-6, 0, 0), rh=(0.05, 0.75, -1.3), rf=(0, -0.15, 0.22, 0, 6), lf=(0, 0.1, 0.25, 0, 6), **SAG(48, 0.0)),
            K(1.5, "whip", pel=(0, -1.0, -0.45), pelR=(20, 0, 0), chest=(27, 0, 0), neck=(-22, 0, 0), relb=(0.8, -0.4, 0.3), rh=(0.0, -0.75, -1.25), rf=(0, -0.42, 0, 0, 0), lf=(0, 0.25, 0, 0, 0), rknee=rest["rknee"], lknee=rest["lknee"], **SAG(-40, 0.0)),
            K(1.92, "out", pel=(0, -1.08, -0.42), pelR=(23, 0, 0), chest=(30, 0, 0), neck=(-16, 0, 0), rh=(0.0, -0.82, -1.18), **SAG(-42, 0.0)),
            K(2.3, "io", pel=(0, -0.45, -0.2), pelR=(9, -2, 0), chest=(11, -3, 0), neck=(-6, 2, 0), rf=(0, -0.2, 0, 0, 0), lf=(0, 0.1, 0, 0, 0), rh=(0.45, -1.25, -0.72), haft=H(30, -40), face=(0, -0.8, -0.5), lhw=0.0),
            K(2.6, "io", **READY),
        ], contacts=[1.5], move="GuandaoSkyfall", scrape=True, airborne=True, feet_free=[(0, 2.6)], notes="Coils for the launch, the server's aerial path carries the root (no second leap here), glaive high at the apex, then the blade descends and his knees absorb the landing at the impact.")

    def crimson_embrace():
        back = dict(rh=(0.55, -1.2, 0.5), haft=H(70, -32), face=SIDE(70), relb=(0.8, -0.2, 0.5))
        return Clip(rg, P + "CrimsonEmbrace", 2.4, [
            K(0, **READY),
            K(0.5, "io", pel=(0.0, -0.32, 0.22), pelR=(-6, -16, 0), chest=(-10, -24, 0), neck=(4, 20, 0), ltw=0.8, lt=(-0.75, -0.2, 0.15), lelb=(-0.8, -0.1, 0.5), **back),
            K(0.98, "io", pel=(0.02, -0.4, 0.3), pelR=(-8, -20, 0), chest=(-13, -30, 0), neck=(6, 24, 0), lt=(-0.8, 0.0, 0.25)),
            K(1.2, "whip", pel=(0.0, -0.6, -1.1), pelR=(14, 12, 0), chest=(18, 26, 0), neck=(-14, -20, 0), ltw=1.0, lt=(0.5, 0.1, -1.46), lelb=(-0.5, -0.8, 0.1), rf=(0.0, -0.1, 0, 0, 0), lf=(0.0, -1.0, 0, 0, 0)),
            K(1.4, "out", pel=(0.0, -0.64, -1.2), pelR=(16, 16, 0), chest=(20, 32, 0), lt=(0.55, -0.15, -1.25), lf=(0.0, -1.0, 0, 0, 0)),
            K(1.8, "io", pel=(0.0, -0.46, -0.65), pelR=(9, 8, 0), chest=(11, 12, 0), neck=(-8, -8, 0), ltw=0.4, lt=(0.1, -0.6, -0.6), lf=(0.0, -0.55, 0, 0, 0)),
            K(2.4, "io", **READY),
        ], contacts=[1.2], move="CrimsonEmbrace", notes="The whole torso follows the clawed left arm into the reach while the glaive stays back in the right hand; a short breath in, the snatch on the server's impact and a heavy recovery. Cosmetic only: nothing attaches to a player.")

    # ---------------------------------------------------------------- idle, travel, guard
    def idle():
        """A body at rest is never still: the breath lifts the chest and the shoulders with it, the weight drifts between the feet, the head makes small slow looks. Keyed by the frame on whole cycles so it loops."""
        p1 = phase == 1
        length = 6.4 if p1 else 4.2
        breaths = 2 if p1 else 3
        n = int(length * 15)
        keys = []
        for i in range(n):
            t = i / n * length
            a = 2 * math.pi * t / length
            breath = 0.5 - 0.5 * math.cos(a * breaths)
            breath = breath ** (1.5 if p1 else 0.8)          # a slow fill, a quicker let-go
            sway = math.sin(a)                               # weight over the right foot at +
            sway2 = math.sin(2 * a + 0.9)
            if p1:
                look = 3.0 * L.smooth01((math.sin(a * 1 + 0.4) + 0.2) / 0.5) - 1.6 + 0.8 * math.sin(3 * a)
                k = dict(pel=(0.04 * sway, -0.05 - 0.018 * breath - 0.008 * sway2, 0.008 * sway2), pelR=(0.3 * sway2, 1.2 * sway, 1.1 * sway),
                         chest=(-1.3 * breath + 0.3 * sway2, -1.5 * sway, -1.5 * sway), neck=(0.8 * breath + 0.6 * math.sin(2 * a), look, 0.9 * sway),
                         rh=(rest["rh"][0] - 0.012 * sway, rest["rh"][1] + 0.02 * breath, rest["rh"][2]), lua=(1.2 * math.sin(a + 0.8), 0, 0.9 * breath), lfa=(1.5 * math.sin(a + 1.2), 0.8 * sway2, 0), lha=(3.0 * math.sin(2 * a), 0, 1.5 * sway))
            else:
                # the corrupted form cannot hold still: he pants, his head hunts in short snaps, the claw works
                snap = sum(w * L.smooth01((t - at) / 0.11) for at, w in ((0.7, 9.0), (1.5, -13.0), (2.5, 8.0), (3.4, -4.0)))
                k = dict(pel=(0.06 * sway, -0.09 - 0.05 * breath - 0.015 * sway2, 0.015 * sway2), pelR=(1.2 * breath, 2.2 * sway, 1.8 * sway),
                         chest=(-3.2 * breath + 0.8 * sway2, -3.0 * sway, -2.4 * sway + 0.6 * sway2), neck=(2.6 * breath - 1.0, snap + 1.5 * sway, 1.5 * math.sin(a + 0.6)),
                         rh=(rest["rh"][0] - 0.02 * sway, rest["rh"][1] + 0.05 * breath, rest["rh"][2] + 0.015 * sway2), lua=(3 + 2.5 * math.sin(a + 0.8), 0, 2.5 + 1.5 * breath), lfa=(2 + 3 * math.sin(2 * a + 1.2), 2 * sway2, 0),
                         lha=(8 * math.sin(3 * a), 6 * math.sin(2 * a + 1), 3 * math.sin(5 * a)))
            keys.append((t, k, "lin"))
        return Clip(rg, P + "Idle", length, keys, loop=True, priority="Idle", authored_feet=True,
                    notes="Sculpt pose alive: slow breath, weight drifting between the feet, small looks." if p1 else "Sculpt pose lowered and panting: head hunting in short snaps, claw working, the beads drifting on their own.")

    def gait(name, period, dx, dz, lift, beta, lean=0.0, sink=0.0, bob=0.04, sway=0.04, twist=3.0, drop=1.0, shoulders=0.9, head=0.0, swing=8.0, narrow=0.42, carry=False, run=False, backward=False):
        """One full gait from the two foot strikes: heel strike, roll flat, heel off, toe off, swing. The right foot strikes at 0, the left at half. A foot in stance moves at exactly the body's speed, so it never skates:
        the rate in Rules.Locomotion is 2 * stride / (beta * period). Hips lead the chest, which counters them; the head stays level over it all."""
        count = max(int(period * 30), 16)
        keys = []
        reach = math.hypot(dx, dz)
        pos_of = lambda s: (dx * s, dz * s)

        def foot(tau, side):
            tau %= 1.0
            inset = narrow * (-1 if side > 0 else 1)  # feet come in under the body from the sculpt's wide stance
            if tau < beta:                            # stance
                f = tau / beta
                s = 1 - 2 * f
                if backward:      # lands on the toe, lets the heel down, pushes off the heel
                    pitch = -14 * (1 - smooth(f / 0.2)) + 6 * smooth((f - 0.72) / 0.28)
                elif dx != 0:     # sideways: the foot rolls less and stays flat longer
                    pitch = 5 * (1 - smooth(f / 0.2)) - 14 * smooth((f - 0.65) / 0.35)
                else:
                    flat_from = 0.16 if not run else 0.08
                    off_from = 0.55 if not run else 0.3
                    pitch = (16 if not run else 8) * (1 - smooth(f / flat_from)) - (34 if not run else 42) * smooth((f - off_from) / (1 - off_from))
                up, fw = L.foot_roll(pitch)
                sign = 1 if not backward else -1
                x, z = pos_of(s)
                return (x + inset, z - fw * sign if dz else z, max(up, 0.0), 0, pitch)
            u = (tau - beta) / (1 - beta)             # swing: leaves fast, the knee carries it through, reaches forward and sets the heel
            s = -1 + 2 * smooth(u) ** 0.9
            start = (6 if backward else -34 if not run else -42) if dx == 0 else -14
            end = (-14 if backward else 16 if not run else 8) if dx == 0 else 5
            mid = -28 if run else -14
            pitch = start + (mid - start) * smooth(u / 0.4) if u < 0.4 else mid + (end - mid) * smooth((u - 0.4) / 0.6)
            up, fw = L.foot_roll(start)
            up2, _ = L.foot_roll(end)
            base = up * (1 - smooth(u / 0.3)) + up2 * smooth((u - 0.7) / 0.3)
            x, z = pos_of(s)
            return (x + inset, z, max(base, 0.0) + lift * math.sin(math.pi * u ** 0.8), 0, pitch)

        def smooth(v):
            return L.smooth01(v)

        for i in range(count):
            p = i / count
            a = 2 * math.pi * p
            wave = math.cos(a)                      # + right leg forward
            over = math.sin(a)                      # + weight over the right foot
            if run:      # runs drop through mid-stance and rise into the flight
                vert = math.cos(2 * a - 4 * math.pi * (beta / 2))
                y = -sink - bob * vert
            else:        # walks are lowest at the double support just after a strike, highest over the planted foot
                vert = math.cos(2 * (a - 0.2))
                y = -sink - bob * vert
            hips_yaw = twist * wave
            hips_roll = drop * over
            chest_yaw = -twist * shoulders * math.cos(a - 0.2)
            chest_world = hips_yaw + chest_yaw
            k = dict(pel=(sway * over, y, -lean * 0.012 - 0.015 * vert), pelR=(lean * 0.55 + 1.0 * vert * (0.5 if not run else 1.0), hips_yaw, hips_roll),
                     chest=(lean * 0.55 - 0.8 * vert, chest_yaw, -hips_roll * 1.3), neck=(-lean * 1.05 + head + 0.6 * vert, -chest_world * 0.85, hips_roll * 0.4),
                     rf=foot(p, 1), lf=foot(p + 0.5, -1), rknee=(0.22, 0.0, -1.0), lknee=(-0.22, 0.0, -1.0))
            arm_a = math.cos(a - 0.3)              # the left arm forward as the right leg comes forward, a beat behind it
            if carry:
                k.update(rh=(0.05 + 0.03 * over, -1.28 + 0.05 * vert, 0.42 - 0.2 * arm_a), haft=H(165 + 3.0 * arm_a, -20 + 2.5 * vert), face=(0.1, -0.9, -0.3), relb=(0.8, -0.2, 0.5),
                         lua=(-swing * 2.2 * arm_a + 10, 0, 5), lfa=(-52 - swing * 1.3 * (0.5 + 0.5 * arm_a), -8, 0), lha=(-6, 0, 0))
            else:
                # the glaive rides in the right hand: the arm gives a little against the left leg and the long haft nods with the steps
                r0 = rest["rh"]
                h0, f0 = np.array(rest["haft"]), np.array(rest["face"])
                nod = L.rodrigues(np.array([1.0, 0, 0]) * math.radians(1.6 * math.cos(2 * a - 0.5)) + np.array([0, 1.0, 0]) * math.radians(1.2 * arm_a))
                k.update(rh=(r0[0] - 0.02 * over, r0[1] + 0.05 + 0.03 * vert, r0[2] + 0.07 * arm_a), haft=tuple(nod @ h0), face=tuple(nod @ f0),
                         lua=(-swing * arm_a, 0, 1.5 + 1.0 * over), lfa=(-7 - swing * 0.55 * (0.5 + 0.5 * arm_a), -2, 0), lha=(-3 + 2 * arm_a, 0, 0))
            keys.append((p * period, k, "lin"))
        rate = 2 * reach / (beta * period)
        return Clip(rg, P + name, period, keys, loop=True, priority="Movement", authored_feet=True, feet_free=[(0, period)], notes="%s: %.2f rig studs per second at speed 1." % (name, rate))

    def locomotion():
        # strides solve 2 * stride / (beta * period) = the rate Rules.Locomotion holds, so nothing skates at the speeds the game asks for
        if phase == 1:
            return [gait("WalkForward", 1.25, 0, -0.767, 0.14, 0.62, lean=2.5, sink=0.11, bob=0.03, sway=0.06, twist=3.5, drop=1.6, shoulders=0.92, swing=9.0, narrow=0.3),
                    gait("RunForward", 0.72, 0, -0.79, 0.3, 0.36, lean=13, sink=0.22, bob=0.06, sway=0.05, twist=7.0, drop=2.0, shoulders=1.05, swing=12.0, carry=True, run=True),
                    gait("WalkBackward", 1.35, 0, 0.62, 0.11, 0.62, lean=1.5, sink=0.1, bob=0.022, sway=0.05, twist=2.5, drop=1.4, swing=4.0, backward=True),
                    gait("StrafeLeft", 1.3, -0.62, 0, 0.11, 0.62, lean=2.0, sink=0.12, bob=0.02, sway=0.03, twist=1.0, drop=1.2, swing=3.0, narrow=0.15),
                    gait("StrafeRight", 1.3, 0.62, 0, 0.11, 0.62, lean=2.0, sink=0.12, bob=0.02, sway=0.03, twist=1.0, drop=1.2, swing=3.0, narrow=0.15)]
        return [gait("WalkForward", 1.1, 0, -0.79, 0.15, 0.6, lean=6.0, sink=0.1, bob=0.05, sway=0.1, twist=7.0, drop=3.2, shoulders=1.5, head=4.0, swing=13.0, narrow=0.34),
                gait("RunForward", 0.62, 0, -0.79, 0.34, 0.34, lean=19, sink=0.16, bob=0.08, sway=0.09, twist=11.0, drop=3.2, shoulders=1.5, head=6.0, swing=16.0, narrow=0.36, carry=True, run=True),
                gait("WalkBackward", 1.2, 0, 0.65, 0.12, 0.6, lean=5.0, sink=0.1, bob=0.04, sway=0.1, twist=5.0, drop=2.6, shoulders=1.4, head=5.0, swing=7.0, narrow=0.34, backward=True),
                gait("StrafeLeft", 1.15, -0.67, 0, 0.13, 0.6, lean=5.0, sink=0.12, bob=0.035, sway=0.04, twist=3.0, drop=2.2, shoulders=1.4, head=5.0, swing=6.0, narrow=0.12),
                gait("StrafeRight", 1.15, 0.67, 0, 0.13, 0.6, lean=5.0, sink=0.12, bob=0.035, sway=0.04, twist=3.0, drop=2.2, shoulders=1.4, head=5.0, swing=6.0, narrow=0.12)]

    def guard():
        a = {**READY, **GUARD}
        b = dict(chest=(GUARD["chest"][0] - 1.0, GUARD["chest"][1], 0), pel=(0.0, -0.33, 0.06))
        hit = {**READY, **GUARD, "pel": (0.0, -0.4, 0.34), "chest": (-3, GUARD["chest"][1] - 6, 3), "rh": (-0.62, -0.62, -0.6)}
        return [Clip(rg, P + "GuardLoop", 1.8, [K(0, **a), K(0.9, **b)], loop=True, priority="Movement", notes="Haft raised across the body in both hands, weight low and quiet."),
                Clip(rg, P + "GuardHit", 0.45, [K(0, **a), K(0.1, "snap", **hit), K(0.45, "io", **a)], priority="Movement", notes="A blow on the haft: he gives a little ground and resets.")]

    # ---------------------------------------------------------------- reactions
    def reactions():
        knee = dict(pel=(0.05, -1.0, 0.18), pelR=(13, 8, 0), chest=(18, 8, 0), neck=(-3, 0, 0), rf=(0.0, 0.95, 0.5, 0, -55), lf=(0.05, -0.6, 0, 0, 0), rknee=(0.3, 0, -1), lknee=(0, 0, -1), rh=(0.55, -0.85, -0.85), haft=H(20, -62), face=(0.2, -0.3, 0.9), relb=rest["relb"], lua=(-30, 0, -8), lfa=(-24, -20, -6), lhw=0.0)
        flinch = {**READY, "pel": (0, -0.08, 0.16), "pelR": (-3, 0, 0), "chest": (-6, 0, 0), "neck": (-4, 0, 0)}
        return [
            Clip(rg, P + "HitLightFront", 0.4, [K(0, **READY), K(0.09, "snap", **flinch), K(0.4, "io", **READY)], priority="Action3", notes="Light flinch; composure barely breaks."),
            Clip(rg, P + "PostureBreak", 1.0, [K(0, **READY), K(0.14, "snap", pel=(0.02, -0.25, 0.42), pelR=(-14, 7, 0), chest=(-20, 8, 0), neck=(13, 0, 0), rf=(0, 0.22, 0, 0, 0), lua=(-4, 0, -22), lfa=(0, 14, -12), rh=(0.8, -0.95, 0.55), haft=H(50, -38), face=(0, -0.8, 0.5)),
                                                 K(0.46, "io", pel=(0.05, -0.65, 0.3), pelR=(5, 8, 0), chest=(6, 8, 0), neck=(2, 0, 0), rf=(0.0, 0.6, 0.3, 0, -26), lf=(0.05, -0.3, 0, 0, 0), rh=(0.6, -1.0, -0.45), haft=H(30, -52), face=(0.1, -0.5, 0.8)), K(1.0, "in", **knee)],
                 priority="Action3", feet_free=[(0, 1)], notes="Stance broken: thrown back, the guard flies wide, and he sinks to his right knee on the haft."),
            Clip(rg, P + "DeathblowVictim", 2.2, [K(0, **knee), K(0.22, "snap", pel=(0.05, -0.84, 0.32), pelR=(-9, 8, 0), chest=(-14, 8, 0), neck=(15, 0, 0)), K(0.9, "io", pel=(0.05, -0.96, 0.28), pelR=(9, 6, 0), chest=(14, 6, 0), neck=(0, 0, 0), lua=(-4, 0, -16), lfa=(0, 8, -8)),
                                                  K(1.5, "in", pel=(0.05, -1.06, 0.16), pelR=(20, 6, 0), chest=(29, 6, 0), neck=(-14, 0, 0)), K(2.2, "io", pel=(0.05, -1.1, 0.12), pelR=(24, 6, 0), chest=(34, 6, 0), neck=(-20, 0, 0))],
                 priority="Action4", feet_free=[(0, 2.2)], notes="Takes the deathblow on the knee: head snaps back, then the old body bows over the haft."),
            Clip(rg, P + "Death", 3.0, [K(0, **READY), K(0.24, "snap", pel=(0, -0.26, 0.4), pelR=(-12, 6, 0), chest=(-18, 6, 0), neck=(16, 0, 0), lua=(-4, 0, -14), lfa=(0, 8, -8)),
                                        K(0.85, "io", pel=(0.03, -0.7, 0.3), pelR=(6, 8, 0), chest=(10, 8, 0), neck=(4, 0, 0), rf=(0, 0.6, 0.32, 0, -30), lf=(0.05, -0.3, 0, 0, 0), rknee=(0.3, 0, -1), lknee=(0, 0, -1), rh=(0.55, -0.98, -0.55), haft=H(25, -55), face=(0.1, -0.4, 0.9)),
                                        K(1.35, "in", pel=(0.05, -1.02, 0.18), pelR=(14, 8, 0), chest=(21, 8, 0), neck=(-8, 0, 0), rf=(0, 0.95, 0.5, 0, -55), lf=(0.05, -0.6, 0, 0, 0), rh=(0.55, -0.85, -0.85), haft=H(20, -62), face=(0.2, -0.3, 0.9), lua=(-30, 0, -6), lfa=(-24, -22, 0)),
                                        K(2.2, "io", pel=(0.05, -1.1, 0.1), pelR=(25, 8, 0), chest=(36, 8, 0), neck=(-24, 0, 0), rh=(0.55, -0.8, -0.95), lua=(-44, 0, -6), lfa=(-40, -24, 0)), K(3.0, "io", pel=(0.05, -1.12, 0.08), pelR=(29, 8, 0), chest=(40, 8, 0), neck=(-28, 0, 0), rh=(0.55, -0.75, -1.0), lua=(-50, 0, -6), lfa=(-46, -24, 0))],
                 priority="Action4", feet_free=[(0, 3)], notes="Killed on his feet: staggers, sinks to the right knee and dies kneeling on the haft; the body fades there."),
        ]

    # ---------------------------------------------------------------- the transformation: both forms meet at one pose at Transition.Reveal
    def handoff():
        r1, r2 = RIGS[1], RIGS[2]
        out = dict(pel=(0.0, -0.58, 0.12), pelR=(18, 0, 0), chest=(26, 0, 0), neck=(-12, 0, 0), rgw=1.0, rg=(1.0, -0.42, -1.05), haft=H(26, -46), face=(0.15, -0.35, 0.92), relb=(0.8, -0.3, 0.4), lhw=1.0, lsl=-0.95, ltw=0.0, lelb=(-0.7, -0.6, 0.3), lua=(0, 0, 0), lfa=(0, 0, 0), lha=(0, 0, 0))
        for side, key in (("Right", "rf"), ("Left", "lf")):
            d = r1.LEGS[side]["ankle"] - rg.LEGS[side]["ankle"]
            out[key] = (float(d[0]), float(d[2]), 0.0, 0, 0)
        out["rknee"], out["lknee"] = r1.REST["rknee"], r1.REST["lknee"]
        return out

    def transform():
        R = handoff()
        if phase == 1:
            return [Clip(rg, P + "Transform", 1.7, [
                K(0, **READY),
                K(0.22, "snap", pel=(0.0, -0.26, 0.16), pelR=(9, 7, 3), chest=(15, 9, 2), neck=(10, 5, 0), ltw=1.0, lt=(0.72, -0.38, -0.5), lelb=(-0.8, -0.6, 0.3), lf=(0.02, 0.12, 0, 0, 0)),
                K(0.52, "io", pel=(0.0, -0.46, 0.16), pelR=(15, 3, 1), chest=(23, 4, 0), neck=(4, 2, 0), lt=(0.7, -0.55, -0.55), rgw=0.6, rg=R["rg"], haft=H(26, -46), face=R["face"]),
                K(0.72, "io", ltw=0.0, lhw=1.0, lsl=-0.95, lelb=R["lelb"], rgw=1.0),
                K(REVEAL, "in", **R),
                K(1.7, "lin", **R),
            ], priority="Action4", feet_free=[(0, 1.7)], raw_after=REVEAL, notes="He falters, clutches his chest, grips the glaive in both hands and breaks; reaches the shared handoff pose at the Reveal and holds it for the swap.")]
        rise = dict(pel=(0.0, -0.08, 0.14), pelR=(-13, 0, 0), chest=(-22, 0, 0), neck=(18, 0, 0), rgw=0.0, relb=(0.9, 0.2, 0.3), rh=(1.1, 0.75, 0.4), haft=H(95, 30), face=(0.3, -0.2, 0.9), lhw=0.0, ltw=1.0, lt=(-1.25, 0.55, -0.45), lelb=(-0.5, -0.8, 0.3))
        CR = dict(READY, pel=(0, -0.2, -0.03), pelR=(6, 0, 0), chest=(8, 0, 0), neck=(-9, 0, 0), rf=(0.06, 0, 0, 0, 0), lf=(-0.06, 0, 0, 0, 0))
        return [Clip(rg, P + "Transform", 1.5, [
            K(0, **R),
            K(0.1, "out", rgw=0.55, haft=H(62, -22), face=(0.25, -0.3, 0.9), lhw=0.2),
            K(0.32, "snap", **rise),
            K(0.8, "io", pel=(0.0, -0.1, 0.14), pelR=(-15, 0, 0), chest=(-25, 0, 0), neck=(20, 0, 0), rh=(1.1, 0.8, 0.42), lt=(-1.25, 0.6, -0.42)),
            K(1.15, "io", pel=(0.0, -0.24, 0.04), pelR=(3, 0, 0), chest=(5, 0, 0), neck=(-4, 0, 0), ltw=0.0, rh=rest["rh"], haft=rest["haft"], face=rest["face"], relb=rest["relb"], rf=CR["rf"], lf=CR["lf"], rknee=READY["rknee"], lknee=READY["lknee"]),
            K(1.5, "io", **CR),
        ], priority="Action4", corrupt=False, feet_free=[(0, 1.5)], notes="Revealed from the shared handoff pose in the localized burst: he straightens, arm and claw flung wide on the inhale and roar, then sinks into the corrupted stance. Ends exactly on the phase 2 idle.")]

    out = [idle(), strike()] + locomotion() + guard() + reactions() + transform()
    out += [crescent_reap(), returning_tide(), heaven_cleave(), green_dragon(), charging_thrust(), cyclone()]
    out += [flowing_thrust(), prayer_beads(), abbot_sweep()] if phase == 1 else [blood_wave(), skyfall(), crimson_embrace()]
    return out


def library():
    return build(1) + build(2)
