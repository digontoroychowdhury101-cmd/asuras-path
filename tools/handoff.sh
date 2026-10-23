#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

BRANCH="ux/onboarding-overhaul"
MSG="${1:-chore: sync progress between computers}"

echo "=========================================================="
echo " Handing off to the other computer..."
echo "=========================================================="

# 1. Rebuild the place so places/AsurasPath.rbxlx matches the latest code/assets
echo "[1/4] Rebuilding places/AsurasPath.rbxlx..."
if command -v python3 >/dev/null 2>&1; then
    python3 tools/build.py
elif command -v python >/dev/null 2>&1; then
    python tools/build.py
fi

# 2. Stage all project files
echo "[2/4] Staging changes..."
git add src/ assets/ default.project.json places/ outputs/ tools/ docs/ PROJECT_STATE.md CLAUDE.md CHATGPT_CUSTOM_INSTRUCTIONS.md 2>/dev/null || true

# 3. Commit if there are changes
if ! git diff --cached --quiet; then
    echo "[3/4] Committing: '$MSG'..."
    git commit -m "$MSG"
else
    echo "[3/4] Working tree already clean; no new commit needed."
fi

# 4. Pull remote changes with rebase and push
echo "[4/4] Syncing with GitHub..."
git pull --rebase origin "$BRANCH"
git push origin "$BRANCH"

echo "=========================================================="
echo " ✅ Handoff complete! All changes are pushed to GitHub."
echo " The other computer can now run: git pull origin $BRANCH"
echo "=========================================================="
