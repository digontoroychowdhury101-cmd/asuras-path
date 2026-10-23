-- Run read-only against the final Play Client. Screenshots are a separate visual acceptance step.
local root = workspace.Sanctuary
local colossus = root.ColossusSanctuary
local hero = colossus.AsuraVeiledTitan
local light = game:GetService("Lighting")
local atmosphere = light:FindFirstChildOfClass("Atmosphere")
local result = { bareNeon = {}, lanternViolations = {}, lanternLights = 0, tinyCandleFlames = 0, peaks = {} }
local function counts(container)
	local n = { BaseParts = 0, MeshParts = 0, collidingParts = 0, Decals = 0, SurfaceAppearances = 0, PointLights = 0, SpotLights = 0, enabledEmitters = 0 }
	for _, d in container:GetDescendants() do
		if d:IsA("BasePart") then n.BaseParts += 1; if d.CanCollide then n.collidingParts += 1 end end
		if d:IsA("MeshPart") then n.MeshParts += 1
		elseif d:IsA("Decal") then n.Decals += 1
		elseif d:IsA("SurfaceAppearance") then n.SurfaceAppearances += 1
		elseif d:IsA("PointLight") then n.PointLights += 1
		elseif d:IsA("SpotLight") then n.SpotLights += 1
		elseif d:IsA("ParticleEmitter") and d.Enabled then n.enabledEmitters += 1 end
	end
	return n
end
local function inspect(container)
	for _, d in container:GetDescendants() do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			local chamber = d:FindFirstAncestor("FrostedLanternChamber")
			local paper = chamber and d.Name == "FrostedPaperPane" and math.min(d.Size.X, d.Size.Y, d.Size.Z) <= 0.04
			local flame = d.Name == "ShelteredFlame" and d.Size.X <= 0.5 and d.Size.Z <= 0.5 and d.Size.Y <= (if chamber then 0.8 else 0.25)
			if flame and not chamber then result.tinyCandleFlames += 1 end
			if not paper and not flame then table.insert(result.bareNeon, d:GetFullName()) end
		end
		if d:IsA("PointLight") and d.Parent:FindFirstAncestor("FrostedLanternChamber") then
			result.lanternLights += 1
			local c = d.Color
			if d.Brightness < 1.2 or d.Brightness > 1.5 or d.Range < 12 or d.Range > 16 or not d.Shadows
				or math.abs(c.R - 1) > 0.001 or math.abs(c.G - 175 / 255) > 0.001 or math.abs(c.B - 95 / 255) > 0.001 then
				table.insert(result.lanternViolations, d:GetFullName())
			end
		end
		if d:GetAttribute("VistaDistance") then
			table.insert(result.peaks, { name = d.Name, distance = d:GetAttribute("VistaDistance"), foot = d:GetAttribute("VistaFootElevation"), layer = d:GetAttribute("VistaLayer") })
		end
	end
end
inspect(root)
if workspace:FindFirstChild("SpectatorBalcony") then inspect(workspace.SpectatorBalcony) end
result.Sanctuary, result.Workspace = counts(root), counts(workspace)
result.figureHeight, result.treeHeight = hero.Figure:GetExtentsSize().Y, hero.Tree:GetExtentsSize().Y
result.axialWalk = tostring(root:FindFirstChild("AxialWalk", true).Size)
result.arrivalBridge = tostring(root:FindFirstChild("PilgrimWalk", true).Size)
result.terraceFoundation = colossus:FindFirstChild("TerraceKarstCliffs", true):GetAttributes()
result.hiddenSupport = {}
for _, name in { "ColossusTerrace", "TerraceKerb", "TerraceFoot", "TerraceRoot" } do
	local p = colossus[name]
	result.hiddenSupport[name] = { transparency = p.Transparency, collides = p.CanCollide, size = tostring(p.Size) }
end
result.cloudSea = root:FindFirstChild("CloudSea", true):GetAttributes()
result.horizon = root:FindFirstChild("KarstHorizon", true):GetAttributes()
result.atmosphere = { Density = atmosphere.Density, Haze = atmosphere.Haze, Glare = atmosphere.Glare, Offset = atmosphere.Offset, Color = tostring(atmosphere.Color), Decay = tostring(atmosphere.Decay) }
result.lighting = { ClockTime = light.ClockTime, Brightness = light.Brightness, EnvironmentDiffuseScale = light.EnvironmentDiffuseScale, EnvironmentSpecularScale = light.EnvironmentSpecularScale, LightingStyle = tostring(light.LightingStyle) }
result.post = {}
for _, d in light:GetChildren() do
	if d:IsA("BloomEffect") then result.post.Bloom = { Intensity = d.Intensity, Size = d.Size, Threshold = d.Threshold }
	elseif d:IsA("SunRaysEffect") then result.post.SunRays = { Intensity = d.Intensity, Spread = d.Spread }
	elseif d:IsA("ColorCorrectionEffect") and d.Name == "CB_ColorCorrection" then result.post.ColorCorrection = { Contrast = d.Contrast, Saturation = d.Saturation, TintColor = tostring(d.TintColor) } end
end
result.quality, result.viewport = tostring(settings().Rendering.QualityLevel), tostring(workspace.CurrentCamera.ViewportSize)
result.playerPosition = tostring(game.Players.LocalPlayer.Character.HumanoidRootPart.Position)
return game:GetService("HttpService"):JSONEncode(result)
