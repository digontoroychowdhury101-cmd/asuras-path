--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/StrikeTrajectories
-- The visible blade as data (combat recovery Stage 3, TIMING_CONTRACT A4). Baked offline from the published clips
-- (tools/animation/bake_trajectories.py), read the same way by the server's sweep, the client's trail and the client's
-- presented step, so no client-evaluated pose decides a hit and what is drawn is what was swept.
-- A fighter whose character set plays its own clips, and a move without a baked clip, has no entry here: those keep
-- the generic StrikeGeometry path, and ANIMATION_COVERAGE.md lists them as open.
local hasScript = pcall(function()
	return script.Parent
end)
local Data: any, Catalog: any
if hasScript then
	Data = require(script.Parent.StrikeTrajectoryData)
	Catalog = require(script.Parent.AnimationCatalog)
else
	Data = require("./StrikeTrajectoryData")
	Catalog = require("./AnimationCatalog")
end

local Trajectories = {}

-- The baked data for a move, or nil.
function Trajectories.forMove(moveId: string): any
	return Data[moveId]
end

-- The baked data for this fighter's swing of a move: nil for a character with its own clips, which are not these.
function Trajectories.forFighter(moveId: string, definition: string?): any
	if definition and Catalog.Characters[definition] then
		return nil
	end
	return Data[moveId]
end

-- The server-to-clip phase map for a move's clip: baked where known, otherwise the clip stretched over the move's
-- frame data in proportion (a clip shared across a family, whose authored contact is not known here).
function Trajectories.phases(moveId: string, timing: any, clipLength: number): any
	local data = Data[moveId]
	if data then
		return data
	end
	local total = timing.TotalSeconds
	local length = if clipLength > 0 then clipLength else total
	local share = length / math.max(total, 1e-6)
	return { Startup = timing.StartupSeconds, Active = timing.ActiveSeconds, Total = total, ClipContact = timing.StartupSeconds * share,
		ClipActiveEnd = (timing.StartupSeconds + timing.ActiveSeconds) * share, ClipLength = length }
end

-- Studs the body stands forward of its root at this clip time.
function Trajectories.stepAt(data: any, clipTime: number): number
	local keys = data.Step
	local count = #keys
	if count == 0 or clipTime <= keys[1][1] or clipTime >= keys[count][1] then
		return 0
	end
	for index = 2, count do
		local b = keys[index]
		if clipTime <= b[1] then
			local a = keys[index - 1]
			return a[2] + (b[2] - a[2]) * (clipTime - a[1]) / math.max(b[1] - a[1], 1e-6)
		end
	end
	return 0
end

-- Root-space blade (hilt xyz, tip xyz) at `progress` 0..1 through the active frames: the same six numbers as
-- StrikeGeometry.segment. A reach bonus lengthens the tip along the blade; a scaled body scales the whole path.
function Trajectories.segment(data: any, progress: number, bonus: number, scale: number?): (number, number, number, number, number, number)
	local samples = data.Samples
	local at = math.clamp(progress, 0, 1) * (#samples - 1) + 1
	local index = math.min(math.floor(at), #samples - 1)
	local a, b = samples[math.max(index, 1)], samples[math.max(index, 1) + 1] or samples[#samples]
	local share = at - math.max(index, 1)
	local size = scale or 1
	local hx = (a[1] + (b[1] - a[1]) * share) * size
	local hy = (a[2] + (b[2] - a[2]) * share) * size
	local hz = (a[3] + (b[3] - a[3]) * share) * size
	local tx = (a[4] + (b[4] - a[4]) * share) * size
	local ty = (a[5] + (b[5] - a[5]) * share) * size
	local tz = (a[6] + (b[6] - a[6]) * share) * size
	if bonus ~= 0 then
		local dx, dy, dz = tx - hx, ty - hy, tz - hz
		local length = math.sqrt(dx * dx + dy * dy + dz * dz)
		if length > 1e-6 then
			local grow = bonus / length
			tx, ty, tz = tx + dx * grow, ty + dy * grow, tz + dz * grow
		end
	end
	return hx, hy, hz, tx, ty, tz
end

-- The farthest the tip gets from the root's axis through the active frames.
function Trajectories.reach(data: any, bonus: number, scale: number?): number
	local most = 0
	for _, sample in data.Samples do
		most = math.max(most, math.sqrt(sample[4] * sample[4] + sample[6] * sample[6]))
	end
	return most * (scale or 1) + bonus
end

return table.freeze(Trajectories)
