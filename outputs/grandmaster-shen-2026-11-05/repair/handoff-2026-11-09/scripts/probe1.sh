#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
# usage: probe1.sh TAG CLOTHDIR [SIM]   bake the three P1 probe clips as _TAG and mesh-clash them into $S/probe_TAG.json
cd "${SHEN_ROOT:-$H/../../../../..}"
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
tag=$1; cdir=$2; sim=${3:-src/shared/ClothSim.luau}
for g in c1_Idle c1_RunForward c1_Flourish; do SHEN_CLOTH_SIM=$sim SHEN_CLOTH_DIR=$cdir SHEN_SHOT_SUFFIX=_$tag python3 tools/animation/opening_cast/cloth_bake.py $g > $S/probe_bake_${tag}_$g.log 2>&1 & done
wait
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/blender/shen_import/mesh_clash.py -- $S/probe_$tag.json 2 c1_Idle_$tag c1_RunForward_$tag c1_Flourish_$tag > $S/probe_clash_$tag.log 2>&1
grep -h "Error\|SystemExit\|non-finite\|not finite" $S/probe_bake_${tag}_*.log $S/probe_clash_$tag.log | head -3
echo DONE $tag
