#!/usr/bin/env python3
"""Capture timed running-client wind frames, retaining the normal scene, HUD and wind.

python3 tools/qa/foliage_capture.py CONFIRMED_STUDIO OUTDIR [--frames 24]
This is a discrete frame sequence from Studio, not a continuous gameplay video. It pins an
ordinary player-height camera temporarily and restores the camera and character in finally.
The recorded timestamps, unaltered source images and actual client transforms accompany it.
"""
from __future__ import annotations

import argparse
import base64
import json
import time
from pathlib import Path

from bamboo_capture import call, lua, studio_mcp

PIN = "AsuraFoliageEvidence"
PROBE = """local p=game.Players.LocalPlayer local c=workspace.CurrentCamera
local plants={}
for _,m in game.CollectionService:GetTagged('AsuraWindPlant') do
 local base=m:GetAttribute('WindBase')
 if m:IsDescendantOf(workspace) and typeof(base)=='CFrame' and (base.Position-c.CFrame.Position).Magnitude<55 then
  local kind=m:GetAttribute('WindKind')
  if not plants[kind] then
   local part=nil
   for _,d in m:GetDescendants() do if d:IsA('BasePart') and (kind~='Bamboo' or d.Name:find('Culm',1,true)) then part=d break end end
   if part then
    local root=part:GetAttribute('WindRootLocal')
    local tip=part.CFrame:PointToWorldSpace(Vector3.new(0,part.Size.Y/2,0))
    plants[kind]={name=part:GetFullName(),frame={part.CFrame:GetComponents()},tip={tip.X,tip.Y,tip.Z},
     rootError=typeof(root)=='Vector3' and (part.CFrame:PointToWorldSpace(root)-base.Position).Magnitude or nil}
   end
  end
 end
end
return game.HttpService:JSONEncode({clock=os.clock(),plants=plants,wind=tostring(workspace.GlobalWind),
active=p:GetAttribute('FoliageActive'),registered=p:GetAttribute('FoliageRegistered'),
updateMs=p:GetAttribute('FoliageUpdateMs'),peakMs=p:GetAttribute('FoliagePeakUpdateMs'),
viewport={c.ViewportSize.X,c.ViewportSize.Y},fov=c.FieldOfView,region=p:GetAttribute('AsuraRegion')})"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("studio")
    parser.add_argument("outdir", type=Path)
    parser.add_argument("--frames", type=int, default=24)
    args = parser.parse_args()
    if not 4 <= args.frames <= 120:
        parser.error("frames must be 4..120")
    if args.outdir.exists():
        parser.error("choose a new output directory to preserve existing evidence")
    args.outdir.mkdir(parents=True)
    client, sid = studio_mcp.Client(), args.studio
    manifest = {"kind": "timed discrete Studio running-client wind sequence; seeded camera",
                "camera": {"eye": [1.8, 6.5, -1165], "target": [-25, 15, -1193], "fov": 70},
                "frames": [], "restoration_errors": []}
    saved_server = saved_client = False
    try:
        lua(client, sid, "Client", """local pg=game.Players.LocalPlayer.PlayerGui
assert(not pg:FindFirstChild('AsuraPrologue'),'wait for normal prologue')
local c=workspace.CurrentCamera assert(c.ViewportSize.X>100 and c.ViewportSize.Y>100,'inactive viewport')
_G.AsuraWindEvidenceCamera={Type=c.CameraType,Frame=c.CFrame,FOV=c.FieldOfView} return 'ready'""")
        saved_client = True
        lua(client, sid, "Server", """local p=game.Players:GetPlayers()[1]
assert(p and p.Character,'character missing')
_G.AsuraWindEvidenceOrigin={UserId=p.UserId,Frame=p.Character:GetPivot()}
p.Character:PivotTo(CFrame.new(-6,3.2,-1174))
p.Character.HumanoidRootPart.AssemblyLinearVelocity=Vector3.zero return 'positioned'""")
        saved_server = True
        lua(client, sid, "Client", f"""local c=workspace.CurrentCamera local rs=game.RunService
rs:UnbindFromRenderStep('{PIN}')
local frame=CFrame.lookAt(Vector3.new(1.8,6.5,-1165),Vector3.new(-25,15,-1193))
rs:BindToRenderStep('{PIN}',Enum.RenderPriority.Last.Value+50,function()
c.CameraType=Enum.CameraType.Scriptable c.CFrame=frame c.FieldOfView=70 end) return 'pinned'""")
        time.sleep(3)
        manifest["conditions"] = json.loads(lua(client, sid, "Client", """local l=game.Lighting
local a=l:FindFirstChildOfClass('Atmosphere')
return game.HttpService:JSONEncode({version=version(),quality=UserSettings():GetService('UserGameSettings').SavedQualityLevel.Name,
clock=l.ClockTime,exposure=l.ExposureCompensation,ambient=tostring(l.Ambient),outdoor=tostring(l.OutdoorAmbient),
density=a and a.Density,haze=a and a.Haze,art=workspace:GetAttribute('BambooArtPass')})"""))
        start = time.monotonic()
        for i in range(args.frames):
            began = time.monotonic() - start
            result, _ = call(client, sid, "screen_capture", capture_id=f"wind_{i:03}")
            ended = time.monotonic() - start
            images = [c for c in result.get("content", []) if c.get("type") == "image"]
            if not images:
                raise RuntimeError("screen_capture returned no image")
            img = images[0]
            ext = "png" if "png" in img.get("mimeType", "") else "jpg"
            path = args.outdir / f"frame_{i:03}.{ext}"
            path.write_bytes(base64.b64decode(img["data"]))
            metrics = json.loads(lua(client, sid, "Client", PROBE))
            manifest["frames"].append({"file": path.name, "requestStartSeconds": began,
                                       "requestEndSeconds": ended, "clientAfterCapture": metrics})
            (args.outdir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
            print(f"frame {i + 1}/{args.frames} at {ended:.3f}s", flush=True)
            time.sleep(0.1)
    finally:
        if saved_client:
            try:
                lua(client, sid, "Client", f"""game.RunService:UnbindFromRenderStep('{PIN}')
local s=_G.AsuraWindEvidenceCamera local c=workspace.CurrentCamera
if s then c.CameraType=s.Type c.CFrame=s.Frame c.FieldOfView=s.FOV end
_G.AsuraWindEvidenceCamera=nil return 'camera restored'""")
            except Exception as exc:
                manifest["restoration_errors"].append(str(exc))
        if saved_server:
            try:
                lua(client, sid, "Server", """local s=_G.AsuraWindEvidenceOrigin
local p=s and game.Players:GetPlayerByUserId(s.UserId)
if p and p.Character then p.Character:PivotTo(s.Frame) p.Character.HumanoidRootPart.AssemblyLinearVelocity=Vector3.zero end
_G.AsuraWindEvidenceOrigin=nil return 'player restored'""")
            except Exception as exc:
                manifest["restoration_errors"].append(str(exc))
        (args.outdir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        client.close()


if __name__ == "__main__":
    main()
