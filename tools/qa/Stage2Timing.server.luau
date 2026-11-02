--!nonstrict
-- Unmapped Studio-only probe (combat recovery Stage 2), the server half of Stage2Timing.client. Insert into
-- ServerScriptService during Play with tools/qa/qa_inject.py (never save). For SECONDS it records:
--   * the wall time between consecutive CharacterService ticks (os.clock) and Stats heartbeat time;
--   * each player fighter's state transitions with simTime and move id (action starts);
--   * when each AsuraAck / AsuraResult value is set on the server (receipt and terminal result).
-- JSON lands in ServerStorage.AsuraStage2Probe. Evidence type: seeded Studio diagnostic. Changes no rule.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")
local Characters = require(game:GetService("ServerScriptService").AsurasPath.Services.CharacterService)

local SECONDS = tonumber(game:GetService("ServerStorage"):GetAttribute("AsuraStage2Seconds")) or 30
local previous = game:GetService("ServerStorage"):FindFirstChild("AsuraStage2Probe")
if previous then
	previous:Destroy()
end
local out = Instance.new("StringValue")
out.Name, out.Value, out.Parent = "AsuraStage2Probe", "", game:GetService("ServerStorage")
local ticks, states, acks = {}, {}, {}
local last, lastState, t0 = nil, {}, os.clock()
local connections = {}

for _, player in Players:GetPlayers() do
	for _, name in { "AsuraAck", "AsuraResult", "AsuraIntent" } do
		table.insert(connections, player:GetAttributeChangedSignal(name):Connect(function()
			table.insert(acks, { id = player.UserId, name = name, value = tostring(player:GetAttribute(name)), s = Characters.Now() })
		end))
	end
end

local unsubscribe
unsubscribe = Characters.OnStep(function(now)
	local clock = os.clock()
	if last then
		table.insert(ticks, math.floor((clock - last) * 1e5) / 100)
	end
	last = clock
	for _, player in Players:GetPlayers() do
		local e = Characters.GetEntity(player.UserId)
		local f = e and e.Fighter
		if f then
			local key = f.State .. "|" .. (if f.Move then f.Move.Id else "-") .. "|" .. tostring(f.MoveStart)
			if key ~= lastState[player.UserId] then
				lastState[player.UserId] = key
				table.insert(states, { id = player.UserId, s = now, state = f.State, move = if f.Move then f.Move.Id else nil, start = f.MoveStart })
			end
		end
	end
	if clock - t0 > SECONDS then
		unsubscribe()
		for _, c in connections do
			c:Disconnect()
		end
		local ok, heartbeat = pcall(function() return Stats.HeartbeatTimeMs end)
		out.Value = HttpService:JSONEncode({ ticks = ticks, states = states, acks = acks, heartbeatMs = if ok then heartbeat else nil })
	end
end)
