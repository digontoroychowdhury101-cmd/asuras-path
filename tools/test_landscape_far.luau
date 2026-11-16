--!nonstrict
-- Runs the real LandscapeBudget against fakes: the "<Id>_Far" silhouette shows only beyond FarBeyond
-- from the camera, hides nearer, hides in the lobby, follows tag add/remove and Destroy restores it.
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

print(string.format("landscape far: %d passed, %d failed", passed, failed))
if failed > 0 then error("landscape far toggle failed") end
