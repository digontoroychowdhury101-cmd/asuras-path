-- Prints every playable weapon's authoritative move timing (built WeaponSchema: 1.4x tempo, 60 Hz ticks) as JSON for the clip baker.
local W = require("../../../src/simulation/WeaponSchema")
local out = {}
for _, id in W.WeaponKeys do
	local weapon = W.Weapons[id]
	local rows = {}
	local function add(m)
		local t = m.Timing
		table.insert(rows, string.format('"%s":{"kind":"%s","index":%d,"startup":%.6f,"active":%.6f,"recovery":%.6f,"combo":%.6f,"total":%.6f,"arc":%.3f,"reach":%.3f,"lunge":%.3f}',
			m.Id, m.Kind, m.ComboIndex or 0, t.StartupSeconds, t.ActiveSeconds, t.RecoverySeconds, t.ComboWindowSeconds, t.TotalSeconds, m.Arc, m.Reach, m.Lunge))
	end
	for _, m in weapon.Light do add(m) end
	add(weapon.Heavy); add(weapon.RunningAttack); add(weapon.WeaponArt)
	table.insert(out, string.format('"%s":{"grip":"%s","moves":{%s}}', id, tostring(weapon.Grip), table.concat(rows, ",")))
end
print("{" .. table.concat(out, ",") .. "}")
