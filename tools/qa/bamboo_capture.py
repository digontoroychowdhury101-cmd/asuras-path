#!/usr/bin/env python3
"""Repeatable player-height Bamboo Pass captures in the unmodified running client.

Usage: python3 tools/qa/bamboo_capture.py STUDIO OUTDIR before|after [view,...]
Requires a confirmed Studio instance already in Play. It never starts Play, changes lighting,
graphics, geometry, actor visibility, HUD visibility, saves, or progression. Temporary server teleports and
client camera pins are restored in finally. These are seeded Studio diagnostics, not earned play.
"""
from __future__ import annotations

import argparse
import base64
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import studio_mcp

# (camera position, target, character root position). Y=6.5 on the valley floor is ordinary
# shoulder-camera height; the crest/ridge views follow their existing +12/+18 elevations.
CAMERAS = {
    "entry": ((1.8, 6.5, -1124), (0, 7, -1174), (0, 3.2, -1135)),
    "close_path": ((1.8, 6.5, -1183), (0, 7, -1223), (0, 3.2, -1194)),
    "ground_transition": ((-10, 5.5, -1200), (-37, 2, -1220), (-17, 3.2, -1205)),
    "crest_shrine": ((1.8, 18.5, -1282), (-24, 4, -1335), (0, 15.2, -1288)),
    "shrine": ((-25, 6.5, -1307), (-36, 4, -1345), (-29, 3.4, -1318)),
    "arena": ((1.8, 6.5, -1374), (0, 6, -1460), (0, 3.2, -1385)),
    "frost_overlook": ((129, 24.5, -1415), (48, 8, -1470), (118, 21.4, -1418)),
    "moon_gate": ((1.8, 6.5, -1550), (0, 12, -1597), (0, 3.2, -1561)),
    # Supplementary close inspection of the fallen trunk/root assembly from the gate path.
    "root_detail": ((-27, 5.5, -1131), (-56, 1.5, -1153), (-24, 3.2, -1127)),
}
BINDING = "AsuraBambooComparison"


def call(client: studio_mcp.Client, sid: str, name: str, **args):
    reply = client.request("tools/call", {"name": name, "arguments": {"studio_id": sid, **args}})
    result = reply.get("result") or {}
    text = "\n".join(c.get("text", "") for c in result.get("content", []) if c.get("type") == "text")
    if reply.get("error") or result.get("isError"):
        raise RuntimeError(f"{name}: {text or reply.get('error')}")
    return result, text


def lua(client, sid, model, code):
    return call(client, sid, "execute_luau", datamodel_type=model, code=code)[1]


def vector(v):
    return "Vector3.new(" + ",".join(map(str, v)) + ")"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("studio", help="exact, already-confirmed Studio id")
    parser.add_argument("outdir", type=Path)
    parser.add_argument("stage", choices=("before", "after"))
    parser.add_argument("views", nargs="?", help="comma-separated views; defaults to every camera")
    parser.add_argument("--cameras", type=Path, help="optional JSON mapping of names to [eye, target, stand] vectors")
    parser.add_argument("--settle", type=float, default=3.0, help="seconds to let lighting and material maps settle")
    parser.add_argument("--cost-seconds", type=float, default=0, help="optional 1..10 second fixed-view cost diagnostic")
    args = parser.parse_args()
    if args.cost_seconds and not 1 <= args.cost_seconds <= 10:
        parser.error("cost-seconds must be 1..10, or zero to disable")
    cameras = json.loads(args.cameras.read_text()) if args.cameras else CAMERAS
    names = args.views.split(",") if args.views else list(cameras)
    if set(names) - cameras.keys():
        parser.error("unknown view(s)")
    for name in names:
        vectors = cameras[name]
        if len(vectors) != 3 or any(len(v) != 3 or any(not isinstance(n, (int, float)) for n in v) for v in vectors):
            parser.error(f"invalid camera vectors for {name}")
    args.outdir.mkdir(parents=True, exist_ok=True)
    manifest_path = args.outdir / f"{args.stage}_cameras.json"
    if manifest_path.exists() or any((args.outdir / f"{args.stage}_{n}.jpg").exists() for n in names):
        parser.error("evidence already exists; choose a new output directory to preserve it")
    client = studio_mcp.Client()
    sid = args.studio
    manifest = {"kind": "seeded Studio running-client diagnostic; original scene and HUD",
                "stage": args.stage, "views": [], "restoration_errors": []}
    saved_server = saved_client = False
    try:
        state = call(client, sid, "get_studio_state")[1]
        if "Client" not in state or "Server" not in state:
            raise RuntimeError("Start Play in the confirmed instance before capturing")
        lua(client, sid, "Client", """local pg=game.Players.LocalPlayer.PlayerGui
assert(not pg:FindFirstChild('AsuraPrologue'),'wait for the normal prologue to finish before capturing')
local card=pg:FindFirstChild('ControlsCard',true)
assert(not card or not card.Visible,'close the normal controls card with Backspace before capturing')
return 'normal gameplay HUD ready'""")
        lua(client, sid, "Server", """local p=game:GetService('Players'):GetPlayers()[1]
assert(p and p.Character and p.Character:FindFirstChild('HumanoidRootPart'),'player character not ready')
_G.AsuraBambooCaptureOrigin={UserId=p.UserId,Frame=p.Character:GetPivot()}
return 'saved server origin'""")
        saved_server = True
        lua(client, sid, "Client", """local c=workspace.CurrentCamera
_G.AsuraBambooCaptureCamera={Type=c.CameraType,Frame=c.CFrame,FOV=c.FieldOfView}
return 'saved camera'""")
        saved_client = True
        for name in names:
            eye, target, stand = cameras[name]
            lua(client, sid, "Server", f"""local s=_G.AsuraBambooCaptureOrigin
local p=game:GetService('Players'):GetPlayerByUserId(s.UserId)
assert(p and p.Character,'player character missing')
p.Character:PivotTo(CFrame.new({vector(stand)}))
p.Character.HumanoidRootPart.AssemblyLinearVelocity=Vector3.zero
return 'positioned'""")
            lua(client, sid, "Client", f"""local rs=game:GetService('RunService')
rs:UnbindFromRenderStep('{BINDING}')
local c=workspace.CurrentCamera local frame=CFrame.lookAt({vector(eye)},{vector(target)})
rs:BindToRenderStep('{BINDING}',Enum.RenderPriority.Last.Value+50,function()
c.CameraType=Enum.CameraType.Scriptable c.FieldOfView=70 c.CFrame=frame end)
return 'pinned'""")
            time.sleep(args.settle)  # regional lighting blend and material-variant maps settle
            metadata = lua(client, sid, "Client", """local p=game:GetService('Players').LocalPlayer
local c=workspace.CurrentCamera local l=game:GetService('Lighting') local a=l:FindFirstChildOfClass('Atmosphere')
local gui={} for _,g in p.PlayerGui:GetChildren() do if g:IsA('ScreenGui') then gui[g.Name]=g.Enabled end end
local function safe(f) local ok,v=pcall(f) return if ok then tostring(v) else 'unavailable' end
return game:GetService('HttpService'):JSONEncode({studioVersion=version(),place=game.Name,
viewport={c.ViewportSize.X,c.ViewportSize.Y},fov=c.FieldOfView,camera=tostring(c.CFrame),
quality=safe(function() return UserSettings():GetService('UserGameSettings').SavedQualityLevel.Name end),
editorQuality=safe(function() return settings().Rendering.QualityLevel.Name end),
maxFramerate=safe(function() return UserSettings():GetService('UserGameSettings').FramerateCap end),
region=p:GetAttribute('AsuraRegion'),encounter=p:GetAttribute('AsuraEncounter'),hud=gui,
tier=p:GetAttribute('LandscapeTier'),foliageRegistered=p:GetAttribute('FoliageRegistered'),
foliageActive=p:GetAttribute('FoliageActive'),foliageShadows=p:GetAttribute('LandscapeFoliageShadows'),
touch=game:GetService('UserInputService').TouchEnabled,
lighting={clock=l.ClockTime,exposure=l.ExposureCompensation,ambient=tostring(l.Ambient),
outdoor=tostring(l.OutdoorAmbient),density=a and a.Density,haze=a and a.Haze},
wind=tostring(workspace.GlobalWind),terrainDecoration=safe(function() return workspace.Terrain.Decoration end)})""")
            result, _ = call(client, sid, "screen_capture", capture_id=f"{args.stage}_{name}")
            images = [c for c in result.get("content", []) if c.get("type") == "image"]
            if not images:
                raise RuntimeError("screen_capture returned no image")
            files = []
            for index, image in enumerate(images):
                ext = "png" if "png" in image.get("mimeType", "") else "jpg"
                suffix = "" if index == 0 else f"_{index}"
                path = args.outdir / f"{args.stage}_{name}{suffix}.{ext}"
                path.write_bytes(base64.b64decode(image["data"]))
                files.append(path.name)
            cost = None
            if args.cost_seconds:
                code = f"_G.AsuraViewCostSeconds={args.cost_seconds}\n" + (Path(__file__).parent / "ViewCost.luau").read_text()
                cost = json.loads(lua(client, sid, "Client", code))
            manifest["views"].append({"name": name, "eye": eye, "target": target, "stand": stand,
                                      "files": files, "settle": args.settle, "conditions": json.loads(metadata), "cost": cost})
            manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
            print(f"Captured {name}: {', '.join(files)}", flush=True)
    finally:
        if saved_client:
            try:
                lua(client, sid, "Client", f"""game:GetService('RunService'):UnbindFromRenderStep('{BINDING}')
local c=workspace.CurrentCamera local s=_G.AsuraBambooCaptureCamera
if s then c.CameraType=s.Type c.FieldOfView=s.FOV c.CFrame=s.Frame end
_G.AsuraBambooCaptureCamera=nil return 'camera restored'""")
            except Exception as exc:
                manifest["restoration_errors"].append(str(exc))
        if saved_server:
            try:
                lua(client, sid, "Server", """local s=_G.AsuraBambooCaptureOrigin
local p=s and game:GetService('Players'):GetPlayerByUserId(s.UserId)
if p and p.Character then p.Character:PivotTo(s.Frame) p.Character.HumanoidRootPart.AssemblyLinearVelocity=Vector3.zero end
_G.AsuraBambooCaptureOrigin=nil return 'player restored'""")
            except Exception as exc:
                manifest["restoration_errors"].append(str(exc))
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
        client.close()


if __name__ == "__main__":
    main()
