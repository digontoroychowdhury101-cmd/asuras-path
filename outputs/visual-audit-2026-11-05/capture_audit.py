"""Unmapped art audit driver; requires the confirmed temporary Play helper.
Keeps source/geometry/lighting/quality unchanged. Teleports and pins camera for disclosed views.
Run from repository root: python3 outputs/visual-audit-2026-11-05/capture_audit.py shots.json
"""
import base64
import json
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
import studio_mcp

SID = 'e0b129cf-6a75-4ad1-80fc-825fff0dd0ed'
OUT = Path(__file__).parent
BIND = 'AsuraVisualAuditView'

def main():
    shots = json.loads(Path(sys.argv[1]).read_text())
    client = studio_mcp.Client()
    def call(name, args):
        ok, text = client.call(name, {'studio_id': SID, **args})
        with (OUT / 'tool-log.jsonl').open('a') as log:
            log.write(json.dumps({'at': time.time(), 'tool': name, 'ok': ok, 'text': text[:10000]})+'\n')
        if not ok:
            raise RuntimeError(text)
        return text
    def lua(dm, code):
        return call('execute_luau', {'datamodel_type': dm, 'code': code})
    def op(value):
        value['nonce'] = time.time()
        payload = json.dumps(value)
        lua('Server', 'game.ServerStorage.AsuraVisualAudit.Command.Value=[==['+payload+']==] return "sent"')
        time.sleep(.15)
        result = json.loads(lua('Server', 'return game.ServerStorage.AsuraVisualAudit.Result.Value'))
        if not result.get('ok'):
            raise RuntimeError(result)
        return result
    try:
        assert 'Client' in call('get_studio_state', {})
        for shot in shots:
            target = OUT / (shot['id']+'.jpg')
            assert not target.exists(), f'Preserve existing evidence: {target}'
            if shot.get('boss'):
                data = op({'action': 'boss', 'id': shot['boss']})
                (OUT / (shot['id']+'-actors.json')).write_text(json.dumps(data, indent=2))
            x,y,z = shot['stand']
            op({'action': 'teleport', 'x': x, 'y': y, 'z': z, 'yaw': shot.get('yaw',0)})
            eye = ','.join(map(str,shot['eye']))
            look = ','.join(map(str,shot['look']))
            lua('Client', f'''local r=game.RunService local c=workspace.CurrentCamera
r:UnbindFromRenderStep('{BIND}')
local cf=CFrame.lookAt(Vector3.new({eye}),Vector3.new({look}))
_G.AsuraAuditHidden=_G.AsuraAuditHidden or {{}}
local avatar=game.Players.LocalPlayer.Character
r:BindToRenderStep('{BIND}',Enum.RenderPriority.Last.Value+60,function()
c.CameraType=Enum.CameraType.Scriptable c.FieldOfView=70 c.CFrame=cf
if avatar then for _,p in avatar:GetDescendants() do if p:IsA('BasePart') then
if _G.AsuraAuditHidden[p]==nil then _G.AsuraAuditHidden[p]=p.LocalTransparencyModifier end
p.LocalTransparencyModifier=1 end end end end)
return 'pinned' ''')
            time.sleep(3)
            meta = json.loads(lua('Client', '''local p=game.Players.LocalPlayer local c=workspace.CurrentCamera
return game.HttpService:JSONEncode({region=p:GetAttribute('AsuraRegion'),
position={p.Character:GetPivot().X,p.Character:GetPivot().Y,p.Character:GetPivot().Z},
viewport={c.ViewportSize.X,c.ViewportSize.Y},fov=c.FieldOfView,
frm=settings().Rendering.AutoFRMLevel,quality=tostring(settings().Rendering.QualityLevel),
localAvatarHidden=true,tier=p:GetAttribute('LandscapeTier'),
clock=game.Lighting.ClockTime,exposure=game.Lighting.ExposureCompensation,
encounter=p:GetAttribute('AsuraEncounter'),alive=p.Character.Humanoid.Health>0})'''))
            if meta['region'] != shot['region'] or not meta['alive']:
                raise RuntimeError({'shot':shot['id'],'conditions':meta})
            if shot.get('diagnosticFill'):
                lua('Client', '''local l=game.Lighting local a=l:FindFirstChildOfClass('Atmosphere')
local cc=l:FindFirstChild('CB_ColorCorrection')
_G.AsuraAuditFill={ambient=l.Ambient,outdoor=l.OutdoorAmbient,exposure=l.ExposureCompensation,
density=a and a.Density,cc=cc and cc.Enabled}
l.Ambient=Color3.fromRGB(170,170,170) l.OutdoorAmbient=l.Ambient l.ExposureCompensation=0.35
if a then a.Density=0.18 end if cc then cc.Enabled=false end return 'temporary diagnostic fill' ''')
                time.sleep(.3)
                meta['diagnosticFill'] = True
            call('screen_capture', {'capture_id': shot['id']})
            assert client.images, 'No image returned'
            target.write_bytes(base64.b64decode(client.images[0]))
            row = {**shot, 'conditions':meta,'evidence':'assisted Studio Play visual inspection; seeded placement, scripted camera, boss bypass, no earned-play claim'}
            with (OUT / 'views.jsonl').open('a') as log:
                log.write(json.dumps(row)+'\n')
            print('CAPTURED',shot['id'],meta['region'],flush=True)
            lua('Client', '''local o=_G.AsuraAuditFill if o then local l=game.Lighting
l.Ambient=o.ambient l.OutdoorAmbient=o.outdoor l.ExposureCompensation=o.exposure
local a=l:FindFirstChildOfClass('Atmosphere') if a then a.Density=o.density end
local cc=l:FindFirstChild('CB_ColorCorrection') if cc then cc.Enabled=o.cc end
_G.AsuraAuditFill=nil end return 'diagnostic fill restored' ''')
    finally:
        client.close()

if __name__=='__main__':
    main()
