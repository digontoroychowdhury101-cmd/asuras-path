#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

LUAU="work/bin/luau/luau"

if [ ! -f "$LUAU" ]; then
    if command -v luau >/dev/null 2>&1; then
        LUAU="luau"
    else
        echo "Error: Luau binary not found in work/bin/luau/luau or on PATH."
        exit 1
    fi
fi

echo "=========================================================="
echo " Running Full Verification Suite for Asura's Path"
echo "=========================================================="

echo "[1/11] Testing Asura Stage 1..."
"$LUAU" tools/test_asura_stage1.luau

echo "[2/11] Testing Asura Stage 2..."
python3 tools/test_asura_stage2.py

echo "[3/11] Testing Asura Stage 3..."
"$LUAU" tools/test_asura_stage3.luau

echo "[4/11] Testing Weapons & Spells Contracts..."
"$LUAU" tools/test_weapons_and_spells.luau

echo "[5/11] Testing Weapons & Spells Server Runtime..."
python3 tools/test_weapons_and_spells_runtime.py

echo "[6/11] Testing Profile Integrity & Migrations..."
"$LUAU" tools/test_profile_integrity.luau

echo "[7/11] Testing Movement Controller & Kinetics..."
python3 tools/test_movement.py

echo "[8/11] Testing Boss Encounters & Runtime..."
python3 tools/test_boss_runtime.py

echo "[9/11] Testing Objectives System..."
python3 tools/test_objectives.py

echo "[10/11] Testing Progression, Lore & Review Regressions..."
"$LUAU" tools/test_progression_and_lore.luau
python3 tools/test_review_regressions.py

echo "[11/11] Compiling Roblox Place..."
python3 tools/build.py

echo "=========================================================="
echo " SUCCESS: All tests passed & outputs/AsurasPath.rbxlx built!"
echo "=========================================================="
