-- Prints the Jian's authoritative move timing (built WeaponSchema: 1.4x tempo, 60 Hz ticks) as JSON for the clip baker.
local W = require("../../../src/simulation/WeaponSchema")
local jian = W.Weapons.Jian
local out = {}
local function add(m)
	local t = m.Timing
	table.insert(out, string.format('"%s":{"kind":"%s","startup":%.6f,"active":%.6f,"recovery":%.6f,"combo":%.6f,"cancel":%d,"total":%.6f,"arc":%d,"reach":%.2f,"lunge":%.2f}',
		m.Id, m.Kind, t.StartupSeconds, t.ActiveSeconds, t.RecoverySeconds, t.ComboWindowSeconds, t.CancelFrame, t.TotalSeconds, m.Arc, m.Reach, m.Lunge))
end
for _, m in jian.Light do add(m) end
add(jian.Heavy); add(jian.RunningAttack); add(jian.WeaponArt)
print("{" .. table.concat(out, ",") .. "}")
