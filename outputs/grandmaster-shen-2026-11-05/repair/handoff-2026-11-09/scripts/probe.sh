#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
# usage: probe.sh TAG CLOTHDIR [SIM]   bake the six probe clips as _TAG and mesh-clash them into $S/probe_TAG.json
cd "${SHEN_ROOT:-$H/../../../../..}"
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
export SHEN_BAKE_DIR=$S/bake_snap   # (frozen motion: the full export rewrites work/opening_cast_bake/shen)
tag=$1; cdir=$2; sim=${3:-src/shared/ClothSim.luau}
A=(c2_Idle c1_Flourish); B=(c1_RunForward c2_Flourish); C=(c1_Idle c2_TurnRight)
for g in A B C; do SHEN_CLOTH_SIM=$sim SHEN_CLOTH_DIR=$cdir SHEN_SHOT_SUFFIX=_$tag python3 tools/animation/opening_cast/cloth_bake.py ${(P)g} > $S/probe_bake_${tag}_$g.log 2>&1 & done
wait
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/blender/shen_import/mesh_clash.py -- $S/probe_$tag.json 2 c2_Idle_$tag c1_Flourish_$tag c1_RunForward_$tag c2_Flourish_$tag c1_Idle_$tag c2_TurnRight_$tag > $S/probe_clash_$tag.log 2>&1
echo DONE $tag
