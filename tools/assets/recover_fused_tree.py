#!/usr/bin/env python3
"""Recover editable copies of the uploaded monument without modifying Studio.

python3 tools/assets/recover_fused_tree.py CONFIRMED_STUDIO NEW_DIRECTORY [--parts name,name]
Uses Roblox's permission-checked EditableMesh reader. Keeps original vertex positions,
triangle winding, corner UVs/normals, template transforms and uploaded PBR references.
This is a derived copy of the uploaded geometry, not the missing original Blender master.
"""
from __future__ import annotations

import argparse
import base64
import gzip
import hashlib
import json
import struct
import sys
import zlib
from pathlib import Path

try:
    from compression import zstd
except ImportError:
    zstd = None

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "qa"))
from bamboo_capture import call, lua, studio_mcp

ROOT = Path(__file__).resolve().parents[2]
READ = """local p=game.ServerStorage.AsuraAssets.FusedTreeStatue:FindFirstChild(PART_NAME,true)
assert(p and p:IsA('MeshPart'),'uploaded monument part missing')
local mesh=game.AssetService:CreateEditableMeshAsync(p.MeshContent)
assert(mesh,'editable mesh memory budget exhausted')
local ok,data=pcall(function()
 local vs,ns,us,fs={},{},{},{} local vi,ni,ui={},{},{}
 for _,id in mesh:GetVertices() do
  local v=mesh:GetPosition(id) vi[id]=#vs vs[#vs+1]={v.X,v.Y,v.Z}
 end
 local function normal(id)
  if ni[id]==nil then local n=mesh:GetNormal(id) ni[id]=#ns ns[#ns+1]={n.X,n.Y,n.Z} end
  return ni[id]
 end
 local function uv(id)
  if ui[id]==nil then local u=mesh:GetUV(id) ui[id]=#us us[#us+1]={u.X,u.Y} end
  return ui[id]
 end
 for i,f in mesh:GetFaces() do
  local v,n,u=mesh:GetFaceVertices(f),mesh:GetFaceNormals(f),mesh:GetFaceUVs(f)
  assert(#v==3 and #n==3 and #u==3,'expected triangulated mesh with corner attributes')
  fs[#fs+1]={vi[v[1]],vi[v[2]],vi[v[3]],normal(n[1]),normal(n[2]),normal(n[3]),uv(u[1]),uv(u[2]),uv(u[3])}
  if i%1000==0 then task.wait() end
 end
 local s=p:FindFirstChildOfClass('SurfaceAppearance') local maps={}
 if s then for _,k in {'ColorMapContent','NormalMapContent','RoughnessMapContent','MetalnessMapContent'} do
  maps[k]=s[k].Uri
 end end
 return {name=p.Name,mesh=p.MeshContent.Uri,vertices=vs,normals=ns,uvs=us,faces=fs,
  frame={p.CFrame:GetComponents()},size={p.Size.X,p.Size.Y,p.Size.Z},
  meshSize={p.MeshSize.X,p.MeshSize.Y,p.MeshSize.Z},doubleSided=p.DoubleSided,maps=maps,
  renderFidelity=p.RenderFidelity.Name,canCollide=p.CanCollide,canQuery=p.CanQuery}
end)
mesh:Destroy()
assert(ok,tostring(data))
local e=game:GetService('EncodingService') local raw=buffer.fromstring(game.HttpService:JSONEncode(data))
if COMPRESS then raw=e:CompressBuffer(raw,Enum.CompressionAlgorithm.Zstd,5) end
_G.AsuraMeshRecovery=buffer.tostring(e:Base64Encode(raw))
return tostring(#_G.AsuraMeshRecovery)"""

READ_MAP = """local image=game.AssetService:CreateEditableImageAsync(Content.fromUri(MAP_URI))
assert(image,'editable image unavailable') local size=image.Size
local ok,raw=pcall(function() return image:ReadPixelsBuffer(Vector2.zero,size) end)
image:Destroy() assert(ok,tostring(raw))
local e=game:GetService('EncodingService')
if COMPRESS then raw=e:CompressBuffer(raw,Enum.CompressionAlgorithm.Zstd,5) end
_G.AsuraMeshRecovery=buffer.tostring(e:Base64Encode(raw))
return game.HttpService:JSONEncode({size={size.X,size.Y},length=#_G.AsuraMeshRecovery})"""


def transfer(client, studio, length):
    chunks = []
    for offset in range(0, length, 60000):
        chunk = lua(client, studio, "Edit", f"return string.sub(_G.AsuraMeshRecovery,{offset + 1},{min(offset + 60000, length)})")
        assert len(chunk) == min(60000, length - offset), "transport truncated mesh data"
        chunks.append(chunk)
    raw = base64.b64decode("".join(chunks), validate=True)
    lua(client, studio, "Edit", "_G.AsuraMeshRecovery=nil return 'released read buffer'")
    return zstd.decompress(raw) if zstd else raw


def rgba_png(pixels, width, height):
    """Lossless packaging of API-returned RGBA bytes; no pixel modifications."""
    assert len(pixels) == width * height * 4
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    stride = width * 4
    scanlines = b"".join(b"\0" + pixels[y*stride:(y+1)*stride] for y in range(height))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(scanlines)) + chunk(b"IEND", b""))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("studio")
    parser.add_argument("outdir", type=Path)
    parser.add_argument("--parts", help="optional exact uploaded part names")
    parser.add_argument("--maps-only", action="store_true", help="append API-readable map copies to a complete recovery; EditableImage is capped at 1024")
    args = parser.parse_args()
    if args.outdir.exists() and not args.maps_only:
        parser.error("choose a new directory; recovered copies are never overwritten")
    registry = json.loads((ROOT / "assets/FUSED_TREE_STATUE_UPLOADED.json").read_text())
    names = args.parts.split(",") if args.parts else sorted(registry["parts"])
    if set(names) - registry["parts"].keys():
        parser.error("part not in the uploaded monument registry")
    args.outdir.mkdir(parents=True, exist_ok=args.maps_only)
    manifest = {"kind": "read-only recovery of uploaded geometry; not original master",
                "studio": args.studio, "coordinateSystem": "Roblox local mesh, zero-based face indices",
                "cornerLayout": "vertex[3], normal[3], UV[3]", "parts": [], "complete": False}
    if args.maps_only:
        manifest = json.loads((args.outdir / "manifest.json").read_text())
        assert manifest["complete"], "map recovery requires a completed geometry recovery"
        assert not manifest.get("mapRecovery"), "existing recovered maps are never overwritten"
    client = studio_mcp.Client()
    try:
        state = call(client, args.studio, "get_studio_state")[1]
        assert "Client" not in state and "Server" not in state, "recovery requires Edit mode"
        for name in ([] if args.maps_only else names):
            code = READ.replace("PART_NAME", json.dumps(name)).replace("COMPRESS", "true" if zstd else "false")
            length = int(lua(client, args.studio, "Edit", code))
            data = json.loads(transfer(client, args.studio, length))
            expected = registry["parts"][name]
            assert data["mesh"] == expected["MeshId"], f"{name}: source asset differs"
            assert len(data["faces"]) == expected["triangles"], f"{name}: triangle count differs"
            raw = json.dumps(data, separators=(",", ":")).encode()
            packed = gzip.compress(raw, mtime=0)
            file = name + ".json.gz"
            (args.outdir / file).write_bytes(packed)
            row = {"name": name, "file": file, "mesh": data["mesh"], "triangles": len(data["faces"]),
                   "vertices": len(data["vertices"]), "bytes": len(packed),
                   "sha256": hashlib.sha256(packed).hexdigest()}
            manifest["parts"].append(row)
            (args.outdir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
            print(f"Recovered {name}: {row['triangles']} triangles, {len(packed)} bytes", flush=True)
        manifest["complete"] = True
        manifest["totalTriangles"] = sum(p["triangles"] for p in manifest["parts"])
        if args.maps_only:
            uris = set()
            for row in manifest["parts"]:
                data = json.loads(gzip.decompress((args.outdir / row["file"]).read_bytes()))
                uris.update(v for v in data["maps"].values() if v)
            folder = args.outdir / "maps"
            folder.mkdir()
            manifest["mapRecovery"] = {"kind": "EditableImage readback, capped at 1024; not proof of native renderer resolution", "maps": []}
            for uri in sorted(uris):
                code = READ_MAP.replace("MAP_URI", json.dumps(uri)).replace("COMPRESS", "true" if zstd else "false")
                meta = json.loads(lua(client, args.studio, "Edit", code))
                raw = transfer(client, args.studio, meta["length"])
                packed = rgba_png(raw, *meta["size"])
                file = uri.split("//", 1)[-1] + ".png"
                (folder / file).write_bytes(packed)
                manifest["mapRecovery"]["maps"].append({"uri": uri, "size": meta["size"], "file": "maps/" + file,
                    "sha256": hashlib.sha256(packed).hexdigest()})
                print(f"Read map {uri}: {meta['size']}", flush=True)
    finally:
        try:
            lua(client, args.studio, "Edit", "_G.AsuraMeshRecovery=nil return 'released read buffer'")
        except BaseException as exc:
            manifest["cleanupError"] = str(exc)
        (args.outdir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        client.close()


if __name__ == "__main__":
    main()
