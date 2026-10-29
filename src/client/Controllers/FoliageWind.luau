--!strict
-- One client scheduler for registered rooted plants. Spatial buckets, bounded active lists and
-- distance-based rates keep motion independent of world size. No decorative movement replicates.
local Run = game:GetService("RunService")
local Tags = game:GetService("CollectionService")
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local GameSettings = UserSettings():GetService("UserGameSettings")
local Effects = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.EffectsPreference)
local Wind = {}
Wind.__index = Wind
local TAG, CELL = "AsuraWindPlant", 64

local function key(x: number, z: number): string
	return math.floor(x / CELL) .. ":" .. math.floor(z / CELL)
end
local function restore(row: any)
	for _, p in row.Parts do if p.Part.Parent then p.Part.CFrame = p.Frame end end
	row.Moved = false
end

local function collect(row: any)
	local waiting = false
	for _, p in row.Model:GetDescendants() do
		if p:IsA("BasePart") then
			if p.Anchored and not p.CanCollide then
				if not row.ByPart[p] then
					local piece = { Part = p, Frame = p.CFrame, Flutter = p:GetAttribute("WindFlutter") == true }
					row.ByPart[p] = piece
					table.insert(row.Parts, piece)
				end
			else
				waiting = true
			end
		end
	end
	return #row.Parts > 0 and not waiting
end

local function comfort(self: any)
	if not self.Alive then return end
	local ok, platform = pcall(function() return GuiService.ReducedMotionEnabled end)
	self.Reduced = Effects.reducedMotion() or (ok and platform == true)
	-- The game's comfort preference also weakens native terrain wind on this client. Roblox
	-- additionally handles its own accessibility preference inside the native grass renderer.
	workspace.GlobalWind = self.BaseWind * (if self.Reduced then 0.1 else 1)
	if self.Reduced then for _, row in self.Active do restore(row) end end
	self.RefreshAt = 0
end

function Wind.new(): any
	local self = setmetatable({ Rows = {}, Cells = {}, Active = {}, Pending = {}, Links = {}, Clock = 0,
		RefreshAt = 0, MetricsAt = 0, Count = 0, Alive = true, Reduced = Effects.reducedMotion() }, Wind) :: any
	self.BaseWind = workspace.GlobalWind
	local function remove(model: Instance)
		local row = self.Rows[model]
		if not row then return end
		restore(row)
		self.Rows[model] = nil
		self.Pending[model] = nil
		local cell = self.Cells[row.Cell]
		if cell then cell[model] = nil; if next(cell) == nil then self.Cells[row.Cell] = nil end end
		self.Count -= 1
		self.RefreshAt = 0
	end
	local function register(model: Instance)
		if self.Rows[model] or not model:IsA("Model") or not model:IsDescendantOf(workspace) then return end
		local base = model:GetAttribute("WindBase")
		if typeof(base) ~= "CFrame" then return end
		local position = base.Position
		local cellKey = key(position.X, position.Z)
		local row = { Model = model, Parts = {}, ByPart = {}, Position = position, Cell = cellKey,
			Height = model:GetAttribute("WindHeight") or 2, Kind = model:GetAttribute("WindKind"), Next = 0, Moved = false }
		collect(row)
		-- A replicated tag can precede its MeshParts or their final properties. Revisit the
		-- local model after replication settles; one shared scheduler drains this queue.
		row.ReadyAt, row.RetryUntil = self.Clock + 0.2, self.Clock + 3
		self.Pending[model] = row
		self.Rows[model] = row
		self.Cells[cellKey] = self.Cells[cellKey] or {}
		self.Cells[cellKey][model] = row
		self.Count += 1
		self.RefreshAt = 0
	end
	for _, model in Tags:GetTagged(TAG) do register(model) end
	table.insert(self.Links, Tags:GetInstanceAddedSignal(TAG):Connect(register))
	table.insert(self.Links, Tags:GetInstanceRemovedSignal(TAG):Connect(remove))
	local function owner(part: Instance): any
		local ancestor = part.Parent
		while ancestor and ancestor ~= workspace do
			if self.Rows[ancestor] then return self.Rows[ancestor] end
			ancestor = ancestor.Parent
		end
		return nil
	end
	table.insert(self.Links, workspace.DescendantAdded:Connect(function(part)
		if not part:IsA("BasePart") then return end
		local row = owner(part)
		if row then
			row.ReadyAt, row.RetryUntil = self.Clock + 0.2, self.Clock + 3
			self.Pending[row.Model] = row
		end
	end))
	table.insert(self.Links, workspace.DescendantRemoving:Connect(function(item)
		if self.Rows[item] then remove(item) return end
		if not item:IsA("BasePart") then return end
		local row = owner(item)
		local piece = row and row.ByPart[item]
		if piece then
			local index = table.find(row.Parts, piece)
			if index then table.remove(row.Parts, index) end
			row.ByPart[item] = nil
		end
	end))
	self.PreferenceDisconnect = Effects.onChanged(function() comfort(self) end)
	pcall(function()
		table.insert(self.Links, GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function() comfort(self) end))
	end)
	comfort(self)
	table.insert(self.Links, Run.Heartbeat:Connect(function(dt) self:Update(dt) end))
	return self
end

function Wind.Refresh(self: any, at: Vector3, low: boolean)
	local previous = self.Active
	self.Active = {}
	if self.Reduced then
		for _, row in previous do if row.Moved then restore(row) end end
		return
	end
	local x, z = math.floor(at.X / CELL), math.floor(at.Z / CELL)
	local range = if low then 82 else 120
	local candidates = {}
	for dx = -2, 2 do for dz = -2, 2 do
		local bucket = self.Cells[(x + dx) .. ":" .. (z + dz)]
		if bucket then for _, row in bucket do
			local distance = (row.Position - at).Magnitude
			if distance < range and row.Model:IsDescendantOf(workspace) then
				row.Distance = distance
				table.insert(candidates, row)
			end
		end end
	end end
	table.sort(candidates, function(a, b) return a.Distance < b.Distance end)
	local selected = {}
	for i = 1, math.min(#candidates, if low then 64 else 112) do
		local row = candidates[i]
		row.Period = if row.Distance < 42 then (if low then 1 / 20 else 1 / 30) elseif row.Distance < 78 then 1 / 15 else 1 / 7.5
		selected[row] = true
		table.insert(self.Active, row)
	end
	for _, row in previous do if not selected[row] and row.Moved then restore(row) end end
end

function Wind.Update(self: any, dt: number)
	if not self.Alive or not workspace.CurrentCamera then return end
	local began = os.clock()
	self.Clock += dt
	local t = self.Clock
	local drained = 0
	for model, row in self.Pending do
		if t < row.ReadyAt then continue end
		local ready = collect(row)
		if ready or t >= row.RetryUntil then self.Pending[model] = nil else row.ReadyAt = t + 0.2 end
		drained += 1
		if drained >= 8 then break end
	end
	local quality = GameSettings.SavedQualityLevel.Value
	local low = (quality > 0 and quality <= 4) or (quality == 0 and UIS.TouchEnabled)
	if t >= self.RefreshAt then
		self:Refresh(workspace.CurrentCamera.CFrame.Position, low)
		self.RefreshAt = t + 0.5
	end
	local parts, frames = {}, {}
	if not self.Reduced then
		local flow = workspace.GlobalWind
		local strength = math.clamp(flow.Magnitude / 7, 0, 1.6)
		local direction = if flow.Magnitude > 0.001 then flow.Unit else Vector3.xAxis
		for _, row in self.Active do
			if t < row.Next or self.Rows[row.Model] ~= row then continue end
			row.Next = t + row.Period
			local p = row.Position
			local phase = p.X * 0.043 + p.Z * 0.027
			local gust = 0.55 + 0.28 * math.sin(t * 0.62 - p.X * 0.011 - p.Z * 0.018)
			local bamboo = row.Kind == "Bamboo"
			local frequency = if bamboo then 1.1 elseif row.Kind == "Grass" then 3.1 elseif row.Kind == "Shoot" then 1.65 else 2.3
			local amplitude = (if bamboo then 0.006 elseif row.Kind == "Grass" then 0.055 elseif row.Kind == "Shoot" then 0.02 else 0.035) * strength
			local bend = amplitude * (gust + 0.28 * math.sin(t * frequency + phase))
			local sway = CFrame.new(p) * CFrame.Angles(direction.Z * bend, 0, -direction.X * bend) * CFrame.new(-p)
			local crown = p + Vector3.yAxis * row.Height * 0.55
			local flutter = math.sin(t * 2.9 + phase * 1.8) * 0.012 * strength
			local leaf = CFrame.new(crown) * CFrame.Angles(flutter * 0.6, flutter * 0.25, flutter) * CFrame.new(-crown)
			for _, piece in row.Parts do
				if piece.Part.Parent then
					table.insert(parts, piece.Part)
					table.insert(frames, sway * (if piece.Flutter then leaf else CFrame.identity) * piece.Frame)
				end
			end
			row.Moved = true
		end
	end
	if #parts > 0 then workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged) end
	local cost = (os.clock() - began) * 1000
	self.CostSum = (self.CostSum or 0) + cost
	self.CostSamples = (self.CostSamples or 0) + 1
	self.CostPeak = math.max(self.CostPeak or 0, cost)
	if t >= self.MetricsAt then
		local player = Players.LocalPlayer
		local cached = 0
		for _, row in self.Rows do cached += #row.Parts end
		player:SetAttribute("FoliageCachedParts", cached)
		player:SetAttribute("FoliageRegistered", self.Count)
		player:SetAttribute("FoliageActive", if self.Reduced then 0 else #self.Active)
		player:SetAttribute("FoliageUpdateMs", self.CostSum / self.CostSamples)
		player:SetAttribute("FoliagePeakUpdateMs", self.CostPeak)
		player:SetAttribute("FoliageMovedParts", #parts)
		self.MetricsAt = t + 1
		self.CostSum, self.CostSamples, self.CostPeak = 0, 0, 0
	end
end

function Wind.Destroy(self: any)
	self.Alive = false
	for _, link in self.Links do link:Disconnect() end
	self.PreferenceDisconnect()
	workspace.GlobalWind = self.BaseWind
	for _, row in self.Rows do restore(row) end
	table.clear(self.Rows); table.clear(self.Cells); table.clear(self.Active); table.clear(self.Pending); table.clear(self.Links)
end

return Wind
