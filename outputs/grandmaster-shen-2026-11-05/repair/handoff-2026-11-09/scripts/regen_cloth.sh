#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
# regenerate both phases' cloth with skin_rig's defaults: rig, reach lists from the _pre shots, rig again
cd "${SHEN_ROOT:-$H/../../../../..}"
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
export VECLIB_MAXIMUM_THREADS=1 OMP_NUM_THREADS=1
python3 tools/blender/shen_import/skin_rig.py --cloth-only 1 2 > $S/regen_rig1.log 2>&1 || { echo RIG1_FAIL; exit 1; }
python3 tools/blender/shen_import/cloth_skin_reach.py 1 _pre > $S/regen_reach1.log 2>&1 & python3 tools/blender/shen_import/cloth_skin_reach.py 2 _pre > $S/regen_reach2.log 2>&1 & wait
python3 tools/blender/shen_import/skin_rig.py --cloth-only 1 2 > $S/regen_rig2.log 2>&1 || { echo RIG2_FAIL; exit 1; }
mkdir -p $S/cloth_new; cp work/shen_import/cloth_p?.json work/shen_import/clothskin_reach_p?.json $S/cloth_new/
for f in cloth_p2.json clothskin_reach_p2.json; do cmp -s $S/cloth_new/$f $S/cloth_bd5/$f && echo "$f == bd5" || echo "$f != bd5"; done
echo REGEN_DONE
