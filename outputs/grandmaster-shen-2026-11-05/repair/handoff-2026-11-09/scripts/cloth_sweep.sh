#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
# usage: cloth_sweep.sh TAG MARGIN PCT
cd "${SHEN_ROOT:-$H/../../../../..}"
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
SHEN_CLOTH_MARGIN=$2 SHEN_CLOTH_PCT=$3 python3 tools/blender/shen_import/skin_rig.py --cloth-only > $S/sw_$1_rig.log 2>&1
for c in c1_Idle c1_WalkForward c2_WalkForward c1_RunForward; do SHEN_BAKE_DIR=$S/clothframes SHEN_SHOT_SUFFIX=_$1 python3 tools/animation/opening_cast/cloth_bake.py $c > $S/sw_$1_$c.log 2>&1 & done; wait
for c in c1_Idle c1_WalkForward c2_WalkForward c1_RunForward; do /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/blender/shen_import/mesh_clash.py -- $S/sw_$1_$c.json 3 ${c}_$1 > $S/sw_$1_$c.clash 2>&1 & done; wait
python3 - $1 <<'PY'
import json, sys
tag = sys.argv[1]
S = "/private/tmp/claude-501/-Users-digonto-Documents/55e7af69-a636-414f-b9b3-9e34929af331/scratchpad"
for c in ("c1_Idle", "c1_WalkForward", "c2_WalkForward", "c1_RunForward"):
    try:
        r = json.load(open(f"{S}/sw_{tag}_{c}.json"))[f"{c}_{tag}"]["pairs"]
    except Exception as e:
        print(c, "ERR", e); continue
    cl = {k: v for k, v in r.items() if " in weapon" not in k and not k.startswith("weapon in") and k.split(" in ")[0] not in ("LowerTorso", "UpperTorso", "Head", "RightUpperArm", "RightLowerArm", "LeftUpperArm", "LeftLowerArm", "RightHand", "LeftHand")}
    tot = sum(v["share"] for v in cl.values())
    deep = max([v["deepest"] for v in cl.values()] or [0])
    top = sorted(cl.items(), key=lambda kv: -kv[1]["share"])[:4]
    print("%-16s cloth share-sum %.2f deepest %.3f | %s" % (c, tot, deep, "  ".join("%s %.0f%% %.3f" % (k, 100 * v["share"], v["deepest"]) for k, v in top)))
PY
