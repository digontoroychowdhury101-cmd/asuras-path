#!/usr/bin/env python3
"""Cross-platform launcher and protocol compatibility shim for Roblox Studio MCP.
Finds StudioMCP on macOS or Windows and bridges stdio.
Shims MCP protocolVersion negotiation so newer Roblox Studio builds don't fail client validation.
"""
import sys
import os
import glob
import json
import platform
import subprocess
import threading

def find_binary():
    system = platform.system()
    if system == "Darwin":
        mac_bin = "/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP"
        if os.path.exists(mac_bin):
            return mac_bin
        return None
    elif system == "Windows":
        local_app_data = os.environ.get("LOCALAPPDATA", "")
        pattern = os.path.join(local_app_data, "Roblox", "Versions", "*", "StudioMCP.exe")
        candidates = glob.glob(pattern)
        if not candidates:
            prog_files = os.environ.get("ProgramFiles(x86)", "C:\\Program Files (x86)")
            pattern2 = os.path.join(prog_files, "Roblox", "Versions", "*", "StudioMCP.exe")
            candidates = glob.glob(pattern2)
        if candidates:
            return max(candidates, key=os.path.getmtime)
        return None
    return None

def main():
    binary = find_binary()
    if not binary:
        sys.stderr.write("[ERROR] StudioMCP binary not found. Ensure Roblox Studio is installed.\n")
        sys.exit(1)

    proc = subprocess.Popen(
        [binary] + sys.argv[1:],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=sys.stderr,
        bufsize=0
    )

    requested_protocol_version = ["2024-11-05"]
    init_response_handled = [False]

    def forward_in():
        try:
            for line in iter(sys.stdin.readline, ""):
                if not line:
                    break
                try:
                    data = json.loads(line)
                    if data.get("method") == "initialize":
                        params = data.get("params", {})
                        if "protocolVersion" in params:
                            requested_protocol_version[0] = params["protocolVersion"]
                except Exception:
                    pass
                proc.stdin.write(line.encode("utf-8"))
                proc.stdin.flush()
        except Exception:
            pass
        finally:
            try:
                proc.stdin.close()
            except Exception:
                pass

    def forward_out():
        try:
            for line in iter(proc.stdout.readline, b""):
                if not line:
                    break
                if not init_response_handled[0]:
                    try:
                        text = line.decode("utf-8", errors="replace")
                        data = json.loads(text)
                        if "result" in data and "protocolVersion" in data["result"]:
                            # Echo back whatever protocol version the client requested
                            data["result"]["protocolVersion"] = requested_protocol_version[0]
                            line = (json.dumps(data) + "\n").encode("utf-8")
                            init_response_handled[0] = True
                    except Exception:
                        pass
                sys.stdout.buffer.write(line)
                sys.stdout.buffer.flush()
        except Exception:
            pass

    t_in = threading.Thread(target=forward_in, daemon=True)
    t_out = threading.Thread(target=forward_out, daemon=True)

    t_in.start()
    t_out.start()

    sys.exit(proc.wait())

if __name__ == "__main__":
    main()
