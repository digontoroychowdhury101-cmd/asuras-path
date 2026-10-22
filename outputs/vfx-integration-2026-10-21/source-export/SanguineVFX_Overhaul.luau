    local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local TweenService = game:GetService("TweenService")
	local Debris = game:GetService("Debris")
	local Lighting = game:GetService("Lighting")

	local VFX = {}

	local LOCAL_PLAYER = Players.LocalPlayer
	local RANDOM = Random.new()

	local CONFIG = {
		Quality = "High",
		EnableCameraShake = true,
		EnableScreenFlash = true,
		EnablePostProcessing = true,
		EnableAfterimages = true,
		EnableParticles = true,
		EnableDebris = true,
		MaximumScreenFlashAlpha = 0.58,
	}

	local QUALITY = {
		Low = {
			Geometry = 0.36,
			Particles = 0.38,
			Debris = 0.35,
			Lightning = 0.50,
			Rings = 0.55,
		},
		Medium = {
			Geometry = 0.68,
			Particles = 0.70,
			Debris = 0.65,
			Lightning = 0.75,
			Rings = 0.78,
		},
		High = {
			Geometry = 1.00,
			Particles = 1.00,
			Debris = 1.00,
			Lightning = 1.00,
			Rings = 1.00,
		},
		Cinematic = {
			Geometry = 1.34,
			Particles = 1.45,
			Debris = 1.30,
			Lightning = 1.35,
			Rings = 1.30,
		},
	}

	local COLOR = {
		Ash = Color3.fromRGB(128, 134, 148),
		DarkAsh = Color3.fromRGB(39, 40, 49),
		Crimson = Color3.fromRGB(218, 22, 42),
		Blood = Color3.fromRGB(118, 7, 22),
		BloodHot = Color3.fromRGB(255, 48, 42),
		Ember = Color3.fromRGB(255, 113, 42),
		ElectricBlue = Color3.fromRGB(35, 101, 255),
		IceBlue = Color3.fromRGB(91, 190, 255),
		CoreWhite = Color3.fromRGB(255, 251, 243),
		RuneGold = Color3.fromRGB(255, 195, 86),
		Smoke = Color3.fromRGB(63, 56, 66),
		Black = Color3.fromRGB(9, 8, 13),
	}

	local TEXTURE = {
		Sparks = "rbxasset://textures/particles/sparkles_main.dds",
		Smoke = "rbxasset://textures/particles/smoke_main.dds",
	}

	local initialized = false
	local fxFolder = nil
	local screenGui = nil
	local screenFlashFrame = nil
	local activeFlashTween = nil
	local blurEffect = nil
	local colorGrade = nil
	local bloomEffect = nil
	local renderBindingName = "SanguineVFX_CameraShake_2026"
	local cameraConnection = nil
	local activeShakes = {}
	local auraHandles = setmetatable({}, { __mode = "k" })
	local baseBloomIntensity = 0.52

	--------------------------------------------------------------------------------
	-- INTERNAL UTILITY LAYER
	--------------------------------------------------------------------------------

	local function getQualityConfig()
		return QUALITY[CONFIG.Quality] or QUALITY.High
	end

	local function scaleGeometry(count)
		return math.max(1, math.floor(count * getQualityConfig().Geometry + 0.5))
	end

	local function scaleParticles(count)
		return math.max(0, math.floor(count * getQualityConfig().Particles + 0.5))
	end

	local function scaleDebris(count)
		return math.max(0, math.floor(count * getQualityConfig().Debris + 0.5))
	end

	local function scaleLightning(count)
		return math.max(1, math.floor(count * getQualityConfig().Lightning + 0.5))
	end

	local function scaleRings(count)
		return math.max(6, math.floor(count * getQualityConfig().Rings + 0.5))
	end

	local function getEffectFolder()
		if fxFolder and fxFolder.Parent then
			return fxFolder
		end

		fxFolder = Instance.new("Folder")
		fxFolder.Name = "__SanguineVFX_LocalOnly"
		fxFolder.Archivable = false
		fxFolder.Parent = workspace
		return fxFolder
	end

	local function newGroup(name, lifetime)
		local group = Instance.new("Folder")
		group.Name = name or "VFX"
		group.Archivable = false
		group.Parent = getEffectFolder()

		if lifetime and lifetime > 0 then
			Debris:AddItem(group, lifetime)
		end

		return group
	end

	local function safeDestroy(instance)
		if instance and instance.Parent then
			instance:Destroy()
		end
	end

	local function tween(instance, duration, properties, style, direction)
		if not instance or not instance.Parent then
			return nil
		end

		local info = TweenInfo.new(
			math.max(0.03, duration or 0.25),
			style or Enum.EasingStyle.Quad,
			direction or Enum.EasingDirection.Out
		)

		local ok, result = pcall(function()
			return TweenService:Create(instance, info, properties)
		end)

		if not ok or not result then
			return nil
		end

		result:Play()
		return result
	end

	local function makePart(parent, name, size, cf, color, material, transparency, shape)
		local part = Instance.new("Part")
		part.Name = name or "VFXPart"
		part.Size = size or Vector3.new(1, 1, 1)
		part.CFrame = cf or CFrame.new()
		part.Color = color or COLOR.CoreWhite
		part.Material = material or Enum.Material.Neon
		part.Transparency = transparency == nil and 0 or transparency
		part.Shape = shape or Enum.PartType.Block
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Massless = true
		part.Archivable = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = parent
		return part
	end

	local function makeAnchor(parent, position, name)
		local anchor = Instance.new("Part")
		anchor.Name = name or "VFXAnchor"
		anchor.Size = Vector3.new(0.15, 0.15, 0.15)
		anchor.CFrame = CFrame.new(position)
		anchor.Transparency = 1
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanTouch = false
		anchor.CanQuery = false
		anchor.CastShadow = false
		anchor.Massless = true
		anchor.Archivable = false
		anchor.Parent = parent
		return anchor
	end

	local function makeLine(parent, startPosition, endPosition, width, color, transparency, name)
		local difference = endPosition - startPosition
		local length = difference.Magnitude

		if length < 0.035 then
			return nil
		end

		local middle = (startPosition + endPosition) * 0.5
		local line = makePart(
			parent,
			name or "EnergyLine",
			Vector3.new(width or 0.12, width or 0.12, length),
			CFrame.lookAt(middle, endPosition),
			color or COLOR.CoreWhite,
			Enum.Material.Neon,
			transparency == nil and 0.04 or transparency,
			Enum.PartType.Block
		)

		return line
	end

	local function makeParticleEmitter(parent, options)
		options = options or {}

		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = options.Name or "SanguineEmitter"
		emitter.Texture = options.Texture or TEXTURE.Sparks
		emitter.Enabled = options.Enabled == true
		emitter.Rate = options.Rate or 0
		emitter.Lifetime = options.Lifetime or NumberRange.new(0.18, 0.42)
		emitter.Speed = options.Speed or NumberRange.new(9, 20)
		emitter.SpreadAngle = options.SpreadAngle or Vector2.new(180, 180)
		emitter.Color = options.Color or ColorSequence.new(COLOR.CoreWhite, COLOR.Crimson)
		emitter.Size = options.Size or NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(0.35, 0.16),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = options.Transparency or NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.04),
			NumberSequenceKeypoint.new(0.7, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.LightEmission = options.LightEmission == nil and 1 or options.LightEmission
		emitter.LightInfluence = options.LightInfluence == nil and 0 or options.LightInfluence
		emitter.Drag = options.Drag or 1.5
		emitter.Acceleration = options.Acceleration or Vector3.new(0, -12, 0)
		emitter.Rotation = options.Rotation or NumberRange.new(-180, 180)
		emitter.RotSpeed = options.RotSpeed or NumberRange.new(-260, 260)
		emitter.ZOffset = options.ZOffset or 0
		emitter.LockedToPart = options.LockedToPart == true
		emitter.EmissionDirection = options.EmissionDirection or Enum.NormalId.Top
		emitter.Parent = parent
		return emitter
	end

	local function emitBurst(parent, position, options)
		if not CONFIG.EnableParticles then
			return nil
		end

		options = options or {}
		local amount = scaleParticles(options.Count or 18)
		local smokeAmount = scaleParticles(options.SmokeCount or 0)
		local lifetimeMax = 1.5

		if options.Lifetime then
			lifetimeMax = options.Lifetime.Max
		end

		local anchor = makeAnchor(parent, position, options.AnchorName or "BurstAnchor")
		local attachment = Instance.new("Attachment")
		attachment.Name = "BurstAttachment"
		attachment.Parent = anchor

		if amount > 0 then
			local sparkEmitter = makeParticleEmitter(attachment, {
				Name = "Sparks_" .. (options.Name or "Burst"),
				Texture = options.Texture or TEXTURE.Sparks,
				Lifetime = options.Lifetime or NumberRange.new(0.18, 0.62),
				Speed = options.Speed or NumberRange.new(7, 24),
				SpreadAngle = options.SpreadAngle or Vector2.new(180, 180),
				Color = options.Color or ColorSequence.new(COLOR.CoreWhite, COLOR.Crimson),
				Size = options.Size or NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.28),
					NumberSequenceKeypoint.new(0.22, 0.16),
					NumberSequenceKeypoint.new(1, 0),
				}),
				Transparency = options.Transparency or NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.62, 0.22),
					NumberSequenceKeypoint.new(1, 1),
				}),
				LightEmission = options.LightEmission == nil and 1 or options.LightEmission,
				Drag = options.Drag or 1.2,
				Acceleration = options.Acceleration or Vector3.new(0, -17, 0),
				RotSpeed = NumberRange.new(-320, 320),
			})

			sparkEmitter:Emit(amount)
		end

		if smokeAmount > 0 then
			local smokeEmitter = makeParticleEmitter(attachment, {
				Name = "Smoke_" .. (options.Name or "Burst"),
				Texture = TEXTURE.Smoke,
				Lifetime = options.SmokeLifetime or NumberRange.new(0.55, 1.35),
				Speed = options.SmokeSpeed or NumberRange.new(2, 8),
				SpreadAngle = Vector2.new(180, 180),
				Color = options.SmokeColor or ColorSequence.new(COLOR.Smoke, COLOR.DarkAsh),
				Size = options.SmokeSize or NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1.2),
					NumberSequenceKeypoint.new(0.4, 2.8),
					NumberSequenceKeypoint.new(1, 4.4),
				}),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.28),
					NumberSequenceKeypoint.new(0.45, 0.48),
					NumberSequenceKeypoint.new(1, 1),
				}),
				LightEmission = 0.05,
				Drag = 3,
				Acceleration = Vector3.new(0, 3, 0),
			})

			smokeEmitter:Emit(smokeAmount)
		end

		Debris:AddItem(anchor, math.max(0.8, lifetimeMax + 0.75))
		return anchor
	end

	local function flashScreen(color, alpha, duration)
		if not CONFIG.EnableScreenFlash or not screenFlashFrame then
			return
		end

		alpha = math.clamp(alpha or 0.2, 0, CONFIG.MaximumScreenFlashAlpha)
		duration = duration or 0.16

		if activeFlashTween then
			pcall(function()
				activeFlashTween:Cancel()
			end)
		end

		screenFlashFrame.BackgroundColor3 = color or COLOR.CoreWhite
		screenFlashFrame.BackgroundTransparency = 1 - alpha
		activeFlashTween = tween(screenFlashFrame, duration, {
			BackgroundTransparency = 1,
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end

	local function punchBloom(amount, duration)
		if not bloomEffect or not CONFIG.EnablePostProcessing then
			return
		end

		amount = amount or 0.8
		duration = duration or 0.32

		bloomEffect.Intensity = math.clamp(baseBloomIntensity + amount, 0, 4)
		tween(bloomEffect, duration, {
			Intensity = baseBloomIntensity,
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end

	local function pulseSphere(parent, position, startDiameter, endDiameter, color, duration, initialTransparency, name)
		local sphere = makePart(
			parent,
			name or "EnergyPulse",
			Vector3.new(startDiameter, startDiameter, startDiameter),
			CFrame.new(position),
			color or COLOR.CoreWhite,
			Enum.Material.Neon,
			initialTransparency == nil and 0.2 or initialTransparency,
			Enum.PartType.Ball
		)

		tween(sphere, duration or 0.35, {
			Size = Vector3.new(endDiameter, endDiameter, endDiameter),
			Transparency = 1,
		}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

		return sphere
	end

	local function drawRing(parent, position, startRadius, endRadius, width, color, duration, segments, verticalOffset, initialTransparency)
		segments = scaleRings(segments or 20)
		startRadius = math.max(0.1, startRadius or 1)
		endRadius = math.max(startRadius, endRadius or startRadius * 1.4)
		verticalOffset = verticalOffset or 0.08

		local ringParts = {}

		for index = 1, segments do
			local angle0 = ((index - 1) / segments) * math.pi * 2
			local angle1 = (index / segments) * math.pi * 2

			local startA = position + Vector3.new(math.cos(angle0) * startRadius, verticalOffset, math.sin(angle0) * startRadius)
			local startB = position + Vector3.new(math.cos(angle1) * startRadius, verticalOffset, math.sin(angle1) * startRadius)
			local endA = position + Vector3.new(math.cos(angle0) * endRadius, verticalOffset, math.sin(angle0) * endRadius)
			local endB = position + Vector3.new(math.cos(angle1) * endRadius, verticalOffset, math.sin(angle1) * endRadius)

			local startLength = (startB - startA).Magnitude
			local endLength = (endB - endA).Magnitude
			local piece = makeLine(
				parent,
				startA,
				startB,
				width or 0.12,
				color or COLOR.Crimson,
				initialTransparency == nil and 0.07 or initialTransparency,
				"ShockRingSegment"
			)

			if piece then
				table.insert(ringParts, piece)
				tween(piece, duration or 0.45, {
					CFrame = CFrame.lookAt((endA + endB) * 0.5, endB),
					Size = Vector3.new(width or 0.12, width or 0.12, endLength),
					Transparency = 1,
				}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
			end
		end

		return ringParts
	end

	local function drawLightningPath(parent, points, width, color, lifetime, transparency)
		local segments = {}

		for index = 1, #points - 1 do
			local t = (index - 1) / math.max(1, #points - 2)
			local segmentColor = color or COLOR.ElectricBlue
			local segmentWidth = math.max(0.025, (width or 0.22) * (1 - t * 0.55))
			local line = makeLine(
				parent,
				points[index],
				points[index + 1],
				segmentWidth,
				segmentColor,
				transparency == nil and 0.02 or transparency,
				"FractureLightning"
			)

			if line then
				table.insert(segments, line)
				tween(line, lifetime or 0.22, {
					Transparency = 1,
					Size = Vector3.new(segmentWidth * 0.08, segmentWidth * 0.08, (points[index + 1] - points[index]).Magnitude),
				}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			end
		end

		return segments
	end

	local function drawCurvedBeam(parent, startPosition, endPosition, colorA, colorB, width, curveAmount, lifetime)
		-- A real Beam provides the soft, camera-facing energy core. The jagged Part segments
		-- drawn alongside it supply the broken lightning silhouette shown in the reference clip.
		local anchor0 = makeAnchor(parent, startPosition, "EnergyBeamAnchor0")
		local anchor1 = makeAnchor(parent, endPosition, "EnergyBeamAnchor1")

		local attachment0 = Instance.new("Attachment")
		attachment0.Name = "EnergyBeamAttachment0"
		attachment0.Parent = anchor0

		local attachment1 = Instance.new("Attachment")
		attachment1.Name = "EnergyBeamAttachment1"
		attachment1.Parent = anchor1

		local beam = Instance.new("Beam")
		beam.Name = "SanguineEnergyBeam"
		beam.Attachment0 = attachment0
		beam.Attachment1 = attachment1
		beam.Color = ColorSequence.new(colorA or COLOR.ElectricBlue, colorB or colorA or COLOR.CoreWhite)
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.03),
			NumberSequenceKeypoint.new(0.72, 0.16),
			NumberSequenceKeypoint.new(1, 0.45),
		})
		beam.Width0 = width or 0.18
		beam.Width1 = math.max(0.015, (width or 0.18) * 0.08)
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.FaceCamera = true
		beam.Segments = 12
		beam.CurveSize0 = curveAmount or 1.2
		beam.CurveSize1 = -(curveAmount or 1.2)
		beam.Enabled = true
		beam.Parent = anchor0

		tween(beam, lifetime or 0.22, {
			Width0 = 0.01,
			Width1 = 0.005,
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		return beam
	end

	local function drawLightningBetween(parent, startPosition, endPosition, color, width, spread, steps, lifetime)
		steps = math.max(3, steps or 5)
		spread = spread or 2.4
		lifetime = lifetime or 0.22

		local delta = endPosition - startPosition
		local points = { startPosition }

		for index = 1, steps - 1 do
			local alpha = index / steps
			local ideal = startPosition + delta * alpha
			local jitter = Vector3.new(
				RANDOM:NextNumber(-spread, spread),
				RANDOM:NextNumber(-spread * 0.7, spread * 0.7),
				RANDOM:NextNumber(-spread, spread)
			)
			table.insert(points, ideal + jitter)
		end

		table.insert(points, endPosition)
		drawLightningPath(parent, points, width or 0.2, color or COLOR.ElectricBlue, lifetime, 0.025)
		drawCurvedBeam(parent, startPosition, endPosition, color or COLOR.ElectricBlue, COLOR.CoreWhite, (width or 0.2) * 0.82, RANDOM:NextNumber(-spread, spread), lifetime)

		return points
	end

	local function drawEnergyForks(parent, position, radius, count, colorA, colorB, verticalRange)
		count = scaleLightning(count or 6)
		verticalRange = verticalRange or 2.5

		for index = 1, count do
			local angle = RANDOM:NextNumber(0, math.pi * 2)
			local distance = radius * RANDOM:NextNumber(0.45, 1.0)
			local startPosition = position + Vector3.new(
				math.cos(angle) * radius * 0.08,
				RANDOM:NextNumber(0.2, verticalRange),
				math.sin(angle) * radius * 0.08
			)
			local endPosition = position + Vector3.new(
				math.cos(angle) * distance,
				RANDOM:NextNumber(-0.4, verticalRange * 0.5),
				math.sin(angle) * distance
			)
			local useColor = (index % 2 == 0) and (colorA or COLOR.Crimson) or (colorB or COLOR.ElectricBlue)

			drawLightningBetween(
				parent,
				startPosition,
				endPosition,
				useColor,
				RANDOM:NextNumber(0.07, 0.22),
				math.max(0.3, radius * 0.045),
				RANDOM:NextInteger(3, 5),
				RANDOM:NextNumber(0.18, 0.36)
			)

			if RANDOM:NextNumber() > 0.52 then
				local branchEnd = endPosition + Vector3.new(
					RANDOM:NextNumber(-radius * 0.18, radius * 0.18),
					RANDOM:NextNumber(-1, 2),
					RANDOM:NextNumber(-radius * 0.18, radius * 0.18)
				)
				drawLightningBetween(parent, endPosition, branchEnd, useColor, 0.075, radius * 0.025, 3, 0.2)
			end
		end
	end

	local function drawGroundCracks(parent, position, radius, color, count, secondColor)
		count = scaleGeometry(count or 10)
		radius = math.max(radius or 8, 1)

		for index = 1, count do
			local angle = RANDOM:NextNumber(0, math.pi * 2)
			local totalLength = radius * RANDOM:NextNumber(0.48, 1.08)
			local segmentCount = RANDOM:NextInteger(2, 5)
			local travel = 0
			local previous = position + Vector3.new(0, 0.09, 0)
			local side = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local perpendicular = Vector3.new(-side.Z, 0, side.X)

			for segment = 1, segmentCount do
				local fraction = 1 / segmentCount
				travel += totalLength * fraction * RANDOM:NextNumber(0.72, 1.18)
				local lateral = RANDOM:NextNumber(-radius * 0.11, radius * 0.11)
				local nextPosition = position
					+ side * math.min(travel, totalLength)
					+ perpendicular * lateral
					+ Vector3.new(0, 0.085 + RANDOM:NextNumber(0, 0.055), 0)

				local useColor = color or COLOR.Crimson
				if secondColor and index % 3 == 0 then
					useColor = secondColor
				elseif index % 5 == 0 then
					useColor = COLOR.CoreWhite
				end

				local width = (segment == 1) and 0.17 or 0.095
				local line = makeLine(parent, previous, nextPosition, width, useColor, 0.05, "GroundFracture")

				if line then
					tween(line, RANDOM:NextNumber(0.32, 0.78), {
						Transparency = 1,
						Size = Vector3.new(width * 0.1, width * 0.1, (nextPosition - previous).Magnitude),
					}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				end

				previous = nextPosition
			end
		end
	end

	local function spawnRockShards(parent, position, radius, count, style)
		if not CONFIG.EnableDebris then
			return
		end

		count = scaleDebris(count or 12)
		local materialPool = {
			Enum.Material.Slate,
			Enum.Material.Rock,
			Enum.Material.Basalt,
		}

		for index = 1, count do
			local angle = RANDOM:NextNumber(0, math.pi * 2)
			local distance = radius * RANDOM:NextNumber(0.35, 1.05)
			local startPosition = position + Vector3.new(
				math.cos(angle) * radius * 0.08,
				RANDOM:NextNumber(0.1, 0.7),
				math.sin(angle) * radius * 0.08
			)
			local endPosition = position + Vector3.new(
				math.cos(angle) * distance,
				RANDOM:NextNumber(0.3, radius * 0.24),
				math.sin(angle) * distance
			)
			local shardSize = Vector3.new(
				RANDOM:NextNumber(0.16, 0.72),
				RANDOM:NextNumber(0.16, 0.88),
				RANDOM:NextNumber(0.3, 1.15)
			)
			local shardColor = RANDOM:NextNumber() > 0.55 and COLOR.DarkAsh or COLOR.Ash
			local shard = makePart(
				parent,
				"ScorchedStoneShard",
				shardSize,
				CFrame.new(startPosition) * CFrame.Angles(
					RANDOM:NextNumber(-math.pi, math.pi),
					RANDOM:NextNumber(-math.pi, math.pi),
					RANDOM:NextNumber(-math.pi, math.pi)
				),
				shardColor,
				materialPool[RANDOM:NextInteger(1, #materialPool)],
				0.03,
				RANDOM:NextNumber() > 0.5 and Enum.PartType.Wedge or Enum.PartType.Block
			)

			local targetCF = CFrame.new(endPosition) * CFrame.Angles(
				RANDOM:NextNumber(-math.pi, math.pi),
				RANDOM:NextNumber(-math.pi, math.pi),
				RANDOM:NextNumber(-math.pi, math.pi)
			)

			tween(shard, RANDOM:NextNumber(0.32, 0.74), {
				CFrame = targetCF,
				Transparency = 1,
				Size = shardSize * 0.55,
			}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		end
	end

	local function getStyleColors(style)
		style = string.lower(tostring(style or "bloodflame"))

		if string.find(style, "gold") or string.find(style, "holy") then
			return COLOR.RuneGold, COLOR.CoreWhite
		elseif string.find(style, "parry") or string.find(style, "lightning") then
			return COLOR.ElectricBlue, COLOR.Crimson
		elseif string.find(style, "meteor") or string.find(style, "dive") or string.find(style, "blood") then
			return COLOR.BloodHot, COLOR.ElectricBlue
		elseif string.find(style, "death") then
			return COLOR.CoreWhite, COLOR.ElectricBlue
		elseif string.find(style, "phase") then
			return COLOR.Crimson, COLOR.ElectricBlue
		end

		return COLOR.Crimson, COLOR.RuneGold
	end

	local function worldPosition(rootOrPosition)
		if typeof(rootOrPosition) == "Vector3" then
			return rootOrPosition
		end

		if typeof(rootOrPosition) == "CFrame" then
			return rootOrPosition.Position
		end

		if typeof(rootOrPosition) == "Instance" and rootOrPosition:IsA("BasePart") then
			return rootOrPosition.Position
		end

		if typeof(rootOrPosition) == "Instance" and rootOrPosition:IsA("Model") then
			local root = rootOrPosition.PrimaryPart or rootOrPosition:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				return root.Position
			end
		end

		return Vector3.zero
	end

	--------------------------------------------------------------------------------
	-- INITIALIZATION, ATMOSPHERE, AND CAMERA RUMBLE
	--------------------------------------------------------------------------------

	local function ensurePostEffects()
		local camera = workspace.CurrentCamera
		if not camera or not CONFIG.EnablePostProcessing then
			return
		end

		colorGrade = camera:FindFirstChild("SanguineVFX_ColorGrade")
		if not colorGrade then
			colorGrade = Instance.new("ColorCorrectionEffect")
			colorGrade.Name = "SanguineVFX_ColorGrade"
			colorGrade.Parent = camera
		end

		colorGrade.Enabled = true
		colorGrade.TintColor = Color3.fromRGB(234, 229, 239)
		colorGrade.Saturation = -0.13
		colorGrade.Contrast = 0.13
		colorGrade.Brightness = -0.015

		bloomEffect = camera:FindFirstChild("SanguineVFX_Bloom")
		if not bloomEffect then
			bloomEffect = Instance.new("BloomEffect")
			bloomEffect.Name = "SanguineVFX_Bloom"
			bloomEffect.Parent = camera
		end

		bloomEffect.Enabled = true
		bloomEffect.Intensity = 0.52
		bloomEffect.Size = 22
		bloomEffect.Threshold = 1.08
		baseBloomIntensity = bloomEffect.Intensity

		blurEffect = camera:FindFirstChild("SanguineVFX_BurstBlur")
		if not blurEffect then
			blurEffect = Instance.new("BlurEffect")
			blurEffect.Name = "SanguineVFX_BurstBlur"
			blurEffect.Parent = camera
		end

		blurEffect.Enabled = true
		blurEffect.Size = 0
	end

	local function ensureOverlay()
		if not LOCAL_PLAYER then
			return
		end

		local playerGui = LOCAL_PLAYER:FindFirstChildOfClass("PlayerGui") or LOCAL_PLAYER:WaitForChild("PlayerGui")
		screenGui = playerGui:FindFirstChild("SanguineVFX_Overlay")

		if not screenGui then
			screenGui = Instance.new("ScreenGui")
			screenGui.Name = "SanguineVFX_Overlay"
			screenGui.ResetOnSpawn = false
			screenGui.IgnoreGuiInset = true
			screenGui.DisplayOrder = 9000
			screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			screenGui.Parent = playerGui
		end

		screenFlashFrame = screenGui:FindFirstChild("Flash")
		if not screenFlashFrame then
			screenFlashFrame = Instance.new("Frame")
			screenFlashFrame.Name = "Flash"
			screenFlashFrame.Size = UDim2.fromScale(1, 1)
			screenFlashFrame.Position = UDim2.fromScale(0, 0)
			screenFlashFrame.BackgroundColor3 = COLOR.CoreWhite
			screenFlashFrame.BackgroundTransparency = 1
			screenFlashFrame.BorderSizePixel = 0
			screenFlashFrame.Active = false
			screenFlashFrame.Selectable = false
			screenFlashFrame.ZIndex = 999
			screenFlashFrame.Parent = screenGui
		end
	end

	function VFX.Init(qualityName)
		if qualityName then
			VFX.SetQuality(qualityName)
		end

		getEffectFolder()
		ensureOverlay()
		ensurePostEffects()

		if initialized then
			return VFX
		end

		initialized = true

		RunService:BindToRenderStep(renderBindingName, Enum.RenderPriority.Camera.Value + 1, function(dt)
			if not CONFIG.EnableCameraShake or #activeShakes == 0 then
				return
			end

			local camera = workspace.CurrentCamera
			if not camera then
				return
			end

			local offset = Vector3.zero
			local rotation = Vector3.zero

			for index = #activeShakes, 1, -1 do
				local shake = activeShakes[index]
				shake.Elapsed += dt

				if shake.Elapsed >= shake.Duration then
					table.remove(activeShakes, index)
				else
					local progress = shake.Elapsed / shake.Duration
					local damp = (1 - progress) ^ 2.25
					local magnitude = shake.Intensity * damp
					local timeValue = shake.Elapsed * shake.Frequency
					local seed = shake.Seed

					offset += Vector3.new(
						math.noise(seed + 3, timeValue, 0) * magnitude * 0.16,
						math.noise(seed + 7, timeValue, 0) * magnitude * 0.13,
						math.noise(seed + 11, timeValue, 0) * magnitude * 0.075
					)

					rotation += Vector3.new(
						math.noise(seed + 17, timeValue, 0) * magnitude * 0.008,
						math.noise(seed + 23, timeValue, 0) * magnitude * 0.008,
						math.noise(seed + 31, timeValue, 0) * magnitude * 0.006
					)
				end
			end

			-- Roblox's normal camera update runs first. This adds this frame's offset once,
			-- rather than accumulating shake on top of the previous shaken CFrame.
			if offset.Magnitude > 0 or rotation.Magnitude > 0 then
				camera.CFrame = camera.CFrame
					* CFrame.new(offset)
					* CFrame.Angles(rotation.X, rotation.Y, rotation.Z)
			end
		end)

		if not cameraConnection then
			cameraConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
				task.defer(function()
					ensurePostEffects()
				end)
			end)
		end

		return VFX
	end

	function VFX.SetQuality(qualityName)
		if QUALITY[qualityName] then
			CONFIG.Quality = qualityName
		else
			warn("SanguineVFX: unknown quality preset '" .. tostring(qualityName) .. "'; using High.")
			CONFIG.Quality = "High"
		end
	end

	function VFX.SetupEnvironment()
		-- The old script deleted every Atmosphere/Sky/PostEffect in Lighting. This version
		-- preserves anything not owned by this module and only creates/updates named objects.
		Lighting.ClockTime = 18.05
		Lighting.Brightness = 2.15
		Lighting.GlobalShadows = true
		Lighting.ExposureCompensation = 0.05
		Lighting.OutdoorAmbient = Color3.fromRGB(70, 75, 87)
		Lighting.Ambient = Color3.fromRGB(56, 52, 65)
		Lighting.ColorShift_Top = Color3.fromRGB(154, 143, 167)
		Lighting.ColorShift_Bottom = Color3.fromRGB(47, 38, 57)

		local atmosphere = Lighting:FindFirstChild("SanguineVFX_Atmosphere")
		if not atmosphere then
			atmosphere = Instance.new("Atmosphere")
			atmosphere.Name = "SanguineVFX_Atmosphere"
			atmosphere.Parent = Lighting
		end

		atmosphere.Density = 0.26
		atmosphere.Offset = 0.08
		atmosphere.Color = Color3.fromRGB(133, 132, 151)
		atmosphere.Decay = Color3.fromRGB(50, 37, 55)
		atmosphere.Glare = 0.12
		atmosphere.Haze = 1.7

		VFX.Init()
	end

	function VFX.CameraShake(intensity, duration, frequency)
		if not initialized then
			VFX.Init()
		end

		if not CONFIG.EnableCameraShake then
			return
		end

		intensity = math.clamp(intensity or 1, 0, 8)
		duration = math.clamp(duration or 0.3, 0.04, 5)
		frequency = math.clamp(frequency or 32, 3, 100)

		table.insert(activeShakes, {
			Intensity = intensity,
			Duration = duration,
			Frequency = frequency,
			Elapsed = 0,
			Seed = RANDOM:NextNumber(0, 10000),
		})

		while #activeShakes > 12 do
			table.remove(activeShakes, 1)
		end
	end

	--------------------------------------------------------------------------------
	-- WEAPON MOTION: COMBO SLASHES AND DODGE AFTERIMAGES
	--------------------------------------------------------------------------------

	function VFX.Slash(rootPart, comboStep, isHeavy)
		if not rootPart or not rootPart:IsA("BasePart") then
			return nil
		end

		if not initialized then
			VFX.Init()
		end

		comboStep = tonumber(comboStep) or 1
		local isThird = comboStep == 3
		local mainColor
		local edgeColor

		if isHeavy then
			mainColor = COLOR.RuneGold
			edgeColor = COLOR.CoreWhite
		elseif comboStep == 2 then
			mainColor = COLOR.ElectricBlue
			edgeColor = COLOR.IceBlue
		elseif isThird then
			mainColor = COLOR.Crimson
			edgeColor = COLOR.CoreWhite
		else
			mainColor = COLOR.BloodHot
			edgeColor = COLOR.RuneGold
		end

		local group = newGroup(isHeavy and "HeavyWeaponCrescent" or "WeaponCrescent", isHeavy and 1.15 or 0.82)
		local forward = rootPart.CFrame.LookVector
		local right = rootPart.CFrame.RightVector
		local center = rootPart.Position + forward * (isHeavy and 3.4 or 2.65) + Vector3.new(0, 2.35, 0)
		local segmentCount = scaleGeometry(isHeavy and 18 or 12)
		local arcRadius = isHeavy and 8.7 or (isThird and 7.7 or 6.6)
		local sweepStart = comboStep == 2 and -145 or -35
		local sweepEnd = comboStep == 2 and 35 or 145

		-- The outside ribbon has some physical depth and uneven width so it reads as a
		-- curved blade wake rather than a flat rectangle.
		for layer = 1, (isHeavy and 3 or 2) do
			local points = {}
			local layerRadius = arcRadius + (layer - 1) * 0.32
			local layerDepth = (layer - 1) * 0.22

			for index = 0, segmentCount do
				local alpha = index / segmentCount
				local angle = math.rad(sweepStart + (sweepEnd - sweepStart) * alpha)
				local vertical = math.sin(angle) * (isHeavy and 4.2 or 3.1)
				local horizontal = math.cos(angle) * layerRadius
				local point = center
					+ right * horizontal
					+ Vector3.new(0, vertical, 0)
					+ forward * layerDepth
				table.insert(points, point)
			end

			for index = 1, #points - 1 do
				local segmentAlpha = index / (#points - 1)
				local taper = 1 - (math.abs(segmentAlpha - 0.5) * 1.15)
				local width = (isHeavy and 0.72 or 0.46) * math.max(0.18, taper)
				if layer > 1 then
					width *= 0.43
				end

				local useColor = layer == 2 and edgeColor or mainColor
				if layer == 3 then
					useColor = COLOR.ElectricBlue
				end

				local line = makeLine(group, points[index], points[index + 1], width, useColor, 0.025, "SwordArcRibbon")
				if line then
					tween(line, isHeavy and 0.43 or 0.31, {
						Transparency = 1,
						Size = Vector3.new(width * 0.06, width * 0.06, (points[index + 1] - points[index]).Magnitude),
					}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
				end
			end
		end

		local slashTip = center + right * (math.cos(math.rad(sweepEnd)) * arcRadius)
			+ Vector3.new(0, math.sin(math.rad(sweepEnd)) * (isHeavy and 4.2 or 3.1), 0)

		pulseSphere(group, slashTip, 0.35, isHeavy and 3.0 or 1.7, edgeColor, isHeavy and 0.32 or 0.21, 0.12, "SlashTipFlash")
		emitBurst(group, center, {
			Name = "SlashSparks",
			Count = isHeavy and 32 or 16,
			Color = ColorSequence.new(edgeColor, mainColor),
			Lifetime = NumberRange.new(0.16, 0.42),
			Speed = NumberRange.new(isHeavy and 14 or 9, isHeavy and 35 or 23),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, isHeavy and 0.52 or 0.32),
				NumberSequenceKeypoint.new(0.5, 0.18),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Acceleration = Vector3.new(0, -4, 0),
		})

		if isHeavy then
			drawRing(group, center, 1.3, 8.3, 0.2, COLOR.RuneGold, 0.38, 18, 0.1, 0.04)
			drawEnergyForks(group, center, 6.5, 5, COLOR.RuneGold, COLOR.ElectricBlue, 1.7)
			flashScreen(COLOR.RuneGold, 0.12, 0.14)
			punchBloom(0.75, 0.35)
			VFX.CameraShake(0.65, 0.2, 46)
		end

		return group
	end

	local function makeAfterimage(character, direction, tint, groupName)
		if not CONFIG.EnableAfterimages or not character or not character.Parent then
			return nil
		end

		local group = newGroup(groupName or "DodgeAfterimage", 0.62)
		local created = 0

		for _, sourcePart in ipairs(character:GetDescendants()) do
			if sourcePart:IsA("BasePart") and sourcePart.Transparency < 0.98 and sourcePart.Name ~= "HumanoidRootPart" then
				local ok, ghost = pcall(function()
					return sourcePart:Clone()
				end)

				if ok and ghost then
					for _, child in ipairs(ghost:GetDescendants()) do
						child:Destroy()
					end

					ghost.Name = "SpectralAfterimagePart"
					ghost.Anchored = true
					ghost.CanCollide = false
					ghost.CanTouch = false
					ghost.CanQuery = false
					ghost.CastShadow = false
					ghost.Massless = true
					ghost.Material = Enum.Material.ForceField
					ghost.Color = tint or COLOR.ElectricBlue
					ghost.Transparency = math.clamp(sourcePart.Transparency + 0.28, 0.25, 0.78)
					ghost.CFrame = sourcePart.CFrame
					ghost.Parent = group

					local drift = (direction or Vector3.zero) * (0.9 + (created % 3) * 0.18)
					tween(ghost, 0.32, {
						CFrame = sourcePart.CFrame + drift + Vector3.new(0, 0.12, 0),
						Transparency = 1,
					}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

					created += 1
				end
			end
		end

		if created == 0 then
			group:Destroy()
			return nil
		end

		return group
	end

	function VFX.AttachWeaponTrail(weaponPart, trailColor)
		if not weaponPart or not weaponPart:IsA("BasePart") then
			return function() end
		end

		local existing = weaponPart:FindFirstChild("SanguineVFX_WeaponTrail")
		if existing and existing:IsA("Trail") then
			existing.Enabled = true
			return function()
				if existing and existing.Parent then
					existing.Enabled = false
					existing:Clear()
					existing:Destroy()
				end
			end
		end

		local upperAttachment = Instance.new("Attachment")
		upperAttachment.Name = "SanguineVFX_TrailTop"
		upperAttachment.Position = Vector3.new(0, weaponPart.Size.Y * 0.48, 0)
		upperAttachment.Parent = weaponPart

		local lowerAttachment = Instance.new("Attachment")
		lowerAttachment.Name = "SanguineVFX_TrailBottom"
		lowerAttachment.Position = Vector3.new(0, -weaponPart.Size.Y * 0.48, 0)
		lowerAttachment.Parent = weaponPart

		local tint = trailColor or COLOR.Crimson
		local trail = Instance.new("Trail")
		trail.Name = "SanguineVFX_WeaponTrail"
		trail.Attachment0 = upperAttachment
		trail.Attachment1 = lowerAttachment
		trail.Color = ColorSequence.new(COLOR.CoreWhite, tint)
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.02),
			NumberSequenceKeypoint.new(0.35, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		})
		trail.WidthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.82),
			NumberSequenceKeypoint.new(0.24, 1),
			NumberSequenceKeypoint.new(1, 0),
		})
		trail.Lifetime = 0.22
		trail.MinLength = 0.04
		trail.MaxLength = 18
		trail.FaceCamera = true
		trail.LightEmission = 1
		trail.LightInfluence = 0
		trail.Enabled = true
		trail.Parent = weaponPart

		return function()
			if trail and trail.Parent then
				trail.Enabled = false
				trail:Clear()
				trail:Destroy()
			end
			safeDestroy(upperAttachment)
			safeDestroy(lowerAttachment)
		end
	end

	function VFX.Dodge(character, rootPart, moveDirection, duration)
		if not rootPart or not rootPart:IsA("BasePart") then
			return nil
		end

		if not initialized then
			VFX.Init()
		end

		duration = math.clamp(duration or 0.42, 0.18, 0.8)
		local direction = moveDirection or Vector3.zero
		direction = Vector3.new(direction.X, 0, direction.Z)

		if direction.Magnitude < 0.05 then
			direction = -rootPart.CFrame.LookVector
			direction = Vector3.new(direction.X, 0, direction.Z)
		end

		if direction.Magnitude > 0.05 then
			direction = direction.Unit
		else
			direction = Vector3.new(0, 0, -1)
		end

		if CONFIG.EnableAfterimages then
			makeAfterimage(character, direction, COLOR.IceBlue, "DodgeAfterimage_Blue")
			task.delay(duration * 0.22, function()
				makeAfterimage(character, direction, COLOR.CoreWhite, "DodgeAfterimage_White")
			end)
			task.delay(duration * 0.45, function()
				makeAfterimage(character, direction, COLOR.RuneGold, "DodgeAfterimage_Gold")
			end)
		end

		local group = newGroup("DodgeWindShear", 0.7)
		local position = rootPart.Position + Vector3.new(0, 0.9, 0)
		local opposite = position - direction * 3.5

		for index = 1, scaleGeometry(4) do
			local side = rootPart.CFrame.RightVector * RANDOM:NextNumber(-1.6, 1.6)
			local endPoint = opposite + side + Vector3.new(0, RANDOM:NextNumber(-0.5, 1.2), 0)
			local line = makeLine(group, position, endPoint, RANDOM:NextNumber(0.055, 0.13), index % 2 == 0 and COLOR.IceBlue or COLOR.CoreWhite, 0.08, "DodgeAirCut")
			if line then
				tween(line, 0.22, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			end
		end

		emitBurst(group, rootPart.Position, {
			Name = "DodgeDust",
			Count = 7,
			SmokeCount = 3,
			Color = ColorSequence.new(COLOR.IceBlue, COLOR.CoreWhite),
			Lifetime = NumberRange.new(0.2, 0.4),
			Speed = NumberRange.new(3, 9),
			SmokeColor = ColorSequence.new(COLOR.Smoke, COLOR.DarkAsh),
			SmokeLifetime = NumberRange.new(0.45, 0.75),
			SmokeSize = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.6),
				NumberSequenceKeypoint.new(1, 1.8),
			}),
		})

		if blurEffect then
			blurEffect.Size = 7
			tween(blurEffect, 0.22, { Size = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		end

		return group
	end

	--------------------------------------------------------------------------------
	-- TELEGRAPHS: HIGH-CONTRAST GROUND WARNING SIGILS
	--------------------------------------------------------------------------------

	function VFX.GroundTelegraph(position, radius, duration, style)
		if not initialized then
			VFX.Init()
		end

		radius = math.clamp(radius or 12, 2, 100)
		duration = math.clamp(duration or 1, 0.25, 3.5)
		local primary, secondary = getStyleColors(style or "Bloodflame")
		local ground = Vector3.new(position.X, position.Y + 0.06, position.Z)
		local group = newGroup("BossAttackTelegraph", duration + 0.45)

		-- Main circumference and two staggered rings create a readable danger radius.
		drawRing(group, ground, radius * 0.84, radius * 1.04, 0.18, primary, duration, 28, 0.08, 0.05)
		drawRing(group, ground, radius * 0.47, radius * 0.67, 0.11, secondary, duration * 0.92, 22, 0.12, 0.2)
		drawRing(group, ground, radius * 0.16, radius * 0.33, 0.075, COLOR.CoreWhite, duration * 0.84, 16, 0.16, 0.3)

		-- Eight radial runes, plus small cross marks, rather than a filled neon disc.
		local runeCount = scaleGeometry(8)
		for index = 1, runeCount do
			local angle = ((index - 1) / runeCount) * math.pi * 2
			local radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local tangent = Vector3.new(-radial.Z, 0, radial.X)
			local inner = ground + radial * radius * 0.68 + Vector3.new(0, 0.12, 0)
			local outer = ground + radial * radius * 0.94 + Vector3.new(0, 0.12, 0)
			local runeColor = index % 2 == 0 and secondary or primary
			local runeLine = makeLine(group, inner, outer, 0.1, runeColor, 0.08, "TelegraphRadialRune")

			if runeLine then
				tween(runeLine, duration * 0.86, {
					Transparency = 1,
				}, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
			end

			local tickCenter = ground + radial * radius * 0.72 + Vector3.new(0, 0.16, 0)
			local tickA = tickCenter - tangent * radius * 0.055
			local tickB = tickCenter + tangent * radius * 0.055
			local tick = makeLine(group, tickA, tickB, 0.085, COLOR.CoreWhite, 0.12, "TelegraphRuneTick")
			if tick then
				tween(tick, duration, { Transparency = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
			end
		end

		-- Small angular marks make the graphic feel ritualistic without using an image decal.
		local glyphCount = scaleGeometry(5)
		for index = 1, glyphCount do
			local angle = ((index - 1) / glyphCount) * math.pi * 2 + 0.22
			local radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local tangent = Vector3.new(-radial.Z, 0, radial.X)
			local center = ground + radial * radius * 0.51 + Vector3.new(0, 0.16, 0)
			local pointA = center + radial * radius * 0.06
			local pointB = center - radial * radius * 0.035 + tangent * radius * 0.04
			local pointC = center - radial * radius * 0.035 - tangent * radius * 0.04

			local a = makeLine(group, pointA, pointB, 0.09, secondary, 0.05, "TelegraphGlyph")
			local b = makeLine(group, pointB, pointC, 0.09, primary, 0.05, "TelegraphGlyph")
			local c = makeLine(group, pointC, pointA, 0.09, COLOR.CoreWhite, 0.05, "TelegraphGlyph")

			for _, glyphLine in ipairs({ a, b, c }) do
				if glyphLine then
					tween(glyphLine, duration * 0.9, { Transparency = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
				end
			end
		end

		emitBurst(group, ground + Vector3.new(0, 0.22, 0), {
			Name = "TelegraphSparks",
			Count = 12,
			Color = ColorSequence.new(primary, secondary),
			Lifetime = NumberRange.new(0.12, 0.28),
			Speed = NumberRange.new(1, 5),
			Acceleration = Vector3.new(0, 2, 0),
		})

		return group
	end

	--------------------------------------------------------------------------------
	-- IMPACT SYSTEM: SHOCK RINGS, STONE FRACTURES, SMOKE AND ENERGY SHEAR
	--------------------------------------------------------------------------------

	function VFX.Impact(position, radius, style)
		if not initialized then
			VFX.Init()
		end

		radius = math.clamp(radius or 14, 2, 110)
		style = style or "Bloodflame"
		local primary, secondary = getStyleColors(style)
		local ground = Vector3.new(position.X, position.Y + 0.04, position.Z)
		local smallImpact = string.find(string.lower(tostring(style)), "meteor") ~= nil
		local groupLifetime = smallImpact and 2.2 or 3.2
		local group = newGroup("SanguineImpact_" .. tostring(style), groupLifetime)

		-- The near-white inner flash provides contrast; darker layers carry the color.
		pulseSphere(group, ground + Vector3.new(0, 0.8, 0), 0.7, radius * 0.62, COLOR.CoreWhite, 0.22, 0.18, "ImpactWhiteCore")
		pulseSphere(group, ground + Vector3.new(0, 0.6, 0), 1.4, radius * 1.0, primary, 0.48, 0.56, "ImpactOuterBloom")
		pulseSphere(group, ground + Vector3.new(0, 0.3, 0), 0.35, radius * 0.4, secondary, 0.34, 0.45, "ImpactBlueCore")

		-- Offset rings with different speeds imply pressure waves traveling through the floor.
		if smallImpact then
			drawRing(group, ground, radius * 0.22, radius * 1.25, 0.16, primary, 0.43, 12, 0.11, 0.02)
			drawRing(group, ground, radius * 0.42, radius * 1.55, 0.085, secondary, 0.58, 10, 0.15, 0.12)
			drawGroundCracks(group, ground, radius * 0.95, primary, 4, secondary)
			spawnRockShards(group, ground, radius, 5, style)
			drawEnergyForks(group, ground + Vector3.new(0, 0.3, 0), radius * 0.9, 3, primary, secondary, 1.4)
			emitBurst(group, ground + Vector3.new(0, 0.2, 0), {
				Name = "MeteorImpact",
				Count = 18,
				SmokeCount = 5,
				Color = ColorSequence.new(COLOR.CoreWhite, primary),
				Lifetime = NumberRange.new(0.16, 0.6),
				Speed = NumberRange.new(10, 28),
				SmokeColor = ColorSequence.new(COLOR.Smoke, COLOR.DarkAsh),
				SmokeLifetime = NumberRange.new(0.45, 1.1),
				SmokeSize = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1.0),
					NumberSequenceKeypoint.new(0.45, 2.2),
					NumberSequenceKeypoint.new(1, 3.5),
				}),
			})
		else
			drawRing(group, ground, radius * 0.12, radius * 1.05, 0.22, COLOR.CoreWhite, 0.32, 24, 0.12, 0.04)
			drawRing(group, ground, radius * 0.28, radius * 1.42, 0.16, primary, 0.56, 26, 0.1, 0.04)
			drawRing(group, ground, radius * 0.47, radius * 1.85, 0.085, secondary, 0.78, 24, 0.16, 0.18)
			drawGroundCracks(group, ground, radius * 1.12, primary, radius > 30 and 22 or 14, secondary)
			spawnRockShards(group, ground, radius, radius > 30 and 23 or 15, style)
			drawEnergyForks(group, ground + Vector3.new(0, 0.25, 0), radius * 1.15, radius > 30 and 12 or 8, primary, secondary, radius * 0.12)
			emitBurst(group, ground + Vector3.new(0, 0.3, 0), {
				Name = "SanguineShockwave",
				Count = radius > 30 and 70 or 44,
				SmokeCount = radius > 30 and 20 or 12,
				Color = ColorSequence.new(COLOR.CoreWhite, primary),
				Lifetime = NumberRange.new(0.2, 0.82),
				Speed = NumberRange.new(8, radius > 30 and 42 or 30),
				Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.42),
					NumberSequenceKeypoint.new(0.35, 0.18),
					NumberSequenceKeypoint.new(1, 0),
				}),
				SmokeColor = ColorSequence.new(COLOR.Smoke, COLOR.DarkAsh),
				SmokeLifetime = NumberRange.new(0.7, 1.55),
				SmokeSpeed = NumberRange.new(2, 7),
				SmokeSize = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1.6),
					NumberSequenceKeypoint.new(0.45, 3.2),
					NumberSequenceKeypoint.new(1, 5.5),
				}),
			})
		end

		local isHeavy = radius >= 28 or string.find(string.lower(tostring(style)), "dive") ~= nil
		flashScreen(primary, isHeavy and 0.27 or 0.15, isHeavy and 0.2 or 0.14)
		punchBloom(isHeavy and 1.1 or 0.65, isHeavy and 0.5 or 0.34)
		VFX.CameraShake(isHeavy and 2.5 or 1.25, isHeavy and 0.85 or 0.42, isHeavy and 48 or 38)

		return group
	end

	function VFX.MeteorImpact(position, radius)
		return VFX.Impact(position, radius or 13, "MeteorBloodflame")
	end

	function VFX.MeteorFall(startPosition, endPosition, duration, impactRadius)
		if not initialized then
			VFX.Init()
		end

		duration = math.clamp(duration or 0.46, 0.15, 2)
		impactRadius = math.clamp(impactRadius or 13, 4, 30)

		local group = newGroup("FallingBloodflameMeteor", duration + 2.8)
		local initialSize = RANDOM:NextNumber(2.1, 3.6)
		local orb = makePart(
			group,
			"MeteorOuterShell",
			Vector3.new(initialSize, initialSize, initialSize),
			CFrame.new(startPosition),
			COLOR.BloodHot,
			Enum.Material.Neon,
			0.04,
			Enum.PartType.Ball
		)
		local core = makePart(
			group,
			"MeteorWhiteCore",
			Vector3.new(initialSize * 0.45, initialSize * 0.45, initialSize * 0.45),
			CFrame.new(startPosition),
			COLOR.CoreWhite,
			Enum.Material.Neon,
			0.02,
			Enum.PartType.Ball
		)

		local shellLight = Instance.new("PointLight")
		shellLight.Name = "MeteorLight"
		shellLight.Color = COLOR.BloodHot
		shellLight.Brightness = 2.4
		shellLight.Range = 18
		shellLight.Shadows = false
		shellLight.Parent = orb

		local trailAttachment = Instance.new("Attachment")
		trailAttachment.Name = "MeteorTrailAttachment"
		trailAttachment.Parent = orb

		local sparks = makeParticleEmitter(trailAttachment, {
			Name = "MeteorEmberTail",
			Texture = TEXTURE.Sparks,
			Enabled = true,
			Rate = 65 * getQualityConfig().Particles,
			Lifetime = NumberRange.new(0.16, 0.42),
			Speed = NumberRange.new(2, 9),
			SpreadAngle = Vector2.new(100, 100),
			Color = ColorSequence.new(COLOR.CoreWhite, COLOR.BloodHot),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.5),
				NumberSequenceKeypoint.new(0.4, 0.25),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.02),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Acceleration = Vector3.new(0, 8, 0),
			Drag = 1,
		})

		local smoke = makeParticleEmitter(trailAttachment, {
			Name = "MeteorSmokeTail",
			Texture = TEXTURE.Smoke,
			Enabled = true,
			Rate = 17 * getQualityConfig().Particles,
			Lifetime = NumberRange.new(0.34, 0.9),
			Speed = NumberRange.new(1, 4),
			SpreadAngle = Vector2.new(80, 80),
			Color = ColorSequence.new(COLOR.Smoke, COLOR.DarkAsh),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1.1),
				NumberSequenceKeypoint.new(0.45, 2.0),
				NumberSequenceKeypoint.new(1, 3.2),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Acceleration = Vector3.new(0, 2, 0),
			Drag = 3,
		})

		local destination = CFrame.new(endPosition)
		local fallTween = tween(orb, duration, { CFrame = destination }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(core, duration, { CFrame = destination }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

		if fallTween then
			fallTween.Completed:Connect(function(playbackState)
				if playbackState == Enum.PlaybackState.Completed then
					if group.Parent then
						VFX.MeteorImpact(endPosition, impactRadius)
						group:Destroy()
					end
				end
			end)
		else
			task.delay(duration, function()
				if group.Parent then
					VFX.MeteorImpact(endPosition, impactRadius)
					group:Destroy()
				end
			end)
		end

		return group
	end

	--------------------------------------------------------------------------------
	-- PARRY IMPACT: CRIMSON/COBALT CROSS-FRACTURE, INSPIRED BY THE REFERENCE VIDEO
	--------------------------------------------------------------------------------

	function VFX.Parry(position, direction)
		if not initialized then
			VFX.Init()
		end

		direction = direction or Vector3.new(0, 0, -1)
		direction = Vector3.new(direction.X, 0, direction.Z)
		if direction.Magnitude < 0.01 then
			direction = Vector3.new(0, 0, -1)
		end
		direction = direction.Unit

		local right = Vector3.new(-direction.Z, 0, direction.X)
		local center = position + Vector3.new(0, 1.9, 0)
		local group = newGroup("CrimsonCobaltParryClash", 1.35)

		pulseSphere(group, center, 0.25, 5.4, COLOR.CoreWhite, 0.18, 0.04, "ParryWhiteFlash")
		pulseSphere(group, center, 0.65, 8.5, COLOR.ElectricBlue, 0.3, 0.58, "ParryBlueHalo")
		drawRing(group, position, 0.7, 5.9, 0.17, COLOR.CoreWhite, 0.27, 18, 0.16, 0.04)
		drawRing(group, position, 1.3, 8.2, 0.12, COLOR.Crimson, 0.39, 20, 0.19, 0.1)

		-- Two crossed energy cuts plus broken branching edges create the split-colour impact.
		local slashA0 = center - right * 4.6 - direction * 0.3 + Vector3.new(0, -2.7, 0)
		local slashA1 = center + right * 4.6 + direction * 0.3 + Vector3.new(0, 2.7, 0)
		local slashB0 = center + right * 4.4 - direction * 0.2 + Vector3.new(0, 2.5, 0)
		local slashB1 = center - right * 4.4 + direction * 0.2 + Vector3.new(0, -2.5, 0)

		drawLightningBetween(group, slashA0, slashA1, COLOR.ElectricBlue, 0.3, 1.45, 6, 0.28)
		drawLightningBetween(group, slashB0, slashB1, COLOR.Crimson, 0.31, 1.6, 6, 0.29)

		local boltCount = scaleLightning(9)
		for index = 1, boltCount do
			local angle = (index / boltCount) * math.pi * 2
			local radial = Vector3.new(math.cos(angle), RANDOM:NextNumber(-0.6, 1.3), math.sin(angle))
			local endpoint = center + radial * RANDOM:NextNumber(3.4, 7.3)
			drawLightningBetween(group, center, endpoint, index % 2 == 0 and COLOR.Crimson or COLOR.ElectricBlue, 0.13, 1.0, 4, 0.24)
		end

		emitBurst(group, center, {
			Name = "ParryMetalSparks",
			Count = 42,
			Color = ColorSequence.new(COLOR.CoreWhite, COLOR.IceBlue),
			Lifetime = NumberRange.new(0.11, 0.36),
			Speed = NumberRange.new(12, 34),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.38),
				NumberSequenceKeypoint.new(0.24, 0.16),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Acceleration = Vector3.new(0, -8, 0),
		})

		flashScreen(COLOR.CoreWhite, 0.34, 0.13)
		punchBloom(1.0, 0.36)
		VFX.CameraShake(1.1, 0.3, 68)
		return group
	end

	function VFX.PerfectParry(position, direction)
		local group = VFX.Parry(position, direction)
		if not group then
			return nil
		end

		local center = position + Vector3.new(0, 1.9, 0)
		pulseSphere(group, center, 0.2, 11.0, COLOR.RuneGold, 0.26, 0.27, "PerfectParryGoldCore")
		drawRing(group, position, 0.6, 10.5, 0.19, COLOR.RuneGold, 0.28, 22, 0.22, 0.03)
		drawEnergyForks(group, center, 8.5, 10, COLOR.RuneGold, COLOR.ElectricBlue, 3)
		emitBurst(group, center, {
			Name = "PerfectParryAshAndGold",
			Count = 52,
			SmokeCount = 7,
			Color = ColorSequence.new(COLOR.RuneGold, COLOR.CoreWhite),
			Lifetime = NumberRange.new(0.14, 0.45),
			Speed = NumberRange.new(15, 39),
			SmokeLifetime = NumberRange.new(0.5, 0.95),
		})
		flashScreen(COLOR.RuneGold, 0.43, 0.18)
		punchBloom(1.45, 0.52)
		VFX.CameraShake(2.0, 0.48, 74)
		return group
	end

	function VFX.BossHit(position, isHeavy, isPerfectParry)
		local style = isPerfectParry and "PerfectParry" or (isHeavy and "HolyImpact" or "Bloodflame")
		local primary, secondary = getStyleColors(style)
		local center = position + Vector3.new(0, 0.8, 0)
		local group = newGroup("BossHitSpark", 0.88)

		pulseSphere(group, center, 0.16, isHeavy and 4.2 or 2.4, COLOR.CoreWhite, 0.18, 0.03, "BossHitWhiteFlash")
		drawRing(group, center, 0.45, isHeavy and 4.2 or 2.5, 0.11, primary, 0.24, 14, 0.05, 0.05)
		drawEnergyForks(group, center, isHeavy and 4.0 or 2.4, isHeavy and 7 or 4, primary, secondary, 1.3)
		emitBurst(group, center, {
			Name = "BossHitSparks",
			Count = isHeavy and 28 or 16,
			Color = ColorSequence.new(COLOR.CoreWhite, primary),
			Lifetime = NumberRange.new(0.1, 0.31),
			Speed = NumberRange.new(9, isHeavy and 32 or 22),
			Acceleration = Vector3.new(0, -7, 0),
		})

		if isHeavy or isPerfectParry then
			flashScreen(primary, isPerfectParry and 0.26 or 0.12, 0.11)
			VFX.CameraShake(isPerfectParry and 1.1 or 0.6, 0.2, 58)
		end

		return group
	end

	--------------------------------------------------------------------------------
	-- BOSS AURA, PHASE TRANSFORMATION AND DEATH FINISHER
	--------------------------------------------------------------------------------

	function VFX.AttachBossAura(rootPart, auraColor)
		if not rootPart or not rootPart:IsA("BasePart") then
			return function() end
		end

		if auraHandles[rootPart] and auraHandles[rootPart].Attachment and auraHandles[rootPart].Attachment.Parent then
			return auraHandles[rootPart].Cleanup
		end

		local auraColor = auraColor or COLOR.BloodHot
		local attachment = Instance.new("Attachment")
		attachment.Name = "SanguineVFX_BossAuraAttachment"
		attachment.Position = Vector3.new(0, 0.6, 0)
		attachment.Parent = rootPart

		local embers = makeParticleEmitter(attachment, {
			Name = "BossAuraEmbers",
			Texture = TEXTURE.Sparks,
			Enabled = true,
			Rate = 10 * getQualityConfig().Particles,
			Lifetime = NumberRange.new(0.45, 1.1),
			Speed = NumberRange.new(1.5, 5.2),
			SpreadAngle = Vector2.new(180, 180),
			Color = ColorSequence.new(auraColor, COLOR.ElectricBlue),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.42),
				NumberSequenceKeypoint.new(0.55, 0.19),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.14),
				NumberSequenceKeypoint.new(0.75, 0.38),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Acceleration = Vector3.new(0, 5, 0),
			Drag = 2.0,
		})

		local spectralSmoke = makeParticleEmitter(attachment, {
			Name = "BossAuraSmoke",
			Texture = TEXTURE.Smoke,
			Enabled = true,
			Rate = 2.5 * getQualityConfig().Particles,
			Lifetime = NumberRange.new(0.8, 1.7),
			Speed = NumberRange.new(0.6, 2.2),
			SpreadAngle = Vector2.new(180, 180),
			Color = ColorSequence.new(COLOR.DarkAsh, auraColor),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1.1),
				NumberSequenceKeypoint.new(0.7, 2.0),
				NumberSequenceKeypoint.new(1, 2.8),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.6),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Acceleration = Vector3.new(0, 1.4, 0),
			Drag = 2.7,
		})

		local auraLight = Instance.new("PointLight")
		auraLight.Name = "SanguineVFX_BossAuraLight"
		auraLight.Color = auraColor
		auraLight.Brightness = 1.1
		auraLight.Range = 18
		auraLight.Shadows = false
		auraLight.Parent = attachment

		local handles = {
			Attachment = attachment,
			Embers = embers,
			Smoke = spectralSmoke,
			Light = auraLight,
		}

		local function cleanup()
			safeDestroy(attachment)
			auraHandles[rootPart] = nil
		end

		handles.Cleanup = cleanup
		auraHandles[rootPart] = handles
		return cleanup
	end

	function VFX.PhaseTransition(rootOrPosition, bossModel)
		if not initialized then
			VFX.Init()
		end

		local position = worldPosition(rootOrPosition)
		local ground = Vector3.new(position.X, position.Y - 7, position.Z)
		local group = newGroup("SanguinePhaseAscension", 4.8)

		-- A vertical ignition silhouette, horizontal floor fractures, and two coloured arcs
		-- communicate a change of phase without covering the whole screen in opaque glow.
		pulseSphere(group, position, 2, 27, COLOR.CoreWhite, 0.65, 0.6, "PhaseWhiteExpansion")
		pulseSphere(group, position, 4, 39, COLOR.Crimson, 0.95, 0.78, "PhaseCrimsonVeil")
		drawRing(group, ground, 1.8, 32, 0.27, COLOR.CoreWhite, 0.7, 30, 0.16, 0.04)
		drawRing(group, ground, 4.2, 45, 0.17, COLOR.Crimson, 1.05, 30, 0.22, 0.08)
		drawRing(group, ground, 7.4, 52, 0.1, COLOR.ElectricBlue, 1.18, 28, 0.26, 0.15)
		drawGroundCracks(group, ground, 35, COLOR.Crimson, 28, COLOR.ElectricBlue)
		drawEnergyForks(group, position, 22, 16, COLOR.Crimson, COLOR.ElectricBlue, 14)

		local pillarCount = scaleGeometry(12)
		for index = 1, pillarCount do
			local angle = ((index - 1) / pillarCount) * math.pi * 2
			local radius = RANDOM:NextNumber(9, 24)
			local base = ground + Vector3.new(math.cos(angle) * radius, 0.3, math.sin(angle) * radius)
			local height = RANDOM:NextNumber(12, 28)
			local pillar = makePart(
				group,
				"PhaseEnergyPillar",
				Vector3.new(RANDOM:NextNumber(0.18, 0.38), height, RANDOM:NextNumber(0.18, 0.38)),
				CFrame.new(base + Vector3.new(0, height * 0.5, 0)),
				index % 2 == 0 and COLOR.Crimson or COLOR.ElectricBlue,
				Enum.Material.Neon,
				0.18,
				Enum.PartType.Block
			)
			tween(pillar, RANDOM:NextNumber(0.45, 0.85), {
				Transparency = 1,
				Size = Vector3.new(0.025, height * 1.25, 0.025),
			}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		end

		emitBurst(group, position, {
			Name = "PhaseAscensionEmbers",
			Count = 90,
			SmokeCount = 24,
			Color = ColorSequence.new(COLOR.CoreWhite, COLOR.Crimson),
			Lifetime = NumberRange.new(0.24, 0.85),
			Speed = NumberRange.new(8, 31),
			Acceleration = Vector3.new(0, 12, 0),
			SmokeColor = ColorSequence.new(COLOR.DarkAsh, COLOR.Blood),
			SmokeLifetime = NumberRange.new(0.75, 1.8),
		})

		if bossModel and bossModel:IsA("Model") then
			local highlight = bossModel:FindFirstChild("SanguineVFX_PhaseHighlight")
			if not highlight then
				highlight = Instance.new("Highlight")
				highlight.Name = "SanguineVFX_PhaseHighlight"
				highlight.Adornee = bossModel
				highlight.DepthMode = Enum.HighlightDepthMode.Occluded
				highlight.Parent = bossModel
			end

			highlight.FillColor = COLOR.Crimson
			highlight.OutlineColor = COLOR.ElectricBlue
			highlight.FillTransparency = 0.86
			highlight.OutlineTransparency = 0.12
			tween(highlight, 2.5, {
				FillTransparency = 1,
				OutlineTransparency = 1,
			}, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		end

		if typeof(rootOrPosition) == "Instance" and rootOrPosition:IsA("BasePart") then
			VFX.AttachBossAura(rootOrPosition, COLOR.Crimson)
		end

		flashScreen(COLOR.CoreWhite, 0.33, 0.2)
		punchBloom(1.4, 0.72)
		VFX.CameraShake(3.3, 1.4, 42)
		return group
	end

	function VFX.BossDeath(bossModel, position)
		if not initialized then
			VFX.Init()
		end

		position = position or worldPosition(bossModel)
		local group = newGroup("GreatEnemyFelled_VFX", 5.3)

		VFX.Impact(position, 31, "DeathAsh")
		drawEnergyForks(group, position + Vector3.new(0, 4, 0), 19, 15, COLOR.CoreWhite, COLOR.ElectricBlue, 10)
		drawRing(group, position, 4, 30, 0.14, COLOR.CoreWhite, 1.0, 30, 0.18, 0.03)
		drawRing(group, position, 7, 42, 0.09, COLOR.RuneGold, 1.35, 28, 0.24, 0.12)

		emitBurst(group, position, {
			Name = "BossDeathSoulFragments",
			Count = 100,
			SmokeCount = 32,
			Color = ColorSequence.new(COLOR.CoreWhite, COLOR.RuneGold),
			Lifetime = NumberRange.new(0.3, 1.05),
			Speed = NumberRange.new(6, 30),
			Acceleration = Vector3.new(0, 17, 0),
			SmokeColor = ColorSequence.new(COLOR.DarkAsh, COLOR.Smoke),
			SmokeLifetime = NumberRange.new(0.9, 2.0),
			SmokeSize = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1.4),
				NumberSequenceKeypoint.new(0.5, 3.5),
				NumberSequenceKeypoint.new(1, 5.4),
			}),
		})

		if bossModel and bossModel:IsA("Model") then
			for _, part in ipairs(bossModel:GetDescendants()) do
				if part:IsA("BasePart") and not part:GetAttribute("SanguineVFX_IgnoreDeathDissolve") then
					-- Fade is deliberately delayed so the player sees the boss's final silhouette.
					local originalTransparency = part.Transparency
					task.delay(2.15, function()
						if part and part.Parent then
							part.Material = Enum.Material.Neon
							part.Color = COLOR.CoreWhite
							part.Transparency = math.min(originalTransparency, 0.18)
							tween(part, 2.1, {
								Transparency = 1,
								Size = Vector3.new(0.02, 0.02, 0.02),
							}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
						end
					end)
				end
			end

			local highlight = bossModel:FindFirstChild("SanguineVFX_PhaseHighlight")
			if highlight and highlight:IsA("Highlight") then
				highlight.FillColor = COLOR.CoreWhite
				highlight.OutlineColor = COLOR.RuneGold
				highlight.FillTransparency = 0.2
				highlight.OutlineTransparency = 0.05
				tween(highlight, 2.3, {
					FillTransparency = 1,
					OutlineTransparency = 1,
				}, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
			end
		end

		flashScreen(COLOR.CoreWhite, 0.38, 0.25)
		punchBloom(1.5, 0.9)
		VFX.CameraShake(3.6, 2.0, 32)
		return group
	end

	--------------------------------------------------------------------------------
	-- LIFECYCLE
	--------------------------------------------------------------------------------

	function VFX.ClearAll()
		if fxFolder and fxFolder.Parent then
			fxFolder:ClearAllChildren()
		end
		table.clear(activeShakes)
	end

	function VFX.Cleanup()
		if initialized then
			pcall(function()
				RunService:UnbindFromRenderStep(renderBindingName)
			end)
		end

		if cameraConnection then
			cameraConnection:Disconnect()
			cameraConnection = nil
		end

		for rootPart, handle in pairs(auraHandles) do
			if handle and handle.Cleanup then
				handle.Cleanup()
			end
			auraHandles[rootPart] = nil
		end

		if fxFolder and fxFolder.Parent then
			fxFolder:Destroy()
		end
		fxFolder = nil

		safeDestroy(screenGui)
		screenGui = nil
		screenFlashFrame = nil

		if colorGrade and colorGrade.Parent then colorGrade:Destroy() end
		if bloomEffect and bloomEffect.Parent then bloomEffect:Destroy() end
		if blurEffect and blurEffect.Parent then blurEffect:Destroy() end
		colorGrade = nil
		bloomEffect = nil
		blurEffect = nil

		table.clear(activeShakes)
		initialized = false
	end

	return VFX