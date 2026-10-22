--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/SanctuaryDuelCourt
-- The Colosseum Promenade restyled as an open duel court on a rock spur: a paved octagonal balcony
-- ringed by carved balustrade, crimson banners on every far vertex and braziers flanking the gallery
-- entry, with the PvP ring itself still raised at the centre by ColosseumService (unchanged size and
-- id). `base` is the Promenade centre on the balcony top; the gallery arrives from -X.
local Kit = require(script.Parent:WaitForChild("SanctuaryKit") :: ModuleScript)
local Rails = require(script.Parent:WaitForChild("SanctuaryRails") :: ModuleScript)
local Props = require(script.Parent:WaitForChild("SanctuaryProps") :: ModuleScript)

local DuelCourt = {}

local ENTRY = 7 -- half-width of the opening for the 12-stud gallery walkway

function DuelCourt.Build(parent: Instance, base: CFrame, apothem: number): Folder
	local group = Kit.folder("ColosseumPromenade", parent)
	for index = 0, 1 do
		local yaw = base * CFrame.Angles(0, math.rad(45 * index), 0)
		Kit.slab(group, "Balcony" .. index, Vector3.new(apothem * 2, 5, apothem * 2), yaw * CFrame.new(0, -2.5, 0), "Paving")
		Kit.slab(group, "BalconySkirting" .. index, Vector3.new(apothem * 2 + 1, 2, apothem * 2 + 1), yaw * CFrame.new(0, -4.4, 0), "StoneDark")
	end
	-- Inner sill ring of darker stone just outside the duel band, so the court reads as a stage.
	local sill = Kit.disc(group, "CourtSill", 27, 0.3, base * CFrame.new(0, -0.1, 0), Kit.Surface.StoneDark.Color, Enum.Material.Slate, Kit.decor())
	sill.MaterialVariant = Kit.Surface.StoneDark.Variant
	local half = apothem * math.tan(math.rad(22.5)) - 0.9
	for k = 0, 7 do
		local edge = base * CFrame.Angles(0, math.rad(45 * k), 0) * CFrame.new(0, 0, -(apothem - 0.7))
		local a, b = (edge * CFrame.new(-half, 0, 0)).Position, (edge * CFrame.new(half, 0, 0)).Position
		if k == 5 then
			-- South-east edge stays open onto the landing below the spectator balcony stair (WagerWorld).
			local landing = base * CFrame.Angles(0, math.rad(225), 0) * CFrame.new(0, 0, -(apothem + 9))
			Kit.slab(group, "SpectatorLanding", Vector3.new(30, 5, 18), landing * CFrame.new(0, -2.5, 0), "Paving")
			Kit.slab(group, "SpectatorLandingSkirting", Vector3.new(31, 2, 18.5), landing * CFrame.new(0, -4.4, 0), "StoneDark")
			for s = -1, 1, 2 do
				Rails.run(group, (landing * CFrame.new(s * 14.4, 0, 8.4)).Position, (landing * CFrame.new(s * 14.4, 0, -8.4)).Position)
			end
		elseif k == 2 then
			-- West edge: the gallery walkway comes in through its middle.
			local c = edge.Position
			local dir = (b - a).Unit
			Rails.run(group, a, c - dir * ENTRY)
			Rails.run(group, c + dir * ENTRY, b)
		else
			Rails.run(group, a, b)
		end
		local vertex = base * CFrame.Angles(0, math.rad(45 * k + 22.5), 0) * CFrame.new(0, 0, -(apothem / math.cos(math.rad(22.5)) - 2.6))
		local facing = CFrame.lookAt(vertex.Position, base.Position) -- banners turn their cloth to the court
		if k == 1 or k == 2 then
			Props.brazier(group, facing)
		else
			Props.banner(group, facing, 16)
		end
	end
	for _, k in { 0, 4, 6 } do
		local mid = base * CFrame.Angles(0, math.rad(45 * k), 0) * CFrame.new(0, 0, -(apothem - 4))
		Props.lantern(group, mid)
	end
	return group
end

return table.freeze(DuelCourt)
