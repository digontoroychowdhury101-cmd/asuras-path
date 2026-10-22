--!strict
-- Adapted from SanguineVFX_Overhaul's ring, pulse and branching energy shapes.
local Geometry = {}
local rng = Random.new()
function Geometry.line(ctx: any, group: Folder, a: Vector3, b: Vector3, width: number, color: Color3, duration: number)
	local delta = b - a
	if delta.Magnitude < 0.03 then return end
	local p = ctx:Part(group, "SanguineEnergyLine", Vector3.new(width, width, delta.Magnitude), CFrame.lookAt((a + b) / 2, b), color)
	ctx:Tween(p, duration, { Transparency = 1, Size = Vector3.new(0.01, 0.01, delta.Magnitude) })
end
function Geometry.pulse(ctx: any, group: Folder, position: Vector3, radius: number, color: Color3, duration: number)
	local p = ctx:Part(group, "SanguinePulse", Vector3.one * 0.25, CFrame.new(position), color, 0.8)
	if p then p.Shape = Enum.PartType.Ball end
	ctx:Tween(p, duration, { Transparency = 1, Size = Vector3.one * math.clamp(radius * 2, 0.5, 12) })
end
function Geometry.ring(ctx: any, group: Folder, cf: CFrame, radius: number, color: Color3, duration: number)
	-- Segmented rings preserve the demo's broken-energy silhouette without large opaque floors.
	local segments = 10
	for i = 1, segments do
		local angle = i * math.pi * 2 / segments
		local localPoint = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local from = cf * CFrame.new(localPoint * 0.4) * CFrame.Angles(0, -angle, 0)
		local p = ctx:Part(group, "SanguineRing", Vector3.new(0.12, 0.05, 0.15), from, color, 0.55)
		ctx:Tween(p, duration, { CFrame = cf * CFrame.new(localPoint * radius) * CFrame.Angles(0, -angle, 0),
			Size = Vector3.new(0.02, 0.02, math.max(0.15, radius * 0.4)), Transparency = 1 })
	end
end
function Geometry.lightning(ctx: any, group: Folder, a: Vector3, b: Vector3, color: Color3, duration: number)
	local previous = a
	for i = 1, 4 do
		local point = a:Lerp(b, i / 4)
		if i < 4 then point += Vector3.new(rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.3, 0.3)) end
		Geometry.line(ctx, group, previous, point, 0.06, color, duration)
		previous = point
	end
end
function Geometry.forks(ctx: any, group: Folder, position: Vector3, radius: number, first: Color3, second: Color3)
	for i = 1, 3 do
		local angle = i * math.pi * 2 / 3
		local target = position + Vector3.new(math.cos(angle), 0.3, math.sin(angle)) * radius
		Geometry.lightning(ctx, group, position, target, if i % 2 == 0 then first else second, 0.22)
	end
end
return table.freeze(Geometry)
