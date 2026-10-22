--!strict
-- Procedural building blocks for the showcase sorceries (Celestial Supernova, Blazing Sun).
-- Every instance, tween, connection and thread goes into a Trove so a cast can be torn down in one
-- call (interrupt, KO, despawn, controller destroy). Nothing here collides, queries or touches.
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Assets = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.PresentationAssets)
local Kit = {}
export type Trove = { Items: { any }, Dead: boolean }

function Kit.trove(): Trove
	return { Items = {}, Dead = false }
end

function Kit.add<T>(trove: Trove, item: T): T
	if trove.Dead then
		Kit.dispose(item)
	else
		table.insert(trove.Items, item)
	end
	return item
end

function Kit.dispose(item: any)
	local kind = typeof(item)
	if kind == "Instance" then
		if item:IsA("Tween") then item:Cancel() end
		item:Destroy()
	elseif kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "thread" then
		if coroutine.status(item) ~= "dead" and item ~= coroutine.running() then pcall(task.cancel, item) end
	elseif kind == "function" then
		item()
	elseif kind == "table" and item.Cancel then
		item:Cancel()
	end
end

function Kit.clean(trove: Trove)
	trove.Dead = true
	local items = trove.Items
	trove.Items = {}
	for index = #items, 1, -1 do Kit.dispose(items[index]) end
end

-- Delayed step owned by the trove: cleaning the cast cancels everything still scheduled.
function Kit.after(trove: Trove, seconds: number, callback: () -> ())
	Kit.add(trove, task.delay(math.max(0, seconds), function()
		if not trove.Dead then callback() end
	end))
end

function Kit.folder(trove: Trove, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = Workspace
	return Kit.add(trove, folder)
end

function Kit.part(parent: Instance, name: string, color: Color3, size: Vector3, cframe: CFrame, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name, p.Color, p.Size, p.CFrame = name, color, size, cframe
	p.Material, p.Shape = Enum.Material.Neon, shape or Enum.PartType.Block
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Parent = parent
	return p
end

function Kit.tween(trove: Trove, instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	Kit.add(trove, tween)
	tween:Play()
	return tween
end

-- A ring of segmented neon slabs (a procedural torus); returns a Model to spin with PivotTo.
function Kit.ring(parent: Instance, name: string, radius: number, thickness: number, color: Color3, segments: number): Model
	local model = Instance.new("Model")
	model.Name = name
	local chord = 2 * radius * math.sin(math.pi / segments) * 1.08
	for n = 1, segments do
		local angle = (n / segments) * math.pi * 2
		local cf = CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -radius)
		Kit.part(model, "Segment", color, Vector3.new(chord, thickness, thickness), cf)
	end
	model.WorldPivot = CFrame.identity
	model.Parent = parent
	return model
end

-- Flat ground shockwave: a thin disc that grows and fades (Quad ease-out).
function Kit.shockwave(trove: Trove, parent: Instance, at: CFrame, color: Color3, radius: number, seconds: number, transparency: number?)
	local disc = Kit.part(parent, "Shockwave", color, Vector3.new(0.12, 1, 1), at * CFrame.Angles(0, 0, math.pi / 2), Enum.PartType.Cylinder)
	disc.Transparency = transparency or 0.2
	Kit.tween(trove, disc, seconds, { Size = Vector3.new(0.05, radius * 2, radius * 2), Transparency = 1 })
	return disc
end

export type EmitterSpec = {
	Texture: string?, Color: ColorSequence, Size: NumberSequence, Rate: number, Lifetime: NumberRange,
	Speed: NumberRange, Spread: number?, Accel: Vector3?, Drag: number?, Light: number?, Spin: NumberRange?, Transparency: NumberSequence?,
}

function Kit.emitter(parent: Instance, spec: EmitterSpec): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = spec.Texture or Assets.Textures.Flame
	e.Color, e.Size, e.Rate, e.Lifetime, e.Speed = spec.Color, spec.Size, spec.Rate, spec.Lifetime, spec.Speed
	e.SpreadAngle = Vector2.new(spec.Spread or 20, spec.Spread or 20)
	e.Acceleration = spec.Accel or Vector3.zero
	e.Drag, e.LightEmission = spec.Drag or 0, spec.Light or 1
	e.RotSpeed = spec.Spin or NumberRange.new(-90, 90)
	e.Rotation = NumberRange.new(0, 360)
	e.Transparency = spec.Transparency or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = parent
	return e
end

function Kit.light(parent: Instance, color: Color3, range: number, brightness: number): PointLight
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = color, range, brightness, false
	light.Parent = parent
	return light
end

-- R15 hands fall back to R6 arms; the returned parts are the character's own (never edited).
function Kit.hands(model: Model): { BasePart }
	local found: { BasePart } = {}
	for _, pair in { { "LeftHand", "Left Arm" }, { "RightHand", "Right Arm" } } do
		local p = model:FindFirstChild(pair[1]) or model:FindFirstChild(pair[2])
		if p and p:IsA("BasePart") then table.insert(found, p) end
	end
	return found
end

function Kit.head(model: Model): BasePart?
	local head = model:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head else nil
end

-- Attachment owned by the trove, so emitters on a character limb leave with the cast.
function Kit.attach(trove: Trove, parent: BasePart, offset: Vector3, name: string): Attachment
	local a = Instance.new("Attachment")
	a.Name, a.Position, a.Parent = name, offset, parent
	return Kit.add(trove, a)
end

return table.freeze(Kit)
