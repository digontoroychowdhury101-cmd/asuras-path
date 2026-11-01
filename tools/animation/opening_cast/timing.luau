-- Prints the authoritative timing (built WeaponSchema: 1.4x tempo, 60 Hz ticks) of the opening cast's weapons as JSON,
-- keyed by move id, for the clip baker.
local W = require("../../../src/simulation/WeaponSchema")
local out = {}
local function add(m)
	local t = m.Timing
	table.insert(out, string.format('"%s":{"kind":"%s","startup":%.6f,"active":%.6f,"recovery":%.6f,"combo":%.6f,"cancel":%d,"total":%.6f,"arc":%d,"reach":%.2f,"lunge":%.2f}',
		m.Id, m.Kind, t.StartupSeconds, t.ActiveSeconds, t.RecoverySeconds, t.ComboWindowSeconds, t.CancelFrame, t.TotalSeconds, m.Arc, m.Reach, m.Lunge))
end
for _, name in { "Unarmed", "Dao" } do
	local w = W.Weapons[name]
	for _, m in w.Light do add(m) end
	add(w.Heavy); add(w.RunningAttack); add(w.WeaponArt)
end
print("{" .. table.concat(out, ",") .. "}")
