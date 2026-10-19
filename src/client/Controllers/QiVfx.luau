--!strict
local Debris = game:GetService("Debris")
local Tween = game:GetService("TweenService")
local Assets = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.PresentationAssets)
local Surfaces = require(script.Parent.CombatSurfaces)
local Qi = {}
function Qi.seal(hand: BasePart, color: Color3, duration: number): BillboardGui?
	if Assets.Textures.Rune == "" then return nil end
	local gui = Instance.new("BillboardGui")
	gui.Name, gui.Adornee, gui.Size, gui.LightInfluence = "QiHandSeal", hand, UDim2.fromScale(1,1), 0
	gui.AlwaysOnTop = false
	local image = Instance.new("ImageLabel")
	image.Image, image.ImageColor3, image.BackgroundTransparency = Assets.Textures.Rune, color, 1
	image.Size, image.Parent = UDim2.fromScale(1,1), gui
	gui.Parent = hand
	Tween:Create(gui,TweenInfo.new(duration),{Size=UDim2.fromScale(4,4)}):Play()
	Tween:Create(image,TweenInfo.new(duration),{Rotation=180,ImageTransparency=1}):Play()
	Debris:AddItem(gui,duration+0.1); return gui
end
function Qi.tail(head: BasePart, color: Color3)
	local a,b=Instance.new("Attachment"),Instance.new("Attachment")
	a.Position,b.Position=Vector3.new(-0.2,0,0),Vector3.new(0.2,0,0)
	a.Parent,b.Parent=head,head
	local trail=Instance.new("Trail")
	trail.Attachment0,trail.Attachment1,trail.FaceCamera=a,b,true
	trail.Lifetime,trail.MinLength,trail.LightEmission=0.2,0.02,0.8
	trail.Color=ColorSequence.new(Color3.new(1,1,1),color)
	trail.Transparency=NumberSequence.new(0.15,1);trail.Texture=Assets.Textures.Ribbon;trail.Parent=head
	if Assets.Textures.Smoke~="" then
		local smoke=Instance.new("ParticleEmitter")
		smoke.Texture,smoke.Rate,smoke.Lifetime=Assets.Textures.Smoke,18,NumberRange.new(0.15,0.35)
		smoke.Color,smoke.Speed,smoke.Drag=ColorSequence.new(color),NumberRange.new(0.2,0.5),2
		smoke.Size,smoke.Transparency=NumberSequence.new(0.25,1.4),NumberSequence.new(0.65,1)
		smoke.Parent=head
	end
end
function Qi.rupture(folder: Instance, point: Vector3, direction: Vector3, color: Color3, character: Model?)
	Surfaces.rupture(folder,point,direction,color,if character then {character} else {})
end
return Qi
