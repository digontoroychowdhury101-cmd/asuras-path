@echo off
rem Starts Roblox Studio's bundled MCP proxy (StudioMCP.exe) over stdio for Claude on Windows.
rem Each Studio update installs into a new Roblox\Versions\version-* folder, so this finds the
rem newest copy every time instead of storing a path that the next update would break.
setlocal
set "EXE="
for /f "usebackq delims=" %%F in (`powershell -NoProfile -Command "Get-ChildItem -Path \"$env:LOCALAPPDATA\Roblox\Versions\",\"${env:ProgramFiles(x86)}\Roblox\Versions\",\"$env:ProgramFiles\Roblox\Versions\" -Filter StudioMCP*.exe -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName"`) do set "EXE=%%F"
if not defined EXE (
  echo StudioMCP.exe was not found under Roblox\Versions. Update Roblox Studio and enable its MCP server. 1>&2
  exit /b 1
)
"%EXE%" %*
