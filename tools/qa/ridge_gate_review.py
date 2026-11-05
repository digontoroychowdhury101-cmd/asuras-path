#!/usr/bin/env python3
"""Owned local Play diagnostic: real Z hold opens the ridge gate; inspect art/collision alignment.

Seeded avatar positions and observer camera only. No health, AI, lighting, quality or reward overrides.
Usage: python3 -u tools/qa/ridge_gate_review.py CONFIRMED_STUDIO NEW_OUTDIR
"""
import argparse
import base64
import json
import time
from pathlib import Path

from bamboo_capture import call, lua, studio_mcp


AUDIT = """local map=assert(workspace:FindFirstChild('Map_BambooPass'))
local gate=assert(map:FindFirstChild('RidgeGate')) local p=game.Players:GetPlayers()[1]
local leaves,visuals,wings={},{},{} local count,bad=0,0
for _,d in gate:GetChildren() do
 if d:IsA('BasePart') and d.Name=='GateLeaf' then table.insert(leaves,d)
 elseif d:IsA('Model') and d.Name=='GateLeaf_Cedar' then table.insert(visuals,d) end
end
table.sort(leaves,function(a,b)return a.Position.X<b.Position.X end)
table.sort(visuals,function(a,b)return a:GetPivot().X<b:GetPivot().X end)
local rows={}
for i,leaf in leaves do
 local model=assert(visuals[i],'missing leaf visuals')
 local delta=leaf.CFrame:ToObjectSpace(model:GetPivot()) local _,angle=delta:ToAxisAngle()
 table.insert(rows,{position={leaf.Position.X,leaf.Position.Y,leaf.Position.Z},
 frame={leaf.CFrame:GetComponents()},size={leaf.Size.X,leaf.Size.Y,leaf.Size.Z},
 collide=leaf.CanCollide,query=leaf.CanQuery,touch=leaf.CanTouch,transparency=leaf.Transparency,
 visualPositionError=delta.Position.Magnitude,visualAngleError=math.abs(angle)})
end
for _,d in map:GetDescendants() do
 if d:IsA('Model') and (d.Name=='GateLeaf_Cedar' or d.Name=='RidgeGateWing_Cedar') then
  for _,q in d:GetDescendants() do if q:IsA('BasePart') then
   count+=1 if q.CanCollide or q.CanQuery or q.CanTouch or not q.Anchored then bad+=1 end
  end end
 end
end
for _,d in map.Structure:GetChildren() do
 if d:IsA('BasePart') and d.Name=='RidgeGateWing' then
  table.insert(wings,{size={d.Size.X,d.Size.Y,d.Size.Z},collide=d.CanCollide,transparency=d.Transparency})
 end
end
return game.HttpService:JSONEncode({leaves=rows,wings=wings,visualParts=count,invalidDecor=bad,
 openGates=p and p:GetAttribute('AsuraOpenGates'),health=p and p.Character and p.Character.Humanoid.Health,
 players=#game.Players:GetPlayers()})"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('studio')
    parser.add_argument('outdir', type=Path)
    args = parser.parse_args()
    if args.outdir.exists():
        parser.error('choose a new evidence directory')
    args.outdir.mkdir(parents=True)
    result = {'kind': 'single-client seeded gate-art diagnostic; real Z hold; original combat/HUD',
              'restoration_errors': []}
    c, sid = studio_mcp.Client(), args.studio
    owned = camera = False

    def save():
        (args.outdir / 'session.json').write_text(json.dumps(result, indent=2) + '\n')

    def audit():
        return json.loads(lua(c, sid, 'Server', AUDIT))

    def shot(name):
        card = lua(c, sid, 'Client', "local g=game.Players.LocalPlayer.PlayerGui:FindFirstChild('ControlsCard',true) return tostring(g and g.Visible)")
        if card == 'true':
            call(c, sid, 'user_keyboard_input', datamodel_type='Client', actions=[{'action': 'keyPress', 'key_code': 'H'}])
        lua(c, sid, 'Client', "local g=game.Players.LocalPlayer.PlayerGui:FindFirstChild('ControlsCard',true) assert(not g or not g.Visible,'controls card covers comparison') return 'unobstructed'")
        result.setdefault('conditions', {})[name] = json.loads(lua(c, sid, 'Client', """local p=game.Players.LocalPlayer local c=workspace.CurrentCamera
return game.HttpService:JSONEncode({health=p.Character.Humanoid.Health,region=p:GetAttribute('AsuraRegion'),
 camera={c.CFrame:GetComponents()},viewport={c.ViewportSize.X,c.ViewportSize.Y},fov=c.FieldOfView,
 quality=UserSettings():GetService('UserGameSettings').SavedQualityLevel.Name,
 editorQuality=settings().Rendering.QualityLevel.Name,autoFRMLevel=settings().Rendering.AutoFRMLevel})"""))
        reply, _ = call(c, sid, 'screen_capture', capture_id=name)
        images = [x for x in reply.get('content', []) if x.get('type') == 'image']
        assert images, 'missing viewport image'
        for i, item in enumerate(images):
            ext = 'png' if 'png' in item.get('mimeType', '') else 'jpg'
            path = args.outdir / f'{name}{"" if i == 0 else "_" + str(i)}.{ext}'
            path.write_bytes(base64.b64decode(item['data']))

    try:
        assert 'Current Studio Mode: Edit' in call(c, sid, 'get_studio_state')[1], 'requires Edit'
        call(c, sid, 'start_stop_play', is_start=True)
        owned = True
        deadline = time.monotonic() + 35
        while True:
            state = call(c, sid, 'get_studio_state')[1]
            if 'Client' in state and 'Server' in state:
                ready = json.loads(lua(c, sid, 'Client', """local p=game.Players.LocalPlayer
return game.HttpService:JSONEncode({ready=p and p:GetAttribute('AsuraClientReady')==true,
 prologue=p and p.PlayerGui:FindFirstChild('AsuraPrologue')~=nil})"""))
                if ready.get('prologue'):
                    call(c, sid, 'user_keyboard_input', datamodel_type='Client', actions=[{'action': 'keyPress', 'key_code': 'Space'}])
                if ready.get('ready') and not ready.get('prologue'):
                    break
            assert time.monotonic() < deadline, 'Play startup timed out'
            time.sleep(.25)
        lua(c, sid, 'Server', """assert(game.RunService:IsStudio() and game.GameId==0,'local file only')
local p=game.Players:GetPlayers()[1] p.Character:PivotTo(CFrame.new(0,3.2,-1128))
p.Character.HumanoidRootPart.AssemblyLinearVelocity=Vector3.zero return 'seeded safe observer stand'""")
        if lua(c, sid, 'Client', "local g=game.Players.LocalPlayer.PlayerGui:FindFirstChild('ControlsCard',true) return tostring(g and g.Visible)") == 'true':
            call(c, sid, 'user_keyboard_input', datamodel_type='Client', actions=[{'action': 'keyPress', 'key_code': 'H'}])
        lua(c, sid, 'Client', """local c=workspace.CurrentCamera
_G.AsuraGateArtCamera={c.CameraType,c.CFrame,c.FieldOfView}
game.RunService:BindToRenderStep('AsuraGateArtReview',Enum.RenderPriority.Last.Value+50,function()
 c.CameraType=Enum.CameraType.Scriptable c.CFrame=CFrame.lookAt(Vector3.new(3,18.5,-1238),Vector3.new(0,16.5,-1250.5)) c.FieldOfView=70 end)
return 'observer camera saved and pinned'""")
        camera = True
        time.sleep(3)
        result['closed'] = audit()
        assert len(result['closed']['leaves']) == 2 and len(result['closed']['wings']) == 2
        assert result['closed']['invalidDecor'] == 0
        assert all(x['collide'] and x['size'] == [6, 9, 1] for x in result['closed']['leaves'])
        assert all(x['collide'] and x['size'] == [1, 9, 14] for x in result['closed']['wings'])
        shot('gate_closed_front')
        lua(c, sid, 'Server', """local p=game.Players:GetPlayers()[1]
p.Character:PivotTo(CFrame.new(0,15.3,-1253.5)) p.Character.HumanoidRootPart.AssemblyLinearVelocity=Vector3.zero
return 'seeded at the existing crest-side interaction point'""")
        call(c, sid, 'user_keyboard_input', datamodel_type='Client', actions=[
            {'action': 'keyDown', 'key_code': 'Z'}, {'action': 'wait', 'wait_time_ms': 900}, {'action': 'keyUp', 'key_code': 'Z'}])
        time.sleep(.3)
        result['opened'] = audit()
        save()
        assert 'BambooRidge' in (result['opened'].get('openGates') or ''), 'normal Z hold did not lift the bar'
        assert all(not x['collide'] for x in result['opened']['leaves']), 'leaf still blocks the opened route'
        assert all(x['visualPositionError'] < .001 and x['visualAngleError'] < .001 for x in result['opened']['leaves']), 'visual hinge diverged'
        assert result['opened']['invalidDecor'] == 0
        lua(c, sid, 'Server', "local p=game.Players:GetPlayers()[1] p.Character:PivotTo(CFrame.new(0,3.2,-1128)) return 'returned to observer stand'")
        time.sleep(1)
        shot('gate_open_front')
        result['passed'] = True
        print('PASS: normal Z opened gate; both visual pivots match collision leaves; decor has no collision/query/touch', flush=True)
    except BaseException as exc:
        result['error'] = str(exc)
        raise
    finally:
        if owned:
            cleanup = [('release Z', lambda: call(c, sid, 'user_keyboard_input', datamodel_type='Client', actions=[{'action': 'keyUp', 'key_code': 'Z'}]))]
            if camera:
                cleanup.append(('camera', lambda: lua(c, sid, 'Client', """game.RunService:UnbindFromRenderStep('AsuraGateArtReview')
local o=_G.AsuraGateArtCamera local c=workspace.CurrentCamera
if o then c.CameraType=o[1] c.CFrame=o[2] c.FieldOfView=o[3] end _G.AsuraGateArtCamera=nil return 'restored'""")))
            cleanup.append(('owned Play', lambda: call(c, sid, 'start_stop_play', is_start=False)))
            for label, restore in cleanup:
                try:
                    restore()
                except Exception as exc:
                    result['restoration_errors'].append(f'{label}: {exc}')
            try:
                result['owned_play_stopped'] = 'Current Studio Mode: Edit' in call(c, sid, 'get_studio_state')[1]
            except Exception as exc:
                result['restoration_errors'].append(str(exc))
        save()
        c.close()


if __name__ == '__main__':
    main()
