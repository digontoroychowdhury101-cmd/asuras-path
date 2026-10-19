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
 local p=setmetatable({ClassName=class,Name=name or class,Children={},Attributes={},Ended=signal(),Destroying=signal()}, {__index=methods})
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
function methods:Play()self.Played=true end
function methods:Stop()self.Played=false end
local Instance={new=instance}
local registry={}
local require=function(name)return assert(registry[name],tostring(name))end
local script={Parent={SpatialAudio='SpatialAudio'}}
local vecmt={}
local function vec(x,y,z)return setmetatable({X=x,Y=y,Z=z or 0},vecmt)end
vecmt.__index=function(v,k)if k=='Magnitude'then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z)end end
vecmt.__mul=function(a,b)if type(a)=='number'then a,b=b,a end;return vec(a.X*b,a.Y*b,a.Z*b)end
vecmt.__sub=function(a,b)return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
vecmt.__unm=function(a)return vec(-a.X,-a.Y,-a.Z)end
local Vector3={new=vec,one=vec(1,1,1),yAxis=vec(0,1,0)}
local Color3={fromRGB=function(...)return {...}end,new=function(...)return {...}end}
local Enum=setmetatable({}, {__index=function(t,k)local e=setmetatable({}, {__index=function(_,n)return n end});rawset(t,k,e);return e end})
local Random={new=function()return {NextNumber=function(_,a,b)return (a+b)/2 end}end}
local TweenInfo={new=function()end}
local tweens={}
local TweenService={Create=function(_,target,info,values)local t={Target=target,Values=values,Play=function(self)self.Played=true end,Cancel=function(self)self.Cancelled=true end};table.insert(tweens,t);return t end}
local SoundService=instance('SoundService')
local Lighting=instance('Lighting')
for _,n in {'CB_Atmosphere','CB_ColorCorrection','CB_SunRays','CB_Bloom'}do local p=instance('Effect',n);p.Parent=Lighting end
local player=instance('Player')
local Shared={PresentationAssets='PresentationAssets',EnvironmentProfiles='EnvironmentProfiles',WorldDefinitions='WorldDefinitions'}
local services={ReplicatedStorage={AsurasPath={Shared=Shared}},SoundService=SoundService,Lighting=Lighting,Players={LocalPlayer=player},TweenService=TweenService,
 Debris={AddItem=function()end},ServerStorage=instance('ServerStorage')}
local game={GetService=function(_,name)return assert(services[name],name)end}
local workspace=instance('Workspace')
registry.WorldDefinitions={regionAt=function(x,y,z)return if z< -600 then 'DesecratedMonastery' else 'Sanctuary'end}
-- MODULES_INSERT
local assets=registry.PresentationAssets
local profiles=registry.EnvironmentProfiles
check(profiles.resolve(nil,false,1)=='Sanctuary','unknown region falls back')
check(profiles.resolve('BambooPass',false,3)=='BambooPass','another player phase cannot affect lighting')
check(profiles.resolve('Sanctuary',true,2)=='Cataclysm','phase two turns crimson')
check(profiles.resolve('Sanctuary',true,1)=='AshColosseum','phase one arena baseline')
check(profiles.Sanctuary.Lighting.ClockTime==17+40/60,'17:40 golden hour')
check(profiles.Sanctuary.CB_Atmosphere.Density==.35,'golden mist density')
check(profiles.Sanctuary.CB_SunRays.Spread==.4 and profiles.Sanctuary.CB_SunRays.Intensity==.25,'authored sun rays')
check(profiles.acoustics('DesecratedMonastery',vec(0,0,-960))=='Ravine','ravine acoustics')
check(profiles.acoustics('DesecratedMonastery',vec(0,0,-1020))=='Cloister','cloister acoustics')
check(profiles.acoustics('Sanctuary',vec(0,600,900))=='Open','open shrine acoustics')
local audio=registry.SpatialAudio
check(audio.play('Clash',workspace)==nil,'unuploaded sound stays silent')
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
player:SetAttribute('AsuraEncounter','Shen');environment:Update(.3);check(environment.Key=='Cataclysm','replicated phase supports joining mid fight')
check(tweens[1].Cancelled,'biome blend cancels previous transition')
player:SetAttribute('AsuraEncounter',nil);own.Root.Position=vec(0,3,-900);environment:Update(.3)
check(environment.Key=='DesecratedMonastery' and environment.Phase==1,'leaving fight restores biome')
listener({Kind='BossPhase',Data={boss='Other',phase=3}});check(environment.Phase==1,'unrelated phase cue ignored')
environment:Destroy();check(listener==nil,'lighting listeners disconnected')
local pbr=registry.PbrAssets
check(pbr.place(workspace,'Missing',{},10)==nil,'missing uploads preserve geometry')
local model=instance('Model');local mesh=instance('MeshPart');mesh.Parent=model
check(not pbr.validate(model),'untextured import rejected')
local surface=instance('SurfaceAppearance');surface.Parent=mesh
surface.ColorMap='a';surface.NormalMap='b';surface.RoughnessMap='c';surface.MetalnessMap=''
check(not pbr.validate(model),'partial PBR rejected')
surface.MetalnessMap='d';check(pbr.validate(model),'complete PBR accepted')
print('PASS: '..checks..' audiovisual runtime assertions (engine fakes; Studio QA separate)')
