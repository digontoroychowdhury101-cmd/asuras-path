--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/PerfBudget
-- Ticket 18. Server-side sampler: Stats memory by tag, heartbeat rate, physics step p95, instance/part counts
-- under Map_Overworld (total and per region), terrain write progress and entity count. Values are published as
-- attributes on ReplicatedStorage.AsurasPath.Perf; a one-line summary is logged every LOG_EVERY samples and each
-- budget breach warns once per key. Off in live: runs only in Studio or when Perf already carries Enabled=true.
-- Everything external comes through `env` so tools/test_perf_budget.luau drives it with fakes.
local PerfBudget = {}
PerfBudget.__index = PerfBudget

PerfBudget.PERIOD = 5 -- seconds between samples
PerfBudget.COUNT_EVERY = 3 -- descendant walks are O(parts): every 3rd sample (15 s)
PerfBudget.LOG_EVERY = 6 -- summary line every 30 s
PerfBudget.TAGS = { "TerrainVoxels", "PhysicsParts", "Instances", "Sounds", "Gui" }

-- Max = breach above, Min = breach below. TerrainVoxels and heartbeat come from ticket 18; the part and step
-- numbers are provisional until the first clear/severe/combat profile is captured.
PerfBudget.Budgets = {
	Mem_TerrainVoxels = { Max = 200 },
	HeartbeatHz = { Min = 55 },
	StepP95Ms = { Max = 18.2 }, -- 1000 / 55
	PartsPerRegion = { Max = 8000 }, -- applies to every Parts_<region> key
}

local function limitFor(key: string): any?
	local direct = PerfBudget.Budgets[key]
	if direct then return direct end
	if key:sub(1, 6) == "Parts_" then return PerfBudget.Budgets.PartsPerRegion end
	return nil
end

function PerfBudget.new(env: any): any
	return setmetatable({ env = env, N = 0, HbN = 0, HbT = 0, Counts = {}, Warned = {}, Links = {}, Alive = false, Last = {} }, PerfBudget)
end

local function round(v: number): number
	return math.floor(v * 10 + 0.5) / 10
end

function PerfBudget.Sample(self: any): { [string]: number }
	local env = self.env
	self.N += 1
	local m: { [string]: number } = {}
	for _, tag in PerfBudget.TAGS do
		m["Mem_" .. tag] = env.memory(tag)
	end
	if self.HbT > 0 then m.HeartbeatHz = self.HbN / self.HbT end
	self.HbN, self.HbT = 0, 0
	local ents = env.entities()
	m.Entities, m.StepP95Ms = ents.entities, ents.p95StepMs
	local t = env.terrain()
	m.TerrainTotal, m.TerrainDone, m.TerrainFailed = t.Total, t.Done, if t.Failed and t.Failed ~= 0 then 1 else 0 -- Failed is the error text (or nil) in the live Overworld.Stats
	if (self.N - 1) % PerfBudget.COUNT_EVERY == 0 then self.Counts = env.count() end
	m.Instances_Map = self.Counts.Instances
	for region, parts in self.Counts.Regions or {} do m["Parts_" .. region] = parts end

	for key, value in m do
		if value ~= nil then
			env.folder:SetAttribute(key, round(value))
			local limit = limitFor(key)
			if limit and not self.Warned[key] and ((limit.Max and value > limit.Max) or (limit.Min and value < limit.Min)) then
				self.Warned[key] = true
				env.warn(string.format("[PerfBudget] %s=%.1f breaches %s", key, value, if limit.Max then "max " .. limit.Max else "min " .. limit.Min))
			end
		end
	end
	if self.N % PerfBudget.LOG_EVERY == 0 then
		env.log(string.format("[PerfBudget] hb=%.1fHz step95=%.1fms voxels=%.0fMB phys=%.0fMB inst=%s ents=%d terrain=%d/%d",
			m.HeartbeatHz or 0, m.StepP95Ms or 0, m.Mem_TerrainVoxels or 0, m.Mem_PhysicsParts or 0,
			tostring(m.Instances_Map), m.Entities or 0, m.TerrainDone or 0, m.TerrainTotal or 0))
	end
	self.Last = m
	return m
end

function PerfBudget.Start(self: any)
	if self.Alive then return end
	self.Alive = true
	table.insert(self.Links, self.env.heartbeat:Connect(function(dt: number)
		self.HbN += 1
		self.HbT += dt
	end))
	self.env.task.spawn(function()
		while self.Alive do
			self.env.task.wait(PerfBudget.PERIOD)
			if not self.Alive then break end
			self:Sample()
		end
	end)
end

function PerfBudget.Stop(self: any)
	self.Alive = false
	for _, link in self.Links do link:Disconnect() end
	table.clear(self.Links)
end

-- Live wiring: real services. Returns nil (nothing runs) outside Studio unless Perf.Enabled was set true.
function PerfBudget.Boot(services: any): any?
	local g = game :: any
	local Shared = g:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
	local folder = Shared:FindFirstChild("Perf")
	if not (g:GetService("RunService"):IsStudio() or (folder and folder:GetAttribute("Enabled") == true)) then return nil end
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Perf"
		folder.Parent = Shared
	end
	local stats = g:GetService("Stats")
	local env = {
		task = task, heartbeat = g:GetService("RunService").Heartbeat, folder = folder, log = print, warn = warn,
		memory = function(tag: string): number
			local ok, mb = pcall(function() return stats:GetMemoryUsageMbForTag((Enum :: any).DeveloperMemoryTag[tag]) end)
			return if ok then mb else 0
		end,
		entities = function() return services.Characters.GetPerformance() end,
		terrain = function() return services.Overworld.Stats() end,
		count = function()
			local out = { Instances = 0, Regions = {} }
			local map = g.Workspace:FindFirstChild("Map_Overworld")
			if not map then return out end
			out.Instances = #map:GetDescendants()
			for _, region in map:GetChildren() do
				local n = 0
				for _, d in region:GetDescendants() do
					if d:IsA("BasePart") then n += 1 end
				end
				out.Regions[region.Name] = n
			end
			return out
		end,
	}
	local perf = PerfBudget.new(env)
	perf:Start()
	return perf
end

return PerfBudget
