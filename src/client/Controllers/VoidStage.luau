--!strict
-- Caster-only staging for the showcase cinematics: a dark matte "void" box that hides the world
-- behind the shot, a Highlight that turns the caster into a
-- solid silhouette, a key light, and the colour grades the reference cuts between. The parts are
-- created on the caster's client only, never take queries, and leave with the cast's trove.
local Kit = require(script.Parent.SkillKit)
local Cinema = require(script.Parent.SkillCinema)
local Stage = {}

local rgb = Color3.fromRGB
Stage.Grades = table.freeze({
	TealVoid = { Brightness = -0.05, Contrast = 0.25, Saturation = -0.2, TintColor = rgb(170, 235, 240) },
	Duotone = { Brightness = -0.04, Contrast = 0.6, Saturation = -1, TintColor = rgb(255, 120, 62) },
	Ember = { Brightness = -0.2, Contrast = 0.55, Saturation = -0.3, TintColor = rgb(255, 170, 120) },
	Neutral = { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = rgb(255, 255, 255) },
	White = { Brightness = 1, Contrast = -0.2, Saturation = -1, TintColor = rgb(255, 255, 255) },
})

-- Hides every enabled HUD ScreenGui on this client; returns the restore (idempotent).
function Stage.hud(): () -> ()
	local hidden: { ScreenGui } = {}
	local player = game:GetService("Players").LocalPlayer
	local gui = player and player:FindFirstChildOfClass("PlayerGui")
	for _, g in if gui then gui:GetChildren() else {} do
		if g:IsA("ScreenGui") and g.Enabled then table.insert(hidden, g); g.Enabled = false end
	end
	return function()
		for _, g in hidden do if g.Parent then g.Enabled = true end end
		table.clear(hidden)
	end
end

export type Void = { Walls: { BasePart }, Center: Vector3, Restore: () -> () }

-- Hides everything already in the world (except `keep`) and every HUD ScreenGui on this client,
-- remembering what it changed. Effects created afterwards are untouched. Returns the restore.
local function blackout(keep: { Instance }): () -> ()
	local parts: { [Instance]: number } = {}
	local toggles: { [Instance]: boolean } = {}
	local function kept(d: Instance): boolean
		for _, k in keep do if d == k or d:IsDescendantOf(k) then return true end end
		return false
	end
	for _, d in game:GetService("Workspace"):GetDescendants() do
		if (d:IsA("BasePart") or d:IsA("Decal")) and not kept(d) and (d :: any).Transparency < 1 then
			parts[d] = (d :: any).Transparency;
			(d :: any).Transparency = 1 -- a client-side write: never replicates, restored afterwards
		elseif (d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Light") or d:IsA("LayerCollector")) and not kept(d) and (d :: any).Enabled then
			toggles[d] = true;
			(d :: any).Enabled = false
		end
	end
	-- Distance haze would tint the void walls with the biome's sky; terrain water cannot take a
	-- transparency write. Both are client-local property writes, restored with everything else.
	local props: { { any } } = {}
	local function set(inst: Instance, prop: string, value: any)
		table.insert(props, { inst, prop, (inst :: any)[prop] });
		(inst :: any)[prop] = value
	end
	for _, a in game:GetService("Lighting"):GetChildren() do
		if a:IsA("Atmosphere") then set(a, "Density", 0); set(a, "Haze", 0); set(a, "Glare", 0) end
	end
	local terrain = game:GetService("Workspace").Terrain
	set(terrain, "WaterTransparency", 1); set(terrain, "WaterReflectance", 0); set(terrain, "WaterWaveSize", 0)
	local hud = Stage.hud()
	return function()
		hud()
		for d, value in parts do if d.Parent then (d :: any).Transparency = value end end
		for d in toggles do if d.Parent then (d :: any).Enabled = true end end
		for _, p in props do (p[1] :: any)[p[2]] = p[3] end
		table.clear(props)
		table.clear(parts)
		table.clear(toggles)
	end
end

-- A hollow box of thin Neon walls `half` studs out around `center`, floored `down` studs below it and
-- roofed `up` above, with the world and HUD hidden on this client so only the caster (and `keep`)
-- remain. The floor also covers terrain, which cannot be hidden.
function Stage.void(trove: Kit.Trove, center: Vector3, half: number, down: number, up: number, color: Color3, keep: { Instance }): Void
	local unhide = blackout(keep)
	Cinema.clipping(false) -- the hidden world still blocks rays; shots must not dodge invisible walls
	local function restore()
		unhide()
		Cinema.clipping(true)
	end
	Kit.add(trove, restore)
	local folder = Kit.folder(trove, "SkillVoid")
	local walls: { BasePart } = {}
	local height = up + down
	local mid = center + Vector3.new(0, (up - down) / 2, 0)
	local spec = {
		{ Vector3.new(half * 2, height, 1), Vector3.new(0, 0, half) }, { Vector3.new(half * 2, height, 1), Vector3.new(0, 0, -half) },
		{ Vector3.new(1, height, half * 2), Vector3.new(half, 0, 0) }, { Vector3.new(1, height, half * 2), Vector3.new(-half, 0, 0) },
		{ Vector3.new(half * 2, 1, half * 2), Vector3.new(0, height / 2 + 0.5, 0) }, { Vector3.new(half * 2, 1, half * 2), Vector3.new(0, -height / 2 - 0.5, 0) },
	}
	for _, s in spec do
		local wall = Kit.part(folder, "VoidWall", color, s[1], CFrame.new(mid + s[2]))
		wall.Material = Enum.Material.SmoothPlastic -- dark Neon renders flat black; matte keeps the hue
		table.insert(walls, wall)
	end
	return { Walls = walls, Center = center, Restore = restore }
end

function Stage.tint(trove: Kit.Trove, void: Void, color: Color3, seconds: number)
	for _, w in void.Walls do Kit.tween(trove, w, seconds, { Color = color }) end
end

function Stage.remove(void: Void?)
	if void then
		void.Restore()
		for _, w in void.Walls do w:Destroy() end
	end
end

-- The caster drawn as a flat silhouette (black for the blazing-eye close-up).
function Stage.silhouette(trove: Kit.Trove, model: Model, color: Color3): Highlight
	local h = Kit.add(trove, Instance.new("Highlight"))
	h.FillColor, h.FillTransparency, h.OutlineTransparency = color, 0, 1
	h.DepthMode, h.Adornee, h.Parent = Enum.HighlightDepthMode.Occluded, model, model
	return h
end

-- A coloured key light on the caster so they read against a dark void.
function Stage.key(trove: Kit.Trove, root: BasePart, color: Color3, brightness: number): PointLight
	local a = Kit.attach(trove, root, Vector3.new(0, 1, -3), "SkillKeyLight")
	return Kit.light(a, color, 16, brightness)
end

return table.freeze(Stage)
