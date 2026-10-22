--!nonstrict
local checks=0
local function check(value,label) assert(value,label);checks+=1 end
local function signal()
 local callbacks={}
 return {Once=function(_,fn) table.insert(callbacks,fn) end,Connect=function(_,fn) table.insert(callbacks,fn);return {Disconnect=function()end} end,
 Fire=function(_,...) local c=table.clone(callbacks);table.clear(callbacks);for _,fn in c do fn(...) end end}
end
local objects={}
local methods={}
local function instance(class,name)
 local p=setmetatable({ClassName=class,Name=name or class,Children={},Attributes={},Ended=signal(),Destroying=signal()}, {
  __index=function(self,key)
   if rawget(self,'RestrictPbr') and (key=='ColorMap' or key=='NormalMap' or key=='RoughnessMap' or key=='MetalnessMap') then error('Plugin-only map read') end
   return methods[key]
  end,
  __newindex=function(self,key,value)
   if rawget(self,'RestrictPbr') and key=='RenderFidelity' then error('Plugin-only mesh write') end
   rawset(self,key,value)
  end})
 table.insert(objects,p);return p
end
function methods:IsA(class) return self.ClassName==class or class=='BasePart' and (self.ClassName=='Part' or self.ClassName=='MeshPart') end
function methods:FindFirstChild(name) for _,c in self:GetChildren() do if c.Name==name then return c end end end
function methods:GetChildren() local out={};for _,p in objects do if p.Parent==self then table.insert(out,p) end end;return out end
function methods:GetDescendants() local out={};for _,p in self:GetChildren() do table.insert(out,p);for _,v in p:GetDescendants() do table.insert(out,v)end end;return out end
function methods:FindFirstChildOfClass(class) for _,p in self:GetChildren() do if p:IsA(class)then return p end end end
function methods:GetAttribute(key)return self.Attributes[key]end
function methods:SetAttribute(key,value)self.Attributes[key]=value end
function methods:Destroy()if self.Dead then return end;self.Dead=true;self.Destroying:Fire();for _,p in self:GetChildren()do p:Destroy()end;self.Parent=nil end
function methods:WaitForChild(name)return assert(self:FindFirstChild(name),name)end
function methods:ClearAllChildren()for _,p in self:GetChildren()do p:Destroy()end end
function methods:Play()self.Played=true end
function methods:Stop()self.Played=false end
local Instance={new=instance}
local registry={}
local require=function(name)return assert(registry[name],tostring(name))end
local script={Parent={SpatialAudio='SpatialAudio',ArenaAsh='ArenaAsh',CombatSurfaces='CombatSurfaces'}}
local task={defer=function(fn,...)fn(...)end,delay=function()end,spawn=function(fn,...)fn(...)end}
local vecmt={}
local function vec(x,y,z)return setmetatable({X=x,Y=y,Z=z or 0},vecmt)end
vecmt.__index=function(v,k)if k=='Magnitude'then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z)elseif k=='Unit'then return v/v.Magnitude end end
vecmt.__add=function(a,b)return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
vecmt.__div=function(a,b)return vec(a.X/b,a.Y/b,a.Z/b)end
vecmt.__mul=function(a,b)if type(a)=='number'then a,b=b,a end;return vec(a.X*b,a.Y*b,a.Z*b)end
vecmt.__sub=function(a,b)return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
vecmt.__unm=function(a)return vec(-a.X,-a.Y,-a.Z)end
local Vector3={new=vec,one=vec(1,1,1),yAxis=vec(0,1,0)}
local cmt={__mul=function(a,b)return a end,__add=function(a,b)return a end}
local function frame()return setmetatable({Position=vec(0,0,0),VectorToWorldSpace=function(_,v)return v end},cmt)end
local CFrame={new=frame,Angles=frame,lookAt=frame}
local function identity(...)return {...}end
local NumberSequence={new=identity};local NumberSequenceKeypoint={new=identity};local NumberRange={new=identity}
local ColorSequence={new=identity};local Vector2={new=vec}
local RaycastParams={new=function()return {}end}
local Color3={fromRGB=function(r,g,b)return {R=r/255,G=g/255,B=b/255}end,new=function(r,g,b)return {R=r,G=g,B=b}end}
local Enum=setmetatable({}, {__index=function(t,k)local e=setmetatable({}, {__index=function(_,n)return n end});rawset(t,k,e);return e end})
local Random={new=function()return {NextNumber=function(_,a,b)return (a+b)/2 end}end}
local TweenInfo={new=function()end}
local tweens={}
local TweenService={Create=function(_,target,info,values)local t={Target=target,Values=values,Play=function(self)self.Played=true end,Cancel=function(self)self.Cancelled=true end};table.insert(tweens,t);return t end}
local SoundService=instance('SoundService')
local Lighting=instance('Lighting')
for _,n in {'CB_Atmosphere','CB_ColorCorrection','CB_SunRays','CB_Bloom'}do local p=instance('Effect',n);p.Parent=Lighting end
local player=instance('Player')
local brazier=instance('PointLight')
local Shared={PresentationAssets='PresentationAssets',EnvironmentProfiles='EnvironmentProfiles',WorldDefinitions='WorldDefinitions',EffectsPreference='EffectsPreference'}
local AsurasPath={Shared=Shared}
local services={CollectionService={GetTagged=function()return {brazier}end},ReplicatedStorage={AsurasPath=AsurasPath,WaitForChild=function()return AsurasPath end},SoundService=SoundService,Lighting=Lighting,Players={LocalPlayer=player},TweenService=TweenService,
 Debris={AddItem=function()end},ServerStorage=instance('ServerStorage')}
local game={GetService=function(_,name)return assert(services[name],name)end}
function services.ReplicatedStorage:WaitForChild(name)return self[name]end
local workspace=instance('Workspace');function workspace:Raycast()return nil end
registry.WorldDefinitions={regionAt=function(x,y,z)return if z< -600 then 'DesecratedMonastery' else 'Sanctuary'end,Bosses={Shen={Region='AshColosseum'}}}
-- MODULES_INSERT
local assets=registry.PresentationAssets
-- Exercise missing-upload fallback behavior independently of the real published registry.
local uploaded={Wind=assets.Audio.Wind,Clash=assets.Audio.Clash,Ash=assets.Textures.Ash,Ember=assets.Textures.Ember}
assets.Audio.Wind,assets.Audio.Clash,assets.Textures.Ash,assets.Textures.Ember="","","",""
local profiles=registry.EnvironmentProfiles
check(profiles.resolve(nil,false,1)=='Sanctuary','unknown region falls back')
check(profiles.resolve('BambooPass',false,3)=='BambooPass','another player phase cannot affect lighting')
check(profiles.resolve('Sanctuary',true,2)=='Unbound:Sanctuary','phase two deepens the arena biome')
check(profiles.resolve('Sanctuary',true,1,'BambooPass')=='Combat:BambooPass','phase one follows the arena biome')
-- Lobby rebuild (2026-10-21): lower sun, thinner haze over the cloud sea, warm readable fill.
check(profiles.Sanctuary.Lighting.ClockTime==17.5,'17:30 golden hour')
check(profiles.Sanctuary.CB_Atmosphere.Density==.17,'thin golden haze over the cloud sea')
check(profiles.Sanctuary.CB_SunRays.Spread==.4 and profiles.Sanctuary.CB_SunRays.Intensity==.14,'authored sun rays')
check(profiles.skyFor('Sanctuary')=='Sunset' and profiles.skyFor('Combat:Sanctuary')=='Sunset','shrine golden-hour sky')
check(profiles.skyFor('DesecratedMonastery')==nil and profiles.skyFor('AshColosseum')=='Night','other skies unchanged')
check(profiles.acoustics('DesecratedMonastery',vec(0,0,-960))=='Ravine','ravine acoustics')
check(profiles.acoustics('DesecratedMonastery',vec(0,0,-1020))=='Cloister','cloister acoustics')
check(profiles.acoustics('Sanctuary',vec(0,600,900))=='Open','open shrine acoustics')
local audio=registry.SpatialAudio
check(audio.play('Wind',workspace)==nil,'unuploaded ambience stays silent')
local fallback=audio.play('Clash',workspace)
check(fallback.SoundId=='rbxasset://sounds/unsheath.wav','existing combat cues survive pending uploads')
fallback:Destroy()
local library=instance('Folder','AsuraAudio');library.Parent=SoundService
local sound=instance('Sound','Clash');sound.SoundId='rbxassetid://123';sound.Parent=library
local anchor=instance('Part');anchor.Parent=workspace
local loop=audio.play('Clash',anchor,.2,true)
check(loop.Looped and loop.RollOffMode=='InverseTapered' and loop.RollOffMaxDistance==120,'spatial rolloff')
local s=audio.play('Clash',anchor)
check(s.PlaybackSpeed>=.95 and s.PlaybackSpeed<=1.05,'clash pitch variance')
audio.zone('Cloister');local indoor=audio.play('Clash',anchor)
check(indoor:FindFirstChildOfClass('ReverbSoundEffect') and indoor:FindFirstChildOfClass('EqualizerSoundEffect'),'indoor DSP')
for _=1,40 do audio.play('Clash',anchor)end
check(not loop.Dead,'voice pressure preserves ambient loops')
local live=0;for _,p in anchor:GetChildren()do if p.ClassName=='Sound'then live+=1 end end
check(live==assets.Limits.Voices,'voice count bounded')
local positional=audio.at('Clash',vec(1,2,3));local emitter=positional.Parent
check(emitter:IsA('BasePart'),'positional sound attached to part')
positional:Destroy();check(emitter.Dead,'eviction cleans up sound anchor')
audio.destroy();check(loop.Dead,'audio teardown stops loops')
local own={Root={Position=vec(0,600,900)},Snapshot={State='Idle'}}
local boss={Model=instance('Model')};boss.Model:SetAttribute('AsuraEncounter','Shen');boss.Model:SetAttribute('AsuraBossPhase',2)
local listener=nil
local state={Entities={boss},Own=function()return own end,OnCue=function(_,fn)listener=fn;return function()listener=nil end end}
local environment=registry.EnvironmentController.new(state)
environment:Update(.3);check(environment.Key=='Sanctuary','initial shrine profile')
player:SetAttribute('AsuraEncounter','Shen');environment:Update(.3);check(environment.Key=='Unbound:AshColosseum','replicated phase supports joining mid fight')
check(tweens[1].Cancelled,'biome blend cancels previous transition')
local tinted=false;for _,t in tweens do if t.Target==brazier and t.Values.Color==profiles.UnboundBrazier then tinted=true end end
check(tinted,'phase two retints arena braziers')
player:SetAttribute('AsuraEncounter',nil);own.Root.Position=vec(0,3,-900);environment:Update(.3)
check(environment.Key=='DesecratedMonastery' and environment.Phase==1,'leaving fight restores biome')
listener({Kind='BossPhase',Data={boss='Other',phase=3}});check(environment.Phase==1,'unrelated phase cue ignored')
environment:Destroy();check(listener==nil,'lighting listeners disconnected')
local pbr=registry.PbrAssets
check(pbr.place(workspace,'Missing',{},10)==nil,'missing uploads preserve geometry')
local model=instance('Model');local mesh=instance('MeshPart');mesh.Parent=model
check(not pbr.validate(model),'untextured import rejected')
local surface=instance('SurfaceAppearance');surface.Parent=mesh
surface.RestrictPbr=true
surface.ColorMapContent={Uri='a'};surface.NormalMapContent={Uri='b'};surface.RoughnessMapContent={Uri='c'};surface.MetalnessMapContent={Uri=''}
check(not pbr.validate(model),'partial PBR rejected')
surface.MetalnessMapContent.Uri='d';check(pbr.validate(model),'complete PBR accepted without plugin-only map strings')
local templates=instance('Folder','AsuraAssets');templates.Parent=services.ServerStorage
model.Name,model.Parent='TestPbr',templates
local mounted=instance('Model');local mountedPart=instance('MeshPart');mountedPart.Parent=mounted;mountedPart.RestrictPbr=true
function model:Clone()return mounted end
function mounted:GetExtentsSize()return vec(2,4,2)end
function mounted:GetScale()return 1 end
function mounted:ScaleTo(value)self.Scale=value end
function mounted:PivotTo(value)self.Pivot=value end
function mounted:GetBoundingBox()return frame(),vec(2,4,2)end
function mounted:GetPivot()return self.Pivot end
local proxy=instance('Part');proxy.Parent=workspace
check(pbr.place(workspace,'TestPbr',frame(),8,'Y',proxy)==mounted,'PBR mounting avoids restricted runtime writes')
check(mountedPart.Anchored and not mountedPart.CanCollide and not mountedPart.CanQuery and not mountedPart.CanTouch,'mounted scenery is decorative')
check(proxy.Transparency==1 and mounted.Scale==2,'PBR mounting scales visual and retains collision proxy')
local ash=registry.ArenaAsh.new()
ash:Update(.1,vec(0,0,0),'AshColosseum');check(#ash.Bits==24,'unuploaded ash uses bounded custom geometry')
ash:Update(.1,vec(0,0,0),'Sanctuary');check(ash.Folder==nil and #ash.Bits==0,'ash removed after leaving arena')
local folder=instance('Folder');folder.Parent=workspace
local vfx=registry.CombatVfx.new(folder)
for _=1,30 do vfx:burst(vec(0,0,0),Vector3.yAxis,Color3.fromRGB(255,180,70),40,55) end
local bursts=0;for _,p in folder:GetChildren()do if p.Name=='BladeEmbers'then bursts+=1 end end
check(bursts<=assets.Limits.Bursts and #vfx.Shards<=assets.Limits.Shards,'impact spam bounded by burst/shard budgets')
vfx:Update(.4);check(#vfx.Shards==0,'expired geometric sparks released')
vfx:ring(vec(0,0,0),Vector3.yAxis,Color3.fromRGB(255,255,255),4)
vfx:Destroy();check(#folder:GetChildren()==0,'effect teardown removes shockwave nodes')
assets.Audio.Wind,assets.Audio.Clash,assets.Textures.Ash,assets.Textures.Ember=uploaded.Wind,uploaded.Clash,uploaded.Ash,uploaded.Ember
check(audio.id('Wind')==uploaded.Wind,'registered ambience resolves to uploaded asset')
if uploaded.Ash~='' then
 ash:Update(.1,vec(0,0,0),'AshColosseum')
 check(ash.Anchor and ash.Anchor:FindFirstChildOfClass('ParticleEmitter').Texture==uploaded.Ash,'registered ash uses authored texture')
 ash:Destroy()
end
print('PASS: '..checks..' audiovisual runtime assertions (engine fakes; Studio QA separate)')
