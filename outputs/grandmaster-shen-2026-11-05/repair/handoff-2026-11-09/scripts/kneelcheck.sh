#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
# usage: kneelcheck.sh TAG clip1 clip2 ...   (clip as P2_DeathblowVictim) export, cloth-bake (current sim), mesh-clash; prints the robe-in-leg pairs
cd "${SHEN_ROOT:-$H/../../../../..}"
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
tag=$1; shift
for c in $@; do python3 tools/animation/opening_cast/export.py shen GrandmasterShen_$c > $S/kc_exp_${tag}_$c.log 2>&1 & done; wait
grep -hE "^(OK|FIX)" $S/kc_exp_${tag}_*.log | cut -c1-70
shots=(); for c in $@; do shots+=c${c[2]}_${c[4,-1]}; done
for sh in $shots; do SHEN_SHOT_SUFFIX=_$tag python3 tools/animation/opening_cast/cloth_bake.py $sh > $S/kc_bake_${tag}_$sh.log 2>&1 & done; wait
rm -f $S/kc_${tag}.json
for sh in $shots; do /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/blender/shen_import/mesh_clash.py -- $S/kc_${tag}_$sh.json 2 ${sh}_$tag > $S/kc_clash_${tag}_$sh.log 2>&1 & done; wait
python3 - $S $tag $shots <<'PY'
import json, sys
S, tag, shots = sys.argv[1], sys.argv[2], sys.argv[3:]
for sh in shots:
    d = json.load(open("%s/kc_%s_%s.json" % (S, tag, sh)))[sh + "_" + tag]["pairs"]
    rows = sorted(((k, v) for k, v in d.items() if ("Robe" in k or "Mantle" in k or "Sleeve" in k) and "weapon" not in k and v["deepest"] >= 0.05), key=lambda kv: -kv[1]["share"] * kv[1]["deepest"])
    print(sh, " | ".join("%s %d%% %.3f f%d" % (k, 100 * v["share"], v["deepest"], v["frame"]) for k, v in rows[:6]))
PY
