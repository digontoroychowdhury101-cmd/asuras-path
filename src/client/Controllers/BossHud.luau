--!strict
local Kit = require(script.Parent.HudKit)
local WorldState = require(script.Parent.WorldStateController)
local Hud = {}
function Hud.decorate(frame: Frame, title: string, phases: number)
	local old = frame:FindFirstChild("HonoraryTitle")
	if old then old:Destroy() end
	Kit.label(frame, title, 16, Enum.Font.Garamond, Kit.Palette.Gold, { Name = "HonoraryTitle", Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, TextScaled = true })
	local track = frame:FindFirstChild("Health") :: Frame
	for _, child in track:GetChildren() do if string.sub(child.Name, 1, 7) == "Segment" then child:Destroy() end end
	for i = 1, phases do
		Kit.make("Frame", track, { Name = "Segment" .. i, Size = UDim2.fromOffset(6, 6), Position = UDim2.new((i - 0.5) / phases, -3, 1, 5),
			Rotation = 45, BorderSizePixel = 0, BackgroundColor3 = Kit.Palette.Gold })
		if i < phases then Kit.make("Frame", track, { Name = "SegmentDivider" .. i, Size = UDim2.new(0, 2, 1, 0),
			Position = UDim2.fromScale(i / phases, 0), BackgroundColor3 = Kit.Palette.Ink, BorderSizePixel = 0, ZIndex = 3 }) end
	end
end
function Hud.values(frame: Frame, state: WorldState.WorldState, members: { number }): (number, number, number, boolean)
	local hp, recoverable, maximum, posture, capacity = 0, 0, 0, 0, 0
	local broken, phase = false, 1
	for _, id in members do
		local entity = state:Get(id)
		local s = entity and entity.Snapshot
		if not s then continue end
		if s.State == "KO" and #members > 1 then phase += 1 end
		if s.State ~= "KO" then
			maximum += s.MaxHP
			hp += s.ActiveHP; recoverable += s.RecoverableHP
			posture += s.Posture; capacity += s.PostureCapacity
			broken = broken or s.State == "StanceBroken"
		end
		local value = entity.Model:GetAttribute("AsuraBossPhase")
		if type(value) == "number" then phase = math.max(phase, value) end
	end
	local track = frame:FindFirstChild("Health")
	if track then for _, child in track:GetChildren() do
		local i = tonumber(string.match(child.Name, "^Segment(%d+)$"))
		if i and child:IsA("Frame") then child.BackgroundTransparency = if i < phase then 0.8 else 0 end
	end end
	return math.clamp(hp / math.max(maximum, 1), 0, 1), math.clamp((hp + recoverable) / math.max(maximum, 1), 0, 1),
		math.clamp(posture / math.max(capacity, 1), 0, 1), broken
end
return Hud
