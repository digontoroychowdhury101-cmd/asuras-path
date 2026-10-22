--!strict
-- The VFX demo's crimson/cobalt clash and layered sword wake, sized to real attack reach.
local G = require(script.Parent.SanguineGeometry)
local Combat = {}
local WHITE, GOLD = Color3.fromRGB(255, 245, 229), Color3.fromRGB(255, 195, 86)
local RED, BLUE = Color3.fromRGB(218, 22, 42), Color3.fromRGB(60, 135, 245)
function Combat.slash(ctx: any, root: BasePart, move: any)
	local group = ctx:Group("SanguineWeaponCrescent", 0.45)
	if not group then return end
	local heavy = move.Kind ~= "Light"
	local reach = math.clamp(move.Reach, 1, 16)
	local half = math.rad(math.clamp(move.Arc, 15, 160) * 0.5)
	local cf = root.CFrame
	local color = if heavy then GOLD elseif (move.ComboIndex or 1) % 2 == 0 then BLUE else RED
	for layer = 1, 2 do
		local previous: Vector3? = nil
		for i = 0, 8 do
			local angle = -half + half * 2 * i / 8
			local point = cf:PointToWorldSpace(Vector3.new(math.sin(angle) * reach, 0.25 + math.sin(angle) * 0.6,
				-math.cos(angle) * reach * (if layer == 1 then 1 else 0.94)))
			if previous then G.line(ctx, group, previous, point, if layer == 1 then 0.08 else 0.035, if layer == 1 then color else WHITE, 0.24) end
			previous = point
		end
	end
end
function Combat.parry(ctx: any, position: Vector3, direction: Vector3)
	local group = ctx:Group("SanguineCrimsonCobaltParry", 0.65)
	if not group then return end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	local forward = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
	local right = forward:Cross(Vector3.yAxis)
	G.pulse(ctx, group, position, 1.1, WHITE, 0.18)
	G.lightning(ctx, group, position - right * 1.5 - Vector3.yAxis, position + right * 1.5 + Vector3.yAxis, BLUE, 0.24)
	G.lightning(ctx, group, position + right * 1.5 - Vector3.yAxis, position - right * 1.5 + Vector3.yAxis, RED, 0.24)
	G.ring(ctx, group, CFrame.new(position) * CFrame.Angles(math.pi / 2, 0, 0), 2.3, GOLD, 0.28)
	ctx:Emit(group, position, GOLD, 20)
end
function Combat.hit(ctx: any, position: Vector3, heavy: boolean, blocked: boolean?)
	local group = ctx:Group(if blocked then "SanguineMetalContact" else "SanguineHitSpark", 0.55)
	if not group then return end
	local color = if blocked then GOLD elseif heavy then GOLD else RED
	G.pulse(ctx, group, position, if heavy then 1.2 else 0.55, WHITE, 0.16)
	if heavy then G.forks(ctx, group, position, 1.8, color, BLUE) end
	ctx:Emit(group, position, color, if heavy then 18 else 8)
end
return table.freeze(Combat)
