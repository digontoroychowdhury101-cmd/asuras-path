#!/usr/bin/env python3
"""Keep one local Studio test alive for native viewport recording.

Usage: python3 -u tools/qa/recording_session.py CONFIRMED_STUDIO OUTDIR
Commands on stdin: ground (closer ground wind view), sample (16 s visible plant transforms), report, traverse (normal camera at entry),
walk (12 s ordinary forward/jump/dash inputs), stop. This does not record the desktop itself.
Use the native recorder with a viewport-only selection and save into OUTDIR.

Wind uses a player-height observer camera, with the mock character parked in the empty arena
to avoid interrupting setup. Traversal returns to the production camera and normal player controls.
An actual portal touch first establishes the production camera's Monastery arrival heading.
No lighting, quality, geometry, combat, health, HUD or progression override is applied.
"""
import argparse
import json
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

from bamboo_capture import call, lua, studio_mcp
from foliage_capture import PROBE


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("studio")
    parser.add_argument("outdir", type=Path)
    parser.add_argument("--activate-window", type=int, help="explicitly authorized macOS Studio window ID; focus Studio through the approved CLI helper")
    args = parser.parse_args()
    args.outdir.mkdir(parents=True, exist_ok=True)
    if (args.outdir / "session.json").exists():
        parser.error("choose a new directory; an existing recording manifest is never overwritten")
    c, sid = studio_mcp.Client(), args.studio
    owned = camera = inserted = False
    shot = "wide"
    result = {"kind": "native video setup; seeded observer wind / normal-camera scripted traversal",
              "createdUtc": datetime.now(timezone.utc).isoformat(), "restoration_errors": []}
    def activate():
        if args.activate_window is None:
            return
        root = Path(__file__).resolve().parents[2]
        completed = subprocess.run(["/usr/bin/swift", "-module-cache-path", str(root / "work/swift-module-cache"),
                                    str(Path(__file__).with_name("studio_activate.swift")), str(args.activate_window)],
                                   cwd=root, check=True, capture_output=True, text=True, timeout=15)
        result.setdefault("activationEvents", []).append(json.loads(completed.stdout))
    def turn():
        activate()
        result["cameraTurn"] = json.loads(lua(c, sid, "Client", """local c=workspace.CurrentCamera
local u=game.UserInputService local v=u:CreateVirtualInput() assert(v,'testing input unavailable')
local function yaw() local l=c.CFrame.LookVector return math.atan2(-l.X,-l.Z) end
local function wrap(a) return (a+math.pi)%(2*math.pi)-math.pi end
local before=yaw()
v:SendMouseDelta(Vector2.new(100,0)) task.wait(.6)
local afterProbe=yaw() local gain=-wrap(afterProbe-before)/100
assert(math.abs(gain)>.00001,'normal camera did not receive relative mouse input')
v:SendMouseDelta(Vector2.new(afterProbe/gain,0)) task.wait(.8)
local l=c.CFrame.LookVector
return game.HttpService:JSONEncode({method='documented VirtualInput.SendMouseDelta; production camera',
beforeYaw=before,measuredRadiansPerPixel=gain,frame={c.CFrame:GetComponents()},look={l.X,l.Y,l.Z}})"""))
        assert result["cameraTurn"]["look"][2] < -.75, "normal camera does not face into Bamboo Pass"
        print("READY_TRAVERSE: normal camera faces Bamboo; walk sends ordinary inputs", flush=True)
    try:
        state = call(c, sid, "get_studio_state")[1]
        assert "Client" not in state and "Server" not in state, "start from Edit"
        activate()
        call(c, sid, "start_stop_play", is_start=True)
        owned = True
        deadline = time.monotonic() + 30
        while True:
            state = call(c, sid, "get_studio_state")[1]
            if "Client" in state and "Server" in state:
                ready = json.loads(lua(c, sid, "Client", """local p=game.Players.LocalPlayer
return game.HttpService:JSONEncode({ready=p and p:GetAttribute('AsuraClientReady')==true,
prologue=p and p.PlayerGui:FindFirstChild('AsuraPrologue')~=nil})"""))
                if ready.get("prologue"):
                    call(c, sid, "user_keyboard_input", datamodel_type="Client", actions=[{"action": "keyPress", "key_code": "Space"}])
                if ready.get("ready") and not ready.get("prologue"):
                    break
            if time.monotonic() > deadline:
                raise RuntimeError("owned Play session did not become ready")
            time.sleep(.25)
        lua(c, sid, "Client", "local v=workspace.CurrentCamera.ViewportSize assert(v.X>=200 and v.Y>=100,'inactive viewport') return 'viewport active'")
        source = """local s=game.ServerScriptService.AsurasPath.Services
assert(require(s.PersistenceService).IsMock,'mock persistence required')
local cs=require(s.CharacterService) local p=game.Players:GetPlayers()[1]
local origin=p.Character:GetPivot()
local portalTouches=0
local f=Instance.new('BindableFunction') f.Name='Control'
f.OnInvoke=function(op)
 if op=='Portal' then
  local portal=workspace.Sanctuary:FindFirstChild('PortalTrigger',true)
  assert(portal and portal:IsA('BasePart'),'normal Sanctuary portal missing')
  portal.Touched:Once(function(hit) if hit:IsDescendantOf(p.Character) then portalTouches+=1 end end)
  cs.Teleport(p.UserId,CFrame.new(portal.Position-Vector3.yAxis*(portal.Size.Y/2-3.2)))
 elseif op=='Wind' then cs.Teleport(p.UserId,CFrame.new(-90,3.2,-1470))
 elseif op=='Traverse' then cs.Teleport(p.UserId,CFrame.new(0,3.2,-1126))
 elseif op=='Restore' then cs.Teleport(p.UserId,origin) end
 local r=p.Character.HumanoidRootPart
 return game.HttpService:JSONEncode({position={r.Position.X,r.Position.Y,r.Position.Z},
 health=p.Character.Humanoid.Health,region=p:GetAttribute('AsuraRegion'),encounter=p:GetAttribute('AsuraEncounter'),portalTouches=portalTouches})
end f.Parent=script"""
        lua(c, sid, "Server", "local s=Instance.new('Script') s.Name='AsuraRecordingSession' s.Source=" + json.dumps(source) + " s.Parent=game.ServerScriptService return 'inserted'")
        inserted = True
        lua(c, sid, "Server", "return game.ServerScriptService.AsuraRecordingSession:WaitForChild('Control',8).Name")
        result["portalSeed"] = json.loads(lua(c, sid, "Server", "return game.ServerScriptService.AsuraRecordingSession.Control:Invoke('Portal')"))
        time.sleep(3)
        result["portalArrival"] = json.loads(lua(c, sid, "Server", "return game.ServerScriptService.AsuraRecordingSession.Control:Invoke('Read')"))
        assert result["portalArrival"]["portalTouches"] > 0 and -750 < result["portalArrival"]["position"][2] < -690, "normal portal arrival failed"
        result["windPlayer"] = json.loads(lua(c, sid, "Server", "return game.ServerScriptService.AsuraRecordingSession.Control:Invoke('Wind')"))
        lua(c, sid, "Client", """local cam=workspace.CurrentCamera
_G.AsuraRecordCamera={cam.CameraType,cam.CFrame,cam.FieldOfView}
_G.AsuraRecordPose=CFrame.lookAt(Vector3.new(1.8,6.5,-1165),Vector3.new(-25,15,-1193))
game.RunService:BindToRenderStep('AsuraNativeRecording',Enum.RenderPriority.Last.Value+50,function()
cam.CameraType=Enum.CameraType.Scriptable cam.CFrame=_G.AsuraRecordPose cam.FieldOfView=70 end)
return 'player-height observer pinned'""")
        camera = True
        time.sleep(5)
        card = lua(c, sid, "Client", "local g=game.Players.LocalPlayer.PlayerGui:FindFirstChild('ControlsCard',true) return tostring(g and g.Visible)")
        if card == "true":
            call(c, sid, "user_keyboard_input", datamodel_type="Client", actions=[{"action": "keyPress", "key_code": "H"}])
            time.sleep(.25)
        lua(c, sid, "Client", "local g=game.Players.LocalPlayer.PlayerGui:FindFirstChild('ControlsCard',true) assert(not g or not g.Visible,'controls card covers recording') return 'unobstructed'")
        result["windStart"] = json.loads(lua(c, sid, "Client", PROBE))
        print("READY_WIND: commands ground / sample / report / traverse / turn / walk / stop", flush=True)
        while True:
            command = input().strip()
            if command == "stop":
                break
            if command == "ground":
                shot = "ground"
                lua(c, sid, "Client", "_G.AsuraRecordPose=CFrame.lookAt(Vector3.new(-8,5.5,-1184),Vector3.new(-25,1.3,-1200)) return 'ground wind camera'")
                time.sleep(3)
                result["groundStart"] = json.loads(lua(c, sid, "Client", PROBE))
                print("READY_GROUND", flush=True)
            elif command == "sample":
                lua(c, sid, "Client", "local function probe() " + PROBE + " end _G.AsuraNativeMotion={} task.spawn(function() for i=1,32 do table.insert(_G.AsuraNativeMotion,game.HttpService:JSONDecode(probe())) task.wait(.5) end end) return '16-second transform sample armed'")
                print("SAMPLING_WIND_16_SECONDS", flush=True)
            elif command == "report":
                result["motion"] = json.loads(lua(c, sid, "Client", "return game.HttpService:JSONEncode(_G.AsuraNativeMotion or {})"))
                result.setdefault("motionSeries", {})[shot] = result["motion"]
                print("SAMPLES", len(result["motion"]), flush=True)
            elif command == "traverse":
                lua(c, sid, "Client", "game.RunService:UnbindFromRenderStep('AsuraNativeRecording') local c=workspace.CurrentCamera local o=_G.AsuraRecordCamera c.CameraType=o[1] c.CFrame=o[2] c.FieldOfView=o[3] return 'production camera restored'")
                result["traverseStart"] = json.loads(lua(c, sid, "Server", "return game.ServerScriptService.AsuraRecordingSession.Control:Invoke('Traverse')"))
                time.sleep(4)
                result["traverseCamera"] = json.loads(lua(c, sid, "Client", "local c=workspace.CurrentCamera return game.HttpService:JSONEncode({frame={c.CFrame:GetComponents()},look={c.CFrame.LookVector.X,c.CFrame.LookVector.Y,c.CFrame.LookVector.Z}})"))
                try:
                    turn()
                except Exception as exc:
                    result["cameraTurnError"] = str(exc)
                    print("NEEDS_VIEWPORT_FOCUS:", str(exc), flush=True)
            elif command == "turn":
                try:
                    turn()
                    result.pop("cameraTurnError", None)
                except Exception as exc:
                    result["cameraTurnError"] = str(exc)
                    print("NEEDS_VIEWPORT_FOCUS:", str(exc), flush=True)
            elif command == "walk":
                assert result.get("cameraTurn", {}).get("look", [0, 0, 1])[2] < -.75, "turn the normal camera before walking"
                actions = [{"action": "keyDown", "key_code": "W"}]
                for ms, key in [(2500, "Q"), (2000, "Space"), (3000, "Q"), (2000, "Space"), (2500, None)]:
                    actions.append({"action": "wait", "wait_time_ms": ms})
                    if key: actions.append({"action": "keyPress", "key_code": key})
                actions.append({"action": "keyUp", "key_code": "W"})
                call(c, sid, "user_keyboard_input", datamodel_type="Client", actions=actions)
                result["traverseEnd"] = json.loads(lua(c, sid, "Server", "return game.ServerScriptService.AsuraRecordingSession.Control:Invoke('Read')"))
                print("TRAVERSE_DONE", json.dumps(result["traverseEnd"]), flush=True)
            else:
                print("Unknown command", flush=True)
            (args.outdir / "session.json").write_text(json.dumps(result, indent=2) + "\n")
    except BaseException as exc:
        result["error"] = str(exc)
        raise
    finally:
        if owned:
            cleanup = [("release keys", lambda: call(c, sid, "user_keyboard_input", datamodel_type="Client", actions=[{"action": "keyUp", "key_code": "W"}, {"action": "keyUp", "key_code": "Space"}]))]
            if camera:
                cleanup.append(("camera", lambda: lua(c, sid, "Client", "game.RunService:UnbindFromRenderStep('AsuraNativeRecording') local c=workspace.CurrentCamera local o=_G.AsuraRecordCamera c.CameraType=o[1] c.CFrame=o[2] c.FieldOfView=o[3] _G.AsuraRecordCamera=nil _G.AsuraRecordPose=nil _G.AsuraNativeMotion=nil return 'restored'")))
            if inserted:
                cleanup.append(("player and probe", lambda: lua(c, sid, "Server", "game.ServerScriptService.AsuraRecordingSession.Control:Invoke('Restore') game.ServerScriptService.AsuraRecordingSession:Destroy() return 'removed'")))
            cleanup.append(("stop owned test", lambda: call(c, sid, "start_stop_play", is_start=False)))
            def confirm_edit():
                deadline = time.monotonic() + 20
                while True:
                    state = call(c, sid, "get_studio_state")[1]
                    if "Current Studio Mode: Edit" in state:
                        result["ownedTestStopped"] = True
                        return
                    if time.monotonic() > deadline:
                        raise RuntimeError("owned test did not return to Edit")
                    time.sleep(.25)
            cleanup.append(("confirm owned test stopped", confirm_edit))
            for label, action in cleanup:
                try:
                    action()
                except BaseException as exc:
                    result["restoration_errors"].append(label + ": " + str(exc))
        (args.outdir / "session.json").write_text(json.dumps(result, indent=2) + "\n")
        c.close()


if __name__ == "__main__":
    main()
