#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
# usage: probeP1.sh TAG CLOTHDIR [SIM]   bake four P1 clips (dense-cloud motion, frozen in bake_dc) as _TAG and mesh-clash them into $S/probe_TAG.json
cd "${SHEN_ROOT:-$H/../../../../..}"
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
export SHEN_BAKE_DIR=$S/bake_dc
tag=$1; cdir=$2; sim=${3:-src/shared/ClothSim.luau}
G=(c1_GuardLoop c1_WalkForward c1_RunForward c1_Strike)
for g in $G; do SHEN_CLOTH_SIM=$sim SHEN_CLOTH_DIR=$cdir SHEN_SHOT_SUFFIX=_$tag python3 tools/animation/opening_cast/cloth_bake.py $g > $S/probe_bake_${tag}_$g.log 2>&1 & done
wait
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/blender/shen_import/mesh_clash.py -- $S/probe_$tag.json 2 ${G/%/_$tag} > $S/probe_clash_$tag.log 2>&1
grep -h "Error\|SystemExit\|non-finite\|not finite" $S/probe_bake_${tag}_*.log $S/probe_clash_$tag.log | head -3
echo DONE $tag
