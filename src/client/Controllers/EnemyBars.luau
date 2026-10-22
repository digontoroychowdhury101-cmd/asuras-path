--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/EnemyBars
-- Overhead plate for every nearby hostile (NPCs and duel opponents; bosses use the top boss bar):
-- name, a crimson health bar with a pale trail showing recent damage, and a gold posture bar that
-- grows from the centre. Above it, the enemy's incoming attack: an icon of the attack type and a
-- ring that closes on the icon at the moment of impact. When the ring turns gold, press Parry.
-- Unblockable (perilous) attacks show a red "!" and tell you to dodge instead.
local Workspace = game:GetService("Workspace")
local Sakura = require(script.Parent:WaitForChild("SakuraKit") :: ModuleScript)
local Plate = require(script.Parent:WaitForChild("EnemyPlate") :: ModuleScript)
local PlateLayout = require(script.Parent:WaitForChild("PlateLayout") :: ModuleScript)

local Bars = {}
local C = Sakura.Colors

-- Customization ------------------------------------------------------------------------------
local SHOW_RANGE = 60 -- studs; locked targets always show
local TRAIL_SPEED = 0.6 -- health fraction per second the damage trail drains

export type View = { Gui: ScreenGui, State: any, Plates: { [any]: Plate.Plate } }

function Bars.new(gui: ScreenGui, state: any): View
	return { Gui = gui, State = state, Plates = {} }
end

-- Boss-style cues carry a counter hint ("Double Jump", "Slide Dash"...) for perilous attacks.
function Bars.cue(view: View, entity: any, data: { [string]: any })
	local plate = view.Plates[entity]
	if plate and type(data.impact) == "number" then
		local now = Workspace:GetServerTimeNow()
		plate.Class, plate.Start, plate.Impact = tostring(data.class or "Heavy"), now, data.impact
		plate.Counter = if type(data.counter) == "string" then data.counter else nil
	end
end

-- `focus` is the foe shown on the top TargetPlate; its overhead plate keeps only the warning.
function Bars.step(view: View, dt: number, locked: any?, focus: any?)
	local state = view.State
	local own = state:Own()
	local origin = own and own.Root and own.Root.Position
	local now = Workspace:GetServerTimeNow()
	local camera = Workspace.CurrentCamera
	local seen: { [any]: boolean } = {}
	local candidates: { PlateLayout.Candidate } = {}
	for _, entity in state.Entities do
		local snapshot = entity.Snapshot
		if entity ~= own and not entity.Boss and entity.Root and snapshot and state:IsAlive(entity) and state:IsHostile(entity) and origin then
			local distance = (entity.Root.Position - origin).Magnitude
			if distance <= SHOW_RANGE or entity == locked then
				seen[entity] = true
				local plate = view.Plates[entity] or Plate.build(view.Gui, entity, SHOW_RANGE)
				view.Plates[entity] = plate
				plate.Gui.Adornee = entity.Root
				local ratio = math.clamp(snapshot.ActiveHP / math.max(snapshot.MaxHP, 1), 0, 1)
				plate.Trailing = if plate.Trailing > ratio then math.max(ratio, plate.Trailing - TRAIL_SPEED * dt) else ratio
				plate.Fill.Size = UDim2.fromScale(ratio, 1)
				plate.Trail.Size = UDim2.fromScale(plate.Trailing, 1)
				local p = math.clamp(snapshot.Posture / math.max(snapshot.PostureCapacity, 1), 0, 1)
				local broken = snapshot.State == "StanceBroken"
				plate.Posture.Size = UDim2.fromScale(if broken then 1 else p, 1)
				plate.Posture.BackgroundColor3 = if broken and (os.clock() * 6) % 2 < 1 then C.Ivory elseif p > 0.8 then C.Crimson else C.Gold
				plate.Name.TextColor3 = if entity == locked then C.Gold else C.Ivory
				Plate.telegraph(plate, entity.Model, now)
				local point = if camera then camera:WorldToViewportPoint(entity.Root.Position + Vector3.yAxis * 3.4) else Vector3.zero
				table.insert(candidates, { Id = entity.Id, X = point.X, Y = point.Y, Distance = distance, Focus = entity == focus, Warning = Plate.warning(plate, now) })
			end
		end
	end
	local placements = PlateLayout.arrange(candidates)
	for entity, plate in view.Plates do
		local placement = placements[entity.Id]
		if placement then Plate.mode(plate, placement.Mode, placement.Lift) end
		if not seen[entity] then
			plate.Gui:Destroy()
			view.Plates[entity] = nil
		end
	end
end

function Bars.destroy(view: View)
	for _, plate in view.Plates do plate.Gui:Destroy() end
	table.clear(view.Plates)
end

return table.freeze(Bars)
