#!/usr/bin/env python3
"""Short Baize camera evidence in normal Studio combat (seeded placement, no stat overrides).

Requires a confirmed local Play session with mock persistence. Starts through the normal gate
interaction, uses the production lock-on input/camera, and restores the player origin afterwards.
No geometry, lighting, graphics, HUD, combat rules or health override is applied. Ordinary combat
can teach lock-on and kill the local mock character; nothing is written to live persistence.
"""
import argparse
import base64
import json
import time
from pathlib import Path

from bamboo_capture import call, lua, studio_mcp

NAME = "AsuraBambooCombatEvidence"
SERVER = r"""
local cs=require(game.ServerScriptService.AsurasPath.Services.CharacterService)
assert(require(game.ServerScriptService.AsurasPath.Services.PersistenceService).IsMock,'mock persistence required')
local p=game.Players:GetPlayers()[1]
local e=assert(p and cs.GetEntity(p.UserId),'live player required')
local origin=e.Model:GetPivot()
local function status()
 local me=cs.GetEntity(p.UserId)
 local bosses={}
 for id,b in cs.Entities() do
  if b.Kind=='Enemy' and b.Model:GetAttribute('AsuraEncounter')=='VenerableBaize' then
   table.insert(bosses,{id=id,name=b.Model.Name,position=tostring(b.Root.Position),state=b.Fighter.State,hp=b.Fighter.ActiveHP})
  end
 end
 return game.HttpService:JSONEncode({encounter=p:GetAttribute('AsuraEncounter'),
  hp=me and me.Fighter.ActiveHP,maxHP=me and me.Fighter.MaxHP,bosses=bosses})
end
local control=Instance.new('BindableFunction') control.Name='Control'
control.OnInvoke=function(op)
 if op=='Start' then
  assert(not p:GetAttribute('AsuraEncounter'),'player already in an encounter')
  cs.Teleport(p.UserId,CFrame.new(0,3.2,-1376))
  local ok,reason=cs.GetHooks().Interact(p.UserId)
  assert(ok,reason)
  cs.Teleport(p.UserId,CFrame.lookAt(Vector3.new(0,3.2,-1460),Vector3.new(0,3.2,-1495)))
 elseif op=='Restore' then
  if cs.GetEntity(p.UserId) then cs.Teleport(p.UserId,origin) end
 end
 return status()
end
control.Parent=script
script:SetAttribute('Ready',true)
"""
CLIENT = r"""
local c=workspace.CurrentCamera local p=game.Players.LocalPlayer
local bosses={}
for _,m in workspace:GetDescendants() do
 if m:IsA('Model') and m:GetAttribute('AsuraKind')=='Enemy' and m:GetAttribute('AsuraEncounter')=='VenerableBaize' then
  local box,size=m:GetBoundingBox() local pos,visible=c:WorldToViewportPoint(box.Position)
  table.insert(bosses,{name=m.Name,centre=tostring(box.Position),size=tostring(size),
   projected=tostring(pos),centreInViewport=visible})
 end
end
return game.HttpService:JSONEncode({camera=tostring(c.CFrame),type=c.CameraType.Name,fov=c.FieldOfView,
 viewport={c.ViewportSize.X,c.ViewportSize.Y},encounter=p:GetAttribute('AsuraEncounter'),
 quality=UserSettings():GetService('UserGameSettings').SavedQualityLevel.Name,bosses=bosses})
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("studio")
    parser.add_argument("outdir", type=Path)
    args = parser.parse_args()
    if args.outdir.exists():
        parser.error("choose a new evidence directory")
    args.outdir.mkdir(parents=True)
    client = studio_mcp.Client()
    sid = args.studio
    report = {"kind": "seeded Studio Baize combat, ordinary camera/lock input; original health and rules",
              "frames": [], "restoration_errors": []}
    inserted = False
    try:
        state = call(client, sid, "get_studio_state")[1]
        assert "Server" in state and "Client" in state, "Play required"
        source = ("assert(not game.ServerScriptService:FindFirstChild('" + NAME + "'),'probe already exists') "
                  "local s=Instance.new('Script') s.Name='" + NAME + "' s.Source=" + json.dumps(SERVER)
                  + " s.Parent=game.ServerScriptService return 'probe inserted'")
        lua(client, sid, "Server", source)
        inserted = True
        lua(client, sid, "Server", "local s=game.ServerScriptService." + NAME + " local deadline=os.clock()+5 "
            "repeat task.wait(.05) until s:GetAttribute('Ready') or os.clock()>deadline assert(s:GetAttribute('Ready'),'probe not ready') return 'ready'")
        report["start"] = json.loads(lua(client, sid, "Server", "return game.ServerScriptService." + NAME + ".Control:Invoke('Start')"))
        call(client, sid, "user_keyboard_input", datamodel_type="Client", actions=[{"action": "keyPress", "key_code": "X"}])
        started = time.monotonic()
        for i in range(8):
            result, _ = call(client, sid, "screen_capture", capture_id=f"baize_{i:02}")
            picture = next(x for x in result["content"] if x["type"] == "image")
            suffix = "png" if "png" in picture.get("mimeType", "") else "jpg"
            name = f"baize_{i:02}.{suffix}"
            (args.outdir / name).write_bytes(base64.b64decode(picture["data"]))
            report["frames"].append({"file": name, "seconds": time.monotonic() - started,
                                      "client": json.loads(lua(client, sid, "Client", CLIENT)),
                                      "server": json.loads(lua(client, sid, "Server", "return game.ServerScriptService." + NAME + ".Control:Invoke('Status')"))})
            print(f"captured {name}", flush=True)
            time.sleep(.25)
    finally:
        if inserted:
            try:
                report["restored"] = json.loads(lua(client, sid, "Server", "return game.ServerScriptService." + NAME + ".Control:Invoke('Restore')"))
                lua(client, sid, "Server", "game.ServerScriptService." + NAME + ":Destroy() return 'probe removed'")
            except Exception as exc:
                report["restoration_errors"].append(str(exc))
        (args.outdir / "manifest.json").write_text(json.dumps(report, indent=2) + "\n")
        client.close()


if __name__ == "__main__":
    main()
