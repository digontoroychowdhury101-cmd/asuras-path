--!strict
-- C00 intake probe (Edit, read-only: clones are measured in nil and destroyed). Measures the boss
-- templates at their roster scale, root-to-feet offsets, weapon extents, the ServerStorage libraries
-- and the authored camera/lighting/player settings. Output: JSON.
local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local SP = game:GetService("StarterPlayer")

local function r2(v: number): number return math.floor(v * 100 + 0.5) / 100 end
local function v3(v: Vector3) return { r2(v.X), r2(v.Y), r2(v.Z) } end

local World = require(RS.AsurasPath.Shared.WorldDefinitions) :: any
local out: any = { bosses = {}, templates = {}, libraries = {}, lighting = {}, player = {}, camera = {} }

local scales: { [string]: number } = {
	AsuraBoss_GrandmasterShen_P1 = World.Bosses.GrandmasterShen.Scale or 1,
	AsuraBoss_GrandmasterShen_P2 = World.Bosses.GrandmasterShen.Scale or 1,
	AsuraBoss_GeneralZhao = World.Bosses.TwinSentinels.Scale or 1,
	AsuraBoss_IronBull = (World.Bosses.TwinSentinels.Partner or {}).Scale or 1,
}

local assets = SS:FindFirstChild("AsuraAssets")
for _, t in (assets and assets:GetChildren() or {}) do
	if t:IsA("Model") and string.sub(t.Name, 1, 10) == "AsuraBoss_" then
		local m = t:Clone()
		local scale = scales[t.Name] or 1
		pcall(function() m:ScaleTo(scale) end)
		local cf, size = m:GetBoundingBox()
		local root = m:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = m:FindFirstChildOfClass("Humanoid")
		local minY, weaponMin, weaponMax = math.huge, nil :: Vector3?, nil :: Vector3?
		local parts, bones, meshes = 0, 0, 0
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				parts += 1
				if d:IsA("MeshPart") then meshes += 1 end
				local half = d.Size / 2
				for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
					local p = d.CFrame:PointToWorldSpace(Vector3.new(sx * half.X, sy * half.Y, sz * half.Z))
					minY = math.min(minY, p.Y)
					if string.find(d.Name, "Weapon") or string.find(d.Name, "Glaive") or string.find(d.Name, "Guandao") then
						weaponMin = if weaponMin then weaponMin:Min(p) else p
						weaponMax = if weaponMax then weaponMax:Max(p) else p
					end
				end end end
			elseif d:IsA("Bone") then
				bones += 1
			end
		end
		local rel = if root then root.CFrame:Inverse() * cf else cf
		table.insert(out.templates, {
			name = t.Name, scale = scale, bbox = v3(size), bboxCentreRootSpace = v3(rel.Position),
			rootToFeet = if root then r2(root.Position.Y - minY) else nil,
			rootSize = if root then v3(root.Size) else nil,
			hipHeight = if hum then r2(hum.HipHeight) else nil,
			weaponExtent = if weaponMin and weaponMax then v3(weaponMax - weaponMin) else nil,
			parts = parts, meshParts = meshes, bones = bones,
		})
		m:Destroy()
	end
end

for id, boss in World.Bosses do
	local fog = World.FogGates[boss.FogGate]
	table.insert(out.bosses, {
		id = id, region = boss.Region, scale = boss.Scale or 1, archetype = boss.Archetype,
		arenaCentre = { boss.Arena.Center.X, boss.Arena.Center.Y, boss.Arena.Center.Z },
		arenaSize = { boss.Arena.Size.X, boss.Arena.Size.Y, boss.Arena.Size.Z },
		spawn = boss.Spawn, fogGate = fog and { placement = fog.Placement, inside = fog.Inside, outside = fog.Outside,
			trigger = { fog.Trigger.Center.X, fog.Trigger.Center.Y, fog.Trigger.Center.Z, fog.Trigger.Size.X, fog.Trigger.Size.Y, fog.Trigger.Size.Z } } or nil,
	})
end

for _, k in { "Brightness", "ClockTime", "GeographicLatitude", "ExposureCompensation", "FogStart", "FogEnd", "EnvironmentDiffuseScale",
	"EnvironmentSpecularScale", "ShadowSoftness" } do
	out.lighting[k] = (Lighting :: any)[k]
end
out.lighting.Ambient = tostring(Lighting.Ambient)
out.lighting.OutdoorAmbient = tostring(Lighting.OutdoorAmbient)
out.lighting.FogColor = tostring(Lighting.FogColor)
local effects = {}
for _, e in Lighting:GetChildren() do table.insert(effects, e.ClassName .. ":" .. e.Name) end
out.lighting.children = effects

for _, k in { "CharacterWalkSpeed", "CharacterJumpPower", "CharacterJumpHeight", "CameraMaxZoomDistance", "CameraMinZoomDistance", "CameraMode",
	"DevComputerCameraMovementMode", "AutoJumpEnabled", "LoadCharacterAppearance" } do
	local ok, v = pcall(function() return (SP :: any)[k] end)
	out.player[k] = if ok then tostring(v) else nil
end
out.player.StarterCharacter = SP:FindFirstChild("StarterCharacter") ~= nil
out.camera.FieldOfView = workspace.CurrentCamera.FieldOfView
out.camera.StreamingEnabled = workspace.StreamingEnabled
out.camera.Gravity = workspace.Gravity
out.camera.FallenPartsDestroyHeight = workspace.FallenPartsDestroyHeight

return HS:JSONEncode(out)
