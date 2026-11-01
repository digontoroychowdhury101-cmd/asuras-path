#!/usr/bin/env python3
"""Verify the configured desktop MCP connection without changing the Blender scene."""
import argparse
import datetime
import json
import os
from pathlib import Path
import queue
import subprocess
import threading
import time
import tomllib


def check(server, timeout):
    started = time.monotonic()
    env = {**os.environ, **server.get("env", {})}
    process = subprocess.Popen(
        [server["command"], *server.get("args", [])],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        text=True, bufsize=1, env=env, cwd=server.get("cwd"),
    )
    messages = queue.Queue()
    logs = []

    def read_stdout():
        for line in process.stdout:
            messages.put(line)
        messages.put(None)

    def read_stderr():
        for line in process.stderr:
            logs.append(line.rstrip())

    threading.Thread(target=read_stdout, daemon=True).start()
    threading.Thread(target=read_stderr, daemon=True).start()
    request_id = 0

    def send(message):
        process.stdin.write(json.dumps({"jsonrpc": "2.0", **message}) + "\n")
        process.stdin.flush()

    def request(method, params):
        nonlocal request_id
        request_id += 1
        current_id = request_id
        send({"id": current_id, "method": method, "params": params})
        deadline = time.monotonic() + timeout
        while True:
            try:
                line = messages.get(timeout=max(0.001, deadline - time.monotonic()))
            except queue.Empty:
                raise TimeoutError(f"{method} did not respond within {timeout}s")
            if line is None:
                raise RuntimeError("MCP server exited: " + "\n".join(logs[-10:]))
            message = json.loads(line)
            if "method" in message:
                if "id" in message:
                    send({"id": message["id"], "error": {
                        "code": -32601, "message": "Diagnostic client does not handle server requests"
                    }})
                continue
            if message.get("id") == current_id:
                if "error" in message:
                    raise RuntimeError(str(message["error"]))
                return message["result"]

    def call(name, arguments):
        result = request("tools/call", {"name": name, "arguments": arguments})
        texts = [item["text"] for item in result.get("content", []) if item.get("type") == "text"]
        if result.get("isError") or any(text.startswith("Error") for text in texts):
            raise RuntimeError("\n".join(texts))
        return "\n".join(texts)

    try:
        initialized = request("initialize", {
            "protocolVersion": "2024-11-05", "capabilities": {},
            "clientInfo": {"name": "desktop-blender-connection-check", "version": "1.0"},
        })
        send({"method": "notifications/initialized"})
        names = [tool["name"] for tool in request("tools/list", {}).get("tools", [])]
        for name in ["get_scene_info", "execute_blender_code"]:
            if name not in names:
                raise RuntimeError(f"Required MCP tool is missing: {name}; available: {names}")
        scene = call("get_scene_info", {"limit": 5})
        probe = call("execute_blender_code", {"code": (
            "import bpy, json\n"
            "print('CONNECTION_VERIFIED ' + json.dumps({"
            "'blender_version': bpy.app.version_string, "
            "'scene': bpy.context.scene.name, "
            "'object_count': len(bpy.context.scene.objects), "
            "'addon_enabled': 'blender_mcp' in bpy.context.preferences.addons, "
            "'auto_start': getattr(bpy.context.scene, 'blendermcp_auto_start_server', None), "
            "'port': getattr(bpy.context.scene, 'blendermcp_port', None)}))"
        )})
        if "CONNECTION_VERIFIED" not in probe:
            raise RuntimeError("Blender did not return the verification marker: " + probe)
        return {"success": True, "seconds": round(time.monotonic() - started, 3),
                "server_info": initialized.get("serverInfo"),
                "protocol_version": initialized.get("protocolVersion"),
                "tool_count": len(names), "tools": names, "scene": scene, "probe": probe}
    finally:
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=3)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=Path.home() / ".codex/config.toml")
    parser.add_argument("--server", default="Blender")
    parser.add_argument("--attempts", type=int, default=2)
    parser.add_argument("--timeout", type=float, default=30)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    report = {"checked_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "config": str(args.config), "server": args.server, "attempts": []}
    try:
        server = tomllib.loads(args.config.read_text())["mcp_servers"][args.server]
        if not server.get("enabled", True):
            raise RuntimeError("The Blender MCP server is disabled in the app configuration")
        if args.attempts < 1:
            raise ValueError("--attempts must be positive")
        for _ in range(args.attempts):
            report["attempts"].append(check(server, args.timeout))
        report["success"] = True
    except Exception as error:
        report.update(success=False, error=f"{type(error).__name__}: {error}")
    output = json.dumps(report, indent=2)
    if args.report:
        args.report.write_text(output + "\n")
    print(output)
    raise SystemExit(0 if report["success"] else 1)


if __name__ == "__main__":
    main()
