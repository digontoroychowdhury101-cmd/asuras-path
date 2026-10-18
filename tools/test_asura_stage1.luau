--!strict
-- Local Luau runner; no Explorer location. Stage 1 (Asura's Path) core module checks.
local Settings = require("../src/shared/CombatSettings")
local Tempo = require("../src/simulation/Tempo")
local Schema = require("../src/simulation/MoveSchema")
local Weapons = require("../src/simulation/WeaponSchema")
local InputBuffer = require("../src/simulation/InputBuffer")
local Animations = require("../src/shared/AnimationCatalog")

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

-- Settings
assert(table.isfrozen(Settings) and table.isfrozen(Settings.Stamina.Costs), "settings frozen")
assert(Settings.Health.MaxHP == 100 and Settings.Posture.MaxPosture == 100 and Settings.Stamina.Max == 100)
assert(Settings.Posture.DeflectWindow == 0.10)
assert(Settings.Stun.StaminaBroken == 1.4 and Settings.Stun.GuardBroken == 1.4 and Settings.Stun.StanceBroken == 2.5)

-- Tempo
assert(near(Tempo.toDuration(1.4), 1) and near(Tempo.toRate(10), 14))
assert(Tempo.HeavyMinFrames == 13 and Tempo.HeavyMinSeconds >= 0.210, "heavy telegraph floor")
assert(Tempo.LightMinFrames == 5, "light telegraph target")
assert(Tempo.toFrames(0.10) == 6 and Tempo.toFramesCeil(0.10) == 6, "deflect window is six ticks")
assert(Tempo.scaleFrames(7) == 5 and Tempo.scaleFrames(24) == 17)
assert(near(Tempo.quantize(0.0249), 1 / 60) and near(Tempo.quantizeUp(0.017), 2 / 60))
assert(Tempo.withinWindow(1.105, 1.0, 0.10) and not Tempo.withinWindow(1.12, 1.0, 0.10))
assert(near(Tempo.reconcile(5.5, 5.0, 0.2), 5.0) and near(Tempo.reconcile(4.0, 5.0, 0.2), 4.8) and near(Tempo.reconcile(4.99, 5.0, 0.2), 299 / 60))

-- MoveSchema
local ok, reason = Schema.canAct("Idle", "Light", 100, 0)
assert(ok and reason == "Ok")
ok, reason = Schema.canAct("Active", "Deflect", 100, 0)
assert(not ok and reason == "NotInWindow")
assert((Schema.canAct("Recovery", "Deflect", 50, 0)))
assert(not Schema.canAct("Recovery", "Light", 50, 0))
assert((Schema.canAct("Recovery", "Light", 50, 0, { ComboWindowOpen = true })))
ok, reason = Schema.canAct("Hitstun", "Roll", 100, 0)
assert(not ok and reason == "StateLocked")
ok, reason = Schema.canAct("Idle", "Heavy", 100, 100)
assert(not ok and reason == "PostureBroken")
ok, reason = Schema.canAct("Idle", "Roll", 5.9, 0)
assert(not ok and reason == "InsufficientStamina")
assert((Schema.canAct("Idle", "Deflect", 0.5, 0)), "deflect needs only positive stamina")
ok, reason = Schema.canAct("Idle", "Heavy", 10, 0, { ArmTier = "Severe" })
assert(not ok and reason == "InsufficientStamina", "severe arm raises heavy cost to 13.5")
ok, reason = Schema.canAct("Idle", "RunningAttack", 100, 0)
assert(not ok and reason == "RequiresSprint")
ok, reason = Schema.canAct("Idle", "Deathblow", 100, 0)
assert(not ok and reason == "NoDeathblowTarget")
assert((Schema.canAct("Deflecting", "Deathblow", 100, 0, { TargetDeathblowable = true })))
ok, reason = Schema.canAct("Idle", "WeaponArt", 100, 0, { Qi = 10, QiCost = 35 })
assert(not ok and reason == "InsufficientQi")
assert(Schema.canTransition("StanceBroken", "DeathblowVictim") and not Schema.canTransition("Idle", "DeathblowVictim"))
assert(Schema.stateDuration("StanceBroken") == 2.5 and Schema.isDeathblowVulnerable("StanceBroken"))
assert(near(Schema.postureDecayMultiplier("Blocking"), Settings.Posture.GuardingDecayMultiplier))
assert(near(Schema.armStaminaMultiplier("Impaired"), 1.30) and near(Schema.armStaminaMultiplier("Severe"), 1.50))
assert(near(Schema.armDamageMultiplier("Impaired"), 0.80) and near(Schema.armDamageMultiplier("Severe"), 0.65))
assert(near(Schema.legSpeedMultiplier("Impaired"), 0.85) and near(Schema.legSpeedMultiplier("Severe"), 0.70))
assert(near(Schema.armStaminaMultiplier("Injured"), 1.40) and near(Schema.legSpeedMultiplier("None"), 1))
assert(Schema.tierFromCoefficient("Head", 0.5) == "Injured" and Schema.tierFromCoefficient("LeftLeg", 0.1) == "None")
assert(Schema.headDeflectWindow("Severe") >= Settings.Posture.DeflectWindowMin)
local p = Schema.penalties({ LeftArm = "Severe", RightArm = "Impaired", RightLeg = "Injured" }, true)
assert(near(p.StaminaCostMultiplier, 1.5) and near(p.SpeedMultiplier, 0.775))
p = Schema.penalties({ LeftArm = "Severe", RightArm = "None" }, false, "Right")
assert(near(p.StaminaCostMultiplier, 1))

-- WeaponSchema
for _, kind in Weapons.WeaponTypes do
	local weapon = Weapons.get(kind)
	assert(#weapon.Light >= 3 and #weapon.Light <= 4)
	for _, move in weapon.Moves do
		assert(move.Timing.Reactable, move.Id .. " reactable")
		if move.Kind == "Heavy" or move.Kind == "WeaponArt" then
			assert(move.Timing.StartupSeconds >= 0.210, move.Id .. " heavy telegraph")
		end
	end
end
local jian, dao, glaive = Weapons.get("Jian"), Weapons.get("Dao"), Weapons.get("Guandao")
assert(Weapons.getById("Jian_Sword") == jian and Weapons.nextLight(jian, jian.Light[4]) == jian.Light[1])
assert(Weapons.get("Unarmed").Light[1].Timing.StartupFrames == 5, "jab ~83ms")
assert(glaive.Heavy.Timing.StartupFrames > jian.Heavy.Timing.StartupFrames, "glaive slower")
local viaJian = Weapons.deflectOutcome(glaive.Heavy, glaive, jian)
local viaDao = Weapons.deflectOutcome(glaive.Heavy, glaive, dao)
assert(viaJian.AttackerPosture > viaDao.AttackerPosture and viaJian.DefenderPosture < viaDao.DefenderPosture and viaJian.DefenderStamina == 0)
local blocked = Weapons.blockOutcome(dao.Light[1], dao, jian, 100)
assert(blocked.DefenderChip > 0 and not blocked.GuardBreak and blocked.DefenderStamina == 12)
assert(Weapons.blockOutcome(dao.Light[1], dao, jian, 10).GuardBreak)
assert(Weapons.bleedBuildup(dao.Heavy, dao) > Weapons.bleedBuildup(jian.Heavy, jian))

-- InputBuffer
local buffer = InputBuffer.new(4, 0.10)
assert(InputBuffer.push(buffer, "Light", 1.00))
assert(not InputBuffer.push(buffer, "Light", 1.01), "duplicate press refreshes")
assert(InputBuffer.push(buffer, "Heavy", 1.02))
assert(InputBuffer.push(buffer, "Deflect", 1.03))
local action = InputBuffer.pop(buffer, 1.05)
assert(action == "Deflect", "deflect has highest priority")
action = InputBuffer.pop(buffer, 1.05)
assert(action == "Heavy")
assert(InputBuffer.pop(buffer, 1.20) == nil, "stale light flushed")
assert(InputBuffer.count(buffer) == 0 and buffer.Count == 0)
for index = 1, 6 do
	InputBuffer.push(buffer, if index % 2 == 0 then "Roll" else "Light", 2 + index * 0.05)
end
assert(InputBuffer.count(buffer, 2.30) <= 4)
InputBuffer.push(buffer, "Block", 3.0)
InputBuffer.push(buffer, "Light", 3.0)
local filtered = InputBuffer.pop(buffer, 3.01, function(a)
	return a ~= "Block"
end)
assert(filtered == "Light" and InputBuffer.has(buffer, "Block", 3.01))
assert(InputBuffer.discard(buffer, "Block") == 1)
InputBuffer.clear(buffer)
assert(InputBuffer.count(buffer) == 0)

-- Animation catalog: every slot resolves, weapons fall back to Unarmed, nothing is custom yet.
assert(#Animations.pending() == #Animations.UniversalKeys + #Animations.WeaponNames * #Animations.WeaponKeys + #Animations.EnemyKeys)
for _, weapon in Animations.WeaponNames do
	for _, key in Animations.WeaponKeys do
		assert(string.match(Animations.resolve(Animations.weapon(weapon, key)), "^rbxassetid://%d+$"))
	end
end
assert(Animations.weapon("Unknown", "Idle") == Animations.Weapons.Unarmed.Idle)
assert(Animations.light("Guandao", 9) == Animations.Weapons.Guandao.Light4)
assert(Animations.resolve(Animations.Universal.Roll, "R6") ~= Animations.resolve(Animations.Universal.Roll, "R15"))
assert(table.isfrozen(Animations.Weapons.Jian.Light1))
assert(#Animations.allIds("R15") >= 5)

print("Asura Stage 1: all checks passed")
