"""Amberfall Ravine hero aqueduct (lane M4): Amber_Aqueduct_Hero, 120 x 82 x 26 studs, sub-meshes Piers / Arches / Deck.

  "C:/Program Files/Blender Foundation/Blender 5.2/blender" -b -P tools/blender/overworld/amberfall_hero.py

Supersedes: the hero_silhouettes.py blockout of Ravine_Aqueduct_Arch stays on disk as the placeholder; this is the refined replacement with the same
size and sub-mesh names (src/shared/BiomeDressing.luau slot Ravine_Aqueduct_Arch). Linked via workers/23a-amber-kit.md (the lead links it from LEDGER.md).
New file because the hero is its own family run (one script run per family).
Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

Layout: two tiers. Lower: 5 battered-pier arch bays on a 22 pitch (clear span 17, springline 36), cornice course, then an upper arcade of 10 smaller
arches (pitch 11, clear span 8.4), then the water-channel deck with parapets; a taller end pylon with a stepped cap at each end.
"""
from pathlib import Path

FAMILY = "hero"
_here = Path(__file__).resolve().parent
exec(compile((_here / "amberfall_common.py").read_text(encoding="utf-8"), "amberfall_common.py", "exec"), globals())
exec(compile((_here / "amberfall_aqueduct_lib.py").read_text(encoding="utf-8"), "amberfall_aqueduct_lib.py", "exec"), globals())

HB = float(os.environ.get("HERO_BEV", "0.06"))


def hero():
    rr = random.Random(2601)
    P, A, D = bmesh.new(), bmesh.new(), bmesh.new()
    pitch, pw, span = 22.0, 5.0, 17.0
    z_cornice, z_up0, z_up_spring, z_deck = 51.0, 53.4, 63.0, 72.0
    for i in range(5):  # lower tier
        cx = -44.0 + pitch * i
        bay(P, A, D, rr, cx, span, pw, 0.0, 18.0, 13.0, 36.0, 8.5, 2.8, -2.0, z_cornice, bw_=1.8, bd=4.0, clip=None, piers=(i == 0, True), n=15, ch=2.4, bev=HB)
    brick_h(D, -56.0, 56.0, z_cornice, z_up0, 0.0, 15.0, rr, bw=(4.0, 6.5), bev=HB)  # cornice course
    for i in range(10):  # upper arcade
        cx = -49.5 + 11.0 * i + 0.0
        bay(P, A, D, rr, cx, 8.4, 2.6, 0.0, 11.0, 10.0, z_up_spring, 4.2, 1.8, z_up0, z_deck, clip=None, piers=(i == 0, True), n=11, ch=2.4, bev=HB)
    deck(D, rr, -56.0, 56.0, z_deck, 0.0, 13.0, bev=HB)
    for sg in (-1, 1):  # end pylons: tall stepped towers capping each end
        x = sg * 56.0
        z = -2.0
        for w, h in ((8.0, 10.0), (7.4, 24.0), (6.8, 24.0), (6.2, 20.4)):
            bx(P, x, 0.0, z, w, 20.0 if w > 7 else 18.0, h + 0.2, bev=0.12)
            z += h
        bx(D, x, 0.0, z, 8.0, 21.0, 1.4, bev=0.12)  # cap slab at 80.8 -> finial
        bx(D, x, 0.0, z + 1.4, 4.6, 12.0, 1.3, bev=0.1)
        bx(D, x, 0.0, z + 2.7, 2.2, 5.0, 1.0, bev=0.08)
    obj("Amber_Aqueduct_Hero", "Piers", P, MATS["Amb_Stone"])
    obj("Amber_Aqueduct_Hero", "Arches", A, MATS["Amb_StoneDark"])
    obj("Amber_Aqueduct_Hero", "Deck", D, MATS["Amb_Stone"])


BUILD = [("Amber_Aqueduct_Hero", hero)]
prep()
built_mats()
run_family(BUILD)
