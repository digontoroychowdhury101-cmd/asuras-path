@echo off
REM Try Python first so the protocolVersion shim is active
where python >nul 2>nul
if %ERRORLEVEL% equ 0 (
    python "%~dp0run_studiomcp.py" %*
    exit /b %ERRORLEVEL%
)
where py >nul 2>nul
if %ERRORLEVEL% equ 0 (
    py "%~dp0run_studiomcp.py" %*
    exit /b %ERRORLEVEL%
)

REM Fallback: direct StudioMCP.exe execution
set "LATEST_STUDIOMCP="
for /f "delims=" %%F in ('dir "%LOCALAPPDATA%\Roblox\Versions\StudioMCP.exe" /s /b /o:-d 2^>nul') do (
    set "LATEST_STUDIOMCP=%%F"
    goto :found
)
for /f "delims=" %%F in ('dir "%ProgramFiles(x86)%\Roblox\Versions\StudioMCP.exe" /s /b /o:-d 2^>nul') do (
    set "LATEST_STUDIOMCP=%%F"
    goto :found
)
echo [ERROR] StudioMCP.exe not found under %%LOCALAPPDATA%%\Roblox\Versions. Make sure Roblox Studio is installed. 1>&2
exit /b 1

:found
"%LATEST_STUDIOMCP%" %*
exit /b %ERRORLEVEL%
