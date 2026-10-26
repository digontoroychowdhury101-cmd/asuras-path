--!nonstrict
-- Unmapped Studio-only probe (post-F26 Step 5). Insert into ServerScriptService during Play (never
-- save); answers ServerStorage.MonasteryQA:Invoke(op, ...). Placement, KO protection and clearing foes
-- off a walked leg are a seeded Studio diagnostic; contact events, prompts and rewards are the live game.
local Run = game:GetService("RunService")
if not Run:IsStudio() then return end
local SSS = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local Characters = require(SSS.AsurasPath.Services.CharacterService)

local events = {}
local function own()
	local p = Players:GetPlayers()[1]
	return p and Characters.GetEntity(p.UserId)
end
Characters.Subscribe(function(event)
	local me = own()
	if me and (event.Target == me.Id or event.Source == me.Id) then
		local other = Characters.GetEntity(if event.Source == me.Id then event.Target else event.Source)
		table.insert(events, string.format("%.2f %s %s %s %.1f", Characters.Now(), event.Kind, if event.Source == me.Id then "by player on" else "on player by",
			other and other.Model.Name or tostring(event.Target), event.Value))
		if #events > 400 then table.remove(events, 1) end
	end
end)
local protect = false
Run.Heartbeat:Connect(function()
	local me = own()
	if me and protect then me.Fighter.KOProtected = true end
end)

local ops = {}
function ops.place(x, y, z, yaw)
	Characters.Teleport(own().Id, CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw or 0), 0))
	return "placed"
end
function ops.protect(on) protect = on == true; return "protect " .. tostring(protect) end
function ops.heal() Characters.RestoreFighter(own().Id); return "healed" end
function ops.weapon(name) Characters.ForceWeapon(own().Id, name); return "weapon " .. name end
-- Living foes within `radius` of (x, z), or removes them when `clear` (seeded, so a walk is not a fight).
function ops.foes(x, z, radius, clear)
	local out = {}
	for _, e in Characters.Entities() do
		if e.Kind == "Enemy" and e.Fighter.State ~= "KO" then
			local p = e.Root.Position
			if (Vector3.new(p.X, 0, p.Z) - Vector3.new(x, 0, z)).Magnitude <= radius then
				table.insert(out, string.format("%d %s (%.0f,%.1f,%.0f) %s", e.Id, e.Model.Name, p.X, p.Y, p.Z, e.Fighter.Weapon))
				if clear then Characters.DespawnEnemy(e.Id) end
			end
		end
	end
	return (if clear then "cleared " else "") .. #out .. "\n" .. table.concat(out, "\n")
end
function ops.events(n)
	local out = {}
	for i = math.max(1, #events - (n or 30) + 1), #events do table.insert(out, events[i]) end
	return table.concat(out, "\n")
end
function ops.reset() table.clear(events); return "cleared" end
-- Claimed caches and read tablets in the live (Studio mock) profile.
function ops.profile()
	local Persistence = require(SSS.AsurasPath.Services.PersistenceService)
	local p = Persistence.Get(Players:GetPlayers()[1].UserId)
	if not p then return "no profile" end
	local caches, lore = {}, {}
	for id, v in p.souls.inventory.caches or {} do if v then table.insert(caches, id) end end
	for id, v in p.inventory.LoreEntries or {} do if v then table.insert(lore, id) end end
	table.sort(caches); table.sort(lore)
	return "caches: " .. table.concat(caches, ",") .. "\nlore: " .. table.concat(lore, ",") .. "\nqiEssence: " .. tostring(p.qiEssence)
end
function ops.attrs()
	local p = Players:GetPlayers()[1]
	local out = {}
	for k, v in p:GetAttributes() do
		if string.find(k, "Essence") or string.find(k, "Lore") or string.find(k, "Tablet") or string.find(k, "Unbanked") or string.find(k, "Qi") or string.find(k, "Cache") then
			table.insert(out, k .. "=" .. tostring(v))
		end
	end
	table.sort(out)
	return table.concat(out, " | ")
end

local old = game:GetService("ServerStorage"):FindFirstChild("MonasteryQA")
if old then old:Destroy() end
local fn = Instance.new("BindableFunction")
fn.Name = "MonasteryQA"
fn.OnInvoke = function(op, ...)
	local handler = ops[op]
	if not handler then return "unknown op" end
	local ok, a = pcall(handler, ...)
	return if ok then a else "error: " .. tostring(a)
end
fn.Parent = game:GetService("ServerStorage")
print("[MonasteryQA] probe ready")
