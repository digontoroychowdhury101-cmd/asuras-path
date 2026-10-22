--!nonstrict
-- Offline rig helper for the batch 11-14 presentation suites (not a test itself). Builds Lune
-- @lune/roblox R15 rigs from CostumeSchema's nominal default-R15 sizes, emulates the few engine
-- members Lune lacks (Model:ScaleTo/GetScale/PivotTo, ChildAdded) closely enough to exercise the
-- real build code, and loads real source modules with an injected environment. Emulated geometry
-- is labelled as such in the suites; it is not a Studio view.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Schema = require("../src/shared/CostumeSchema")

local Scene = {}
local V3, CF, Instance = roblox.Vector3, roblox.CFrame, roblox.Instance
Scene.V3, Scene.CF, Scene.Instance, Scene.Enum = V3, CF, Instance, roblox.Enum

local function signal()
	local s = { Links = {} }
	function s:Connect(fn) table.insert(self.Links, fn); return { Disconnect = function() end, Connected = true } end
	function s:Fire(...) for _, fn in self.Links do fn(...) end end
	return s
end
local added: { [any]: any } = {}
roblox.implementProperty("Model", "ChildAdded", function(model)
	added[model] = added[model] or signal()
	return added[model]
end)
function Scene.fireChildAdded(model, child) if added[model] then added[model]:Fire(child) end end

local function pivotOf(model)
	local ok, pivot = pcall(function() return model.WorldPivot end)
	return if ok and pivot then pivot else CF.new()
end
roblox.implementMethod("Model", "GetScale", function(model) return model:GetAttribute("__scale") or 1 end)
roblox.implementMethod("Model", "PivotTo", function(model, target)
	local delta = target * pivotOf(model):Inverse()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then d.CFrame = delta * d.CFrame end
	end
	model.WorldPivot = target
end)
-- Uniform scale about the pivot: part sizes and positions, joint offsets and attachments.
roblox.implementMethod("Model", "ScaleTo", function(model, scale)
	local factor = scale / (model:GetAttribute("__scale") or 1)
	local pivot = pivotOf(model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Size *= factor
			local rel = pivot:ToObjectSpace(d.CFrame)
			d.CFrame = pivot * (CF.new(rel.Position * factor) * rel.Rotation)
		elseif d:IsA("Weld") or d:IsA("Motor6D") then
			d.C0 = CF.new(d.C0.Position * factor) * d.C0.Rotation
			d.C1 = CF.new(d.C1.Position * factor) * d.C1.Rotation
		elseif d:IsA("Attachment") then
			pcall(function() d.CFrame = CF.new(d.CFrame.Position * factor) * d.CFrame.Rotation end)
		end
	end
	model:SetAttribute("__scale", scale)
end)

-- A default-proportioned R15 rig (blocks at the schema's nominal sizes) standing with its root at `root`.
function Scene.rig(name: string, root: any?): any
	local model = Instance.new("Model")
	model.Name = name
	local base = root or CF.new(0, 3, 0)
	for bone, spec in Schema.R15 do
		local p = Instance.new("Part")
		p.Name, p.Size = bone, V3.new(spec.Size[1], spec.Size[2], spec.Size[3])
		p.CFrame = base * CF.new(spec.At[1], spec.At[2], spec.At[3])
		p.Parent = model
	end
	Instance.new("Humanoid").Parent = model
	model.PrimaryPart = model:FindFirstChild("HumanoidRootPart")
	model.WorldPivot = base
	return model
end

-- Loads a source file with `env` as its globals (plus the standard library and Lune datatypes).
function Scene.load(path: string, env: { [string]: any }): any
	local base = { V3 = V3, Vector3 = V3, CFrame = CF, Instance = Instance, Enum = roblox.Enum, Color3 = roblox.Color3, math = math,
		table = table, string = string, type = type, typeof = typeof, tostring = tostring, tonumber = tonumber, pairs = pairs, ipairs = ipairs,
		next = next, pcall = pcall, error = error, assert = assert, select = select, setmetatable = setmetatable, os = os, print = print,
		warn = function() end, require = function(m) return m end, UDim2 = roblox.UDim2, Vector2 = roblox.Vector2, RaycastParams = roblox.RaycastParams }
	for k, v in env do base[k] = v end
	return luau.load(fs.readFile(path), { debugName = path, environment = base })()
end

-- World-space centre and axis-aligned half extents of a rest-pose piece (scale 1, root at origin).
function Scene.box(piece: any): (any, any)
	local c, size = Schema.centre(piece), Schema.size(piece)
	local rot = piece.Rot or { 0, 0, 0 }
	local frame = CF.new(c[1], c[2], c[3]) * CF.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
	local h = V3.new(size[1] / 2, size[2] / 2, size[3] / 2)
	local ext = V3.new(math.abs(frame.XVector.X) * h.X + math.abs(frame.YVector.X) * h.Y + math.abs(frame.ZVector.X) * h.Z,
		math.abs(frame.XVector.Y) * h.X + math.abs(frame.YVector.Y) * h.Y + math.abs(frame.ZVector.Y) * h.Z,
		math.abs(frame.XVector.Z) * h.X + math.abs(frame.YVector.Z) * h.Y + math.abs(frame.ZVector.Z) * h.Z)
	return frame.Position, ext
end

return Scene
