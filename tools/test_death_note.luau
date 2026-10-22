--!nonstrict
-- Runs the real InterfaceController death-screen methods (ShowDeath, DeathNote, HideDeath) with stub
-- engine services. Regression for follow-up 02: in Studio the server's EssenceLost cue reached the
-- client before the KO event, and ShowDeath then rewrote the note with zero spilled essence, so the
-- death screen dropped "500 essence spilled". Both arrival orders must keep the loss line, and the
-- next death must not inherit the previous amount.
local passed, failed = 0, 0
local function check(name: string, ok: boolean)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name)
	end
end

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local source = fs.readFile("src/client/Controllers/InterfaceController.luau")
local first = assert(string.find(source, "function Controller.ShowDeath", 1, true))
local last = assert(string.find(source, "-- Fades to the portal's light", first, true))
local chunk = "local Controller, TweenService, TweenInfo, Enum, World, task = ...\n" .. string.sub(source, first, last - 1) .. "\nreturn Controller"

local tween = { Play = function() end }
local TweenService = { Create = function() return tween end }
local TweenInfo = { new = function() return {} end }
local Enum = { EasingStyle = { Sine = 0 } }
local World = { Altars = { Altar_DesecratedCloister = { Name = "Desecrated Cloister" } } }
local fakeTask = { delay = function(_, fn) fn() end }
local Controller = luau.load(chunk, { debugName = "InterfaceController.death" })({}, TweenService, TweenInfo, Enum, World, fakeTask)

local function label() return { Text = "", TextTransparency = 1, TextStrokeTransparency = 1 } end
local function interface()
	local attributes = { AsuraActiveAltar = "Altar_DesecratedCloister" }
	local self = {
		DeathShown = false, DeathSpilled = 0,
		Player = { GetAttribute = function(_, key) return attributes[key] end },
		Toast = label(), Banner = label(), BannerSub = label(), DeathTitle = label(), DeathSub = label(), DeathDetail = label(),
		Death = { Visible = false, BackgroundTransparency = 1 },
		CloseAltar = function() end,
	}
	return setmetatable(self, { __index = Controller })
end
local SPILLED = "500 essence spilled"

-- Order seen in Studio: EssenceLost cue, then the KO event.
local a = interface()
a:DeathNote(500)
a:ShowDeath()
check("cue before KO keeps the loss line", string.find(a.DeathDetail.Text, SPILLED, 1, true) ~= nil)
check("cue before KO names the wake altar", string.find(a.DeathDetail.Text, "wake at Desecrated Cloister", 1, true) ~= nil)

-- Opposite order: KO first, then the cue.
local b = interface()
b:ShowDeath()
b:DeathNote(500)
check("KO before cue shows the loss line", string.find(b.DeathDetail.Text, SPILLED, 1, true) ~= nil)

-- Respawn, then a second death with nothing carried: no stale amount.
a:HideDeath()
a:ShowDeath()
a:DeathNote(0)
check("second death carries no stale amount", string.find(a.DeathDetail.Text, "spilled", 1, true) == nil)
check("second death still names the wake altar", string.find(a.DeathDetail.Text, "wake at", 1, true) ~= nil)

-- A second KO report during one death does not reset the note.
b:ShowDeath()
check("duplicate KO keeps the loss line", string.find(b.DeathDetail.Text, SPILLED, 1, true) ~= nil)

print(string.format("death note: %d passed, %d failed", passed, failed))
if failed > 0 then
	error("death note regression failed")
end
