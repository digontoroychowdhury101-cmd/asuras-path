--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/PlateLayout
-- Decides what each overhead enemy plate shows so a crowd stays readable and nothing is repeated:
--   Focus   - the foe on the top TargetPlate: its overhead plate keeps only the attack warning.
--   Full    - the nearest few: name, health and posture.
--   Compact - further foes: bars only, no name.
--   Hidden  - beyond the budget, unless it is winding up an attack (warnings always show).
-- A plate that would overlap one already placed is lifted (in pixels) to sit just above it.
-- Pure; no engine calls.
local Layout = {}

Layout.MaxFull = 3
Layout.MaxShown = 6
Layout.Gap = { X = 150, Y = 46 } -- screen pixels one plate occupies
Layout.MaxLift = 3 * 46 -- pixels

export type Mode = "Focus" | "Full" | "Compact" | "Hidden"
export type Candidate = { Id: number, X: number, Y: number, Distance: number, Focus: boolean, Warning: boolean }
export type Placement = { Mode: Mode, Lift: number } -- Lift: screen pixels upward

function Layout.arrange(candidates: { Candidate }): { [number]: Placement }
	local order = table.clone(candidates)
	table.sort(order, function(a, b)
		if a.Focus ~= b.Focus then return a.Focus end
		if a.Distance ~= b.Distance then return a.Distance < b.Distance end
		return a.Id < b.Id -- stable when two foes stand at the same range
	end)
	local result: { [number]: Placement } = {}
	local placed: { { X: number, Y: number } } = {}
	local full, shown = 0, 0
	for _, c in order do
		local mode: Mode
		if c.Focus then
			mode = "Focus"
		elseif full < Layout.MaxFull then
			mode, full = "Full", full + 1
		elseif shown < Layout.MaxShown or c.Warning then
			mode = "Compact"
		else
			mode = "Hidden"
		end
		if mode ~= "Focus" and mode ~= "Hidden" then shown += 1 end
		local lift = 0
		if mode ~= "Hidden" then
			local y = c.Y
			local moved = true
			while moved do
				moved = false
				for _, p in placed do
					if math.abs(p.X - c.X) < Layout.Gap.X and math.abs(p.Y - y) < Layout.Gap.Y and c.Y - (p.Y - Layout.Gap.Y) <= Layout.MaxLift then
						y = p.Y - Layout.Gap.Y
						moved = true
						break
					end
				end
			end
			lift = c.Y - y
			table.insert(placed, { X = c.X, Y = y })
		end
		result[c.Id] = { Mode = mode, Lift = lift }
	end
	return result
end

return table.freeze(Layout)
