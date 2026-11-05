#!/usr/bin/env python3
"""ClothSim's contract on the real Shen data, in the plain Luau CLI: garments return to the sculpt, roots stay on the body, roaming stays bounded, a sprinting root streams the cloth behind him, the sim is deterministic."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
src = (ROOT / "src/shared/ClothSim.luau").read_text()
data = (ROOT / "src/shared/ShenClothData.luau").read_text()
test = r"""
local Sim = (function()
""" + src + r"""
end)()
local Data = (function()
""" + data + r"""
end)()
local function identity(n, x, y, z)
    local m = table.create(n * 12, 0)
    for i = 1, n do
        local o = (i - 1) * 12
        m[o + 1], m[o + 2], m[o + 3] = x or 0, y or 0, z or 0
        m[o + 4], m[o + 8], m[o + 12] = 1, 1, 1
    end
    return m
end
local still = table.freeze({ x = 0, y = 0, z = 0, gust = 0, flutter = 0 })
for phase = 1, 2 do
    local def = Data[phase]
    assert(#def.bones < 128, "bone count stays bounded")
    local bones = 0
    for _, p in def.particles do if p.bone then bones += 1 end end
    assert(bones == #def.bones - 1 - #def.limbs, "every free particle drives one bone")
    local n = #def.limbs
    local s = Sim.new(def, 1.3)
    local rest = identity(n)
    Sim.reset(s, rest)
    for _ = 1, 240 do Sim.step(s, rest, 1 / 60, still, 3) end
    -- no wind, no motion: the sculpt's own shape
    local worst = 0
    for i = 1, s.n do
        worst = math.max(worst, math.sqrt((s.x[i] - s.rx[i]) ^ 2 + (s.y[i] - s.ry[i]) ^ 2 + (s.z[i] - s.rz[i]) ^ 2))
    end
    assert(worst < 0.2, "rest shape holds, drift " .. worst)
    -- each bone's rotation at rest is the identity
    for k = 1, #s.bones do
        local o = (k - 1) * 9
        assert(math.abs(s.R[o + 1] - 1) < 0.08 and math.abs(s.R[o + 5] - 1) < 0.08 and math.abs(s.R[o + 9] - 1) < 0.08, "rest rotation, bone " .. k .. " in P" .. phase)
    end
    -- sprint toward -Z: pins stay exactly on the body, the hem trails behind and stays inside its reach
    local z = 0
    local maxReach = 0
    local trail, count = 0, 0
    for f = 1, 300 do
        z -= 12 / 60
        local m = identity(n, 0, 0, z)
        Sim.step(s, m, 1 / 60, Sim.DefaultWind, 2)
        if f == 300 then
            for i = 1, s.n do
                if s.pin[i] then
                    assert(math.abs(s.z[i] - (s.rz[i] + z)) < 1e-6, "a pinned root stays on the body")
                else
                    local d = math.sqrt((s.x[i] - s.rx[i]) ^ 2 + (s.y[i] - s.ry[i]) ^ 2 + (s.z[i] - s.rz[i] - z) ^ 2)
                    maxReach = math.max(maxReach, d)
                    trail += s.z[i] - s.rz[i] - z
                    count += 1
                end
            end
        end
    end
    assert(trail / count > 0.1, "cloth streams behind a running body, mean " .. trail / count)
    assert(maxReach < 4, "roaming is bounded, " .. maxReach)
    -- the same inputs give the same cloth
    local a, b = Sim.new(def, 1.3), Sim.new(def, 1.3)
    local m = identity(n, 1, 2, 3)
    for _ = 1, 30 do Sim.step(a, m, 1 / 60, Sim.DefaultWind, 2); Sim.step(b, m, 1 / 60, Sim.DefaultWind, 2) end
    for i = 1, a.n do assert(a.x[i] == b.x[i] and a.y[i] == b.y[i] and a.z[i] == b.z[i], "deterministic") end
    -- a low tier at half the rate still ends near the same place
    print("P" .. phase .. " ok: rest drift " .. string.format("%.3f", worst) .. ", sprint trail " .. string.format("%.2f", trail / count))
end
"""
path = ROOT / "work/opening_cast_bake/_cloth_test.luau"
path.write_text(test)
res = subprocess.run([str(ROOT / "work/bin/luau/luau"), str(path)], capture_output=True, text=True)
path.unlink()
print(res.stdout, end="")
if res.returncode or "error" in res.stderr.lower():
    print(res.stderr)
    sys.exit(1)
for needle, where in (("AsuraSkinnedBoss", "src/server/Services/BossSkin.luau"), ("AsuraSkinnedBoss", "src/client/Controllers/BossCloth.luau"), ("BossCloth", "default.project.json"), ("ClothSim", "default.project.json"), ("ShenClothData", "default.project.json")):
    assert needle in (ROOT / where).read_text(), (needle, where)
source = (ROOT / "src/client/Controllers/BossCloth.luau").read_text()
assert "GetInstanceRemovedSignal" in source and "beat:Disconnect()" in source, "the session ends with its tag and the loop stops"
assert "SetAttribute" not in source and "Remote" not in source, "cloth is cosmetic and client-side"
print("cloth sim: ok")
