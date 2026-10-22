@echo off
setlocal enabledelayedexpansion

REM Search for the newest StudioMCP.exe in %LOCALAPPDATA%\Roblox\Versions\
set "LATEST_STUDIOMCP="
for /f "delims=" %%F in ('dir "%LOCALAPPDATA%\Roblox\Versions\StudioMCP.exe" /s /b /o:-d 2^>nul') do (
    set "LATEST_STUDIOMCP=%%F"
    goto :found
)

REM Fallback search in Program Files (x86)
for /f "delims=" %%F in ('dir "%ProgramFiles(x86)%\Roblox\Versions\StudioMCP.exe" /s /b /o:-d 2^>nul') do (
    set "LATEST_STUDIOMCP=%%F"
    goto :found
)

echo [ERROR] StudioMCP.exe not found under %%LOCALAPPDATA%%\Roblox\Versions. Make sure Roblox Studio is installed. 1>&2
exit /b 1

:found
"%LATEST_STUDIOMCP%" %*
exit /b %ERRORLEVEL%
