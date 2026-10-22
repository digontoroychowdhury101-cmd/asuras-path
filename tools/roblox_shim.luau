--!nonstrict
-- Test helper (not a test): the Roblox datatypes and Instance tree in plain Luau, close enough to
-- @lune/roblox to run server builders and rig code offline (no physics, rendering or replication).
-- CFrames carry real rotations; Instances have class inheritance for IsA, per-class defaults,
-- pivots, joints and attachments; implementProperty / implementMethod extend classes as Lune does.
-- Used by tools/test_campaign_build.py and tools/lune_compat.py (Lune is not installed locally).
local Shim = {}

-- Vector3 -----------------------------------------------------------------------------------
local V = { __type = "Vector3" }
local VM = {}
local function v3(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V) end
V.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X ^ 2 + v.Y ^ 2 + v.Z ^ 2) end
	if k == "Unit" then local m = math.sqrt(v.X ^ 2 + v.Y ^ 2 + v.Z ^ 2); if m == 0 then return v3(0 / 0, 0 / 0, 0 / 0) end; return v3(v.X / m, v.Y / m, v.Z / m) end
	return VM[k]
end
V.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V.__mul = function(a, b) if type(a) == "number" then return v3(b.X * a, b.Y * a, b.Z * a) elseif type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z) end
V.__div = function(a, b) if type(b) == "number" then return v3(a.X / b, a.Y / b, a.Z / b) end return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z) end
V.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V.__tostring = function(v) return string.format("%g, %g, %g", v.X, v.Y, v.Z) end
function VM.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function VM.Cross(a, b) return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
function VM.Lerp(a, b, t) return v3(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t) end
function VM.Abs(a) return v3(math.abs(a.X), math.abs(a.Y), math.abs(a.Z)) end
function VM.Min(a, b) return v3(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z)) end
function VM.Max(a, b) return v3(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z)) end
function VM.Floor(a) return v3(math.floor(a.X), math.floor(a.Y), math.floor(a.Z)) end
function VM.FuzzyEq(a, b, e) e = e or 1e-5; return math.abs(a.X - b.X) <= e and math.abs(a.Y - b.Y) <= e and math.abs(a.Z - b.Z) <= e end
function VM.Angle(a, b) local d = a:Dot(b) / (a.Magnitude * b.Magnitude); return math.acos(math.clamp(d, -1, 1)) end
Shim.Vector3 = { new = v3, zero = v3(0, 0, 0), one = v3(1, 1, 1), xAxis = v3(1, 0, 0), yAxis = v3(0, 1, 0), zAxis = v3(0, 0, 1) }

-- CFrame: P (Vector3) and R, a row-major 3x3 rotation whose columns are right, up and back.
local C = { __type = "CFrame" }
local function cf(p, r) return setmetatable({ P = p, R = r }, C) end
local I = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function mul(a, b)
	local r = {}
	for i = 0, 2 do for j = 0, 2 do
		r[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
	end end
	return r
end
local function transpose(r) return { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] } end
local function apply(r, v) return v3(r[1] * v.X + r[2] * v.Y + r[3] * v.Z, r[4] * v.X + r[5] * v.Y + r[6] * v.Z, r[7] * v.X + r[8] * v.Y + r[9] * v.Z) end
local function columns(x, y, z) return { x.X, y.X, z.X, x.Y, y.Y, z.Y, x.Z, y.Z, z.Z } end
local CM = {}
function CM.Inverse(c) local t = transpose(c.R); return cf(-apply(t, c.P), t) end
function CM.ToObjectSpace(c, o) return CM.Inverse(c) * o end
function CM.ToWorldSpace(c, o) return c * o end
function CM.PointToWorldSpace(c, v) return c.P + apply(c.R, v) end
function CM.PointToObjectSpace(c, v) return apply(transpose(c.R), v - c.P) end
function CM.VectorToWorldSpace(c, v) return apply(c.R, v) end
function CM.VectorToObjectSpace(c, v) return apply(transpose(c.R), v) end
function CM.GetComponents(c) local r = c.R; return c.P.X, c.P.Y, c.P.Z, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9] end
CM.components = CM.GetComponents
function CM.ToEulerAnglesXYZ(c) local r = c.R; return math.atan2(-r[6], r[9]), math.asin(math.clamp(r[3], -1, 1)), math.atan2(-r[2], r[1]) end
function CM.ToEulerAnglesYXZ(c) local r = c.R; return math.asin(math.clamp(-r[6], -1, 1)), math.atan2(r[3], r[9]), math.atan2(r[4], r[5]) end
CM.ToOrientation = CM.ToEulerAnglesYXZ
function CM.Lerp(a, b, t)
	local r = {}
	for i = 1, 9 do r[i] = a.R[i] + (b.R[i] - a.R[i]) * t end
	local x, y = v3(r[1], r[4], r[7]).Unit, v3(r[2], r[5], r[8])
	local z = x:Cross(y).Unit
	y = z:Cross(x)
	return cf(a.P:Lerp(b.P, t), columns(x, y, z))
end
function CM.FuzzyEq(a, b, e) e = e or 1e-5; for i = 1, 9 do if math.abs(a.R[i] - b.R[i]) > e then return false end end; return a.P:FuzzyEq(b.P, e) end
C.__index = function(c, k)
	local r = c.R
	if k == "Position" or k == "p" then return c.P end
	if k == "LookVector" then return v3(-r[3], -r[6], -r[9]) end
	if k == "RightVector" or k == "XVector" then return v3(r[1], r[4], r[7]) end
	if k == "UpVector" or k == "YVector" then return v3(r[2], r[5], r[8]) end
	if k == "ZVector" then return v3(r[3], r[6], r[9]) end
	if k == "Rotation" then return cf(v3(), r) end
	if k == "X" then return c.P.X elseif k == "Y" then return c.P.Y elseif k == "Z" then return c.P.Z end
	return CM[k]
end
C.__mul = function(a, b)
	if getmetatable(b) == C then return cf(a.P + apply(a.R, b.P), mul(a.R, b.R)) end
	return a.P + apply(a.R, b)
end
C.__add = function(a, b) return cf(a.P + b, a.R) end
C.__sub = function(a, b) return cf(a.P - b, a.R) end
C.__eq = function(a, b) if a.P ~= b.P then return false end; for i = 1, 9 do if a.R[i] ~= b.R[i] then return false end end; return true end
C.__tostring = function(c) return string.format("%s, %s", tostring(c.P), table.concat(c.R, ", ")) end
local function rx(a) local c, s = math.cos(a), math.sin(a); return { 1, 0, 0, 0, c, -s, 0, s, c } end
local function ry(a) local c, s = math.cos(a), math.sin(a); return { c, 0, s, 0, 1, 0, -s, 0, c } end
local function rz(a) local c, s = math.cos(a), math.sin(a); return { c, -s, 0, s, c, 0, 0, 0, 1 } end
local function lookAt(at, target, up)
	local f = target - at
	if f.Magnitude < 1e-9 then return cf(at, I) end
	f = f.Unit
	up = up or v3(0, 1, 0)
	if math.abs(f:Dot(up.Unit)) > 0.9999 then up = if math.abs(f.Y) > 0.9 then v3(0, 0, 1) else v3(0, 1, 0) end
	local right = f:Cross(up).Unit
	local trueUp = right:Cross(f)
	return cf(at, columns(right, trueUp, -f))
end
Shim.CFrame = {
	new = function(x, y, z, ...)
		if x == nil then return cf(v3(), I) end
		if type(x) == "table" then return if y then lookAt(x, y) else cf(x, I) end
		local n = select("#", ...)
		if n == 9 then return cf(v3(x, y, z), { ... }) end
		if n == 4 then -- quaternion qx qy qz qw
			local qx, qy, qz, qw = ...
			return cf(v3(x, y, z), { 1 - 2 * (qy * qy + qz * qz), 2 * (qx * qy - qz * qw), 2 * (qx * qz + qy * qw),
				2 * (qx * qy + qz * qw), 1 - 2 * (qx * qx + qz * qz), 2 * (qy * qz - qx * qw),
				2 * (qx * qz - qy * qw), 2 * (qy * qz + qx * qw), 1 - 2 * (qx * qx + qy * qy) })
		end
		return cf(v3(x, y, z), I)
	end,
	Angles = function(x, y, z) return cf(v3(), mul(mul(rx(x), ry(y)), rz(z))) end,
	fromEulerAnglesXYZ = function(x, y, z) return cf(v3(), mul(mul(rx(x), ry(y)), rz(z))) end,
	fromEulerAnglesYXZ = function(x, y, z) return cf(v3(), mul(mul(ry(y), rx(x)), rz(z))) end,
	fromOrientation = function(x, y, z) return cf(v3(), mul(mul(ry(y), rx(x)), rz(z))) end,
	fromAxisAngle = function(axis, a)
		local u, c, s = axis.Unit, math.cos(a), math.sin(a)
		local t = 1 - c
		return cf(v3(), { t * u.X * u.X + c, t * u.X * u.Y - s * u.Z, t * u.X * u.Z + s * u.Y,
			t * u.X * u.Y + s * u.Z, t * u.Y * u.Y + c, t * u.Y * u.Z - s * u.X,
			t * u.X * u.Z - s * u.Y, t * u.Y * u.Z + s * u.X, t * u.Z * u.Z + c })
	end,
	fromMatrix = function(p, x, y, z) return cf(p, columns(x, y, z or x:Cross(y))) end,
	lookAt = lookAt,
	identity = cf(v3(), I),
}

-- Colour, enums and small datatypes ---------------------------------------------------------
local C3 = { __type = "Color3" }
C3.__eq = function(a, b) return math.abs(a.R - b.R) < 1e-6 and math.abs(a.G - b.G) < 1e-6 and math.abs(a.B - b.B) < 1e-6 end
local function color(r, g, b)
	local c = setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3)
	function c:Lerp(o, t) return color(self.R + (o.R - self.R) * t, self.G + (o.G - self.G) * t, self.B + (o.B - self.B) * t) end
	function c:ToHSV()
		local mx, mn = math.max(self.R, self.G, self.B), math.min(self.R, self.G, self.B)
		local d, h = mx - mn, 0
		if d > 0 then
			if mx == self.R then h = ((self.G - self.B) / d) % 6 elseif mx == self.G then h = (self.B - self.R) / d + 2 else h = (self.R - self.G) / d + 4 end
			h /= 6
		end
		return h, if mx > 0 then d / mx else 0, mx
	end
	return c
end
local function hsv(h, s, v)
	local i = math.floor(h * 6) % 6
	local f = h * 6 - math.floor(h * 6)
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	local r, g, b = ({ { v, t, p }, { q, v, p }, { p, v, t }, { p, q, v }, { t, p, v }, { v, p, q } })[i + 1][1], 0, 0
	local row = ({ { v, t, p }, { q, v, p }, { p, v, t }, { p, q, v }, { t, p, v }, { v, p, q } })[i + 1]
	r, g, b = row[1], row[2], row[3]
	return color(r, g, b)
end
Shim.Color3 = { new = color, fromRGB = function(r, g, b) return color(r / 255, g / 255, b / 255) end, fromHSV = hsv }
local E = { __type = "EnumItem" }
E.__tostring = function(e) return "Enum." .. e.EnumType .. "." .. e.Name end
local enums = {}
local function enumOf(name)
	local items = {}
	return setmetatable({}, { __index = function(_, k)
		if k == "GetEnumItems" then return function() local list = {}; for _, v in items do table.insert(list, v) end; return list end end
		items[k] = items[k] or setmetatable({ Name = k, EnumType = name, Value = 0 }, E)
		return items[k]
	end })
end
Shim.Enum = setmetatable({}, { __index = function(_, k) enums[k] = enums[k] or enumOf(k); return enums[k] end })
local function passthrough(...) return { ... } end
local function seq(...)
	local a = { ... }
	if type(a[1]) == "table" and a[1].Time == nil and getmetatable(a[1]) == nil then return { Keypoints = a[1] } end
	return { Keypoints = a }
end
Shim.NumberSequence = { new = seq }
Shim.NumberSequenceKeypoint = { new = function(t, v, e) return { Time = t, Value = v, Envelope = e or 0 } end }
Shim.ColorSequence = { new = seq }
Shim.ColorSequenceKeypoint = { new = function(t, v) return { Time = t, Value = v } end }
Shim.NumberRange = { new = function(a, b) return { Min = a, Max = b or a } end }
local V2 = { __type = "Vector2" }
local V2M = {}
local function v2(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, V2) end
V2.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X ^ 2 + v.Y ^ 2) end
	if k == "Unit" then local m = math.sqrt(v.X ^ 2 + v.Y ^ 2); return v2(v.X / m, v.Y / m) end
	return V2M[k]
end
V2.__add = function(a, b) return v2(a.X + b.X, a.Y + b.Y) end
V2.__sub = function(a, b) return v2(a.X - b.X, a.Y - b.Y) end
V2.__mul = function(a, b) if type(a) == "number" then return v2(b.X * a, b.Y * a) elseif type(b) == "number" then return v2(a.X * b, a.Y * b) end return v2(a.X * b.X, a.Y * b.Y) end
V2.__div = function(a, b) if type(b) == "number" then return v2(a.X / b, a.Y / b) end return v2(a.X / b.X, a.Y / b.Y) end
V2.__unm = function(a) return v2(-a.X, -a.Y) end
V2.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
function V2M.Dot(a, b) return a.X * b.X + a.Y * b.Y end
function V2M.Cross(a, b) return a.X * b.Y - a.Y * b.X end
function V2M.Lerp(a, b, t) return v2(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t) end
Shim.Vector2 = { new = v2, zero = v2(0, 0), one = v2(1, 1), xAxis = v2(1, 0), yAxis = v2(0, 1) }
local function udim2(xs, xo, ys, yo) return { X = { Scale = xs or 0, Offset = xo or 0 }, Y = { Scale = ys or 0, Offset = yo or 0 } } end
Shim.UDim2 = { new = udim2, fromScale = function(x, y) return udim2(x, 0, y, 0) end, fromOffset = function(x, y) return udim2(0, x, 0, y) end }
Shim.UDim = { new = function(s, o) return { Scale = s or 0, Offset = o or 0 } end }
Shim.Region3 = { new = function(lo, hi)
	local r = { CFrame = cf((lo + hi) / 2, I), Size = hi - lo }
	function r:ExpandToGrid() return r end
	return r
end }
Shim.RaycastParams = { new = function() return { FilterDescendantsInstances = {}, FilterType = nil, IgnoreWater = false } end }
Shim.Random = { new = function(seed)
	local state = math.floor(seed or 1) % 2147483647
	if state <= 0 then state += 2147483646 end
	local r = {}
	function r:NextNumber(a, b) state = (state * 48271) % 2147483647; local u = state / 2147483647; return if a then a + (b - a) * u else u end
	function r:NextInteger(a, b) return math.floor(self:NextNumber(a, b + 1 - 1e-9)) end
	return r
end }

-- Instances ---------------------------------------------------------------------------------
local PARENT = {
	Part = "BasePart", WedgePart = "BasePart", CornerWedgePart = "BasePart", TrussPart = "BasePart", MeshPart = "BasePart",
	UnionOperation = "BasePart", SpawnLocation = "Part", Seat = "Part", BasePart = "PVInstance", Model = "PVInstance", WorldModel = "Model",
	Workspace = "Model", PVInstance = "Instance", Weld = "JointInstance", ManualWeld = "JointInstance", Motor6D = "Motor",
	Motor = "JointInstance", JointInstance = "Instance", WeldConstraint = "Instance", PointLight = "Light", SpotLight = "Light",
	SurfaceLight = "Light", Light = "Instance", Texture = "Decal", Decal = "FaceInstance", FaceInstance = "Instance",
	Frame = "GuiObject", TextLabel = "GuiObject", TextButton = "GuiButton", ImageButton = "GuiButton", GuiButton = "GuiObject",
	ImageLabel = "GuiObject", ScrollingFrame = "GuiObject", TextBox = "GuiObject", GuiObject = "GuiBase2d", GuiBase2d = "Instance",
	ScreenGui = "LayerCollector", BillboardGui = "LayerCollector", SurfaceGui = "LayerCollector", LayerCollector = "GuiBase2d",
	StringValue = "ValueBase", NumberValue = "ValueBase", BoolValue = "ValueBase", ObjectValue = "ValueBase", ValueBase = "Instance",
}
local DEFAULTS = {
	BasePart = function() return { Size = v3(4, 1, 2), CFrame = cf(v3(), I), Anchored = false, CanCollide = true, CanQuery = true, CanTouch = true,
		Transparency = 0, Reflectance = 0, CastShadow = true, Material = Shim.Enum.Material.Plastic, Color = color(163 / 255, 162 / 255, 165 / 255), Massless = false } end,
	Model = function() return { WorldPivot = cf(v3(), I) } end,
	JointInstance = function() return { C0 = cf(v3(), I), C1 = cf(v3(), I), Enabled = true } end,
	Attachment = function() return { CFrame = cf(v3(), I), Visible = false } end,
	Humanoid = function() return { Health = 100, MaxHealth = 100, WalkSpeed = 16 } end,
	Light = function() return { Brightness = 1, Range = 8, Enabled = true, Shadows = false, Color = color(1, 1, 1) } end,
}
local custom: { [string]: { [string]: any } } = {}
local function isA(class, target)
	local c = class
	while c do
		if c == target then return true end
		c = PARENT[c] or (if c ~= "Instance" then "Instance" else nil)
	end
	return false
end
local chains = {}
local function chain(class)
	local cached = chains[class]
	if cached then return cached end
	local list = {}; local c = class
	while c do table.insert(list, c); c = PARENT[c] or (if c ~= "Instance" then "Instance" else nil) end
	chains[class] = list
	return list
end
local function signal() local s = { Links = {} }; function s:Connect(fn) table.insert(self.Links, fn); return { Connected = true, Disconnect = function() end } end; function s:Fire(...) for _, f in self.Links do f(...) end end; function s:Wait() end; return s end

local Inst = { __type = "Instance" }
local Methods = {}
local function new(class)
	local o = setmetatable({ ClassName = class, Name = class, Children = {}, Attributes = {}, Tags = {}, Signals = {} }, Inst)
	for _, c in chain(class) do
		local d = DEFAULTS[c]
		if d then for k, v in d() do rawset(o, k, v) end end
	end
	return o
end
Shim.new = new
function Methods:IsA(class) return isA(self.ClassName, class) end
function Methods:SetAttribute(k, v)
	self.Attributes[k] = v
	local s = rawget(self, "Signals")
	if s and s["@" .. k] then s["@" .. k]:Fire() end
end
function Methods:GetAttribute(k) return self.Attributes[k] end
function Methods:GetAttributes() return table.clone(self.Attributes) end
function Methods:AddTag(t) self.Tags[t] = true end
function Methods:RemoveTag(t) self.Tags[t] = nil end
function Methods:HasTag(t) return self.Tags[t] == true end
function Methods:GetTags() local l = {}; for t in self.Tags do table.insert(l, t) end; return l end
function Methods:GetChildren() return table.clone(self.Children) end
function Methods:GetDescendants()
	local out = {}
	local function walk(node) for _, c in node.Children do table.insert(out, c); walk(c) end end
	walk(self)
	return out
end
function Methods:FindFirstChild(name, recursive)
	for _, c in (if recursive then self:GetDescendants() else self.Children) do if c.Name == name then return c end end
	return nil
end
Methods.WaitForChild = Methods.FindFirstChild
function Methods:FindFirstChildOfClass(class) for _, c in self.Children do if c.ClassName == class then return c end end; return nil end
function Methods:FindFirstChildWhichIsA(class, recursive) for _, c in (if recursive then self:GetDescendants() else self.Children) do if c:IsA(class) then return c end end; return nil end
function Methods:FindFirstAncestor(name) local p = self.Parent; while p do if p.Name == name then return p end; p = p.Parent end; return nil end
function Methods:FindFirstAncestorOfClass(class) local p = self.Parent; while p do if p.ClassName == class then return p end; p = p.Parent end; return nil end
function Methods:FindFirstAncestorWhichIsA(class) local p = self.Parent; while p do if p:IsA(class) then return p end; p = p.Parent end; return nil end
function Methods:IsDescendantOf(other) local p = self.Parent; while p do if p == other then return true end; p = p.Parent end; return false end
function Methods:IsAncestorOf(other) return other:IsDescendantOf(self) end
function Methods:GetFullName() local n = self.Name; local p = self.Parent; while p do n = p.Name .. "." .. n; p = p.Parent end; return n end
function Methods:ClearAllChildren() for _, c in table.clone(self.Children) do c:Destroy() end end
function Methods:Destroy() for _, c in table.clone(self.Children) do c:Destroy() end; self.Parent = nil; rawset(self, "Destroyed", true) end
function Methods:Clone()
	local copy = setmetatable({ Children = {}, Attributes = table.clone(self.Attributes), Tags = table.clone(self.Tags), Signals = {} }, Inst)
	for k, v in self do if k ~= "_parent" and k ~= "Children" and k ~= "Attributes" and k ~= "Tags" and k ~= "Signals" then rawset(copy, k, v) end end
	for _, c in self.Children do c:Clone().Parent = copy end
	return copy
end
function Methods:GetPropertyChangedSignal(name) self.Signals[name] = self.Signals[name] or signal(); return self.Signals[name] end
function Methods:GetAttributeChangedSignal(name) return self:GetPropertyChangedSignal("@" .. name) end
function Methods:GetPivot()
	if self:IsA("BasePart") then return self.CFrame end
	local primary = rawget(self, "PrimaryPart")
	if primary then return primary.CFrame end
	return rawget(self, "WorldPivot") or cf(v3(), I)
end
function Methods:PivotTo(target)
	if self:IsA("BasePart") then self.CFrame = target; return end
	local delta = target * self:GetPivot():Inverse()
	for _, d in self:GetDescendants() do if d:IsA("BasePart") then d.CFrame = delta * d.CFrame end end
	rawset(self, "WorldPivot", target)
end
function Methods:GetBoundingBox()
	local lo, hi = v3(math.huge, math.huge, math.huge), v3(-math.huge, -math.huge, -math.huge)
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then
			local h = d.Size / 2
			for sx = -1, 1, 2 do for sy = -1, 1, 2 do for sz = -1, 1, 2 do
				local p = d.CFrame * v3(h.X * sx, h.Y * sy, h.Z * sz)
				lo, hi = lo:Min(p), hi:Max(p)
			end end end
		end
	end
	return cf((lo + hi) / 2, I), hi - lo
end
function Methods:GetExtentsSize() local _, size = self:GetBoundingBox(); return size end

local SIGNALS = { ChildAdded = true, ChildRemoved = true, DescendantAdded = true, DescendantRemoving = true, Destroying = true,
	AncestryChanged = true, Touched = true, Activated = true, Triggered = true, Died = true, Changed = true, MouseButton1Click = true }
Inst.__index = function(o, k)
	if k == "Parent" then return rawget(o, "_parent") end
	for _, c in chain(rawget(o, "ClassName")) do
		local ext = custom[c]
		if ext and ext[k] then
			local entry = ext[k]
			if entry.Method then return entry.Method end
			return entry.Get(o)
		end
	end
	if k == "Position" then local c = rawget(o, "CFrame"); return c and c.P end
	if k == "Orientation" then local c = rawget(o, "CFrame"); if not c then return nil end; local x, y, z = c:ToEulerAnglesYXZ(); return v3(math.deg(x), math.deg(y), math.deg(z)) end
	if k == "WorldPosition" or k == "WorldCFrame" then
		local parent, c = rawget(o, "_parent"), rawget(o, "CFrame") or cf(v3(), I)
		local world = if parent and rawget(parent, "CFrame") then parent.CFrame * c else c
		return if k == "WorldPosition" then world.P else world
	end
	if Methods[k] then return Methods[k] end
	if SIGNALS[k] then o.Signals[k] = o.Signals[k] or signal(); return o.Signals[k] end
	for _, c in rawget(o, "Children") or {} do if c.Name == k then return c end end -- instance.ChildName
	return nil
end
Inst.__newindex = function(o, k, v)
	for _, c in chain(rawget(o, "ClassName")) do
		local ext = custom[c]
		if ext and ext[k] and ext[k].Set then ext[k].Set(o, v); return end
	end
	if k == "Parent" then
		local old = rawget(o, "_parent")
		if old then local i = table.find(old.Children, o); if i then table.remove(old.Children, i) end end
		rawset(o, "_parent", v)
		if v then table.insert(v.Children, o); local s = rawget(v, "Signals"); if s and s.ChildAdded then s.ChildAdded:Fire(o) end end
		local own = rawget(o, "Signals")
		if own and own.AncestryChanged and old ~= v then own.AncestryChanged:Fire(o, v) end
		return
	end
	if k == "Position" and isA(rawget(o, "ClassName"), "BasePart") or (k == "Position" and rawget(o, "ClassName") == "Attachment") then
		local old = rawget(o, "CFrame")
		rawset(o, "CFrame", cf(v, if old then old.R else I)); return
	end
	if k == "Orientation" then
		local old = rawget(o, "CFrame") or cf(v3(), I)
		rawset(o, "CFrame", cf(old.P, Shim.CFrame.fromOrientation(math.rad(v.X), math.rad(v.Y), math.rad(v.Z)).R)); return
	end
	if k == "WorldPosition" and rawget(o, "ClassName") == "Attachment" then
		local parent = rawget(o, "_parent")
		local local_ = if parent and rawget(parent, "CFrame") then parent.CFrame:PointToObjectSpace(v) else v
		rawset(o, "CFrame", cf(local_, (rawget(o, "CFrame") or cf(v3(), I)).R)); return
	end
	rawset(o, k, v)
	local s = rawget(o, "Signals")
	if s and s[k] then s[k]:Fire(v) end
end
Shim.Instance = { new = function(class, parent) local o = new(class); if parent then o.Parent = parent end; return o end }

-- Lune's class extension hooks.
function Shim.implementProperty(class, name, getter, setter)
	custom[class] = custom[class] or {}
	custom[class][name] = { Get = getter, Set = setter }
end
function Shim.implementMethod(class, name, fn)
	custom[class] = custom[class] or {}
	custom[class][name] = { Method = fn }
end

return Shim
