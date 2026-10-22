--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/WaypointMarker
-- On-screen gold diamond + distance that floats over the current objective target. Resolves
-- objective targets (altar id, Sanctuary portal, raw point) to world positions. Presentation only.
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)

local ARRIVE_DISTANCE = 14
local ALTAR_TAG = "AsuraAltar"

local Marker = {}
Marker.__index = Marker

export type WaypointMarker = typeof(setmetatable({} :: {
	Anchor: Attachment,
	Gui: BillboardGui,
	Text: TextLabel,
	Portal: BasePart?,
}, Marker))

function Marker.new(parent: Instance): WaypointMarker
	local anchor = Instance.new("Attachment")
	anchor.Name = "AsuraObjectiveAnchor"
	anchor.Parent = Workspace.Terrain
	local gui = HudKit.make("BillboardGui", parent, { Name = "ObjectiveMarker", Adornee = anchor, AlwaysOnTop = true, LightInfluence = 0, Size = UDim2.fromOffset(240, 54), StudsOffset = Vector3.new(0, 4, 0), Enabled = false }) :: BillboardGui
	HudKit.label(gui, "◆", 26, HudKit.TitleFont, HudKit.Palette.Gold, { Size = UDim2.new(1, 0, 0, 30), TextStrokeTransparency = 0.2 })
	local text = HudKit.label(gui, "", 14, Enum.Font.GothamMedium, HudKit.Palette.Ivory, { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 20), TextStrokeTransparency = 0.3 })
	return setmetatable({ Anchor = anchor, Gui = gui, Text = text, Portal = nil }, Marker)
end

function Marker.Locate(self: WaypointMarker, target: any): Vector3?
	if target == nil then
		return nil
	elseif target.Kind == "Point" then
		return target.Position
	elseif target.Kind == "Altar" then
		-- Authored altars tag a BasePart anchor; greybox altars tag their Model.
		for _, tagged in CollectionService:GetTagged(ALTAR_TAG) do
			if tagged:GetAttribute("AltarId") == target.Id then
				if tagged:IsA("BasePart") then
					return tagged.Position
				elseif tagged:IsA("Model") then
					return tagged:GetPivot().Position
				end
			end
		end
		return nil
	end
	local portal = self.Portal
	if portal == nil or not portal:IsDescendantOf(Workspace) then
		local found = Workspace:FindFirstChild("PortalTrigger", true)
		portal = if found and found:IsA("BasePart") then found else nil
		self.Portal = portal
	end
	return if portal then portal.Position else nil
end

-- Points the marker at `goal` and returns the distance in studs (nil when there is no goal). A
-- staged route step names itself ("Bridge · 64m") and reports the walked distance to the goal.
function Marker.Point(self: WaypointMarker, goal: Vector3?, from: Vector3?, suppressed: boolean, label: string?, walked: number?): number?
	if goal == nil or from == nil then
		self.Gui.Enabled = false
		return nil
	end
	local near = math.floor((goal - from).Magnitude)
	local meters = if walked then math.floor(walked) else near
	self.Anchor.WorldPosition = goal
	self.Text.Text = if label then string.format("%s · %dm", label, meters) else string.format("%dm", meters)
	self.Gui.Enabled = near > ARRIVE_DISTANCE and not suppressed
	return meters
end

function Marker.Destroy(self: WaypointMarker)
	self.Gui:Destroy()
	self.Anchor:Destroy()
end

return Marker
