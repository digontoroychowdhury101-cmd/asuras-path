--!strict
-- Selected demo spell/phase/death motifs. Existing authoritative telegraphs and actor death own timing.
local G = require(script.Parent.SanguineGeometry)
local Magic = {}
local RED, BLUE = Color3.fromRGB(218, 22, 42), Color3.fromRGB(60, 135, 245)
local GOLD = Color3.fromRGB(255, 195, 86)
local COLORS: { [string]: Color3 } = { CelestialThunder = BLUE, CrimsonFlame = RED,
	AbyssalVoid = Color3.fromRGB(129, 80, 175), SpiritTalismans = Color3.fromRGB(91, 216, 164) }
function Magic.spell(ctx: any, position: Vector3, destination: Vector3?, discipline: string?, release: boolean)
	local group = ctx:Group("SanguineSpellEnergy", 0.65)
	if not group then return end
	local color = COLORS[discipline or ""] or GOLD
	if release and destination and (destination - position).Magnitude > 0.1 then
		-- A cosmetic path only; no simulated projectile, invented hit, target selection or damage.
		local goal = position + (destination - position).Unit * math.min((destination - position).Magnitude, 20)
		G.lightning(ctx, group, position, goal, color, 0.16)
	else
		G.ring(ctx, group, CFrame.new(position), if release then 2.4 else 1.3, color, 0.32)
	end
	if release then ctx:Emit(group, position, color, 12) end
end
function Magic.phase(ctx: any, position: Vector3, span: number)
	local group = ctx:Group("SanguinePhaseAscension", 1.1)
	if not group then return end
	local radius = math.clamp(span * 0.3, 2, 6)
	G.ring(ctx, group, CFrame.new(position), radius, RED, 0.65)
	G.forks(ctx, group, position + Vector3.yAxis, radius * 0.6, RED, BLUE)
	ctx:Emit(group, position, RED, 22)
end
function Magic.impact(ctx: any, position: Vector3, radius: number)
	local group = ctx:Group("SanguineGroundImpact", 0.8)
	if not group then return end
	-- Broken ground lines are visuals above the surface, never terrain edits or colliding debris.
	local r = math.clamp(radius, 1, 8)
	G.ring(ctx, group, CFrame.new(position), r, RED, 0.42)
	G.forks(ctx, group, position, r * 0.7, RED, GOLD)
	ctx:Emit(group, position, GOLD, 16)
end
function Magic.death(ctx: any, position: Vector3)
	local group = ctx:Group("SanguineGreatEnemyFelled", 1.2)
	if not group then return end
	G.ring(ctx, group, CFrame.new(position), 5, GOLD, 0.8)
	G.forks(ctx, group, position + Vector3.yAxis * 2, 3, GOLD, BLUE)
	ctx:Emit(group, position + Vector3.yAxis, GOLD, 24)
	-- Deliberately no boss Material/Color/Transparency/Size writes from the demo's BossDeath.
end
return table.freeze(Magic)
