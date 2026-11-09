#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
cd "${SHEN_ROOT:-$H/../../../../..}"
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
shots=(c1_Idle c2_Idle c1_WalkForward c2_WalkForward c1_RunForward c1_Guandao_L1 c2_Guandao_L1 c1_Guandao_Heavy)
for c in $shots; do SHEN_BAKE_DIR=$S/clothframes SHEN_SHOT_SUFFIX=_oldc SHEN_CLOTH_SIM=$S/headcloth/ClothSim.luau SHEN_CLOTH_DIR=$S/headcloth python3 tools/animation/opening_cast/cloth_bake.py $c > $S/iso_old_$c.log 2>&1 &
  SHEN_BAKE_DIR=$S/clothframes SHEN_SHOT_SUFFIX=_newc python3 tools/animation/opening_cast/cloth_bake.py $c > $S/iso_new_$c.log 2>&1 & done; wait
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/blender/shen_import/mesh_clash.py -- $S/iso_old.json 3 ${^shots}_oldc > $S/iso_old.log 2>&1 &
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/blender/shen_import/mesh_clash.py -- $S/iso_new.json 3 ${^shots}_newc > $S/iso_new.log 2>&1 &
wait; echo ISODONE
