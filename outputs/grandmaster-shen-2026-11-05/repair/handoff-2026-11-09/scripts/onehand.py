"""Trial (2026-11-09), reversible: Shen holds the glaive in his right hand only. Imported after shen_lib, before shen_clips.library().
Every clip named in ONEHAND_CLIPS (comma list of short names, e.g. P2_Idle; "all" for every clip) loses its lead-hand channels (lhw, ltw, lt,
lsl, lelb, lpole, lua, lfa, lha) and gets a free left arm instead: a guard (open palm forward of his left side) at both ends, and at each contact a
counterbalance (arm out to his left side and down) held through the cut and eased back to the guard.
The weapon's own keys (rp, haft, face, rsl) are untouched, so reach, contacts and timing are the two-handed clip's."""
import os
import shen_lib as L

def _v(name, default):
    return tuple(float(x) for x in os.environ.get(name, default).split(","))

GUARD = dict(lua=_v("OH_G_UA", "-30,10,-20"), lfa=_v("OH_G_FA", "-60,0,0"), lha=_v("OH_G_HA", "0,0,0"))
BAL = dict(lua=_v("OH_B_UA", "20,0,-45"), lfa=_v("OH_B_FA", "-15,0,0"), lha=_v("OH_B_HA", "0,0,0"))
DROP = ("lhw", "ltw", "lt", "lsl", "lelb", "lpole", "lua", "lfa", "lha", "lhand", "lhand_slant")
WANT = [x.strip() for x in os.environ.get("ONEHAND_CLIPS", "").split(",") if x.strip()]

import shen_clips as SC

_library = SC.library


def onehand(clip):
    length = float(clip.length)
    keys = [(t, {k: v for k, v in c.items() if k not in DROP}, e) for t, c, e in clip.keys]
    keys += [(0.0, dict(lhw=0.0, ltw=0.0, **GUARD), "io"), (length, dict(lhw=0.0, ltw=0.0, **GUARD), "io")]
    contacts = list(clip.contacts or ())
    for tc in contacts:
        keys += [(max(0.05, tc - 0.12), dict(BAL), "io"), (min(length - 0.05, tc + 0.3), dict(BAL), "io")]
    if contacts:
        keys += [(min(length - 0.02, max(contacts) + 0.65), dict(GUARD), "io")]
    clip.keys = sorted(keys, key=lambda k: k[0])
    clip.onehand = True
    return clip


def library(*a, **k):
    out = _library(*a, **k)
    for clip in out:
        short = clip.name.replace("GrandmasterShen_", "")
        if WANT and ("all" in WANT or short in WANT):
            onehand(clip)
    return out


SC.library = library
