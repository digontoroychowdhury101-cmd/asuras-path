# edgecount.py : (Windows pass 2026-11-11) which clips each part of the glaive-edge fix changes in the repo's keys (Clip.controls, every frame).
#   roll: Clip.edge_roll returns a rolled edge somewhere (as the repo has it; and with roll_edges forced on for the clips that turn it off)
#   carry: the face channel differs from a build with arc(carry_edge=False) forced on every arc call
import os, sys, functools
import numpy as np
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, os.path.join(ROOT, "tools/animation/general_zhao"))
sys.path.insert(0, os.path.join(ROOT, "tools/animation/opening_cast"))
import shen_clips as R
import shen_lib as L

hit = set()
orig_roll = L.Clip.edge_roll
def rec(self, *a, **k):
    out = orig_roll(self, *a, **k)
    if out is not None:
        hit.add(self.name)
    return out
L.Clip.edge_roll = rec

def faces(lib):
    out = {}
    for c in lib:
        out[c.name] = [c.controls(t).get("face") for t in c.frames()]
    return out

lib = R.library()
now = faces(lib)
roll_now = set(hit)
hit.clear()
forced = []
for c in lib:
    if not c.roll_edges:
        forced.append(c.name)
        c.roll_edges = True
        [c.controls(t) for t in c.frames()]
roll_forced = set(hit)

orig_arc = R.arc
R.arc = functools.wraps(orig_arc)(lambda *a, **k: orig_arc(*a, **dict(k, carry_edge=False)))
nocarry = faces(R.library())
R.arc = orig_arc
carry = []
for n, fs in now.items():
    gs = nocarry.get(n)
    if gs is None or len(gs) != len(fs):
        carry.append(n + "(len)")
        continue
    if any((a is None) != (b is None) or (a is not None and not np.allclose(a, b, atol=1e-9)) for a, b in zip(fs, gs)):
        carry.append(n)
short = lambda s: sorted(x.replace("GrandmasterShen_", "") for x in s)
print("roll now (%d):" % len(roll_now), short(roll_now))
print("roll_edges off:", short(forced), "-> would roll:", short(roll_forced - roll_now))
print("carry_edge changes now (%d):" % len(carry), short(carry))
print("either (%d):" % len(set(carry) | roll_now), short(set(carry) | roll_now))
