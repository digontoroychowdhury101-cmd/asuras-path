--!strict
local Shared = game:GetService("ReplicatedStorage").AsurasPath.Shared
local Assets = require(Shared.PresentationAssets)
local Profiles = require(Shared.EnvironmentProfiles)
local Effects = require(Shared.EffectsPreference)
local RATE = 18 -- ash flakes per second at full decorative density
local Ash = {}
Ash.__index = Ash
function Ash.new(): any return setmetatable({Folder=nil,Anchor=nil,Emitter=nil,Bits={},Time=0},Ash) end
function Ash.clear(self: any)
	if self.Folder then self.Folder:Destroy() end
	self.Folder,self.Anchor,self.Emitter=nil,nil,nil;table.clear(self.Bits)
end
function Ash.Update(self: any,dt: number,at: Vector3?,key: string)
	-- Colosseum only; thinned during the fight itself (and by reduced effects) so ash never
	-- competes with telegraphs.
	local density=Effects.decor(key~="AshColosseum")
	if not at or not Profiles.ashFall(key) or density<=0 then if self.Folder then self:clear() end;return end
	if not self.Folder then
		local folder=Instance.new("Folder");folder.Name,folder.Parent="AsuraLocalAsh",workspace;self.Folder=folder
		if Assets.Textures.Ash~="" then
			local p=Instance.new("Part");p.Size,p.Transparency=Vector3.new(60,1,60),1
			p.Anchored,p.CanCollide,p.CanQuery,p.CanTouch,p.Parent=true,false,false,false,folder;self.Anchor=p
			local e=Instance.new("ParticleEmitter")
			e.Texture,e.Shape,e.Rate=Assets.Textures.Ash,Enum.ParticleEmitterShape.Box,RATE;self.Emitter=e
			e.Lifetime,e.Speed,e.Drag=NumberRange.new(7,12),NumberRange.new(0.4,1.4),0.4
			e.Acceleration,e.RotSpeed=Vector3.new(0.8,-0.9,0.3),NumberRange.new(-90,90)
			e.Size,e.Transparency=NumberSequence.new(0.09,0.02),NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.15,0.45),NumberSequenceKeypoint.new(1,1)})
			e.Color,e.LightInfluence,e.Parent=ColorSequence.new(Color3.fromRGB(154,139,129)),1,p
		else
			for i=1,24 do
				local p=Instance.new("Part")
				p.Size,p.Color,p.Material=Vector3.new(0.045,0.018,0.07),Color3.fromRGB(132,123,117),Enum.Material.Slate
				p.Anchored,p.CanCollide,p.CanQuery,p.CanTouch,p.CastShadow=true,false,false,false,false
				p.Parent=folder;table.insert(self.Bits,{Part=p,Seed=i*2.399})
			end
		end
	end
	if self.Anchor then self.Anchor.Position=at+Vector3.yAxis*14 end
	if self.Emitter then self.Emitter.Rate=RATE*density end
	self.Time+=dt
	local shown=math.ceil(#self.Bits*density)
	for i, item in self.Bits do
		local n,t=item.Seed,self.Time
		item.Part.Transparency=if i<=shown then 0 else 1
		item.Part.CFrame=CFrame.new(at+Vector3.new(math.sin(n)*22+math.sin(t+n)*2,15-((t*1.5+n*2)%19),math.cos(n)*22))*CFrame.Angles(n+t,n,t*0.5)
	end
end
function Ash.Destroy(self: any) self:clear() end
return Ash
