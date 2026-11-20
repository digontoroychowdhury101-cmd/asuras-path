--!strict
-- Vesperhold's registry references uploaded models. Their imported MeshParts own
-- mesh and PBR maps; collision is set per sub role here (see CORE below). Structural decks retain their simple
-- collision. An unavailable or incomplete visual piece falls back as a unit.
local Kit = {}
Kit.Registry = nil :: any
Kit.LoadModel = nil :: ((string) -> Instance?)?
Kit.MaxLights = 80

local DECOR = { Twigs = true, Banner = true, Rope = true, Wax = true, Candle = true, Flame = true, Staff = true,
	Sword = true, Tracery = true, Crockets = true, Frost = true, Glass = true, Water = true, Bone = true, Chain = true }
-- Collision fidelity by sub role (creator's import rules): cores Hull (PreciseConvexDecomposition only when opts.Walkable), everything
-- else that collides is a thin solid: Box. Decorative roles never collide.
local CORE = { Stone = true, Plinth = true, Bark = true }
local SOLID_GROUPS = { Statue = true, Pedestal = true, Tree = true, Grave = true }
local PRIMARY = { "Stone", "Robe", "Body", "Bark", "Plinth", "Iron", "Water", "Banner", "Figure", "FigureSmooth" }
local CRIMSON, AMBER, FLAME = Color3.fromRGB(150, 26, 38), Color3.fromRGB(224, 142, 62), Color3.fromRGB(255, 138, 52)

type Sub = { Key: string, Source: MeshPart, Frame: CFrame, HasCenter: boolean, Role: string }
type Options = { Group: string?, Walkable: boolean?, Seed: number?, Offset: CFrame? }
local models: { [string]: Instance | boolean } = {}
local templates: { [string]: {Sub} | boolean } = {}
local lamps: { [PointLight]: boolean } = {}

local function registry(): any
	if Kit.Registry == nil then
		local shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath"):WaitForChild("Shared")
		Kit.Registry = require(shared:WaitForChild("VesperholdKitRegistry") :: ModuleScript)
	end
	return Kit.Registry
end

local function loadModel(asset: string): Instance?
	local hit = models[asset]
	if hit ~= nil then return if hit == false then nil else hit :: Instance end
	local ok, result = pcall(function()
		local loader = Kit.LoadModel
		if loader then return loader(asset) end
		local id = string.match(asset, "^rbxassetid://(%d+)$")
		if not id then return nil end
		return game:GetService("InsertService"):LoadAsset(tonumber(id) :: number)
	end)
	local model = if ok and result and result:IsA("Model") then result else nil
	if not model then warn("[VesperholdKit] Could not load " .. asset .. ". Keeping the authored stand-in.") end
	models[asset] = model or false
	return model
end

-- Multiple nodes can share an uploaded mesh id. Prefer the named node, then a
-- unique id match. Identical mesh ids alone cannot identify two different poses.
local function findMesh(nodes: {Instance}, key: string, meshId: string): MeshPart?
	local stem = string.match(key,"__(.+)$")
	local only: MeshPart? = nil
	local count = 0
	for _,node in nodes do
		if node:IsA("MeshPart") and node.MeshId == meshId then
			if node.Name == key or node.Name == stem then return node end
			only, count = node, count+1
		end
	end
	return if count==1 then only else nil
end

local function extent(frame: CFrame, half: Vector3): Vector3
	return frame.RightVector:Abs()*half.X + frame.UpVector:Abs()*half.Y + frame.ZVector:Abs()*half.Z
end

local function readTemplate(piece: string): {Sub}?
	local entries = registry()[piece]
	if type(entries) ~= "table" then return nil end
	local _,first = next(entries)
	if type(first) ~= "table" or type(first.Asset) ~= "string" then return nil end
	-- A piece over the 20 MB upload limit ships as several model assets; then every sub needs a foot-space center.
	local multi = false
	for _,e in entries do
		if type(e) ~= "table" or type(e.Asset) ~= "string" then return nil end
		if e.Asset ~= first.Asset then multi = true end
	end
	local roots: {[string]: {pivot: CFrame, nodes: {Instance}}} = {}
	local function rootOf(asset: string)
		if roots[asset] then return roots[asset] end
		local wrapper = loadModel(asset)
		if not wrapper then return nil end
		local named = wrapper:FindFirstChild(piece,true)
		local root = if named and named:IsA("Model") then named else wrapper :: Model
		roots[asset] = {pivot = root:GetPivot(), nodes = root:GetDescendants()}
		return roots[asset]
	end
	local list: {Sub} = {}
	local used: {[MeshPart]: boolean} = {}
	local lo = Vector3.new(math.huge,math.huge,math.huge)
	local hi = -lo
	for key,e in entries do
		if type(key) ~= "string" or type(e.MeshId) ~= "string" or (multi and e.center == nil) then return nil end
		local r = rootOf(e.Asset)
		if not r then return nil end
		local pivot = r.pivot
		local src = findMesh(r.nodes,key,e.MeshId)
		if not src or not src.Archivable or used[src] then return nil end
		used[src] = true
		local rel = pivot:ToObjectSpace(src.CFrame)
		local half = extent(rel,src.Size*0.5)
		lo = lo:Min(rel.Position-half)
		hi = hi:Max(rel.Position+half)
		local center = e.center
		if center ~= nil then
			if type(center) ~= "table" or #center ~= 3 then return nil end
			for _,v in center do if type(v) ~= "number" or not math.isfinite(v) then return nil end end
			rel = CFrame.new(center[1],center[2],center[3])*rel.Rotation
		end
		local role = string.gsub(string.match(key,"__(.+)$") or key,"_%d+$","")
		table.insert(list,{Key=key,Source=src,Frame=rel,HasCenter=center~=nil,Role=role})
	end
	-- A model returned by LoadAsset can have a Studio bounding-centre pivot.
	-- Missing explicit foot-space centres come from the whole assembled piece,
	-- preserving relative offsets, even if its wrapper has unrelated children.
	local foot = Vector3.new((lo.X+hi.X)*0.5, lo.Y, (lo.Z+hi.Z)*0.5)
	for _,sub in list do
		if not sub.HasCenter then sub.Frame = sub.Frame-foot end
	end
	table.sort(list,function(a,b) return a.Key < b.Key end)
	return list
end

local function template(piece: string): {Sub}?
	local hit = templates[piece]
	if hit ~= nil then return if hit == false then nil else hit :: {Sub} end
	local result = readTemplate(piece)
	templates[piece] = result or false
	return result
end

function Kit.resolve(piece: string, seed: number?): string?
	if template(piece) then return piece end
	local a, b = template(piece .. "_A") ~= nil, template(piece .. "_B") ~= nil
	if a and b then return piece .. (if (seed or 0)%2 == 0 then "_A" else "_B") end
	return if a then piece .. "_A" elseif b then piece .. "_B" else nil
end

function Kit.has(piece: string): boolean
	return Kit.resolve(piece,0) ~= nil
end

function Kit.Lights(): number
	local count = 0
	for light in lamps do
		if light.Parent then count += 1 else lamps[light] = nil end
	end
	return count
end

local function lightPart(part: MeshPart, role: string, piece: string)
	if role ~= "Glass" and role ~= "Flame" then return end
	local color = if role == "Flame" then FLAME elseif piece:find("Rose",1,true) or piece:find("Portal",1,true) then CRIMSON else AMBER
	part.Material, part.Color = Enum.Material.Neon, color
	if Kit.Lights() >= Kit.MaxLights then return end
	local light = Instance.new("PointLight")
	light.Color, light.Shadows = color, false
	light.Range, light.Brightness = if role=="Flame" then 9 else 14, if role=="Flame" then 1.4 else 0.8
	light.Parent = part
	lamps[light] = true
end

-- Express anisotropic scale in each mesh's axes. Rotated 90-degree imported
-- pieces swap dimensions. A general rotation under nonuniform scale can shear,
-- which a rigid CFrame and MeshPart.Size cannot represent.
local function scaledFrame(rel: CFrame, scale: Vector3): (CFrame?,Vector3?)
	local x, y, z = rel.RightVector*scale, rel.UpVector*scale, rel.ZVector*scale
	local sx,sy,sz = x.Magnitude,y.Magnitude,z.Magnitude
	x,y,z = x/sx,y/sy,z/sz
	if math.max(math.abs(x:Dot(y)),math.abs(x:Dot(z)),math.abs(y:Dot(z))) > 0.001 then return nil,nil end
	return CFrame.fromMatrix(rel.Position*scale,x,y,z),Vector3.new(sx,sy,sz)
end

function Kit.place(piece: string, frame: CFrame, scale: Vector3, opts: Options?): Model?
	if not (math.isfinite(scale.X) and math.isfinite(scale.Y) and math.isfinite(scale.Z))
		or math.min(scale.X,scale.Y,scale.Z) <= 0 then return nil end
	local o = opts or {}
	local name = Kit.resolve(piece,o.Seed)
	if not name then return nil end
	local subs = template(name) :: {Sub}
	local base = frame * (o.Offset or CFrame.identity)
	local solid = SOLID_GROUPS[o.Group or ""] == true
	local model = Instance.new("Model")
	model.Name = piece
	local primary: BasePart? = nil
	local best = math.huge
	for _,sub in subs do
		local pose, dimensions = scaledFrame(sub.Frame,scale)
		if not pose or not dimensions then model:Destroy(); return nil end
		local part = sub.Source:Clone() :: MeshPart?
		if not part then model:Destroy(); return nil end
		-- Only the imported surface finish travels onto these static kit parts.
		for _,child in part:GetChildren() do
			if not child:IsA("SurfaceAppearance") and not child:IsA("Decal") then child:Destroy() end
		end
		part.Name = sub.Key
		part.Size,part.CFrame = sub.Source.Size*dimensions,base*pose
		part.Anchored,part.CanTouch = true,false
		part.CanCollide = solid and not DECOR[sub.Role]
		part.CanQuery = part.CanCollide
		if part.CanCollide then
			part.CollisionFidelity = if not CORE[sub.Role] then Enum.CollisionFidelity.Box
				elseif o.Walkable then Enum.CollisionFidelity.PreciseConvexDecomposition else Enum.CollisionFidelity.Hull
		end
		lightPart(part,sub.Role,name)
		part.Parent = model
		local rank = table.find(PRIMARY,sub.Role) or #PRIMARY+1
		if rank < best then best,primary = rank,part end
	end
	model.PrimaryPart = primary
	-- A primary part normally shifts Model:GetPivot() to the mesh centre. Preserve
	-- the same requested foot frame for later PivotTo/ScaleTo and inspection.
	if primary then primary.PivotOffset = primary.CFrame:ToObjectSpace(base) end
	model:SetAttribute("VespKitPiece",name)
	return model
end

function Kit.Reset()
	for _,model in models do
		if typeof(model)=="Instance" then (model :: Instance):Destroy() end
	end
	table.clear(models)
	table.clear(templates)
	table.clear(lamps)
	Kit.Registry, Kit.LoadModel = nil,nil
end

return Kit
