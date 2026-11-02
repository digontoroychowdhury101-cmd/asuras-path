--!nonstrict
-- Unmapped Studio-only probe (Windows acceptance, 2026-11-03): explains how fast ordinary foes take a player down.
-- Logs every damaging or defensive combat event that touches a player, with the attacking fighter's move, state
-- and position, and the player's health layers after it. It changes nothing (no protection, no seeding); inject
-- with tools/qa/qa_inject.py during Play, read the JSON from ServerStorage attribute AsuraMonkLog. Stop removes it.
-- Evidence type: seeded Studio diagnostic (the input driving the player is whatever the run states).
if not game:GetService("RunService"):IsStudio() then
	return
end
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Characters = require(game:GetService("ServerScriptService").AsurasPath.Services.CharacterService)

local t0 = os.clock()
local rows = {}
local players: { [number]: boolean } = {}
local function refresh()
	table.clear(players)
	for _, p in Players:GetPlayers() do
		players[p.UserId] = true
	end
end
refresh()
Players.PlayerAdded:Connect(refresh)

local KINDS = { Hit = true, Block = true, DeflectSpark = true, KO = true, Whiff = true, Deathblow = true, StanceBreak = true,
	GuardBreak = true, Deflected = true, CounterHit = true, Burn = true }
Characters.Subscribe(function(event: any)
	if not KINDS[event.Kind] or not (players[event.Target] or players[event.Source]) then
		return
	end
	local src = event.Source and Characters.GetFighter(event.Source)
	local tgt = event.Target and Characters.GetFighter(event.Target)
	table.insert(rows, {
		t = math.floor((os.clock() - t0) * 1000) / 1000,
		kind = event.Kind,
		src = event.Source,
		tgt = event.Target,
		value = event.Value,
		move = src and src.Move and src.Move.Id or nil,
		srcState = src and src.State or nil,
		tgtState = tgt and tgt.State or nil,
		hp = tgt and math.floor(tgt.ActiveHP * 10) / 10 or nil,
		rec = tgt and math.floor(tgt.RecoverableHP * 10) / 10 or nil,
		maxHp = tgt and tgt.MaxHP or nil,
	})
	ServerStorage:SetAttribute("AsuraMonkLog", HttpService:JSONEncode(rows))
end)
print("[MonkLethality] on")
