#!/usr/bin/env python3
"""ClothSim's contract on the real Shen data, in the plain Luau CLI: garments return to the sculpt, roots stay on the body, roaming stays bounded, a sprinting root streams the cloth behind him while no garment ends inside his body or weapon, the sim is deterministic."""
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
    assert(bones == #def.bones - 1 - 15, "every free particle drives one bone: Root and the 15 limbs aside (the glaive is a collider, not a bone)")
    local n = #def.limbs
    local s = Sim.new(def, 1.3)
    local rest = identity(n)
    Sim.reset(s, rest)
    for _ = 1, 240 do Sim.step(s, rest, 1 / 60, still, 3) end
    -- no wind, no motion: the sculpt's own shape, sagging under its weight now the cloth is free; it never collapses
    local worst, worstAt = 0, nil
    for i = 1, s.n do
        if not s.isOrb[i] then
            local d = math.sqrt((s.x[i] - s.rx[i]) ^ 2 + (s.y[i] - s.ry[i]) ^ 2 + (s.z[i] - s.rz[i]) ^ 2) -- orbs circle his head
            if d > worst then worst, worstAt = d, i end
        end
    end
    assert(worst < 1.2, "rest shape holds, drift " .. worst .. " at particle " .. tostring(worstAt))
    -- each bone rests near the sculpt's turn: a trace above 0 is under 120 degrees
    for k = 1, #s.bones do
        local o = (k - 1) * 9
        assert(s.bones[k].orb or s.bones[k].finger or s.R[o + 1] + s.R[o + 5] + s.R[o + 9] > 0.0, "rest rotation never turns right over, bone " .. k .. " in P" .. phase)
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
                if s.isOrb[i] then
                    continue
                elseif s.pin[i] then
                    assert(math.abs(s.z[i] - (s.rz[i] + z)) < 1e-6, "a pinned root stays on the body")
                else
                    local d = math.sqrt((s.x[i] - s.rx[i]) ^ 2 + (s.y[i] - s.ry[i]) ^ 2 + (s.z[i] - s.rz[i] - z) ^ 2)
                    maxReach = math.max(maxReach, d)
                    if s.rz[i] > 0 then -- (2026-11-06) the cloth behind him streams; cloth in front is solid against his legs and cannot stream back through them
                        trail += s.z[i] - s.rz[i] - z
                        count += 1
                    end
                    -- nothing ends inside a volume it avoids (the particle's own clearance, a little slack for the last pass)
                    for q, c in s.hitIds[i] do
                        local cap, r = s.caps[c], s.hitRad[i][q]
                        local px, py, pz = s.x[i] - cap.wax, s.y[i] - cap.way, s.z[i] - cap.waz
                        local u = math.clamp((px * cap.wdx + py * cap.wdy + pz * cap.wdz) / cap.len2, 0, 1)
                        local dd = math.sqrt((px - cap.wdx * u) ^ 2 + (py - cap.wdy * u) ^ 2 + (pz - cap.wdz * u) ^ 2)
                        if s.hitFirm[i][q] then r += cap.r + (cap.rb - cap.r) * u end -- (2026-11-07) a firm clearance is added to the volume's tapered radius
                        assert(dd > r * 0.9, "cloth stays out of the body and weapon, particle " .. i .. " in P" .. phase)
                    end
                end
            end
        end
    end
    assert(trail / count > 0.1, "cloth streams behind a running body, mean " .. trail / count)
    -- between particles too: the middle of every link stays out of the volumes both its ends avoid
    for l = 1, s.L do
        local i, j = s.la[l], s.lb[l]
        for q, c in s.linkIds[l] do
            local cap, r = s.caps[c], s.linkRad[l][q]
            local px, py, pz = (s.x[i] + s.x[j]) / 2 - cap.wax, (s.y[i] + s.y[j]) / 2 - cap.way, (s.z[i] + s.z[j]) / 2 - cap.waz
            local u = math.clamp((px * cap.wdx + py * cap.wdy + pz * cap.wdz) / cap.len2, 0, 1)
            local dd = math.sqrt((px - cap.wdx * u) ^ 2 + (py - cap.wdy * u) ^ 2 + (pz - cap.wdz * u) ^ 2)
            if s.linkFirm[l][q] then r += cap.r + (cap.rb - cap.r) * u end
            assert(dd > r * 0.85, "cloth between particles stays out of the body and weapon, link " .. l .. " in P" .. phase .. string.format(" cap %d r %.3f dd %.3f firm %s u %.2f", c, r, dd, tostring(s.linkFirm[l][q]), u))
        end
    end
    assert(maxReach < 4, "roaming is bounded, " .. maxReach)
    -- the same inputs give the same cloth
    local a, b = Sim.new(def, 1.3), Sim.new(def, 1.3)
    local m = identity(n, 1, 2, 3)
    for _ = 1, 30 do Sim.step(a, m, 1 / 60, Sim.DefaultWind, 2); Sim.step(b, m, 1 / 60, Sim.DefaultWind, 2) end
    for i = 1, a.n do assert(a.x[i] == b.x[i] and a.y[i] == b.y[i] and a.z[i] == b.z[i], "deterministic") end
    -- defeated: the orbs fall to the floor and come to rest there; the garments stay on the body
    local floorY = -3.1924 * 1.3
    Sim.drop(a, floorY)
    for _ = 1, 240 do Sim.step(a, m, 1 / 60, Sim.DefaultWind, 2) end
    for k = 1, #a.bones do
        local f = a.bones[k]
        if f.orb then
            local i = f.i
            assert(math.abs(a.y[i] - (floorY + 0.21 * 1.3)) < 0.05, "a dropped orb rests on the floor, y " .. a.y[i])
            assert(f.fall and math.abs(f.fall.vy) < 1e-6 and math.abs(f.fall.vx) < 0.05 and math.abs(f.fall.vz) < 0.05, "a dropped orb comes to rest")
        end
    end
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
