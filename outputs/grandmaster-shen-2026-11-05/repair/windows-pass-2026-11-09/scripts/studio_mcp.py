# studio_mcp.py CALLS.json [OUT.json] : one StudioMCP session over stdio (Roblox's own MCP server, as tools/run_studiomcp.py launches it);
# CALLS.json is a list of {"tool": name, "args": {...}} or {"list": true}; each result is printed (text parts) and saved to OUT.json.
import glob, json, os, subprocess, sys, threading, time, queue

calls = json.load(open(sys.argv[1], encoding="utf-8"))
out_path = sys.argv[2] if len(sys.argv) > 2 else None
cands = glob.glob(os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "Versions", "*", "StudioMCP.exe"))
binary = max(cands, key=os.path.getmtime)
proc = subprocess.Popen([binary], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=0)
q = queue.Queue()


def reader():
    for line in iter(proc.stdout.readline, b""):
        try:
            q.put(json.loads(line.decode("utf-8", "replace")))
        except Exception:
            pass


threading.Thread(target=reader, daemon=True).start()
nid = [0]


def send(msg):
    proc.stdin.write((json.dumps(msg) + "\n").encode("utf-8"))
    proc.stdin.flush()


def request(method, params, timeout=600):
    nid[0] += 1
    i = nid[0]
    send({"jsonrpc": "2.0", "id": i, "method": method, "params": params})
    end = time.time() + timeout
    while time.time() < end:
        try:
            m = q.get(timeout=1)
        except queue.Empty:
            continue
        if m.get("id") == i:
            return m
    return {"error": "timeout"}


init = request("initialize", {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "shen-check", "version": "1"}}, 60)
send({"jsonrpc": "2.0", "method": "notifications/initialized"})
results = []
for c in calls:
    if c.get("list"):
        r = request("tools/list", {}, 60)
        names = [t["name"] for t in r.get("result", {}).get("tools", [])]
        print("TOOLS:", names)
        results.append({"list": r.get("result", r)})
        continue
    if c.get("sleep"):
        time.sleep(float(c["sleep"]))
        continue
    r = request("tools/call", {"name": c["tool"], "arguments": c.get("args", {})}, float(c.get("timeout", 600)))
    res = r.get("result", r)
    texts = [p.get("text", "") for p in res.get("content", []) if p.get("type") == "text"] if isinstance(res, dict) and "content" in res else [json.dumps(res)[:4000]]
    if isinstance(res, dict):
        import base64
        for k, p in enumerate(res.get("content", [])):
            if p.get("type") == "image" and c.get("save"):
                open(c["save"], "wb").write(base64.b64decode(p["data"]))
                texts.append("image saved " + c["save"])
        res = {kk: vv for kk, vv in res.items() if kk != "content"} | {"content": [p for p in res.get("content", []) if p.get("type") != "image"]}
    print("== %s %s" % (c["tool"], "ERROR" if (isinstance(res, dict) and res.get("isError")) or "error" in r else ""))
    for t in texts:
        print(t[:20000])
    results.append({"tool": c["tool"], "result": res})
if out_path:
    json.dump(results, open(out_path, "w", encoding="utf-8"), indent=1)
proc.stdin.close()
try:
    proc.wait(timeout=5)
except Exception:
    proc.kill()
