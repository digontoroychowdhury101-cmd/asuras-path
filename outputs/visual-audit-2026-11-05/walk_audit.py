"""Short ordinary-keyboard visual samples from seeded starts; not a progression test."""
import sys,time,json,base64
from pathlib import Path
sys.path.insert(0,'tools');import studio_mcp
SID='e0b129cf-6a75-4ad1-80fc-825fff0dd0ed';out=Path(__file__).parent
c=studio_mcp.Client()
def call(n,a):
 ok,t=c.call(n,{'studio_id':SID,**a})
 if not ok:raise RuntimeError(t)
 return t
def lua(dm,code):return call('execute_luau',{'datamodel_type':dm,'code':code})
def op(v):
 v['nonce']=time.time();lua('Server','game.ServerStorage.AsuraVisualAudit.Command.Value=[==['+json.dumps(v)+']==] return "sent"');time.sleep(.2)
 return json.loads(lua('Server','return game.ServerStorage.AsuraVisualAudit.Result.Value'))
rows=[]
try:
 lua('Client','''game.RunService:UnbindFromRenderStep('AsuraVisualAuditView')
for p,v in _G.AsuraAuditHidden or {} do if p.Parent then p.LocalTransparencyModifier=v end end
_G.AsuraAuditHidden=nil workspace.CurrentCamera.CameraType=Enum.CameraType.Custom return 'normal camera restored' ''')
 for id,region,at in [('w01_shrine','Sanctuary',[0,603.3,940]),('w02_monastery','DesecratedMonastery',[0,3.3,-762]),('w03_bamboo','BambooPass',[0,3.3,-1141]),('w04_ash','AshColosseum',[0,3.3,-1784]),('w05_crypt','SanctuaryDepths',[455,18.3,1055]),('w06_pagoda','CelestialPagoda',[0,3.3,-2292]),('w07_citadel','SkyCitadel',[0,3.3,-2545])]:
  x,y,z=at;op(dict(action='teleport',x=x,y=y,z=z,yaw=0))
  lua('Client',f'''local c=workspace.CurrentCamera c.CameraType=Enum.CameraType.Custom c.CFrame=CFrame.lookAt(Vector3.new({x},{y+5},{z+12}),Vector3.new({x},{y},{z-5})) return 'aligned' ''')
  time.sleep(3)
  code='''local p=game.Players.LocalPlayer local c=workspace.CurrentCamera return game.HttpService:JSONEncode({region=p:GetAttribute('AsuraRegion'),position={p.Character:GetPivot().X,p.Character:GetPivot().Y,p.Character:GetPivot().Z},camera=tostring(c.CameraType),quality=tostring(settings().Rendering.QualityLevel),fov=c.FieldOfView,clock=game.Lighting.ClockTime})'''
  before=json.loads(lua('Client',code))
  call('screen_capture',{'capture_id':id+'_before'});(out/(id+'_before.jpg')).write_bytes(base64.b64decode(c.images[0]))
  call('user_keyboard_input',{'datamodel_type':'Client','actions':[{'action':'keyDown','key_code':'W'},{'action':'wait','wait_time_ms':1800},{'action':'keyUp','key_code':'W'}]})
  time.sleep(.5);after=json.loads(lua('Client',code))
  call('screen_capture',{'capture_id':id+'_after'});(out/(id+'_after.jpg')).write_bytes(base64.b64decode(c.images[0]))
  rows.append(dict(id=id,expected=region,before=before,after=after,evidence='ordinary W key and normal camera from seeded start; boss bypass active; invulnerability seeded, not earned progression'))
  (out/'ordinary-walks.json').write_text(json.dumps(rows,indent=2));print(id,before['position'],after['position'],flush=True)
 data=op({'action':'actors'});(out/'actors-final.json').write_text(json.dumps(data,indent=2))
finally:
 call('user_keyboard_input',{'datamodel_type':'Client','actions':[{'action':'keyUp','key_code':'W'},{'action':'keyUp','key_code':'LeftAlt'}]});c.close()
