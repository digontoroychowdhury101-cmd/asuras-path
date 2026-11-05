--!nonstrict
-- Lune regression: the real ShenPresentation on engine fakes. Effects and sounds run on the server's impact times, a cancel ends what has not left his hand, released beads and the
-- wave finish on bounded lives, a reset or departure leaves nothing. Emulated clock and instances: not a Studio view, and it says nothing about how any of this looks or sounds.
local Scene = require("./rig_scene")
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local V3, CF, Instance = Scene.V3, Scene.CF, Scene.Instance

local passed, failed = 0, 0
local function check(name: string, condition: any)
	if condition then passed += 1 else failed += 1; print("FAIL " .. name) end
end

local clock = 100
local beats: { any } = {}
local Heartbeat = { Connect = function(_, fn)
	local link = { Fn = fn }
	table.insert(beats, link)
	return { Disconnect = function() table.remove(beats, table.find(beats, link)) end }
end }
local function run(to: number)
	while clock < to do
		clock = math.min(clock + 1 / 30, to)
		for _, link in table.clone(beats) do link.Fn(1 / 30) end
	end
end

local camera = Instance.new("Folder")
local moved = 0
local fakeWorkspace = { CurrentCamera = camera, GetServerTimeNow = function() return clock end,
	BulkMoveTo = function(_, parts, frames) moved += 1; for i, p in parts do p.CFrame = frames[i] end end }
local played: { any } = {}
local Audio = { id = function() return "" end, play = function(key, parent, volume, _looped, pitch)
	local s = { Key = key, Parent = parent, Volume = volume, Pitch = pitch, Stopped = false, Stop = function(self) self.Stopped = true end, Destroy = function(self) self.Parent = nil end, RollOffMaxDistance = 0 }
	table.insert(played, s)
	return s
end }
local Comfort = { reduced = function() return false end, flash = function(x) return x end }
local Data = luau.load(fs.readFile("src/shared/ShenPresentationData.luau"), { debugName = "data", environment = { Color3 = roblox.Color3, table = table, math = math } })()
local services = {
	RunService = { Heartbeat = Heartbeat },
	ContentProvider = { PreloadAsync = function() end },
	Debris = { AddItem = function() end },
	TweenService = { Create = function() return { Play = function() end } end },
	ReplicatedStorage = { WaitForChild = function(_, name)
		if name == "AsurasPath" then return { Shared = { ShenPresentationData = Data, EffectsPreference = Comfort } } end
		return nil
	end },
}
local Presentation = Scene.load("src/client/Controllers/ShenPresentation.luau", {
	game = { GetService = function(_, name) return services[name] end }, workspace = fakeWorkspace, script = { Parent = { SpatialAudio = Audio } },
	UserSettings = function() error("no settings in the fake") end, Random = { new = function() return { NextUnitVector = function() return V3.new(0, 1, 0) end, NextNumber = function(_, a) return a end } end },
	NumberSequence = { new = function(...) return { ... } end }, NumberSequenceKeypoint = { new = function(...) return { ... } end }, ColorSequence = { new = function(...) return { ... } end },
	TweenInfo = { new = function(...) return { ... } end }, task = { spawn = function() end }, Part = nil,
})

local function actor()
	local model = Instance.new("Model")
	model.Name = "Shen"
	model:SetAttribute("AsuraLookKey", "GrandmasterShen")
	model:SetAttribute("AsuraBossPhase", 1)
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.CFrame = CF.new(0, 4, 0)
	root.Parent = model
	local skin = Instance.new("Model")
	skin.Name = "AsuraBossSkin"
	skin.Parent = model
	local blade = Instance.new("MeshPart")
	blade.Name = "Shen1_Weapon_1"
	blade.Parent = skin
	for _, name in { "BladeTip", "BladeBase" } do
		local a = Instance.new("Attachment")
		a.Name = name
		a.Parent = blade
	end
	local hand = Instance.new("MeshPart")
	hand.Name = "Shen1_LeftHand"
	hand.Parent = skin
	local bead = Instance.new("Attachment")
	bead.Name = "BeadHand"
	bead.Parent = hand
	local chest = Instance.new("MeshPart")
	chest.Name = "Shen1_UpperTorso"
	chest.Parent = skin
	local core = Instance.new("Attachment")
	core.Name = "ChestCore"
	core.Parent = chest
	model.Parent = Instance.new("Folder")
	return model, blade
end
local function fxCount()
	local folder = camera:FindFirstChild("ShenFx")
	return if folder then #folder:GetChildren() else 0
end
local function trails(blade) return blade:FindFirstChild("ShenEdge") end
local function cue(kind, data) return { Kind = kind, Data = data, Time = clock, Source = -1 } end
local model, blade = actor()
local source = { Model = model }

-- not his look
local other = Instance.new("Model")
check("another boss's cues are left alone", Presentation.cue(cue("Telegraph", { move = "FlowingJian", impact = clock + 1 }), { Model = other }) == false and #beats == 0)

-- 1. four thrusts: sound before each impact, escalating; the edge draws only around it; the generic ring stays
local impact = clock + 0.8
check("a telegraph keeps the generic warning", Presentation.cue(cue("Telegraph", { move = "FlowingJian", kind = "PerilousThrust", impact = impact }), source) == false)
for i = 1, 3 do Presentation.cue(cue("Telegraph", { move = "FlowingJian", impact = impact + i * 0.65 }), source) end
run(impact - 0.25)
check("nothing sounds ahead of its onset", #played == 0 and not trails(blade))
run(impact)
check("the first whoosh leads the impact", #played >= 1 and played[1].Key == "GithubWhooshLight")
check("the edge trail draws around the impact", trails(blade) ~= nil)
run(impact + 0.3)
check("and closes after it", not trails(blade))
run(impact + 2.3)
local whooshes = {}
for _, s in played do if s.Key == "GithubWhooshLight" then table.insert(whooshes, s.Pitch) end end
check("four whooshes escalate", #whooshes == 4 and whooshes[4] > whooshes[3] and whooshes[3] > whooshes[2] and whooshes[2] > whooshes[1])

-- 2. a posture break during the bead windup ends everything still in his hand
table.clear(played)
impact = clock + 1.1
Presentation.cue(cue("Telegraph", { move = "PrayerBeads", kind = "Barrage", impact = impact, radius = 90 }), source)
run(impact - 0.5)
check("seven beads gather", fxCount() == 7)
local charge
for _, s in played do if s.Key == "NovaCharge" then charge = s end end
check("the tension rise is sounding", charge ~= nil and charge.Parent ~= nil)
Presentation.sync(model, "StanceBroken")
check("a posture break clears the windup beads", fxCount() == 0)
check("and its charge sound", charge.Stopped and charge.Parent == nil)
table.clear(played)
run(impact + 0.2)
check("no launch fires after the cancel", #played == 0)

-- 3. released beads follow the server, finish on hit, and expire if no hit comes
impact = clock + 1.1
Presentation.cue(cue("Telegraph", { move = "PrayerBeads", impact = impact }), source)
run(impact)
for i = 1, 7 do
	check("a projectile cue replaces the generic spark", Presentation.cue(cue("BossProjectile", { index = i, x = i, y = 5, z = 0, attack = 1, move = "PrayerBeads", target = 1, state = "fly" }), source) == true)
end
Presentation.sync(model, "Hitstun")
check("released beads outlive a cancel", fxCount() == 7)
Presentation.cue(cue("BossProjectile", { index = 3, x = 3, y = 5, z = 0, attack = 1, move = "PrayerBeads", target = 1, state = "hit" }), source)
check("a hit ends that bead (one puff beside the rest)", fxCount() == 7)
run(clock + Data.Limits.BeadTtlPad + 0.2)
local beads = 0
for _, p in camera:FindFirstChild("ShenFx"):GetChildren() do if p.Material == Scene.Enum.Material.Wood then beads += 1 end end
check("the rest expire with no cue", beads == 0)
camera:FindFirstChild("ShenFx"):ClearAllChildren()

-- 4. the blood wave replaces the generic ring, is bounded, and its edge is the server's own
moved = 0
local start = clock
check("the wave replaces the generic ring", Presentation.cue(cue("BossHazard", { move = "BloodWave", start = start, speed = 38, radius = 90, x = 0, y = 0.3, z = 0 }), source) == true)
check("its segments are bounded by the tier", fxCount() == Data.Tiers.Mid.WaveSegments * Data.Tiers.Mid.WaveLayers)
run(start + 1)
check("it moves every frame in bulk", moved > 20)
local far = 0
for _, p in camera:FindFirstChild("ShenFx"):GetChildren() do far = math.max(far, V3.new(p.CFrame.Position.X, 0, p.CFrame.Position.Z).Magnitude) end
check("the leading edge is at speed x age", math.abs(far - 38) < 1.5)
run(start + 90 / 38 + 0.1)
check("and it is gone at the server's radius", fxCount() == 0)

-- 5. the transition: burst at the reveal, never early, and a reset leaves nothing
table.clear(played)
local t0 = clock
check("the transition replaces the generic bloom", Presentation.cue({ Kind = "BossPhase", Data = { phase = 2, reveal = 0.9, duration = 2.4 }, Time = t0, Source = -1 }, source) == true)
run(t0 + 0.8)
check("no burst before the reveal", fxCount() == 0)
run(t0 + 0.95)
check("the burst is bounded", fxCount() > 0 and fxCount() <= 1 + Data.Limits.Shreds + 7)
Presentation.cue(cue("Telegraph", { move = "PrayerBeads", impact = clock + 1.1 }), source)
Presentation.cue(cue("BossHazard", { move = "BloodWave", start = clock, speed = 38, radius = 90, x = 0, y = 0.3, z = 0 }), source)
run(clock + 0.3)
Presentation.clear()
check("a reset removes every effect", fxCount() == 0)
check("and stops the frame callback", #beats == 0)
table.clear(played)
run(clock + 3)
check("nothing scheduled fires after a reset", #played == 0)

-- 6. the actor leaves the world mid-move
Presentation.cue(cue("Telegraph", { move = "GuandaoSkyfall", impact = clock + 1.5 }), source)
run(clock + 0.1)
model.Parent = nil
run(clock + 0.1)
check("a departed actor's session ends", #beats == 0 and fxCount() == 0)

print(string.format("shen presentation: %d passed, %d failed (engine fakes; Studio look and sound separate)", passed, failed))
if failed > 0 then error("shen presentation regression failed") end
