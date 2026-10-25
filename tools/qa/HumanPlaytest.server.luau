--!nonstrict
-- Unmapped Studio-only kit for the 20-minute human combat playtest (post-F26, `HUMAN_PLAYTEST.md`).
-- Loaded into a running Play session by `python3 tools/qa/human_playtest.py` (never saved, never
-- published). It only moves the player to four combat stations, sets the weapon a station needs and
-- refills health/stamina/posture on request. It changes no rule, timing, AI or damage. Any use marks
-- the player `AsuraPlaytestSeeded`, so a session that touched the kit is never earned evidence.
local Run = game:GetService("RunService")
if not Run:IsStudio() then return end
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local Characters = require(SSS.AsurasPath.Services.CharacterService)
local World = require(ReplicatedStorage.AsurasPath.Shared.WorldDefinitions)

local old = ReplicatedStorage:FindFirstChild("AsuraPlaytest")
if old then old:Destroy() end
local remote = Instance.new("RemoteEvent")
remote.Name = "AsuraPlaytest"
remote.Parent = ReplicatedStorage

-- Nearest living enemy of `kind` to a planar point.
local function nearest(kind: string, x: number, z: number)
	local best, gap = nil, math.huge
	for _, e in Characters.Entities() do
		if e.Kind == "Enemy" and e.Root.Parent and e.Fighter.State ~= "KO" and string.find(e.Model.Name, kind, 1, true) then
			local d = (Vector3.new(e.Root.Position.X, 0, e.Root.Position.Z) - Vector3.new(x, 0, z)).Magnitude
			if d < gap then best, gap = e, d end
		end
	end
	return best
end

-- Stand `distance` studs in front of a foe, facing it.
local function before(foe, distance: number): CFrame
	local look = foe.Root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.1 then look = Vector3.zAxis end
	local spot = foe.Root.Position + look.Unit * distance
	return CFrame.lookAt(spot, Vector3.new(foe.Root.Position.X, spot.Y, foe.Root.Position.Z))
end

local gate = World.FogGates.Gate_TwinSentinels
local STATIONS = {
	Yard = { Label = "1 Training yard", Kind = "Sparring Phantom", X = 15, Z = -705, Distance = 18 },
	Monk = { Label = "2 Monk courtyard", Kind = "Corrupt Wandering Monk", X = 0, Z = -786, Distance = 16 },
	Bridge = { Label = "3 Bridge swordsman (Jian)", Kind = "Cursed Swordsman", X = 0, Z = -960, Distance = 16, Weapon = "Jian" },
	Twins = { Label = "4 Twin Sentinels gate", Gate = gate },
}

local function log(player: Player, text: string)
	print(string.format("[Playtest] t=%.1f %s %s", Characters.Now(), player.Name, text))
end

remote.OnServerEvent:Connect(function(player: Player, op: any, arg: any)
	local me = Characters.GetEntity(player.UserId)
	if not me or type(op) ~= "string" then return end
	player:SetAttribute("AsuraPlaytestSeeded", true)
	if op == "go" and STATIONS[arg] then
		local station = STATIONS[arg]
		local target: CFrame?
		if station.Gate then
			local o, p = station.Gate.Outside, station.Gate.Placement
			local spot = Vector3.new(o.X, o.Y + 1, o.Z)
			target = CFrame.lookAt(spot, Vector3.new(p.X, spot.Y, p.Z))
		else
			local foe = nearest(station.Kind, station.X, station.Z)
			if not foe then remote:FireClient(player, "note", "No living " .. station.Kind .. " near that station; press Stop and Play for a fresh world."); return end
			target = before(foe, station.Distance)
		end
		if station.Weapon then Characters.ForceWeapon(me.Id, station.Weapon) end
		Characters.Teleport(me.Id, target :: CFrame)
		Characters.RestoreFighter(me.Id)
		log(player, "station " .. arg)
		remote:FireClient(player, "note", station.Label)
	elseif op == "heal" then
		Characters.RestoreFighter(me.Id)
		log(player, "heal")
		remote:FireClient(player, "note", "Health, stamina and posture refilled")
	elseif op == "weapon" and (arg == "Jian" or arg == "Unarmed") then
		Characters.ForceWeapon(me.Id, arg)
		log(player, "weapon " .. arg)
		remote:FireClient(player, "note", "Weapon: " .. (if arg == "Unarmed" then "fists" else arg))
	elseif op == "mark" and type(arg) == "string" then
		-- The tester's "something felt wrong here" key: a timestamp to match against the recording.
		log(player, "MARK " .. string.sub(arg, 1, 40))
		remote:FireClient(player, "note", "Marked " .. string.sub(arg, 1, 40))
	end
end)
print("[Playtest] kit ready: stations " .. table.concat({ "Yard", "Monk", "Bridge", "Twins" }, ", "))
