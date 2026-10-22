--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/DuoBars
-- Multi-actor boss encounters (the Twin Sentinels): instead of one merged bar under three
-- overlapping names, each member gets its own row in the boss plate (sigil, name, health with its
-- recoverable layer, posture, status) and a matching overhead tag. Sigils are shapes, so the
-- pairing never relies on colour; row order follows the server's member list and never reshuffles.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
local Kit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)
local Sakura = require(script.Parent:WaitForChild("SakuraKit") :: ModuleScript)
local InputMap = require(Shared:WaitForChild("Shared"):WaitForChild("InputMap") :: ModuleScript)

local Duo = {}
local C = Sakura.Colors
Duo.Sigils = table.freeze({ "◆", "▲", "■", "●" })
Duo.Replaced = table.freeze({ "Casing", "Health", "Posture", "HonoraryTitle" }) -- merged boss-bar parts

export type Row = {
	Id: number, Sigil: string, Root: Frame, Name: TextLabel, Status: TextLabel, Fill: Frame, Recover: Frame,
	Posture: Frame, Stroke: UIStroke, Tag: BillboardGui?,
}
export type View = { Frame: Frame, Gui: ScreenGui, Root: Frame, Hint: TextLabel, Rows: { Row } }

function Duo.new(frame: Frame, gui: ScreenGui): View
	local root = Kit.make("Frame", frame, { Name = "DuoStrip", Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 58), BackgroundTransparency = 1, Visible = false }) :: Frame
	local hint = Kit.label(frame, "", 13, Kit.BodyFont, Kit.Palette.Muted, { Name = "DuoHint", Position = UDim2.fromOffset(0, 94), Size = UDim2.new(1, 0, 0, 16), Visible = false })
	return { Frame = frame, Gui = gui, Root = root, Hint = hint, Rows = {} }
end

local function setReplaced(view: View, visible: boolean)
	for _, name in Duo.Replaced do
		local child = view.Frame:FindFirstChild(name)
		if child and child:IsA("GuiObject") then child.Visible = visible end
	end
end

function Duo.clear(view: View)
	for _, row in view.Rows do
		if row.Tag then row.Tag:Destroy() end
		row.Root:Destroy()
	end
	table.clear(view.Rows)
	view.Root.Visible, view.Hint.Visible = false, false
	setReplaced(view, true)
end

-- Builds one row per member; returns false (and leaves the merged bar) for a single boss.
function Duo.bind(view: View, members: { number }, lockKey: string): boolean
	Duo.clear(view)
	if #members < 2 then return false end
	local share = 1 / #members
	for i, id in members do
		local row = Kit.make("Frame", view.Root, { Name = "Member" .. i, Position = UDim2.new(share * (i - 1), if i > 1 then 10 else 0, 0, 0),
			Size = UDim2.new(share, -10, 1, 0), BackgroundColor3 = C.Ink, BackgroundTransparency = 0.35, BorderSizePixel = 0 }) :: Frame
		local stroke = Kit.make("UIStroke", row, { Color = C.Gold, Thickness = 1, Transparency = 0.6 }) :: UIStroke
		local sigil = Duo.Sigils[(i - 1) % #Duo.Sigils + 1]
		local name = Kit.label(row, "", 17, Enum.Font.Garamond, C.Ivory, { Position = UDim2.fromOffset(8, 2), Size = UDim2.new(1, -96, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0.3 })
		local status = Kit.label(row, "", 12, Enum.Font.GothamBold, C.Gold, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 4), Size = UDim2.fromOffset(84, 16), TextXAlignment = Enum.TextXAlignment.Right })
		local track = Kit.make("Frame", row, { Position = UDim2.fromOffset(8, 26), Size = UDim2.new(1, -16, 0, 12), BackgroundColor3 = C.Track, BorderSizePixel = 0 }) :: Frame
		local recover = Kit.make("Frame", track, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Kit.Palette.Ember, BorderSizePixel = 0 }) :: Frame
		local fill = Kit.make("Frame", track, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Crimson, BorderSizePixel = 0 }) :: Frame
		local postureTrack = Kit.make("Frame", row, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.new(0.7, 0, 0, 5), BackgroundColor3 = C.Ink, BorderSizePixel = 0 }) :: Frame
		local posture = Kit.make("Frame", postureTrack, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Gold, BorderSizePixel = 0 }) :: Frame
		table.insert(view.Rows, { Id = id, Sigil = sigil, Root = row, Name = name, Status = status, Fill = fill, Recover = recover, Posture = posture, Stroke = stroke, Tag = nil })
	end
	view.Hint.Text = if lockKey ~= "" then string.format("[%s] lock a foe · flick to switch", lockKey) else "lock a foe · flick to switch"
	view.Root.Visible, view.Hint.Visible = true, true
	setReplaced(view, false)
	return true
end

-- Overhead tag matching the row: sigil + name above the actor's head.
local function tag(view: View, row: Row, entity: any): BillboardGui
	local height = entity.Model:GetExtentsSize().Y
	local billboard = Kit.make("BillboardGui", view.Gui, { Name = "DuoTag", Adornee = entity.Root, Size = UDim2.fromOffset(180, 26),
		StudsOffsetWorldSpace = Vector3.new(0, height * 0.55 + 1, 0), AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 140, ResetOnSpawn = false }) :: BillboardGui
	Kit.label(billboard, row.Sigil .. "  " .. string.upper(entity.Name), 16, Enum.Font.Garamond, C.Ivory, { Size = UDim2.fromScale(1, 1), TextStrokeTransparency = 0.15 })
	return billboard
end

function Duo.update(view: View, state: any, locked: any?, hidden: boolean)
	for _, row in view.Rows do
		local entity = state:Get(row.Id)
		local s = entity and entity.Snapshot
		if not entity or not s then continue end
		row.Name.Text = row.Sigil .. "  " .. entity.Name
		if not row.Tag and entity.Root then row.Tag = tag(view, row, entity) end
		local maximum = math.max(s.MaxHP, 1)
		local fallen = s.State == "KO"
		row.Fill.Size = UDim2.fromScale(if fallen then 0 else math.clamp(s.ActiveHP / maximum, 0, 1), 1)
		row.Recover.Size = UDim2.fromScale(if fallen then 0 else math.clamp((s.ActiveHP + s.RecoverableHP) / maximum, 0, 1), 1)
		local broken = s.State == "StanceBroken"
		row.Posture.Size = UDim2.fromScale(if broken then 1 else math.clamp(s.Posture / math.max(s.PostureCapacity, 1), 0, 1), 1)
		row.Posture.BackgroundColor3 = if broken then C.Ivory else C.Gold
		local target = entity == locked
		row.Status.Text = if fallen then "FALLEN" elseif broken then "BROKEN" elseif target then "◎ TARGET" else ""
		row.Stroke.Transparency, row.Stroke.Thickness = if target then 0 else 0.6, if target then 2 else 1
		row.Root.BackgroundTransparency = if fallen then 0.7 else 0.35
		if row.Tag then row.Tag.Enabled = not hidden and not fallen end
	end
end

function Duo.lockKey(device: string): string
	return if device == "Touch" then "LOCK" else InputMap.label("Lock", device)
end

return table.freeze(Duo)
