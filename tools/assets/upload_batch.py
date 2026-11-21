"""Upload GLBs as Model assets from the cloud window via the Studio MCP bridge; resume-safe ledger (skip entries with assetId).
python tools/assets/upload_batch.py <ledger.json> <prefix>=<dir> ...   (files <= 20,000,000 bytes only; larger ones are listed as skipped: split them with glb_split.py)"""
import hashlib, json, os, subprocess, sys, time
STUDIO, USER = os.environ.get("ASURA_CLOUD_STUDIO", "3a8c18c2-dd52-4834-89ac-3469ff0a5138"), "3148600636"  # cloud window id changes per launch
ledger_path = sys.argv[1]
ledger = json.load(open(ledger_path)) if os.path.exists(ledger_path) else {}
p = subprocess.Popen([sys.executable, "tools/run_studiomcp.py"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, encoding="utf-8")
n = [10]
def call(tool, args):
    n[0] += 1
    p.stdin.write(json.dumps({"jsonrpc": "2.0", "id": n[0], "method": "tools/call", "params": {"name": tool, "arguments": args}}) + "\n"); p.stdin.flush()
    for line in p.stdout:
        try: m = json.loads(line)
        except ValueError: continue
        if m.get("id") == n[0]: return m["result"]["content"][0]["text"]
def body(text): return json.loads(text.split("\n\n", 1)[1])
p.stdin.write(json.dumps({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "lead-upload", "version": "1"}}}) + "\n"); p.stdin.flush()
for line in p.stdout:
    if '"id": 1' in line or '"id":1' in line: break
p.stdin.write(json.dumps({"jsonrpc": "2.0", "method": "notifications/initialized"}) + "\n"); p.stdin.flush()
def save(): json.dump(ledger, open(ledger_path, "w"), indent=1, sort_keys=True)
for spec in sys.argv[2:]:
    prefix, d = spec.split("=", 1)
    for root, _, files in os.walk(d):
        for f in sorted(files):
            if not f.endswith(".glb"): continue
            path = os.path.abspath(os.path.join(root, f)); stem = f[:-4]
            sub = os.path.relpath(root, d).replace(os.sep, "/")
            key = f"{prefix}/{sub}/{stem}" if sub != "." else f"{prefix}/{stem}"
            e = ledger.get(key, {})
            if e.get("assetId"): continue
            size = os.path.getsize(path)
            sha = hashlib.sha256(open(path, "rb").read()).hexdigest()
            if size > 20_000_000:
                ledger[key] = {"file": path, "bytes": size, "sha256": sha, "skipped": "over 20 MB Open Cloud file limit"}; save(); continue
            name = (f"Vesp_{stem}" if prefix == "vesp" else f"{prefix}_{stem}" if sub == "." else f"R2_{sub}_{stem}")[:50]
            if not e.get("operationId"):
                req = {"request": {"assetType": "Model", "displayName": name, "description": f"Asura's Path {key}", "creationContext": {"creator": {"userId": USER}}}}
                t = call("open_cloud_invoke", {"studio_id": STUDIO, "method": "POST", "endpoint": "/assets/v1/assets", "scopes": ["asset:read", "asset:write"],
                                               "body": json.dumps(req), "files": [{"name": "fileContent", "path": path, "contentType": "model/gltf-binary"}]})
                if "200 OK" not in t:
                    ledger[key] = {"file": path, "bytes": size, "sha256": sha, "error": t[:400]}; save(); print("ERR", key, t[:200], flush=True); continue
                e = {"file": path, "bytes": size, "sha256": sha, "displayName": name, "operationId": body(t)["operationId"]}; ledger[key] = e; save()
            for _ in range(40):
                t = call("open_cloud_invoke", {"studio_id": STUDIO, "method": "GET", "endpoint": f"/assets/v1/operations/{e['operationId']}", "scopes": ["asset:read"]})
                b = body(t) if "200 OK" in t else {}
                if b.get("done"):
                    r = b.get("response") or {}
                    e.update(assetId=r.get("assetId"), moderation=(r.get("moderationResult") or {}).get("moderationState"), error=b.get("error")); save(); break
                time.sleep(5)
            print(key, e.get("assetId"), e.get("moderation"), flush=True)
p.stdin.close(); p.terminate()
