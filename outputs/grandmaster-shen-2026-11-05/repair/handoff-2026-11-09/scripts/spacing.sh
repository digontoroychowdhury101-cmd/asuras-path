#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
# usage: spacing.sh SP TAG   regenerate garment samples at spacing SP into $S/TAG (cloth_pN.json etc.), restoring work/shen_import after
cd "${SHEN_ROOT:-$H/../../../../..}"
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
sp=$1; tag=$2; mkdir -p $S/$tag
for ph in 1 2; do SHEN_SKIN_SPACING=$sp /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/blender/shen_import/cloth_skin.py -- $ph > $S/$tag/cs_$ph.log 2>&1; done
python3 tools/blender/shen_import/cloth_skin_reach.py 1 _pre & python3 tools/blender/shen_import/cloth_skin_reach.py 2 _pre & wait
python3 tools/blender/shen_import/skin_rig.py --cloth-only 1 2 > $S/$tag/rig.log 2>&1
cp work/shen_import/clothskin_p?.json work/shen_import/clothskin_reach_p?.json work/shen_import/cloth_p?.json $S/$tag/
cp $S/sp20new/* work/shen_import/
grep "skin samples" $S/$tag/rig.log
