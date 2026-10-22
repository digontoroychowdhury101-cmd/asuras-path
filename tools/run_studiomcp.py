#!/usr/bin/env python3
"""Cross-platform launcher for Roblox Studio's bundled MCP proxy.
On macOS: runs /Applications/RobloxStudio.app/Contents/MacOS/StudioMCP.
On Windows: dynamically discovers the newest StudioMCP.exe inside %LOCALAPPDATA%\\Roblox\\Versions\\.
"""
import sys
import os
import glob
import platform

def main():
    system = platform.system()
    if system == "Darwin":
        mac_bin = "/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP"
        if os.path.exists(mac_bin):
            os.execv(mac_bin, [mac_bin] + sys.argv[1:])
        else:
            sys.stderr.write(f"[ERROR] StudioMCP not found at {mac_bin}\n")
            sys.exit(1)
    elif system == "Windows":
        local_app_data = os.environ.get("LOCALAPPDATA", "")
        pattern = os.path.join(local_app_data, "Roblox", "Versions", "*", "StudioMCP.exe")
        candidates = glob.glob(pattern)
        if not candidates:
            prog_files = os.environ.get("ProgramFiles(x86)", "C:\\Program Files (x86)")
            pattern2 = os.path.join(prog_files, "Roblox", "Versions", "*", "StudioMCP.exe")
            candidates = glob.glob(pattern2)
        if candidates:
            newest = max(candidates, key=os.path.getmtime)
            os.execv(newest, [newest] + sys.argv[1:])
        else:
            sys.stderr.write("[ERROR] StudioMCP.exe not found under %LOCALAPPDATA%\\Roblox\\Versions\\\n")
            sys.exit(1)
    else:
        sys.stderr.write(f"[ERROR] Unsupported OS: {system}\n")
        sys.exit(1)

if __name__ == "__main__":
    main()
