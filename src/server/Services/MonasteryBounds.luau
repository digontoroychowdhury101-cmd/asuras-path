--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/MonasteryBounds
-- Traversal limits for the Desecrated Monastery (batch 07, findings #26/#27), decided per space so
-- double jump, bullet jump and Air Glide keep all of their reach inside the level:
--   * Intended: wall tops, roofs and rafters inside the valley (the High Pagoda Rafters cache is up
--     there), and gliding across the ravine instead of fighting the bridge swordsman.
--   * Resisted: leaving the valley over the ridges (there is no floor beyond them any more) and
--     climbing out of the ravine onto the far bank to skip the bridge.
-- The crest carries a tall invisible "mist veil" (collides, ignored by queries and cameras) that
-- follows the ridges, the east pass and the side plateau; the road south to the Bamboo Pass stays
-- open. Anyone who drops into the ravine is carried back to the north bridgehead by the mist.
local Players = game:GetService("Players")

local Characters = require(script.Parent:WaitForChild("CharacterService") :: ModuleScript)
local Kit = require(script.Parent:WaitForChild("MonasteryKit") :: ModuleScript)
local Terrain = require(script.Parent:WaitForChild("MonasteryTerrain") :: ModuleScript)

local Bounds = {}

local V, P = Terrain.VALLEY_HALF, Terrain.PLATEAU
-- Crest polyline segments {x0, z0, x1, z1}; the south end (|x| < 130 at z -1200) is the road out.
Bounds.Walls = {
	{ -V, -646, V, -646 }, -- north ridge
	{ -V, -646, -V, -1200 }, -- west ridge
	{ V, -646, V, P.Z0 }, -- east ridge north of the pass
	{ V, P.Z0, P.X1, P.Z0 }, { P.X1, P.Z0, P.X1, P.Z1 }, { P.X1, P.Z1, P.X0, P.Z1 }, -- side plateau
	{ P.X0, P.Z1, P.X0, -1200 }, -- east ridge south of the plateau
	{ -V, -1200, -130, -1200 }, { 130, -1200, P.X0, -1200 }, -- shoulders either side of the south road
} :: { { number } }
Bounds.HEIGHT, Bounds.THICK = 220, 4
Bounds.Ravine = { HalfX = 140, Z0 = Terrain.RAVINE_Z + 26, Z1 = Terrain.RAVINE_Z - 26, Below = Kit.GROUND - 4.5, Hold = 0.6 }
Bounds.Bridgehead = CFrame.new(0, 3, -926) -- facing -Z: back toward the bridge and its guardian

-- Pure: is this root position down in the ravine (below the banks, between its lips)?
function Bounds.inRavine(p: Vector3): boolean
	local r = Bounds.Ravine
	return math.abs(p.X) < r.HalfX and p.Z < r.Z0 and p.Z > r.Z1 and p.Y < r.Below
end

function Bounds.Build(parent: Instance)
	local group = Kit.folder("MistVeil", parent)
	for _, w in Bounds.Walls do
		local a, b = Vector3.new(w[1], 0, w[2]), Vector3.new(w[3], 0, w[4])
		local length = (b - a).Magnitude + Bounds.THICK
		local mid = (a + b) * 0.5 + Vector3.new(0, Bounds.HEIGHT * 0.5 - 40, 0)
		Kit.part(group, "Veil", Vector3.new(Bounds.THICK, Bounds.HEIGHT, length), CFrame.lookAt(mid, mid + (b - a)),
			Kit.Palette.Mist, Enum.Material.Slate, { Collide = true, Query = false, Transparency = 1, Shadow = false })
	end
end

local below: { [number]: number } = {}
local running = false

local function poll(dt: number)
	for _, player in Players:GetPlayers() do
		local id = player.UserId
		local e = Characters.GetEntity(id)
		if e and e.Fighter.State ~= "KO" and not e.Respawning and not Characters.IsInDuel(id) and Bounds.inRavine(e.Root.Position) then
			below[id] = (below[id] or 0) + dt
			if below[id] >= Bounds.Ravine.Hold then
				below[id] = nil
				Characters.Teleport(id, Bounds.Bridgehead)
				Characters.Cue("RavineReturn", id, {})
			end
		else
			below[id] = nil
		end
	end
end

function Bounds.Start()
	if running then return end
	running = true
	task.spawn(function()
		while running do
			poll(task.wait(0.2))
		end
	end)
end

function Bounds.Stop()
	running = false
	table.clear(below)
end

return Bounds
