#!/usr/bin/env bash
# Local regression runner. Evidence type: local regression / engine emulation only; a pass here
# says nothing about Studio physics, appearance, real play, audio, hardware or live services.
# The place is built to a temporary file so the saved outputs/AsurasPath.rbxlx (which may hold
# Studio edits) is never overwritten. Set ASURA_BUILD_OUTPUT to choose another path; run
# `python3 tools/build.py` on its own to deliberately rebuild the saved place.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

LUAU="work/bin/luau/luau"
LUAU_COMPILE="work/bin/luau/luau-compile"

if [ ! -f "$LUAU" ]; then
    if command -v luau >/dev/null 2>&1; then
        LUAU="luau"
        LUAU_COMPILE="luau-compile"
    else
        echo "Error: Luau binary not found in work/bin/luau/luau or on PATH."
        exit 1
    fi
fi

BUILD_OUTPUT="${ASURA_BUILD_OUTPUT:-${TMPDIR:-/tmp}/AsurasPath_verify.rbxlx}"

echo "=========================================================="
echo " Running Full Verification Suite for Asura's Path"
echo "=========================================================="

echo "[1/14] Testing Asura Stage 1..."
"$LUAU" tools/test_asura_stage1.luau

echo "[2/14] Testing Asura Stage 2..."
python3 tools/test_asura_stage2.py

echo "[3/14] Testing Asura Stage 3..."
"$LUAU" tools/test_asura_stage3.luau

echo "[4/14] Testing Weapons & Spells Contracts..."
"$LUAU" tools/test_weapons_and_spells.luau

echo "[5/14] Testing Weapons & Spells Server Runtime..."
python3 tools/test_weapons_and_spells_runtime.py

echo "[6/14] Testing Profile Integrity & Migrations..."
"$LUAU" tools/test_profile_integrity.luau

echo "[7/14] Testing Movement Controller & Kinetics..."
python3 tools/test_movement.py

echo "[8/14] Testing Boss Encounters & Runtime..."
"$LUAU" tools/test_boss_encounters.luau
python3 tools/test_boss_runtime.py

echo "[9/14] Testing Objectives System..."
python3 tools/test_objectives.py

echo "[10/14] Testing Progression, Lore, Review & Campaign Region Regressions..."
"$LUAU" tools/test_progression_and_lore.luau
python3 tools/test_progression_runtime.py
python3 tools/test_review_regressions.py
python3 tools/test_campaign_regions.py
python3 tools/test_campaign_build.py
python3 tools/lune_compat.py --all

echo "[11/14] Testing Backend Persistence & Commercial Systems (local mocks)..."
"$LUAU" tools/test_backend.luau
"$LUAU" tools/test_commercial_systems.luau

echo "[12/14] Testing Audiovisual Modules & Imported Media (engine fakes)..."
python3 tools/test_audiovisual.py

echo "[13/14] Syntax-compiling every source script..."
find src -name '*.luau' -print0 | xargs -0 "$LUAU_COMPILE" --null

echo "[14/14] Compiling Roblox Place to $BUILD_OUTPUT ..."
python3 tools/build.py --output "$BUILD_OUTPUT"

echo "=========================================================="
echo " SUCCESS: All local checks passed; place built at $BUILD_OUTPUT"
echo " (saved outputs/AsurasPath.rbxlx left unchanged)"
echo "=========================================================="
