"""The Iron Bull's clip library, authored on the supplied sculpt (bull_lib.py). Timing comes straight from WeaponSchema/BossAttackCatalog; contact = the first active frame.

Attacks that sweep (Arc > 40) travel left to right because StrikeGeometry fans the server's blow that way: with the maul in his right hand those are backhands. The shield is
strapped to his left forearm, so "both hands" moves in the brief are the maul one-handed with the shield driving alongside.
"""
import math

import bull_lib as B
from bull_lib import Clip, validate, write_rbxmx  # noqa: F401  (export.py takes these from the set's module)

KEY = "IronBull_P1_"
OATH_KEY = "IronBull_P1_Oath_"


def H(yaw, pitch=0.0):
    y, p = math.radians(yaw), math.radians(pitch)
    return (math.sin(y) * math.cos(p), math.sin(p), -math.cos(y) * math.cos(p))


def SIDE(yaw):
    y = math.radians(yaw)
    return (math.cos(y), 0.0, math.sin(y))


def AIM(yaw, pitch=0.0, ext=1.86):
    """Fist from shoulder along a direction; the haft continues the arm's line, the leading face turned into a rightward sweep."""
    d = H(yaw, pitch)
    return dict(rh=tuple(ext * v for v in d), haft=H(yaw, pitch), face=SIDE(yaw))


def SAG(e, x=0.0, ext=None, off=(0.0, 0.0, 0.0)):
    """A vertical swing: elevation e degrees from straight ahead toward up; the leading face turned down the swing."""
    r, c, s = math.radians(e), math.cos(math.radians(e)), math.sin(math.radians(e))
    d = (x, s, -c)
    out = dict(haft=d, face=(0.0, -c, -s))
    if ext is not None:
        out["rh"] = (x * ext + off[0], s * ext + off[1], -c * ext + off[2])
    return out


def K(t, ease="io", **kw):
    return (t, kw, ease)


READY = dict(pel=(0, -0.06, 0), pelR=(0, 0, 0), chest=(0, 0, 0), neck=(0, 0, 0), lookW=0.0, rf=(0, 0, 0, 0, 0), lf=(0, 0, 0, 0, 0), lua=(0, 0, 0), lfa=(0, 0, 0), lha=(0, 0, 0),
             rh=B.REST_CONTROLS["rh"], haft=B.REST_CONTROLS["haft"], face=B.REST_CONTROLS["face"], relb=B.REST_CONTROLS["relb"], rknee=B.REST_CONTROLS["rknee"], lknee=B.REST_CONTROLS["lknee"])
GUARD = dict(pel=(0.02, -0.22, 0.05), pelR=(5, -12, 0), chest=(7, -10, 0), neck=(-6, 8, 0), lua=(-36, 0, 6), lfa=(0, -52, 0), rf=(0.05, 0.28, 0, 10, 0), lf=(0.05, -0.3, 0, -8, 0),
             rh=(0.32, -1.25, 0.72), haft=H(18, -48), face=(0.0, -0.6, 0.8), relb=(0.75, -0.2, 0.65))
BRACE = dict(lua=(-58, -10, 0), lfa=(0, -74, 0))  # the shield squared forward at full extension


def strike_clip(name, oath, length, contact, active_len, arc, reach, lunge, keys, notes, striker="maul", feet_free=()):
    full = (OATH_KEY if oath else KEY) + name
    return Clip(full, length, keys, contacts=[contact], move=name, notes=notes, active=(contact, active_len, arc, reach, lunge), striker=striker, oath=oath, priority="Action", feet_free=feet_free)


def iron_hook(oath=False):
    return strike_clip("IronBullMaul_L1", oath, 0.567, 0.217, 0.067, 100, 9.5, 1.5, [
        K(0, **READY),
        K(0.115, "out", pel=(-0.05, -0.3, 0.14), pelR=(2, 24, 0), chest=(5, 30, 0), neck=(-3, -30, 0), relb=(0.25, -0.5, 0.8), rh=(-1.45, 0.35, -0.55), haft=H(-128, 12), face=SIDE(-128), lua=(-14, 0, -4), lfa=(0, -14, 0)),
        K(0.217, "whip", pel=(-0.1, -0.5, -0.95), pelR=(9, 20, 0), chest=(9, 26, 0), neck=(-6, -28, 0), rf=(-0.28, -1.05, 0, -10, 0), relb=(0.2, -0.75, 0.6), lua=(-26, 0, -6), lfa=(0, -26, 0), **AIM(-88, 2)),
        K(0.284, "lin", pel=(0.08, -0.54, -1.12), pelR=(11, -14, 0), chest=(10, -32, 0), neck=(-6, 26, 0), rf=(-0.28, -1.05, 0, -10, 0), relb=(0.2, -0.9, 0.35), lua=(-16, 0, 4), lfa=(0, -12, 0), **AIM(22, 0)),
        K(0.37, "out", pel=(0.1, -0.5, -0.95), pelR=(9, -28, 0), chest=(8, -48, 0), neck=(-4, 34, 0), relb=(0.1, -0.9, -0.3), lua=(-8, 0, 4), lfa=(0, -4, 0), **AIM(112, -6, 1.7)),
        K(0.46, "io", pel=(0.04, -0.28, -0.42), pelR=(4, -10, 0), chest=(4, -16, 0), neck=(-2, 10, 0), rf=(-0.12, -0.42, 0, -4, 0), rh=(0.8, -1.35, -0.75), haft=H(60, -35), face=SIDE(60), relb=B.REST_CONTROLS["relb"], lua=(-4, 0, 0), lfa=(0, -2, 0)),
        K(0.567, "io", **READY),
    ], "Iron Hook: backhand. Coils across his body, steps through with the right foot and whips the head left to right across the front (the server's 100-degree fan).")


def shield_ram(oath=False):
    return strike_clip("IronBullMaul_L2", oath, 0.5, 0.167, 0.067, 36, 7.0, 3.0, [
        K(0, **READY),
        K(0.085, "out", pel=(0.03, -0.26, 0.2), pelR=(2, -26, 0), chest=(8, -22, 0), neck=(-6, 24, 0), lua=(-22, 0, 8), lfa=(0, -46, 0), rh=(0.32, -1.5, 0.45), haft=H(25, -55), face=(0, -0.5, 0.9)),
        K(0.167, "whip", pel=(-0.2, -0.46, -1.3), pelR=(11, -38, 0), chest=(14, -30, 0), neck=(-14, 34, 0), lf=(0.28, -1.32, 0, -18, 0), rf=(0.0, 0.0, 0, 0, 0), **BRACE),
        K(0.234, "out", pel=(-0.23, -0.48, -1.46), pelR=(13, -40, 0), chest=(15, -32, 0), lf=(0.28, -1.32, 0, -18, 0), rf=(0.0, -0.32, 0, 0, 0), lua=(-64, -12, 0), lfa=(0, -78, 0)),
        K(0.34, "io", pel=(-0.12, -0.32, -0.8), pelR=(6, -22, 0), chest=(8, -16, 0), neck=(-6, 16, 0), lf=(0.14, -0.66, 0, -8, 0), rf=(0, -0.1, 0, 0, 0), lua=(-30, -4, 0), lfa=(0, -36, 0)),
        K(0.5, "io", **READY),
    ], "Shield Ram: left shoulder and tower shield driven straight ahead behind a long left step; maul held back.", striker="shield")


def anvil_drop(oath=False):
    return strike_clip("IronBullMaul_L3", oath, 0.884, 0.317, 0.067, 24, 10.0, 2.5, [
        K(0, **READY),
        K(0.17, "out", pel=(0.02, -0.08, 0.22), pelR=(-9, 10, 0), chest=(-13, 16, 0), neck=(8, -14, 0), relb=(0.9, 0.2, 0.3), rh=(0.2, 1.5, 0.2), **SAG(120, 0.05)),
        K(0.25, "io", pel=(0.02, -0.04, 0.2), pelR=(-11, 10, 0), chest=(-17, 16, 0), neck=(10, -14, 0), relb=(0.9, 0.3, 0.2), rh=(0.16, 1.6, 0.34), lua=(-10, 0, -10), lfa=(0, -14, 0), **SAG(138, 0.05)),
        K(0.317, "whip", pel=(0, -0.54, -1.1), pelR=(14, -4, 0), chest=(21, -8, 0), neck=(-14, 6, 0), rf=(-0.12, -1.18, 0, -4, 0), relb=(0.8, -0.3, 0.45), rh=(0.0, 0.42, -1.82), lua=(-22, 0, -6), lfa=(0, -24, 0), **SAG(22, 0.02)),
        K(0.384, "lin", pel=(0, -0.78, -1.2), pelR=(21, -4, 0), chest=(27, -8, 0), neck=(-22, 6, 0), rf=(-0.12, -1.18, 0, -4, 0), relb=(0.8, -0.4, 0.3), rh=(0.0, -0.75, -1.6), **SAG(-26, 0.02)),
        K(0.5, "out", pel=(0, -0.84, -1.2), pelR=(23, -4, 0), chest=(29, -8, 0), neck=(-24, 6, 0), rf=(-0.12, -1.18, 0, -4, 0), rh=(0.0, -0.85, -1.52), **SAG(-30, 0.02)),
        K(0.68, "io", pel=(0, -0.45, -0.68), pelR=(10, -2, 0), chest=(12, -4, 0), neck=(-8, 2, 0), rf=(-0.07, -0.66, 0, -2, 0), rh=(0.4, -1.4, -0.7), haft=H(30, -40), face=(0, -0.8, -0.5), lua=(-8, 0, -2), lfa=(0, -6, 0)),
        K(0.884, "io", **READY),
    ], "Anvil Drop: lifts the maul behind his head, then a long step and a straight overhead drop that buries the head at the end of the active window; commits low.")


def ox_yoke(oath=False):
    return strike_clip("IronBullMaul_Heavy", oath, 1.2, 0.517, 0.083, 70, 10.5, 2.0, [
        K(0, **READY),
        K(0.3, "out", pel=(0.05, -0.24, 0.2), pelR=(0, 34, 0), chest=(-4, 36, 0), neck=(2, -34, 0), relb=(0.1, 0.2, 0.9), rh=(-1.35, 0.85, 0.65), haft=H(-155, 28), face=SIDE(-155), lua=(-8, 0, -24), lfa=(0, 32, -10)),
        K(0.44, "io", pel=(0.08, -0.22, 0.26), pelR=(-2, 40, 0), chest=(-8, 44, 0), neck=(4, -40, 0), relb=(0.1, 0.25, 0.9), rh=(-1.3, 0.95, 0.75), haft=H(-162, 32), face=SIDE(-162), lua=(-6, 0, -28), lfa=(0, 40, -12)),
        K(0.517, "whip", pel=(-0.12, -0.56, -1.05), pelR=(12, 18, 0), chest=(13, 18, 0), neck=(-8, -18, 0), rf=(-0.25, -1.2, 0, -10, 0), lf=(0.02, 0.0, 0, 0, 0), relb=(0.2, -0.75, 0.6), lua=(-46, -6, 0), lfa=(0, -46, 0), **AIM(-78, 0)),
        K(0.6, "lin", pel=(0.08, -0.62, -1.2), pelR=(15, -10, 0), chest=(16, -26, 0), neck=(-10, 20, 0), rf=(-0.25, -1.2, 0, -10, 0), relb=(0.2, -0.9, 0.3), lua=(-56, -10, 0), lfa=(0, -68, 0), **AIM(4, -4)),
        K(0.74, "out", pel=(0.08, -0.74, -1.12), pelR=(19, -14, 0), chest=(23, -30, 0), neck=(-16, 22, 0), rf=(-0.25, -1.2, 0, -10, 0), relb=(0.3, -0.8, 0.2), rh=(1.25, -0.85, -1.05), haft=H(52, -38), face=(0.2, -0.9, -0.4), lua=(-44, -6, 0), lfa=(0, -46, 0)),
        K(0.9, "io", pel=(0.05, -0.68, -1.06), pelR=(17, -12, 0), chest=(20, -26, 0), neck=(-14, 20, 0), rf=(-0.25, -1.2, 0, -10, 0), rh=(1.2, -0.95, -1.0), haft=H(52, -42), face=(0.2, -0.9, -0.4), lua=(-38, -4, 0), lfa=(0, -38, 0)),
        K(1.06, "io", pel=(0.02, -0.3, -0.5), pelR=(6, -4, 0), chest=(6, -8, 0), neck=(-4, 6, 0), rf=(-0.12, -0.55, 0, -4, 0), rh=(0.6, -1.45, -0.7), haft=H(40, -38), face=(0, -0.8, -0.5), lua=(-10, 0, 0), lfa=(0, -10, 0)),
        K(1.2, "io", **READY),
    ], "Ox-Yoke Crush: hauls maul and shield wide like a yoke, then drives through: the backhand fans left to right as the shield closes from his left, and his weight crushes down at the end. Maul one-handed; the shield is strapped.")


def rampart_rush(oath=False):
    start = dict(pel=(-0.06, -0.26, 0.0), pelR=(12, -16, 0), chest=(12, -12, 0), neck=(-14, 14, 0), lua=(-34, -4, 0), lfa=(0, -52, 0), rh=(0.35, -1.45, 0.45), haft=H(30, -52), face=(0, -0.6, 0.8), relb=(0.7, -0.2, 0.7), rf=(0, -0.5, 0, 0, 0), lf=(0, 0.45, 0.2, 0, 0))
    return strike_clip("IronBullMaul_Running", oath, 0.8, 0.283, 0.083, 40, 8.0, 7.0, [
        K(0, "lin", **start),
        K(0.13, "io", pel=(-0.1, -0.2, -0.3), pelR=(13, -24, 0), chest=(13, -18, 0), rf=(0, 0.1, 0, 0, 0), lf=(0.1, -0.5, 0.45, -10, 0), lua=(-44, -8, 0), lfa=(0, -64, 0)),
        K(0.283, "whip", pel=(-0.22, -0.52, -1.42), pelR=(17, -36, 0), chest=(15, -26, 0), neck=(-18, 30, 0), rf=(0.0, 0.0, 0.0, 0, 0), lf=(0.25, -1.5, 0, -18, 0), **BRACE),
        K(0.366, "out", pel=(-0.24, -0.5, -1.66), pelR=(18, -38, 0), chest=(16, -28, 0), rf=(0.0, -0.3, 0.3, 0, 0), lf=(0.25, -1.5, 0, -18, 0), lua=(-66, -12, 0), lfa=(0, -80, 0)),
        K(0.5, "out", pel=(-0.14, -0.42, -1.2), pelR=(11, -24, 0), chest=(10, -18, 0), rf=(0.05, -0.85, 0, -4, 0), lf=(0.25, -1.5, 0, -18, 0), lua=(-44, -6, 0), lfa=(0, -52, 0), rh=(0.5, -1.5, -0.1), haft=H(35, -45), face=(0, -0.7, -0.6)),
        K(0.65, "io", pel=(-0.06, -0.22, -0.55), pelR=(5, -10, 0), chest=(5, -8, 0), neck=(-4, 6, 0), rf=(0.02, -0.4, 0, 0, 0), lf=(0.1, -0.7, 0, -6, 0), lua=(-16, 0, 0), lfa=(0, -18, 0)),
        K(0.8, "io", **READY),
    ], "Rampart Rush: out of a run, a long left bound with the tower shield squared at the end of it; the maul stays back.", striker="shield", feet_free=[(0, 0.8)])


def bell_breaker(oath=False):
    return strike_clip("IronBullMaul_Art", oath, 1.167, 0.433, 0.117, 200, 9.5, 1.0, [
        K(0, **READY),
        K(0.2, "out", pel=(0.05, -0.28, 0.16), pelR=(0, 34, 0), chest=(0, 42, 0), neck=(0, -36, 0), relb=(0.1, -0.3, 0.9), rh=(-1.35, 0.3, 0.8), haft=H(-168, 8), face=SIDE(-168), lf=(0, 0.0, 0, 14, 0), lua=(-4, 0, -14), lfa=(0, 24, -6)),
        K(0.35, "io", pel=(0.05, -0.32, 0.2), pelR=(0, 42, 0), chest=(-2, 52, 0), neck=(0, -44, 0), relb=(0.1, -0.3, 0.9), rh=(-1.3, 0.35, 0.9), haft=H(-174, 10), face=SIDE(-174), lf=(0, 0.0, 0, 14, 0), lua=(-4, 0, -18), lfa=(0, 30, -8)),
        K(0.433, "whip", pel=(-0.22, -0.5, -0.6), pelR=(8, 34, 0), chest=(10, 42, 0), neck=(-4, -38, 0), rf=(-0.3, -0.75, 0, -18, 0), relb=(0.1, -0.85, 0.5), lua=(-20, 0, -12), lfa=(0, -6, 0), **AIM(-148, 0)),
        K(0.49, "lin", pel=(-0.05, -0.56, -0.95), pelR=(11, 2, 0), chest=(12, -6, 0), neck=(-6, 4, 0), rf=(-0.3, -0.75, 0, -18, 0), relb=(0.15, -0.95, 0.3), lua=(-24, 0, -4), lfa=(0, -24, 0), **AIM(-30, 0)),
        K(0.55, "lin", pel=(0.16, -0.54, -0.86), pelR=(10, -32, 0), chest=(11, -52, 0), neck=(-6, 40, 0), rf=(-0.3, -0.75, 0, -18, 0), relb=(0.1, -0.9, -0.3), lua=(-12, 0, 8), lfa=(0, -4, 0), **AIM(74, 0)),
        K(0.68, "out", pel=(0.2, -0.46, -0.7), pelR=(6, -44, 0), chest=(6, -64, 0), neck=(-4, 46, 0), rf=(-0.3, -0.75, 0, -18, 0), relb=(0.0, -0.8, -0.6), lua=(-6, 0, 10), lfa=(0, 8, 0), **AIM(155, 2, 1.6)),
        K(0.9, "io", pel=(0.08, -0.3, -0.42), pelR=(3, -14, 0), chest=(3, -20, 0), neck=(-2, 14, 0), rf=(-0.2, -0.45, 0, -8, 0), rh=(0.95, -1.3, -0.3), haft=H(85, -38), face=SIDE(85), relb=B.REST_CONTROLS["relb"], lua=(-2, 0, 2), lfa=(0, -2, 0)),
        K(1.167, "io", **READY),
    ], "Bell-Breaker: the widest backhand he has. Coils until his back shows, then the head scythes through 200 degrees in the active window and carries him round. Brief's both-handed grip is impossible with the strapped shield: one hand, full body.")


def strike(oath=False):
    return Clip((OATH_KEY if oath else KEY) + "Strike", 1.2, [
        K(0, **READY),
        K(0.32, "out", pel=(0.02, -0.08, 0.16), pelR=(-7, 8, 0), chest=(-10, 12, 0), neck=(6, -10, 0), relb=(0.9, 0.2, 0.3), rh=(0.2, 1.45, 0.2), **SAG(115, 0.05)),
        K(0.5, "whip", pel=(0, -0.42, -0.8), pelR=(11, -3, 0), chest=(16, -6, 0), neck=(-10, 4, 0), rf=(-0.1, -0.9, 0, -4, 0), relb=(0.8, -0.3, 0.45), rh=(0, 0.2, -1.84), **SAG(10, 0.02)),
        K(0.62, "lin", pel=(0, -0.62, -0.92), pelR=(16, -3, 0), chest=(21, -6, 0), neck=(-16, 4, 0), rf=(-0.1, -0.9, 0, -4, 0), rh=(0, -0.7, -1.62), **SAG(-22, 0.02)),
        K(0.9, "io", pel=(0, -0.34, -0.48), pelR=(6, -1, 0), chest=(8, -2, 0), neck=(-4, 1, 0), rf=(-0.05, -0.48, 0, -2, 0), rh=(0.45, -1.4, -0.6), haft=H(30, -40), face=(0, -0.8, -0.5)),
        K(1.2, "io", **READY),
    ], contacts=[0.5], move="Strike", oath=oath, notes="Fallback overhead for any weapon move without its own slot.")


def iron_charge(oath=False):
    low = dict(pel=(-0.1, -0.5, -0.1), pelR=(19, -22, 0), chest=(19, -16, 0), neck=(-24, 20, 0), lua=(-46, -6, 0), lfa=(0, -66, 0), rh=(0.4, -1.45, 0.5), haft=H(30, -52), face=(0, -0.6, 0.8), relb=(0.7, -0.2, 0.7))
    return Clip(KEY + "IronCharge", 2.3, [
        K(0, **READY),
        K(0.22, "io", pel=(-0.04, -0.3, -0.02), pelR=(10, -10, 0), chest=(10, -6, 0), neck=(-12, 8, 0), lua=(-20, 0, 0), lfa=(0, -26, 0), rf=(0, 0.1, 0, 0, 0)),
        K(0.42, "io", pel=(-0.1, -0.34, -0.1), pelR=(12, -10, 0), chest=(12, -8, 0), rf=(0.02, 0.55, 0.3, 0, -24)),
        K(0.58, "in", rf=(0.02, 0.1, 0, 0, 0), pel=(-0.04, -0.4, 0)),
        K(0.8, "io", pel=(-0.1, -0.38, -0.1), rf=(0.02, 0.6, 0.32, 0, -26), chest=(14, -8, 0), neck=(-16, 8, 0)),
        K(0.97, "in", rf=(0.02, 0.15, 0, 0, 0), pel=(-0.06, -0.46, -0.04)),
        K(1.25, "out", rf=(0.02, 0.35, 0, 0, 0), lf=(0.14, -0.55, 0, -10, 0), **low),
        K(1.5, "whip", pel=(-0.22, -0.56, -1.3), pelR=(21, -36, 0), chest=(18, -26, 0), neck=(-24, 30, 0), rf=(0, 0.0, 0.05, 0, 0), lf=(0.25, -1.4, 0, -18, 0), rh=(0.4, -1.45, 0.5), **BRACE),
        K(1.68, "out", pel=(-0.24, -0.5, -1.6), pelR=(18, -38, 0), chest=(16, -28, 0), rf=(0, -0.45, 0.3, 0, 0), lf=(0.25, -1.4, 0, -18, 0), lua=(-66, -12, 0), lfa=(0, -80, 0)),
        K(1.95, "io", pel=(-0.12, -0.3, -0.8), pelR=(8, -16, 0), chest=(7, -12, 0), neck=(-8, 10, 0), rf=(0.02, -0.75, 0, 0, 0), lf=(0.14, -0.8, 0, -8, 0), lua=(-30, -4, 0), lfa=(0, -36, 0)),
        K(2.3, "io", **READY),
    ], contacts=[1.5], move="IronCharge", striker="shield", feet_free=[(0, 2.3)], notes="Iron Charge: paws the ground twice, drops behind the shield, and the server's lunge carries him through the impact at 1.5 s.")


def colossal_hammer(oath=False):
    high = dict(pel=(0.02, -0.14, 0.26), pelR=(-13, 8, 0), chest=(-20, 12, 0), neck=(13, -10, 0), relb=(0.9, 0.3, 0.2), rh=(0.16, 1.62, 0.34), lua=(-6, 0, -24), lfa=(0, 18, -12))
    return Clip(KEY + "ColossalHammer", 2.8, [
        K(0, **READY),
        K(0.6, "io", pel=(0, -0.2, 0.1), pelR=(-3, 4, 0), chest=(-6, 6, 0), neck=(4, -4, 0), relb=(0.9, -0.1, 0.4), rh=(0.45, 0.25, 0.1), lua=(-4, 0, -10), lfa=(0, 8, -4), **SAG(95, 0.08)),
        K(1.25, "io", **high, **SAG(142, 0.05)),
        K(1.6, "lin", pel=(0.02, -0.18, 0.3), pelR=(-15, 8, 0), chest=(-23, 12, 0), neck=(15, -10, 0), relb=(0.9, 0.3, 0.2), rh=(0.16, 1.62, 0.4), **SAG(150, 0.05)),
        K(1.72, "in", pel=(0, -0.3, -0.5), pelR=(4, 2, 0), chest=(6, 2, 0), neck=(-4, -2, 0), rf=(-0.1, -1.0, 0.3, -4, 0), relb=(0.8, -0.1, 0.5), rh=(0.05, 1.3, -1.25), lua=(-24, 0, -8), lfa=(0, -24, 0), **SAG(62, 0.02)),
        K(1.8, "whip", pel=(0, -0.86, -1.2), pelR=(22, -4, 0), chest=(29, -8, 0), neck=(-24, 6, 0), rf=(-0.12, -1.18, 0, -4, 0), relb=(0.8, -0.4, 0.3), rh=(0, -0.85, -1.54), lua=(-30, 0, -6), lfa=(0, -32, 0), **SAG(-30, 0.02)),
        K(2.1, "out", pel=(0, -0.9, -1.2), pelR=(24, -4, 0), chest=(31, -8, 0), neck=(-20, 6, 0), rf=(-0.12, -1.18, 0, -4, 0), rh=(0, -0.9, -1.5), **SAG(-32, 0.02)),
        K(2.45, "io", pel=(0, -0.45, -0.66), pelR=(9, -2, 0), chest=(11, -4, 0), neck=(-6, 2, 0), rf=(-0.07, -0.66, 0, -2, 0), rh=(0.4, -1.4, -0.7), haft=H(30, -40), face=(0, -0.8, -0.5), lua=(-8, 0, -2), lfa=(0, -6, 0)),
        K(2.8, "io", **READY),
    ], contacts=[1.8], move="ColossalHammer", feet_free=[(1.6, 1.82)], notes="Colossal Hammer: long lift to the top of a full reach, a held breath, and the head into the ground exactly when the shockwave starts.")


def lightning_spear(oath):
    def thrust(t, pull=False):
        return K(t, "whip" if not pull else "io", pel=(-0.05, -0.5, -1.0) if not pull else (0.02, -0.34, -0.25), pelR=(10, -6, 0) if not pull else (3, 14, 0), chest=(13, -10, 0) if not pull else (2, 22, 0),
                 neck=(-10, 8, 0) if not pull else (-3, -18, 0), rf=(-0.1, -1.0, 0, -4, 0), relb=(0.75, -0.4, 0.3) if not pull else (0.7, 0.25, 0.65), rh=(0.0, 0.1, -1.88) if not pull else (0.0, 0.35, 0.65), haft=H(0, 2) if not pull else H(-2, 3), face=(0, -1, 0))
    keys = [K(0, **READY), K(0.45, "io", lua=(-30, 0, -4), lfa=(0, -34, 0), **{k: v for k, v in thrust(0.45, True)[1].items()}),
            thrust(0.65, True), thrust(0.8), K(0.98, "out", rh=(0, 0.1, -1.7)), thrust(1.25, True), thrust(1.5), K(1.68, "out", rh=(0, 0.1, -1.7)), thrust(1.95, True), thrust(2.2),
            K(2.42, "out", rh=(0, 0, -1.6), pel=(-0.05, -0.56, -1.05)), K(2.75, "io", pel=(0, -0.3, -0.55), pelR=(4, -2, 0), chest=(5, -3, 0), neck=(-3, 2, 0), rf=(-0.06, -0.55, 0, -2, 0), rh=(0.4, -1.4, -0.7), haft=H(30, -40), face=(0, -0.8, -0.5), lua=(-8, 0, 0), lfa=(0, -6, 0)),
            K(3.0, "io", **READY)]
    return Clip((OATH_KEY if oath else KEY) + "LightningSpear", 3.0, keys, contacts=[0.8, 1.5, 2.2], move="LightningSpear", oath=oath, notes="Zhao's Lightning Spear, borrowed on the oath: three straight maul-head punches, each on a server pulse (0.8, 1.5, 2.2).")


def quickstep(oath):
    return Clip((OATH_KEY if oath else KEY) + "ThunderQuickstep", 1.8, [
        K(0, **READY),
        K(0.55, "io", pel=(-0.05, -0.55, 0.12), pelR=(13, -18, 0), chest=(15, -14, 0), neck=(-18, 14, 0), lua=(-40, -6, 0), lfa=(0, -60, 0), rh=(0.42, -1.2, 0.55), haft=H(30, -40), face=(0, -0.6, 0.8), relb=(0.7, -0.2, 0.7), rf=(0, 0.3, 0, 0, 0), lf=(0.1, -0.2, 0, -8, 0)),
        K(0.82, "io", pel=(-0.05, -0.6, 0.16), pelR=(15, -20, 0), chest=(17, -16, 0)),
        K(1.0, "whip", pel=(-0.2, -0.52, -1.42), pelR=(18, -36, 0), chest=(15, -26, 0), neck=(-20, 30, 0), rf=(0, 0.0, 0.05, 0, 0), lf=(0.25, -1.45, 0, -18, 0), **BRACE),
        K(1.18, "out", pel=(-0.24, -0.5, -1.62), rf=(0, -0.45, 0.3, 0, 0), lf=(0.25, -1.45, 0, -18, 0), lua=(-66, -12, 0), lfa=(0, -80, 0)),
        K(1.5, "io", pel=(-0.08, -0.26, -0.68), pelR=(6, -12, 0), chest=(6, -10, 0), neck=(-6, 8, 0), rf=(0, -0.65, 0, 0, 0), lf=(0.12, -0.75, 0, -6, 0), lua=(-22, 0, 0), lfa=(0, -28, 0)),
        K(1.8, "io", **READY),
    ], contacts=[1.0], move="ThunderQuickstep", oath=oath, striker="shield", feet_free=[(0.8, 1.8)], notes="Zhao's Thunder Quickstep, borrowed on the oath: coils low, bursts behind the shield.")


def transform():
    return Clip(KEY + "Transform", 2.0, [
        K(0, **READY),
        K(0.28, "out", pel=(0, -0.42, 0.28), pelR=(16, 0, 0), chest=(22, 0, 0), neck=(-6, 0, 0), lua=(-28, 0, -6), lfa=(-16, -16, 0), rh=(0.4, -1.5, 0.15), haft=H(25, -60), face=(0, -0.6, 0.8)),
        K(0.75, "io", pel=(0, -0.56, 0.22), pelR=(22, 0, 0), chest=(29, 0, 0), neck=(-12, 0, 0)),
        K(1.1, "out", pel=(0, -0.12, 0.2), pelR=(-12, 0, 0), chest=(-20, 0, 0), neck=(16, 0, 0), relb=(0.9, 0.25, 0.3), rh=(1.3, 1.1, 0.2), haft=H(70, 62), face=(0.6, -0.1, 0.6), lua=(-12, 0, -30), lfa=(0, 40, -18)),
        K(1.5, "io", pel=(0, -0.08, 0.18), pelR=(-15, 0, 0), chest=(-24, 0, 0), neck=(20, 0, 0)),
        K(1.72, "whip", pel=(0, -0.42, -0.25), pelR=(7, -8, 0), chest=(13, -12, 0), neck=(-12, 10, 0), rf=(0, -0.3, 0, 0, 0), relb=(0.5, -0.3, 0.7), rh=(-1.12, -0.05, -1.3), haft=H(-65, 22), face=SIDE(-65), lua=(-46, -4, 0), lfa=(0, -60, 0)),
        K(2.0, "io", pel=(0, -0.24, -0.05), pelR=(5, 0, 0), chest=(9, 0, 0), neck=(-7, 0, 0), rf=(0, 0, 0, 0, 0), rh=B.REST_CONTROLS["rh"], haft=B.REST_CONTROLS["haft"], face=B.REST_CONTROLS["face"], relb=B.REST_CONTROLS["relb"], lua=(0, 0, 4), lfa=(0, 0, 0)),
    ], priority="Action4", notes="The Oath: bowed over the partner's fall, rises with both arms flung wide, and beats maul on shield. Ends in the oath stance.")


def idle(oath=False):
    a = dict(pel=(0, -0.05, 0), pelR=(0.6, 0, 0), chest=(0.8, 0, 0), neck=(-1, 0, 0), lua=(0, 0, 0), lfa=(0, 0, 0), rh=B.REST_CONTROLS["rh"])
    b = dict(pel=(0.015, -0.1, 0.01), pelR=(-0.4, 0.6, 0), chest=(-1.4, 1.2, 0.4), neck=(1.6, -1.5, 0), lua=(1.5, 0, 1), lfa=(0, 1.2, 0), rh=tuple(v + d for v, d in zip(B.REST_CONTROLS["rh"], (0.02, 0.05, 0.01))))
    return Clip((OATH_KEY if oath else KEY) + "Idle", 2.4 if oath else 3.2, [K(0, **a), K(1.2 if oath else 1.6, **b)], loop=True, priority="Idle", oath=oath, notes="Sculpt pose, heavy slow breath." + (" Oath: lower, faster breath." if oath else ""))


def gait(name, period, dx, dz, lift, lean=(0, 0), bob=0.05, oath=False, guarded=False, tuck=None, swing=0.2, twist=5.0):
    """Stance foot travels against the motion at constant speed; swing foot arcs back to the front. dx, dz: half stride, in the direction of travel."""
    keys = []
    n = 16
    rest = B.REST_CONTROLS["rh"]
    for i in range(n):
        p = i / n
        t = p * period
        def foot(phase):
            phase %= 1.0
            if phase < 0.5:  # stance: front to back
                u = 1 - phase * 4
                return (dx * u, dz * u, 0.0, 0, 0)
            u = (phase - 0.5) * 2  # swing: back to front
            s = -1 + 2 * (u * u * (3 - 2 * u))
            return (dx * s, dz * s, lift * math.sin(math.pi * u), 0, -10 * math.sin(math.pi * u))
        wave = math.cos(2 * math.pi * p)  # + right foot forward
        hipy = -0.1 - bob * math.cos(4 * math.pi * p) - lean[1]
        k = dict(pel=(0.045 * math.sin(2 * math.pi * p), hipy, -lean[0] * 0.018), pelR=(lean[0], twist * wave, 0.9 * math.sin(2 * math.pi * p)), chest=(lean[1] * 22, -twist * 1.4 * wave, -0.9 * math.sin(2 * math.pi * p)),
                 neck=(-(lean[0] + lean[1] * 22) * 0.75, twist * 0.5 * wave, 0), rf=foot(p), lf=foot(p + 0.5))
        if tuck:
            k["rh"] = tuple(v + d for v, d in zip(tuck, (0, 0, swing * wave)))
            k["haft"], k["face"], k["relb"] = H(30, -52), (0, -0.6, 0.8), (0.7, -0.2, 0.7)
        else:
            k["rh"] = (rest[0], rest[1] + 0.05, rest[2] - swing * wave)
        k["lua"] = (-34, -4, 0) if guarded else (-3 * wave, 0, 1)
        k["lfa"] = (0, -52, 0) if guarded else (0, -2 * wave, 0)
        keys.append((t, k, "lin"))
    return Clip((OATH_KEY if oath else KEY) + name, period, keys, loop=True, priority="Movement", oath=oath, feet_free=[(0, period)], notes="%s: %.1f rig studs per second at speed 1." % (name, 2 * math.hypot(dx, dz) * 2 / period))


# Gait speed at playback 1 in rig studs per second (BossAnimationRules.Locomotion takes these x his scale for the gait rate)
WALK = dict(period=1.5, dz=-0.62, lift=0.2)
RUN = dict(period=0.8, dz=-1.05, lift=0.42)


def locomotion(oath=False):
    tuck = (0.35, -1.45, 0.45)
    out = [gait("WalkForward", WALK["period"], 0, WALK["dz"], WALK["lift"], lean=(3.5, 0.03), oath=oath),
           gait("RunForward", RUN["period"], 0, RUN["dz"], RUN["lift"], lean=(15, 0.3), bob=0.09, guarded=True, tuck=tuck, oath=oath, twist=9.0)]
    if not oath:
        out += [gait("WalkBackward", 1.6, 0, 0.5, 0.16, lean=(1.5, 0.03)), gait("StrafeLeft", 1.5, -0.5, 0, 0.18, lean=(2.5, 0.05), twist=2.0, swing=0.08),
                gait("StrafeRight", 1.5, 0.5, 0, 0.18, lean=(2.5, 0.05), twist=2.0, swing=0.08)]
    return out


def guard_loop(oath=False):
    breath = dict(chest=(GUARD["chest"][0] - 1.2, GUARD["chest"][1], 0), pel=(0.02, -0.26, 0.05))
    a = {**READY, **GUARD}
    return Clip((OATH_KEY if oath else KEY) + "GuardLoop", 1.6, [K(0, **a), K(0.8, **breath)], loop=True, priority="Movement", oath=oath, notes="Tower shield squared to the front, maul drawn back, weight low: left foot leads.")


def recoil(name, length, push, tilt, twist=0.0, reach=0.0, priority="Action3", notes="", base=None):
    base = dict(base or READY)
    b_pel = base["pel"]
    hit = dict(pel=(b_pel[0] + push[0], b_pel[1] + push[1], b_pel[2] + push[2]), pelR=(base["pelR"][0] + tilt[0] * 0.6, base["pelR"][1] + twist * 0.6, tilt[2] * 0.6), chest=(base["chest"][0] + tilt[0], base["chest"][1] + twist, tilt[2]), neck=(base["neck"][0] + tilt[0] * 0.6, base["neck"][1], 0))
    return Clip(KEY + name, length, [K(0, **base), K(length * 0.22, "snap", **hit), K(length, "io", **base)], priority=priority, notes=notes)


def reactions():
    out = [recoil("GuardHit", 0.45, (0, -0.1, 0.34), (-5, 0, 0), base={**READY, **GUARD}, notes="A blow on the shield: he gives a little ground and resets."),
           recoil("DeflectRecoil", 0.6, (0.06, -0.08, 0.42), (-11, 0, 3), twist=7, notes="His swing turned aside: weapon arm thrown back."),
           recoil("HitLightFront", 0.4, (0, -0.05, 0.14), (-5, 0, 0), notes="Light flinch; he barely moves."),
           recoil("HitLightBack", 0.4, (0, -0.05, -0.14), (6, 0, 0), notes="Light flinch from behind."),
           recoil("HitLightLeft", 0.4, (0.12, -0.05, 0), (0, 0, -5), twist=-5, notes="Light flinch from his left."),
           recoil("HitLightRight", 0.4, (-0.12, -0.05, 0), (0, 0, 5), twist=5, notes="Light flinch from his right."),
           recoil("HitHeavyFront", 0.8, (0, -0.22, 0.34), (-13, 0, 0), notes="Heavy recoil."),
           recoil("HitHeavyBack", 0.8, (0, -0.22, -0.34), (14, 0, 0), notes="Heavy recoil from behind.")]
    knee = dict(pel=(0.05, -1.02, 0.2), pelR=(13, 8, 0), chest=(19, 8, 0), neck=(-3, 0, 0), rf=(0.0, 1.0, 0.55, 0, -55), lf=(0.05, -0.62, 0, 0, 0), rknee=(0.3, 0, -1), lknee=(0, 0, -1), rh=(0.55, -1.32, -0.6), haft=H(28, -22), face=(0, -1, 0.3), lua=(-38, 0, -8), lfa=(-24, -22, -6), lookW=0.0)
    sag = dict(pel=(0.05, -1.06, 0.22), chest=(22, 8, 0), neck=(-1, 0, 0), rh=(0.55, -1.28, -0.6))
    out += [Clip(KEY + "PostureBreak", 1.0, [K(0, **READY), K(0.14, "snap", pel=(0.02, -0.25, 0.42), pelR=(-14, 7, 0), chest=(-20, 8, 0), neck=(13, 0, 0), rf=(0, 0.22, 0, 0, 0), lua=(-4, 0, -22), lfa=(0, 14, -12), rh=(0.72, -1.6, 0.55), haft=H(45, -50), face=(0, -0.8, 0.5)),
                                             K(0.46, "io", pel=(0.05, -0.65, 0.3), pelR=(5, 8, 0), chest=(6, 8, 0), neck=(2, 0, 0), rf=(0.0, 0.6, 0.3, 0, -26), lf=(0.05, -0.3, 0, 0, 0), rh=(0.6, -1.5, -0.2), haft=H(30, -40), face=(0, -0.9, 0.3)), K(1.0, "in", **knee)], priority="Action3", feet_free=[(0, 1)], notes="Stance broken: thrown back, the guard flies wide, and he sinks to his right knee."),
            Clip(KEY + "StaggerLoop", 1.4, [K(0, **knee), K(0.7, **sag)], loop=True, priority="Action3", feet_free=[(0, 1.4)], notes="Held on the knee, breathing hard, open to the deathblow."),
            Clip(KEY + "StaggerRecover", 0.8, [K(0, **knee), K(0.42, "io", pel=(0.02, -0.5, 0.1), pelR=(6, 2, 0), chest=(8, 2, 0), neck=(-4, 0, 0), rf=(0, 0.3, 0.2, 0, -18), lf=(0, -0.2, 0, 0, 0), rh=(0.4, -1.6, -0.35), haft=H(28, -40), lknee=(0, 0, -1)), K(0.8, "io", **READY)], priority="Action3", feet_free=[(0, 0.8)], notes="Heaves himself back up."),
            Clip(KEY + "DeathblowVictim", 2.2, [K(0, **knee), K(0.22, "snap", pel=(0.05, -0.86, 0.34), pelR=(-9, 8, 0), chest=(-14, 8, 0), neck=(15, 0, 0)), K(0.9, "io", pel=(0.05, -0.98, 0.3), pelR=(9, 6, 0), chest=(14, 6, 0), neck=(0, 0, 0), lua=(-4, 0, -16), lfa=(0, 8, -8)), K(1.5, "in", pel=(0.05, -1.08, 0.18), pelR=(20, 6, 0), chest=(29, 6, 0), neck=(-14, 0, 0), rh=(0.55, -1.0, -0.7)), K(2.2, "io", pel=(0.05, -1.12, 0.14), pelR=(24, 6, 0), chest=(34, 6, 0), neck=(-20, 0, 0), rh=(0.55, -0.82, -0.72))], priority="Action4", feet_free=[(0, 2.2)], notes="Takes the deathblow on the knee: head snaps back, then the great body bows."),
            Clip(KEY + "Death", 3.0, [K(0, **READY), K(0.24, "snap", pel=(0, -0.26, 0.4), pelR=(-12, 6, 0), chest=(-18, 6, 0), neck=(16, 0, 0), lua=(-4, 0, -14), lfa=(0, 8, -8)), K(0.85, "io", pel=(0.03, -0.72, 0.32), pelR=(6, 8, 0), chest=(10, 8, 0), neck=(4, 0, 0), rf=(0, 0.62, 0.34, 0, -30), lf=(0.05, -0.3, 0, 0, 0), rknee=(0.3, 0, -1), lknee=(0, 0, -1), rh=(0.55, -1.5, -0.3), haft=H(30, -35), face=(0, -0.9, 0.3)),
                                       K(1.35, "in", pel=(0.05, -1.06, 0.2), pelR=(14, 8, 0), chest=(21, 8, 0), neck=(-8, 0, 0), rf=(0, 1.0, 0.55, 0, -55), lf=(0.05, -0.62, 0, 0, 0), rh=(0.55, -1.2, -0.6), haft=H(28, -22), face=(0, -1, 0.3), lua=(-38, 0, -6), lfa=(-24, -24, 0)), K(2.2, "io", pel=(0.05, -1.14, 0.1), pelR=(25, 8, 0), chest=(36, 8, 0), neck=(-24, 0, 0), rh=(0.55, -0.72, -0.78), lua=(-52, 0, -6), lfa=(-44, -26, 0)), K(3.0, "io", pel=(0.05, -1.16, 0.08), pelR=(29, 8, 0), chest=(40, 8, 0), neck=(-28, 0, 0), rh=(0.55, -0.55, -0.82), lua=(-56, 0, -6), lfa=(-50, -26, 0))], priority="Action4", feet_free=[(0, 3)], notes="Killed on his feet: staggers, sinks to the right knee and dies kneeling, head down behind the shield; the body fades there.")]
    return out


def library():
    out = [idle(), idle(True), strike(), strike(True), transform(), iron_charge(), colossal_hammer(), lightning_spear(False), lightning_spear(True), quickstep(False), quickstep(True), guard_loop(), guard_loop(True)]
    for fn in (iron_hook, shield_ram, anvil_drop, ox_yoke, rampart_rush, bell_breaker):
        out += [fn(False), fn(True)]
    out += locomotion(False) + locomotion(True) + reactions()
    return out
