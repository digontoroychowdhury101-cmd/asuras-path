--!nonstrict
-- Unmapped Studio-only probe (Grandmaster Shen import). Built only into a throwaway place copy (the assistant's Luau thread may not insert scripts);
-- set ServerStorage attribute ShenQACmd to "op arg", read ShenQAResult. Entry placement, KO protection and seeded damage are a Studio diagnostic;
-- the boss AI, moves, phase change, skin swap and lifecycle are the live game. Observes only; changes no rule.
local Run = game:GetService("RunService")
if not Run:IsStudio() then return end
local SSS = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local Characters = require(SSS.AsurasPath.Services.CharacterService)
local AI = require(SSS.AsurasPath.Services.AIService)
local World = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.WorldDefinitions)

local moves, parries, cues = {}, {}, {}
local seen = {}
local function own()
	local p = Players:GetPlayers()[1]
	return p and Characters.GetEntity(p.UserId)
end
local function shen()
	for _, e in Characters.Entities() do
		if e.Kind == "Enemy" and e.Model:GetAttribute("AsuraLookKey") == "GrandmasterShen" then return e end
	end
	return nil
end
local originalCue = Characters.Cue
Characters.Cue = function(kind, source, payload)
	if kind == "BossIntro" or kind == "BossEnrage" or kind == "BossDefeated" or kind == "BossReset" or kind == "FogGateSealed" or kind == "BossFinish" or kind == "BossPhase" then
		table.insert(cues, string.format("%.2f %s", Characters.Now(), kind))
	end
	return originalCue(kind, source, payload)
end
local protect = false
Run.Heartbeat:Connect(function()
	local me = own()
	if me and protect then me.Fighter.KOProtected = true end
	local e = shen()
	if e and e.Fighter.Move then
		local key = string.format("%.3f", e.Fighter.MoveStart)
		if not seen[key] then
			seen[key] = true
			table.insert(moves, string.format("%.2f P%s %s %s deflect=%s", Characters.Now(), tostring(e.Model:GetAttribute("AsuraBossPhase")), e.Fighter.Move.Id, tostring(e.Fighter.Move.Kind), tostring(e.Fighter.Move.Deflectable)))
		end
	end
end)
local ops = {}
function ops.enter()
	local gate = World.FogGates.Gate_AshColosseum
	local c = gate.Trigger.Center
	Characters.Teleport(own().Id, CFrame.new(c.X, c.Y + 3, c.Z))
	return "placed at the gate trigger " .. tostring(c)
end
function ops.spawn()
	local id = AI.SpawnBoss("GrandmasterShen", { own().Id })
	return "spawned " .. tostring(id)
end
function ops.protect(on) protect = on == true; return "protect " .. tostring(protect) end
-- Seeded player death by Shen: the retry and reset path.
function ops.die()
	local me, e = own(), shen()
	if not e then return "no Shen" end
	protect = false
	me.Fighter.KOProtected = false
	Characters.ApplyArea(e.Id, me.Id, me.Fighter.ActiveHP + 5, 0, true)
	return "player " .. me.Fighter.State
end
function ops.heal() Characters.RestoreFighter(own().Id); return "healed" end
function ops.skip() return Characters.PushIntent(own().Id, "Skip") end
function ops.moves() return table.concat(moves, "\n") end
function ops.cues() return table.concat(cues, "\n") end
function ops.status()
	local e, me = shen(), own()
	if not e then return "no Shen; player at " .. tostring(me and me.Root.Position) end
	local skin = e.Model:FindFirstChild("AsuraBossSkin")
	local mp, bones = 0, 0
	if skin then for _, d in skin:GetDescendants() do if d:IsA("MeshPart") then mp += 1 elseif d:IsA("Bone") then bones += 1 end end end
	return string.format("t=%.2f %s state=%s move=%s hp=%.0f/%.0f phase=%s skinstatus=%s template=%s mp=%d bones=%d scale=%.2f shenpos=%s playerpos=%s dist=%.1f",
		Characters.Now(), e.Model.Name, e.Fighter.State, tostring(e.Fighter.Move and e.Fighter.Move.Id), e.Fighter.ActiveHP, e.Fighter.MaxHP, tostring(e.Model:GetAttribute("AsuraBossPhase")),
		tostring(e.Model:GetAttribute("AsuraSkinStatus")), tostring(skin and skin:GetAttribute("Template")), mp, bones, e.Model:GetScale(), tostring(e.Root.Position), tostring(me.Root.Position), (e.Root.Position - me.Root.Position).Magnitude)
end
-- Seeded: take Shen's health down to `fraction` of this form's maximum.
function ops.damage(fraction)
	local e = shen()
	if not e then return "none" end
	Characters.ApplyArea(own().Id, e.Id, math.max(1, e.Fighter.ActiveHP - e.Fighter.MaxHP * fraction), 0, true)
	return string.format("hp %.0f state %s", e.Fighter.ActiveHP, e.Fighter.State)
end
function ops.posture()
	local e = shen()
	if not e then return "none" end
	Characters.ApplyArea(own().Id, e.Id, 1, e.Fighter.PostureCapacity + 50, true)
	return "posture state " .. e.Fighter.State
end
function ops.face(distance)
	local e, me = shen(), own()
	local look = e.Root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local spot = e.Root.Position + look.Unit * (distance or 14)
	Characters.Teleport(me.Id, CFrame.lookAt(Vector3.new(spot.X, e.Root.Position.Y + 1, spot.Z), e.Root.Position))
	return "faced"
end
function ops.hold(seconds) AI.Hold("GrandmasterShen", Characters.Now() + (seconds or 30)); return "held" end
local store = game:GetService("ServerStorage")
store:GetAttributeChangedSignal("ShenQACmd"):Connect(function()
	local words = string.split(store:GetAttribute("ShenQACmd") or "", " ")
	local arg = tonumber(words[2]) or (if words[2] == "true" then true elseif words[2] == "false" then false else words[2])
	local fn = ops[words[1]]
	if not fn then store:SetAttribute("ShenQAResult", "no op"); return end
	task.spawn(function()
		local ok, result = pcall(fn, arg)
		store:SetAttribute("ShenQAResult", if ok then tostring(result) else "ERR " .. tostring(result))
	end)
end)
store:SetAttribute("ShenQAReady", true)
