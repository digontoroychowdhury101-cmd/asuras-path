@echo off
setlocal

cd /d "%~dp0\.."

set BRANCH=ux/onboarding-overhaul
set MSG=%~1
if "%MSG%"=="" set MSG=chore: sync progress between computers

echo ==========================================================
echo  Handing off to the other computer...
echo ==========================================================

echo [1/4] Rebuilding places/AsurasPath.rbxlx...
where python >nul 2>nul
if %ERRORLEVEL% equ 0 (
    python tools\build.py
) else (
    py tools\build.py
)

echo [2/4] Staging changes...
git add src/ assets/ default.project.json places/ outputs/ tools/ docs/ PROJECT_STATE.md CLAUDE.md CHATGPT_CUSTOM_INSTRUCTIONS.md

echo [3/4] Committing...
git diff --cached --quiet
if %ERRORLEVEL% neq 0 (
    git commit -m "%MSG%"
) else (
    echo Working tree already clean; no new commit needed.
)

echo [4/4] Syncing with GitHub...
git pull --rebase origin %BRANCH%
git push origin %BRANCH%

echo ==========================================================
echo  [OK] Handoff complete! All changes are pushed to GitHub.
echo  The other computer can now run: git pull origin %BRANCH%
echo ==========================================================
endlocal
