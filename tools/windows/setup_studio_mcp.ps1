# One-time Windows setup so every Claude chat (the Code tab and the regular chat window) can use
# Roblox Studio's MCP server. Quit Claude first, then run from the repo folder in PowerShell:
#   powershell -ExecutionPolicy Bypass -File tools\windows\setup_studio_mcp.ps1
# It copies start_studio_mcp.cmd to %USERPROFILE%\.claude\ and adds a "roblox-studio" entry to
# %USERPROFILE%\.claude.json (Claude Code, all projects) and %APPDATA%\Claude\claude_desktop_config.json
# (chat window). Each file is backed up to <file>.bak first; nothing else in them is changed.
$ErrorActionPreference = 'Stop'
$claudeDir = Join-Path $env:USERPROFILE '.claude'
New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null
$launcher = Join-Path $claudeDir 'start_studio_mcp.cmd'
Copy-Item (Join-Path $PSScriptRoot 'start_studio_mcp.cmd') $launcher -Force
Write-Host "Launcher: $launcher"

function Add-StudioServer([string]$path, [bool]$codeFormat) {
    $entry = [ordered]@{}
    if ($codeFormat) { $entry.type = 'stdio' }
    $entry.command = 'cmd'
    $entry.args = @('/c', $launcher)
    if ($codeFormat) { $entry.env = [pscustomobject]@{} }
    if (Test-Path $path) {
        Copy-Item $path "$path.bak" -Force
        $raw = [IO.File]::ReadAllText($path)
        $data = if ($raw.Trim()) { $raw | ConvertFrom-Json } else { [pscustomobject]@{} }
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
        $data = [pscustomobject]@{}
    }
    if (-not $data.PSObject.Properties['mcpServers'] -or $null -eq $data.mcpServers) {
        $data | Add-Member -NotePropertyName mcpServers -NotePropertyValue ([pscustomobject]@{}) -Force
    }
    $data.mcpServers | Add-Member -NotePropertyName 'roblox-studio' -NotePropertyValue ([pscustomobject]$entry) -Force
    $json = $data | ConvertTo-Json -Depth 100
    $null = $json | ConvertFrom-Json  # never write a file that does not parse back
    [IO.File]::WriteAllText($path, $json, (New-Object Text.UTF8Encoding $false))
    Write-Host "Added roblox-studio to $path"
}

Add-StudioServer (Join-Path $env:USERPROFILE '.claude.json') $true
$desktop = Join-Path $env:APPDATA 'Claude\claude_desktop_config.json'
$store = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Packages') -Directory -Filter 'Claude_*' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($store -and -not (Test-Path $desktop)) { $desktop = Join-Path $store.FullName 'LocalCache\Roaming\Claude\claude_desktop_config.json' }
Add-StudioServer $desktop $false

$roots = @("$env:LOCALAPPDATA\Roblox\Versions", "${env:ProgramFiles(x86)}\Roblox\Versions", "$env:ProgramFiles\Roblox\Versions")
$exe = Get-ChildItem -Path $roots -Filter 'StudioMCP*.exe' -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($exe) { Write-Host "Found Roblox Studio MCP: $($exe.FullName)" }
else { Write-Warning 'StudioMCP.exe not found yet: update Roblox Studio, then enable "Studio as MCP server" in its Assistant settings.' }
Write-Host 'Done. Restart Claude (Quit from the tray icon, then reopen) and start a new chat.'
