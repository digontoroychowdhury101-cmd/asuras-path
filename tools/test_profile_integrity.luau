--!strict
-- Standalone Luau regression suite; no Explorer script or Roblox engine required.
local Schema = require("../src/shared/ProfileSchema")

local numericFields = {
	"elo", "peakElo", "wins", "losses", "draws", "winStreak", "qiEssence",
	"styleSpins", "pityCounter", "lastSaveTime",
}
local badNumbers = { 0 / 0, math.huge, -math.huge, -1, 1.5, "corrupt", false, {} }
for _, field in numericFields do
	for _, bad in badNumbers do
		local raw: any = Schema.Default(123)
		raw[field] = bad
		assert(not Schema.Validate(raw), "Validator accepted invalid " .. field)
		local repaired = Schema.Migrate(raw, 123)
		local valid, reason = Schema.Validate(repaired)
		assert(valid, "Migration left invalid " .. field .. ": " .. tostring(reason))
	end
end

-- Mixed-type peak repair previously threw while comparing a number with a string.
local mixed = Schema.Migrate({ elo = "corrupt", peakElo = 1500 }, 123)
assert(mixed.elo == 1000 and mixed.peakElo == 1500)

for _, field in { "xp", "level" } do
	for _, bad in badNumbers do
		local raw: any = Schema.Default(123)
		raw.styles.Ironline[field] = bad
		assert(not Schema.Validate(raw), "Invalid style " .. field .. " accepted")
		assert(Schema.Validate(Schema.Migrate(raw, 123)))
	end
end
for _, field in { "fov", "sensitivity" } do
	for _, bad in { 0 / 0, math.huge, -math.huge, "corrupt", false, {} } do
		local raw: any = Schema.Default(123)
		raw.settings[field] = bad
		assert(not Schema.Validate(raw), "Invalid setting accepted")
		assert(Schema.Validate(Schema.Migrate(raw, 123)))
	end
end

local locked: any = Schema.Default(123)
locked.activeStyle = "DragonClaw"
assert(not Schema.Validate(locked), "Locked active style accepted")
assert(Schema.Migrate(locked, 123).activeStyle == "Ironline")
locked.styles = {}
assert(not Schema.Validate(locked), "Missing styles accepted")
assert(Schema.Validate(Schema.Migrate(locked, 123)))

local future: any = Schema.Default(123)
future.schemaVersion += 1
assert(not Schema.Validate(future))
assert(not pcall(Schema.Migrate, future, 123), "Newer profile version silently downgraded")

local original = Schema.Default(123)
original.settings.fov = 80 -- Explicit fixture: verify isolation independently of the current camera default.
original.qiEssence = nil
original.qiEssence = 12345
original.styles.ApexStriker = { unlocked = true, xp = 2500, level = 3 }
original.activeStyle = "ApexStriker"
local repaired = Schema.Migrate(original, 123)
assert((repaired.qiEssence == 12345 or repaired.qiEssence == 12345) and repaired.styles.ApexStriker.xp == 2500)
assert(repaired.activeStyle == "ApexStriker" and repaired.styles.ApexStriker.level == 3)
repaired.styles.ApexStriker.xp = 0
repaired.settings.fov = 70
assert(original.styles.ApexStriker.xp == 2500 and original.settings.fov == 80, "Migration aliases input")

print("PASS profile integrity: invalid numbers, nested corruption, locked styles, future versions, valid-data preservation and table isolation")
