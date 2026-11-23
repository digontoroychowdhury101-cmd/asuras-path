--!nonstrict
-- Runs the real LandscapeBudget against fakes: the "<Id>_Far" silhouette shows only beyond FarBeyond
-- from the camera, hides nearer, hides in the lobby, follows tag add/remove and Destroy restores it; AsuraKeepFar map meshes
-- skip the 900-stud cut and the size fade outside the lobby.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox") :: any
local Vector3, CFrame = roblox.Vector3, roblox.CFrame

local passed, failed = 0, 0
local function check(name: string, ok: boolean)
	if ok then passed += 1 else failed += 1; print("FAIL " .. name) end
end

local function signal()
	local s = { fns = {} }
	function s:Connect(fn)
		table.insert(self.fns, fn)
		return { Disconnect = function() table.remove(self.fns, table.find(self.fns, fn)) end }
	end
	function s:Fire(...) for _, fn in table.clone(self.fns) do fn(...) end end
	return s
end

local function inst(class, name, parent)
	local i = { ClassName = class, Name = name, Parent = parent, Kids = {}, Attrs = {} }
	function i:IsA(c) return c == class or (c == "BasePart" and class == "Part") end
	function i:GetAttribute(k) return self.Attrs[k] end
	function i:GetDescendants() return self.Kids end
	function i:GetPivot() return CFrame.new(self.At) end
	return i
end
local function farModel(at, beyond)
	local m = inst("Model", "Test_Far", {})
	m.At, m.Attrs.FarBeyond = at, beyond
	for k = 1, 2 do
		local p = inst("Part", "Box" .. k, m)
		p.LocalTransparencyModifier = 0
		table.insert(m.Kids, p)
	end
	return m
end

local tagged, added, removed, heartbeat = {}, signal(), signal(), signal()
local camera = { CFrame = CFrame.new(0, 0, 0) }
local player = { attrs = { AsuraRegion = "Forest" } }
function player:SetAttribute(k, v) self.attrs[k] = v end
function player:GetAttribute(k) return self.attrs[k] end
local fakeWorkspace = { CurrentCamera = camera, DescendantAdded = signal() }
function fakeWorkspace:GetDescendants() return {} end
local services = {
	Players = { LocalPlayer = player },
	UserInputService = { TouchEnabled = false },
	RunService = { Heartbeat = heartbeat },
	CollectionService = {
		GetTagged = function(_, tag) return if tag == "OverworldLandmarkFar" then table.clone(tagged) else {} end,
		GetInstanceAddedSignal = function(_, tag) return if tag == "OverworldLandmarkFar" then added else signal() end,
		GetInstanceRemovedSignal = function(_, tag) return if tag == "OverworldLandmarkFar" then removed else signal() end,
	},
}
local anyTable = setmetatable({}, { __index = function(t) return t end })
services.ReplicatedStorage = { AsurasPath = { Shared = anyTable } }
local game = { GetService = function(_, n) return services[n] end }
local stub = { decor = function() return 1 end, isLobby = function(region) return region == nil or region == "" or region == "Sanctuary" end }
local function fakeRequire() return stub end
local env = setmetatable({ game = game, workspace = fakeWorkspace, require = fakeRequire,
	UserSettings = function() return { GetService = function() return { SavedQualityLevel = { Value = 10 } } end } end },
	{ __index = getfenv() })
-- WorldMap and EffectsPreference are both `anyTable` here; the fake serves isLobby/decor for either.
local Budget = luau.load(fs.readFile("src/client/Controllers/LandscapeBudget.luau"), { debugName = "LandscapeBudget", environment = env })()

check("farShown: hidden inside, shown outside", not Budget.farShown(600, 700, nil, false) and Budget.farShown(800, 700, nil, false))
check("farShown: hysteresis band", not Budget.farShown(710, 700, false, false) and Budget.farShown(710, 700, true, false))
check("farShown: lobby never shows", not Budget.farShown(5000, 700, true, true))

local m = farModel(Vector3.new(0, 0, 1000), 700)
table.insert(tagged, m)
local b = Budget.new()
local function mod(i) return m.Kids[i].LocalTransparencyModifier end
check("camera 1000 away: _Far shown", mod(1) == 0 and mod(2) == 0)
camera.CFrame = CFrame.new(0, 0, 500) -- 500 from the model, inside FarBeyond
b:Refresh()
check("camera 500 away: _Far hidden", mod(1) == 1 and mod(2) == 1)
camera.CFrame = CFrame.new(0, 0, 290) -- 710 away: inside the +15 band, still hidden
b:Refresh()
check("hysteresis keeps it hidden at 710", mod(1) == 1)
camera.CFrame = CFrame.new(0, 0, 200)
b:Refresh()
check("beyond the band: shown again", mod(1) == 0)
player.attrs.AsuraRegion = "Sanctuary"
camera.CFrame = CFrame.new(0, 0, 0)
b:Refresh()
check("lobby hides _Far even when far", mod(1) == 1)
player.attrs.AsuraRegion = "Forest"
b:Refresh()
check("leaving the lobby shows it again", mod(1) == 0)

local late = farModel(Vector3.new(0, 0, 100), 700)
added:Fire(late)
b:Refresh()
check("streamed-in _Far under 700 is hidden", late.Kids[1].LocalTransparencyModifier == 1)
removed:Fire(late)
check("tag removal restores the model", late.Kids[1].LocalTransparencyModifier == 0 and b.Far[late] == nil)
camera.CFrame = CFrame.new(0, 0, 500)
b:Refresh()
local gone = farModel(Vector3.new(0, 0, 900), 700)
added:Fire(gone); gone.Parent = nil
b:Refresh()
check("unparented _Far row is dropped", b.Far[gone] == nil)
b:Destroy()
check("Destroy restores visibility", mod(1) == 0 and mod(2) == 0 and next(b.Far) == nil)

-- AsuraKeepFar (Vesperhold spires, towers and glass windows): no 900-stud cut and no projected-size fade, except in the lobby.
local function mapPart(name, at, radius, keepFar)
	local map = inst("Folder", "Map_Overworld", fakeWorkspace)
	local model = inst("Model", "Spire", map)
	model.Attrs.AsuraKeepFar = (keepFar == true) or nil
	local p = inst("MeshPart", name, model)
	p.Attrs.AsuraKeepFar = (keepFar == "part") or nil
	p.Anchored, p.Position, p.Size, p.LocalTransparencyModifier, p.Transparency = true, at, Vector3.new(radius * 2, 0, 0), 0, 0
	function p:IsA(c) return c == "MeshPart" or c == "BasePart" end
	function p:IsDescendantOf(x) return x == fakeWorkspace end
	return p
end
local kept = mapPart("Spire_Needle_Tip__Iron", Vector3.new(0, 0, 1500), 10, true)
local plain = mapPart("Spire_Needle_Tip__Iron", Vector3.new(0, 0, 1500), 10, false)
local glass = mapPart("Portal_Great__GlassR", Vector3.new(0, 0, 600), 2, true)
local stone = mapPart("Spire_Belfry_Stage__Stone", Vector3.new(0, 0, 1500), 10, "part") -- the attribute on the part itself
camera.CFrame = CFrame.new(0, 0, 0)
player.attrs.AsuraRegion = "Forest"
local k = Budget.new()
fakeWorkspace.DescendantAdded:Fire(kept); fakeWorkspace.DescendantAdded:Fire(plain); fakeWorkspace.DescendantAdded:Fire(glass)
fakeWorkspace.DescendantAdded:Fire(stone)
k:Refresh()
check("all four meshes registered", #k.Parts == 4)
check("a part marked AsuraKeepFar itself stays drawn at 1500", stone.LocalTransparencyModifier == 0)
check("keep-far spire stays drawn at 1500 studs", kept.LocalTransparencyModifier == 0)
check("an unmarked map mesh is still cut beyond 900", plain.LocalTransparencyModifier == 1)
check("small keep-far glass is not faded by projected size", glass.LocalTransparencyModifier == 0)
player.attrs.AsuraRegion = "Sanctuary"
k:Refresh()
check("the lobby still hides keep-far meshes beyond 900", kept.LocalTransparencyModifier == 1)
player.attrs.AsuraRegion = "Forest"
k:Refresh()
check("leaving the lobby draws them again", kept.LocalTransparencyModifier == 0)
-- LocalTransparencyModifier hides a mesh but the renderer still draws it (win-86: 3.62M castle tris either way);
-- a fully faded mesh must also take Transparency 1, and get its own value back when it returns.
check("a mesh cut beyond 900 is really dropped (Transparency 1)", plain.Transparency == 1)
check("kept meshes keep their Transparency", kept.Transparency == 0 and stone.Transparency == 0)
camera.CFrame = CFrame.new(0, 0, 1400)
k:Refresh()
check("back in range: the cut mesh is drawn again", plain.Transparency == 0 and plain.LocalTransparencyModifier == 0)
k:Destroy()

-- Castle ornament subs (crockets, tracery) span a whole spire, so their bounds pass the 38-stud keep, yet their detail
-- is a few studs: they fade by detail size. Silhouette stone of the same bounds stays.
camera.CFrame = CFrame.new(0, 0, 0)
local crockets = mapPart("Spire_Belfry_Stage__Crockets_2", Vector3.new(0, 0, 400), 22, false)
local tracery = mapPart("Arcade_Bay_60__Tracery", Vector3.new(0, 0, 700), 25, false)
local bigStone = mapPart("Spire_Belfry_Stage__Stone", Vector3.new(0, 0, 700), 25, false)
local nearCrockets = mapPart("Spire_Belfry_Stage__Crockets", Vector3.new(0, 0, 120), 22, false)
local o = Budget.new()
for _, p in { crockets, tracery, bigStone, nearCrockets } do fakeWorkspace.DescendantAdded:Fire(p) end
o:Refresh()
check("crockets 400 studs away are dropped", crockets.Transparency == 1)
check("tracery 700 studs away is dropped", tracery.Transparency == 1)
check("stone of the same bounds stays", bigStone.Transparency == 0 and bigStone.LocalTransparencyModifier == 0)
check("crockets 120 studs away stay", nearCrockets.Transparency == 0 and nearCrockets.LocalTransparencyModifier == 0)
o:Destroy()
check("Destroy gives dropped meshes their Transparency back", crockets.Transparency == 0 and tracery.Transparency == 0)

print(string.format("landscape far: %d passed, %d failed", passed, failed))
if failed > 0 then error("landscape far toggle failed") end
