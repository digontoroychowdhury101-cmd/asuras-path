# Blender MCP desktop connection

Configured on 29 October 2026 for this Mac's desktop app.

- Blender: 5.2.2 LTS; installed add-on: 1.8, protocol 15.
- MCP server: `mcp-for-blender==2.2.4`, installed from the local package cache into a persistent uv tool environment.
- Runtime: `/Users/digonto/.local/share/uv/tools/mcp-for-blender/bin/mcp-for-blender`.
- Endpoint: `127.0.0.1:9876`.
- App configuration: `/Users/digonto/.codex/config.toml`, server `Blender`.
- Original configuration backup: `/Users/digonto/.codex/config.toml.before-blender-20261029T022725Z`.
- Startup timeout: 60 seconds; tool timeout: 180 seconds.
- MCP process telemetry disabled through `BLENDER_MCP_DISABLE_TELEMETRY=true`.

Four independent MCP sessions passed initialization, discovery of nine tools, scene inspection, and a read-only Python probe. The probe confirmed that the add-on and its scene auto-start setting were enabled. No scene objects were modified. The reported MCP `serverInfo.version` is the SDK version, 1.30.0; the installed Blender server package version is 2.2.4.

Restart the desktop app once to load the new tools into chats, and keep Blender open. Native tool availability in a restarted chat is the remaining verification: the current chat did not gain Blender tools after the configuration change, and computer use cannot control the desktop app's own interface. Blender restart recovery was inspected in the add-on code but was not exercised because the current scene contains unsaved changes.

To check the saved connection again:

```sh
python3 '/Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/blender-connection-2026-10-29/check_connection.py'
```

The checker launches two independent MCP processes, verifies tool discovery, and reads the live scene without editing objects. It exits with status 0 only when both attempts succeed. Python 3.11 or later is required. The saved result is in `connection-check.json`; `blender-mcp.toml` contains the configuration entry that was added.

Permanent uptime cannot be guaranteed: Blender must be running and its local bridge must be available. The installed server uses an absolute executable path and needs no package download at launch.

Desktop MCP configuration reference: https://learn.chatgpt.com/docs/extend/mcp
