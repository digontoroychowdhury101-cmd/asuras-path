--!nonstrict
-- Studio Command Bar / execute_luau (Edit) utility; read-only, never saves. Proves this Studio holds the same Grandmaster Shen as every other
-- computer: one digest per part of him (P1 and P2 templates: every descendant's class, path, attributes and the properties that change what
-- you see; his 64 registered animation ids; the source of the modules that pose, dress and voice him) and, with CHECK_LOADS, that this
-- computer's signed-in account can actually load every mesh, texture, animation and sound he uses (an asset it cannot load leaves the same
-- ids in the file but a different Shen on screen). Compare the "shen ..." line with the one in the latest Shen handoff; run
-- tools/qa/SourceDigest.luau too for the whole game's scripts.
local CHECK_LOADS = true

local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local assets = assert(SS:FindFirstChild("AsuraAssets"), "ServerStorage.AsuraAssets missing: open places/AsurasPath.rbxlx")

local function num(x: number): string
	local s = string.format("%.4f", x)
	return if s == "-0.0000" then "0.0000" else s
end
local function val(v): string
	local t = typeof(v)
	if t == "number" then return num(v) end
	if t == "Vector3" then return num(v.X) .. "," .. num(v.Y) .. "," .. num(v.Z) end
	if t == "CFrame" then
		local c = { v:GetComponents() }
		for i, x in c do c[i] = num(x) end
		return table.concat(c, ",")
	end
	if t == "Color3" then return num(v.R) .. "," .. num(v.G) .. "," .. num(v.B) end
	if t == "Instance" then return v.Name end
	return tostring(v)
end
local PROPS = {
	BasePart = { "Size", "Transparency", "Color", "Material", "CanCollide" },
	MeshPart = { "MeshId", "TextureID", "DoubleSided", "RenderFidelity" },
	SurfaceAppearance = { "ColorMap", "NormalMap", "MetalnessMap", "RoughnessMap", "AlphaMode", "Color" },
	Attachment = { "CFrame" }, -- Bone is an Attachment
	JointInstance = { "C0", "C1", "Part0", "Part1" },
	Decal = { "Texture", "Transparency", "Color3" },
	Animation = { "AnimationId" },
	Sound = { "SoundId", "Volume", "PlaybackSpeed" },
	ValueBase = { "Value" },
	Humanoid = { "RigType", "HipHeight" },
}
local CLASSES = {}
for cls in PROPS do table.insert(CLASSES, cls) end
table.sort(CLASSES)
local content: { [string]: { any } } = {}
local function row(inst: Instance, root: Instance): string
	local path, p = {}, inst
	while p and p ~= root do table.insert(path, 1, p.Name) p = p.Parent end
	local out = { inst.ClassName, table.concat(path, "/") }
	local attrs = inst:GetAttributes()
	local keys = {}
	for k in attrs do table.insert(keys, k) end
	table.sort(keys)
	for _, k in keys do table.insert(out, "@" .. k .. "=" .. val(attrs[k])) end
	if inst:IsA("BasePart") and root:IsA("Model") then
		table.insert(out, "CF=" .. val(root:GetPivot():ToObjectSpace((inst :: BasePart).CFrame)))
	end
	for _, cls in CLASSES do
		if inst:IsA(cls) then
			for _, prop in PROPS[cls] do
				local ok, v = pcall(function() return (inst :: any)[prop] end)
				table.insert(out, prop .. "=" .. (if ok then val(v) else "?"))
				if ok and type(v) == "string" and string.find(v, "^rbxassetid://%d") then content[v] = { inst.ClassName .. "." .. prop, inst } end
			end
		end
	end
	return table.concat(out, "|")
end
local function digest(rows: { string }): number
	table.sort(rows)
	local h = 0
	for i, s in rows do
		s ..= "\0"
		for j = 1, #s, 4096 do
			for _, b in { string.byte(s, j, math.min(j + 4095, #s)) } do h = (h * 31 + b) % 2147483647 end
		end
		if i % 200 == 0 then task.wait() end
	end
	return h
end

local parts = {}
for _, name in { "AsuraBoss_GrandmasterShen_P1", "AsuraBoss_GrandmasterShen_P2" } do
	local model = assert(assets:FindFirstChild(name), name .. " missing")
	local rows = { row(model, model.Parent) }
	for _, d in model:GetDescendants() do table.insert(rows, row(d, model)) end
	table.insert(parts, string.format("%s %d %d", string.sub(name, -2), #rows, digest(rows)))
end

local anims = {}
for _, d in assert(assets:FindFirstChild("AsuraBossAnimations"), "AsuraBossAnimations missing"):GetDescendants() do
	if d:IsA("Animation") and string.find(d:GetFullName(), "GrandmasterShen") then table.insert(anims, row(d, assets)) end
end
table.insert(parts, string.format("anims %d %d", #anims, digest(anims)))

-- Modules that pose, dress, cloth and voice him (the whole game's scripts: SourceDigest.luau).
local MODULES = { "ShenClothData", "ShenPresentationData", "PresentationAssets", "ClothSim", "BossRigs", "BossAnimationRules", "BossAppearance", "BossCloth", "ShenPresentation", "BossArmaments" }
local wanted = {}
for _, n in MODULES do wanted[n] = true end
local src = {}
for _, service in { RS, game:GetService("ServerScriptService"), game:GetService("StarterPlayer"), SS } do
	for _, d in service:GetDescendants() do
		if d:IsA("LuaSourceContainer") and wanted[d.Name] then
			local s = string.gsub((d :: any).Source, "\r", "")
			table.insert(src, d:GetFullName() .. "\0" .. s)
			if d.Name == "PresentationAssets" then -- his original sound layers (ShenAirTear = "rbxassetid://...")
				for id in string.gmatch(s, 'Shen%a+%s*=%s*"(rbxassetid://%d+)"') do content[id] = { "Sound.SoundId" } end
			end
		end
	end
end
table.insert(parts, string.format("modules %d %d", #src, digest(src)))

local line = "shen " .. table.concat(parts, " | ")
print(line)

if CHECK_LOADS then
	-- Ask this Studio to fetch every asset id Shen uses, each as its own asset type (a bare id string is fetched as an image: right for
	-- SurfaceAppearance maps, wrong for meshes, so a MeshPart is preloaded itself; preloading a SurfaceAppearance reports nothing), and count
	-- by kind what this account could not load.
	local list = {}
	for id in content do table.insert(list, id) end
	table.sort(list)
	local holders, made, seen = {}, {}, {}
	for _, id in list do
		local kind: string, owner = content[id][1], content[id][2]
		if kind == "Animation.AnimationId" or kind == "Sound.SoundId" then
			local inst = Instance.new(if kind == "Sound.SoundId" then "Sound" else "Animation")
			if kind == "Sound.SoundId" then (inst :: Sound).SoundId = id else (inst :: Animation).AnimationId = id end
			table.insert(holders, inst)
			table.insert(made, inst)
		elseif string.find(kind, "^SurfaceAppearance") or string.find(kind, "TextureID") or string.find(kind, "^Decal") then
			local inst = Instance.new("ImageLabel")
			inst.Image = id
			table.insert(holders, inst)
			table.insert(made, inst)
		elseif not seen[owner] then
			seen[owner] = true
			table.insert(holders, owner)
		end
	end
	local status = {}
	game:GetService("ContentProvider"):PreloadAsync(holders, function(id, st) status[id] = st end)
	for _, inst in made do inst:Destroy() end
	local byKind, failed, ok = {}, {}, 0
	for _, id in list do
		local kind: string = content[id][1]
		local k = byKind[kind] or { 0, 0 }
		byKind[kind] = k
		k[2] += 1
		if status[id] == Enum.AssetFetchStatus.Success then
			ok += 1
			k[1] += 1
		else
			table.insert(failed, id .. " (" .. kind .. " " .. tostring(status[id]) .. ")")
		end
	end
	local kinds = {}
	for kind, k in byKind do table.insert(kinds, string.format("%s %d/%d", kind, k[1], k[2])) end
	table.sort(kinds)
	line ..= string.format(" || loads %d/%d", ok, #list)
	print(string.format("loads %d/%d ok: %s", ok, #list, table.concat(kinds, ", ")))
	for _, f in failed do warn("not loaded: " .. f) end
end
print("studio " .. version())
return line
