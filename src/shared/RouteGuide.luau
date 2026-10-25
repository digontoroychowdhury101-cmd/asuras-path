--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/RouteGuide
-- Staged wayfinding (batch 15, #28). Instead of pointing straight at a goal across walls, the
-- ravine or a world separation, the objective marker points at the next usable step: the
-- Sanctuary's northern gate when the goal (a bloodstain, an altar) lies beyond it, the crypt
-- descent for the Sunken Crypt, and inside the Desecrated Monastery the next doorway on the
-- walked route (gatehouse, processional path, bridgeheads, cloister gateway, west postern).
-- `Remaining` is the walked length through those doorways, not the straight-line distance.
-- Batches 16-21: the authored campaign regions stage the same way through CampaignZones (doors
-- carry their height, so the Pagoda's levels and the Citadel's stairs are walked, not flown), and
-- a goal past the Monastery's south road is reached through that road's doorways first.
-- Follow-up 14: every stage carries its whole `Route` (doorways in order, then the goal when it is
-- reached on foot) so the minimap draws the same walked line the marker stages. A route that leaves
-- the world through a portal ends at that portal: the northern gate, the Well of Descent, or the
-- crypt's and bastion's return portals when the goal lies back in the Sanctuary.
local Zones = require(script.Parent.MonasteryZones)
local World = require(script.Parent.WorldDefinitions)
local Campaign = require(script.Parent.CampaignZones)
local Routes = require(script.Parent.SanctuaryRoutes)

local Guide = {}

-- `Exit` names the portal a route ends at (its Position is the last point, or nil for the northern
-- gate, which the client resolves from the placed PortalTrigger).
export type Route = { Points: { Vector3 }, Names: { string }, Exit: string? }
export type Stage = { Kind: string, Position: Vector3?, Label: string?, Remaining: number?, Route: Route }

local descent = Routes.Marks.CryptDescent
Guide.CryptDescent = Vector3.new(descent.X, descent.Y + 5, descent.Z) -- the Well of Descent portal (batch 16)
Guide.Monastery = "DesecratedMonastery"
-- Regions whose own portal walks home to the Sanctuary (SunkenCryptLayout / SkyCitadelLayout marks).
local HOME = { "SanctuaryDepths", "SkyCitadel" }

local function flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

function Guide.regionOf(point: Vector3): string?
	return World.regionAt(point.X, point.Y, point.Z)
end

type Leg = { Points: { Vector3 }, Names: { string } }

local function monasteryLeg(doors: { Zones.Door }, y: number): Leg
	local leg: Leg = { Points = {}, Names = {} }
	for _, door in doors do
		table.insert(leg.Points, Vector3.new(door.X, y, door.Z)); table.insert(leg.Names, door.Name)
	end
	return leg
end

-- The first doorway of a leg, and the walked length through all of them (campaign legs add the
-- height climbed; Monastery legs keep their flat batch 15 measure).
local function direct(goal: Vector3): Stage
	return { Kind = "Point", Position = goal, Label = nil, Remaining = nil, Route = { Points = { goal }, Names = { "" } } }
end

local function staged(from: Vector3, goal: Vector3, leg: Leg, climb: boolean?): Stage
	if #leg.Points == 0 then
		return direct(goal)
	end
	local walked, cursor = 0, from
	for _, point in leg.Points do
		walked += flat(cursor, point) + (if climb then math.abs(point.Y - cursor.Y) else 0)
		cursor = point
	end
	local points, names = table.clone(leg.Points), table.clone(leg.Names)
	table.insert(points, goal); table.insert(names, "")
	return { Kind = "Point", Position = leg.Points[1], Label = leg.Names[1], Remaining = walked + flat(cursor, goal),
		Route = { Points = points, Names = names } }
end

-- Campaign doorways from `from` to the zone holding `target`, as raised route points.
local function campaignLeg(from: Vector3, target: Vector3, leg: Leg)
	local a, b = Campaign.at(from.X, from.Y, from.Z), Campaign.at(target.X, target.Y, target.Z)
	if not (a and b) then return end
	for _, door in Campaign.path(a.Id, b.Id) do
		table.insert(leg.Points, Vector3.new(door.X, door.Y + 3, door.Z)); table.insert(leg.Names, door.Name)
	end
end

-- From the crypt or the bastion, a Sanctuary goal is reached through that region's return portal.
local function homeward(from: Vector3, here: string?): Stage?
	for _, region in HOME do
		if region == here then
			local mark = Campaign.mark(region, "ReturnPortal")
			if not mark then return nil end
			local portal = Vector3.new(mark.X, mark.Y + 3, mark.Z)
			local leg: Leg = { Points = {}, Names = {} }
			campaignLeg(from, portal, leg)
			table.insert(leg.Points, portal); table.insert(leg.Names, "Return portal")
			return { Kind = "Point", Position = leg.Points[1], Label = leg.Names[1], Remaining = nil,
				Route = { Points = leg.Points, Names = leg.Names, Exit = "Return portal" } }
		end
	end
	return nil
end

-- The next step from `from` toward `goal`; Kind "Portal" means the Sanctuary's northern gate.
function Guide.next(from: Vector3, goal: Vector3): Stage
	local here, there = Guide.regionOf(from), Guide.regionOf(goal)
	if here == "Sanctuary" and there ~= nil and there ~= "Sanctuary" then
		if there == "SanctuaryDepths" then
			return { Kind = "Point", Position = Guide.CryptDescent, Label = "Crypt descent", Remaining = nil,
				Route = { Points = { Guide.CryptDescent }, Names = { "Crypt descent" }, Exit = "Crypt descent" } }
		end
		return { Kind = "Portal", Position = nil, Label = "Northern gate", Remaining = nil,
			Route = { Points = {}, Names = {}, Exit = "Northern gate" } }
	end
	if there == "Sanctuary" and here ~= nil and here ~= "Sanctuary" then
		local home = homeward(from, here)
		if home then return home end
	end
	if here == Guide.Monastery and there == Guide.Monastery then
		local a, b = Zones.at(from.X, from.Z), Zones.at(goal.X, goal.Z)
		if a and b and a.Id ~= b.Id then
			return staged(from, goal, monasteryLeg(Zones.path(a.Id, b.Id), goal.Y))
		end
	end
	-- Campaign regions: inside them, between them, and to or from the Monastery's south road.
	local inMonastery, goalInMonastery = here == Guide.Monastery, there == Guide.Monastery
	local a = if inMonastery then Campaign.get("DM:Road") else Campaign.at(from.X, from.Y, from.Z)
	local b = if goalInMonastery then Campaign.get("DM:Road") else Campaign.at(goal.X, goal.Y, goal.Z)
	local campaignDoors = if a and b then Campaign.path(a.Id, b.Id) else {}
	if #campaignDoors > 0 then
		local legs: { Vector3 } = {}
		local names: { string } = {}
		if inMonastery then
			local zone = Zones.at(from.X, from.Z)
			if zone and zone.Id ~= "Road" then
				for _, door in Zones.path(zone.Id, "Road") do
					table.insert(legs, Vector3.new(door.X, from.Y, door.Z)); table.insert(names, door.Name)
				end
			end
		end
		for _, door in campaignDoors do
			table.insert(legs, Vector3.new(door.X, door.Y + 3, door.Z)); table.insert(names, door.Name)
		end
		if goalInMonastery then
			local zone = Zones.at(goal.X, goal.Z)
			if zone and zone.Id ~= "Road" then
				for _, door in Zones.path("Road", zone.Id) do
					table.insert(legs, Vector3.new(door.X, goal.Y, door.Z)); table.insert(names, door.Name)
				end
			end
		end
		if #legs > 0 then
			return staged(from, goal, { Points = legs, Names = names }, true)
		end
	end
	return direct(goal)
end

return table.freeze(Guide)
