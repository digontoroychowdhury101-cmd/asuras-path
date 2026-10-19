--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/SanctuaryService
-- The Shrine of the Ascendant: a lantern-lit Wuxia courtyard above a misted karst valley.
-- Builds every piece procedurally under Workspace.Sanctuary from the WorldDefinitions layout:
--   * Central courtyard: laid flagstones, reflecting basins, incense altar and roofed cloisters.
--   * Ascension Gateway (north): a 20-step grand staircase to a two-tier paifang gatehouse whose portal
--     carries the player to the Monastery Gate.
--   * Blacksmith Loggia (west): pavilion, forge, anvil and Master Smith Gao (reinforce / refill).
--   * Colosseum Promenade (east): balustraded balcony with banners and braziers; the ring itself
--     is raised by ColosseumService on the same anchor.
--   * Sea of clouds and a horizon of ruined spires and castle silhouettes.
-- Start() must run before WorldService.Start(): the region's MapFolder (this folder) suppresses
-- the greybox, and the bonfire's AltarAnchor part receives the altar's rest prompt.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("AsurasPath")
local World = require(Shared.Shared.WorldDefinitions)
local Animations = require(Shared.Shared.AnimationCatalog)
local Characters = require(script.Parent:WaitForChild("CharacterService") :: ModuleScript)
local WorldService = require(script.Parent:WaitForChild("WorldService") :: ModuleScript)
local Dressing = require(script.Parent:WaitForChild("SanctuaryDressing") :: ModuleScript)
local Leaves = require(script.Parent:WaitForChild("SanctuaryLeaves") :: ModuleScript)

local SanctuaryService = {}

-------------------------------------------------------------------------------------------------
-- Layout
-------------------------------------------------------------------------------------------------

local LAYOUT = World.Sanctuary
local ORIGIN = Vector3.new(LAYOUT.Origin.X, LAYOUT.Origin.Y, LAYOUT.Origin.Z)
local R = LAYOUT.PlazaRadius
local LOGGIA = Vector3.new(LAYOUT.Loggia.X, LAYOUT.Loggia.Y, LAYOUT.Loggia.Z)
local PROMENADE = Vector3.new(LAYOUT.Promenade.X, LAYOUT.Promenade.Y, LAYOUT.Promenade.Z)
local BALCONY_APOTHEM = 32
local STAIR_START = R - 1
local LANDING_DEPTH = 22
local ARCH_OFFSET = 15 -- arch depth into the landing

local BONFIRE_ALTAR = World.startingAltar()
local DESTINATION = World.Altars[LAYOUT.PortalDestination]

local PORTAL_FADE = 0.5
local PORTAL_COOLDOWN = 4
local CATCH_DEPTH = 40
local CATCH_RADIUS = 1300
local POLL_INTERVAL = 0.5
local SMITH_RADIUS = 10

local TEXTURE_FIRE = "rbxasset://textures/particles/fire_main.dds"
local TEXTURE_SPARKS = "rbxasset://textures/particles/fire_sparks_main.dds"
local TEXTURE_SMOKE = "rbxasset://textures/particles/smoke_main.dds"

-- Palette
local FLAG_LIGHT = Color3.fromRGB(80, 87, 86)
local FLAG_DARK = Color3.fromRGB(61, 69, 70)
local STONE = Color3.fromRGB(95, 101, 96)
local STONE_DARK = Color3.fromRGB(41, 49, 51)
local ROCK = Color3.fromRGB(49, 60, 64)
local STATUE = Color3.fromRGB(82, 91, 88)
local SHADOW = Color3.fromRGB(26, 24, 24)
local WATER = Color3.fromRGB(30, 53, 57)
local BONFIRE_LIGHT = Color3.fromRGB(255, 185, 90)
local EMBER = Color3.fromRGB(255, 120, 40)
local PORTAL = Color3.fromRGB(111, 170, 164)
local IRON = Color3.fromRGB(34, 32, 34)
local BANNER_RED = Color3.fromRGB(83, 26, 28)
local BANNER_BLACK = Color3.fromRGB(20, 18, 20)
local ROOF = Color3.fromRGB(27, 37, 40)
local BRICK = Color3.fromRGB(63, 49, 43)
local WOOD = Color3.fromRGB(47, 38, 33)
local SILHOUETTE = Color3.fromRGB(62, 80, 88)

-------------------------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------------------------

local root: Folder? = nil
local spawnCFrame = CFrame.new()
local smithPosition = Vector3.zero
local connections: { RBXScriptConnection } = {}
local disconnectors: { () -> () } = {}
local transit: { [number]: number } = {}
local running = false
local accumulator = 0

-------------------------------------------------------------------------------------------------
-- Construction helpers
-------------------------------------------------------------------------------------------------

type PartOptions = {
	Collide: boolean?,
	Query: boolean?,
	Transparency: number?,
	Reflectance: number?,
	Shadow: boolean?,
	Shape: Enum.PartType?,
	Class: string?,
}

local function folder(name: string, parent: Instance): Folder
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = parent
	return created
end

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, options: PartOptions?): BasePart
	local o: PartOptions = options or {}
	local p = Instance.new((o.Class or "Part") :: any) :: BasePart
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	p.CanCollide = if o.Collide == nil then true else o.Collide
	p.CanQuery = if o.Query == nil then p.CanCollide else o.Query
	p.Transparency = o.Transparency or 0
	p.Reflectance = o.Reflectance or 0
	p.CastShadow = if o.Shadow == nil then true else o.Shadow
	if o.Shape and p:IsA("Part") then
		p.Shape = o.Shape
	end
	p.Parent = parent
	return p
end

-- Upright cylinder centred on `center` (Roblox cylinders run along local X).
local function disc(parent: Instance, name: string, radius: number, height: number, center: CFrame, color: Color3, material: Enum.Material, options: PartOptions?): BasePart
	local o: PartOptions = if options then table.clone(options) else {}
	o.Shape = Enum.PartType.Cylinder
	return part(parent, name, Vector3.new(height, radius * 2, radius * 2), center * CFrame.Angles(0, 0, math.rad(90)), color, material, o)
end

local function decor(): PartOptions
	return { Collide = false, Query = false, Shadow = false }
end

local function sequence(points: { { number } }): NumberSequence
	local keys = {}
	for _, point in points do
		table.insert(keys, NumberSequenceKeypoint.new(point[1], point[2]))
	end
	return NumberSequence.new(keys)
end

local function colors(a: Color3, b: Color3): ColorSequence
	return ColorSequence.new(a, b)
end

local function light(parent: BasePart, color: Color3, range: number, brightness: number, shadows: boolean)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = shadows
	l.Parent = parent
end

local function fire(parent: BasePart, size: number, heat: number, color: Color3, secondary: Color3)
	local f = Instance.new("Fire")
	f.Size = size
	f.Heat = heat
	f.Color = color
	f.SecondaryColor = secondary
	f.Parent = parent
end

local function embers(parent: BasePart, rate: number, spread: number, lift: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "Embers"
	e.Texture = TEXTURE_SPARKS
	e.Rate = rate
	e.Lifetime = NumberRange.new(2.5, 4.5)
	e.Speed = NumberRange.new(3, 7)
	e.SpreadAngle = Vector2.new(spread, spread)
	e.Acceleration = Vector3.new(0.6, lift, 0.4)
	e.Drag = 0.6
	e.Size = sequence({ { 0, 0.22 }, { 1, 0.05 } })
	e.Transparency = sequence({ { 0, 0 }, { 0.8, 0.3 }, { 1, 1 } })
	e.Color = colors(Color3.fromRGB(255, 200, 110), Color3.fromRGB(255, 80, 30))
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Parent = parent
	return e
end

local function polar(angle: number, radius: number, y: number): CFrame
	return CFrame.new(ORIGIN) * CFrame.Angles(0, angle, 0) * CFrame.new(0, y, -radius)
end

-------------------------------------------------------------------------------------------------
-- 1. Central Reflective Plaza
-------------------------------------------------------------------------------------------------

-- Architecture is built in layers at human scale: masonry, timber frame, tiled roof, then light.
local BRONZE = Color3.fromRGB(112, 91, 57)
local LANTERN = Color3.fromRGB(232, 180, 112)

local function beam(parent: Instance, name: string, a: Vector3, b: Vector3, thickness: number, color: Color3)
	return part(parent, name, Vector3.new(thickness, thickness, (b-a).Magnitude),
		CFrame.lookAt((a+b)*0.5, b), color, Enum.Material.Wood, decor())
end

local function roof(parent: Instance, base: CFrame, width: number, depth: number)
	local group = folder("TiledEaves", parent)
	local half = width * 0.5
	local function height(t: number): number
		return 4 * (1-t)^1.35 + 1.65 * t^8
	end
	for side = -1, 1, 2 do
		for strip = 0, 5 do
			local a, b = strip/6, (strip+1)/6
			local x0, x1 = side*half*a, side*half*b
			local y0, y1 = height(a), height(b)
			local length = math.sqrt((x1-x0)^2+(y1-y0)^2)
			local angle = math.atan((y1-y0)/(x1-x0))
			local shade = ROOF:Lerp(STONE_DARK, if strip%2==0 then 0.1 else 0.25)
			part(group, "TileCourse", Vector3.new(length+0.12,0.32,depth),
				base*CFrame.new((x0+x1)*0.5,(y0+y1)*0.5,0)*CFrame.Angles(0,0,angle), shade, Enum.Material.Slate, decor())
			-- Thin raised seams give the tiles a legible rhythm from the gameplay camera.
			for _, z in { -depth*0.5+0.1, depth*0.5-0.1 } do
				part(group, "TileRib", Vector3.new(length+0.1,0.1,0.12),
					base*CFrame.new((x0+x1)*0.5,(y0+y1)*0.5+0.19,z)*CFrame.Angles(0,0,angle), STONE_DARK, Enum.Material.Slate, decor())
			end
		end
		for face = -1, 1, 2 do
			beam(group,"EaveTip", (base*CFrame.new(side*(half-2),1.25,face*depth*0.5)).Position,
				(base*CFrame.new(side*(half+1.6),3.4,face*depth*0.5)).Position,0.38,IRON)
		end
	end
	part(group,"Ridge",Vector3.new(0.55,0.55,depth+2),base*CFrame.new(0,4.25,0),IRON,Enum.Material.Metal,decor())
	for side=-1,1,2 do
		beam(group,"RidgeHorn",(base*CFrame.new(0,4.25,side*depth*0.5)).Position,
			(base*CFrame.new(0,5.5,side*(depth*0.5+2))).Position,0.4,IRON)
	end
end

local function lantern(parent: Instance, base: CFrame, hanging: boolean?)
	local group=folder("StoneLantern",parent)
	if not hanging then
		part(group,"Foot",Vector3.new(2.6,0.35,2.6),base*CFrame.new(0,0.175,0),STONE_DARK,Enum.Material.Slate)
		part(group,"Stem",Vector3.new(0.8,2.4,0.8),base*CFrame.new(0,1.5,0),STONE,Enum.Material.Slate)
	end
	local y=if hanging then 0 else 3.2
	part(group,"Sill",Vector3.new(1.9,0.22,1.9),base*CFrame.new(0,y-0.7,0),IRON,Enum.Material.Metal,decor())
	local glow=part(group,"Paper",Vector3.new(1.25,1.4,1.25),base*CFrame.new(0,y,0),LANTERN,Enum.Material.Neon,decor())
	for x=-1,1,2 do
		for z=-1,1,2 do
			part(group,"Frame",Vector3.new(0.12,1.65,0.12),base*CFrame.new(x*0.72,y,z*0.72),WOOD,Enum.Material.Wood,decor())
		end
	end
	part(group,"Cap",Vector3.new(2.2,0.35,2.2),base*CFrame.new(0,y+0.95,0),STONE_DARK,Enum.Material.Slate,decor())
	part(group,"Finial",Vector3.new(0.45,0.45,0.45),base*CFrame.new(0,y+1.3,0),BRONZE,Enum.Material.Metal,decor())
	light(glow,LANTERN,17,1.1,false)
end

local function inscription(parent: BasePart, text: string, face: Enum.NormalId?)
	local gui=Instance.new("SurfaceGui")
	gui.Face=face or Enum.NormalId.Front
	gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud=40
	local label=Instance.new("TextLabel")
	label.Size=UDim2.fromScale(1,1)
	label.BackgroundTransparency=1
	label.Text=text
	label.TextColor3=Color3.fromRGB(158,145,112)
	label.TextSize=56
	label.Font=Enum.Font.Antique
	label.Parent=gui
	gui.Parent=parent
end

local function buildPlaza(parent: Folder): BasePart
	local plaza=folder("CentralPlaza",parent)
	local center=CFrame.new(ORIGIN)
	local rng=Random.new(751)
	disc(plaza,"Foundation",R+2,5,center*CFrame.new(0,-2.5,0),STONE_DARK,Enum.Material.Slate)
	-- Squared foundation buttresses anchor the terrace to the mountain instead of stacked discs.
	for k=0,7 do
		local base=polar(math.rad(k*45),R-2,-8)
		part(plaza,"FoundationButtress",Vector3.new(8,16,11),base,ROCK,Enum.Material.Rock)
	end
	disc(plaza,"CliffFoot",R-2,30,center*CFrame.new(0,-20,0),ROCK,Enum.Material.Rock)
	-- Individually laid flagstones, with an axial route and two recessed reflecting basins.
	for x=-6,6 do
		for z=-6,6 do
			local px,pz=x*6.5,z*6.5
			local pool=math.abs(px)>10 and math.abs(px)<23 and math.abs(pz)<18
			if px*px+pz*pz<(R-1)^2 and not pool then
				local shade=FLAG_DARK:Lerp(FLAG_LIGHT,rng:NextNumber(0,0.7))
				if x==0 then shade=Color3.fromRGB(94,99,94) end
				part(plaza,"Flagstone",Vector3.new(6.36,0.22,6.36),center*CFrame.new(px,0.02+rng:NextNumber(-0.015,0.015),pz),shade,Enum.Material.Slate)
			end
		end
	end
	for side=-1,1,2 do
		local pool=center*CFrame.new(side*16.25,0,0)
		part(plaza,"Basin",Vector3.new(12.9,0.1,32.4),pool*CFrame.new(0,0.02,0),SHADOW,Enum.Material.Slate)
		part(plaza,"StillWater",Vector3.new(12.5,0.05,32),pool*CFrame.new(0,0.09,0),WATER,Enum.Material.Glass,
			{Collide=false,Query=false,Shadow=false,Transparency=0.28,Reflectance=0.38})
		for edge=-1,1,2 do
			part(plaza,"BasinCoping",Vector3.new(0.45,0.3,33),pool*CFrame.new(edge*6.5,0.16,0),STONE_DARK,Enum.Material.Slate)
			part(plaza,"BasinCoping",Vector3.new(13.4,0.3,0.5),pool*CFrame.new(0,0.16,edge*16.5),STONE_DARK,Enum.Material.Slate)
		end
		for z=-36,36,12 do
			part(plaza,"InlaidPathEdge",Vector3.new(0.1,0.04,7.5),center*CFrame.new(side*4,0.15,z),BRONZE,Enum.Material.Metal,decor())
		end
	end
	-- Crimson leaves tumble across the wet plaza stones and settle on the reflecting basins
	local petalAnchor = part(plaza, "PetalAnchor", Vector3.new(R * 1.6, 1, R * 1.6), center * CFrame.new(0, 32, 0), STONE, Enum.Material.SmoothPlastic,
		{ Collide = false, Query = false, Shadow = false, Transparency = 1 })
	Leaves.Emitter(petalAnchor, { Rate = 12, Size = 0.5, Wind = Vector3.new(1.5, -1.0, 0.8) })
	for side = -1, 1, 2 do
		Leaves.Scatter(plaza, center * CFrame.new(side * 16.25, 0.13, 0), Vector2.new(5.8, 15), 60, 90 + side, true)
	end
	-- A low bronze incense altar: the player, rather than a bonfire particle, supplies the scale.
	disc(plaza,"AltarStep",4.6,0.4,center*CFrame.new(0,0.32,0),STONE,Enum.Material.Slate)
	disc(plaza,"AltarDais",3.4,0.7,center*CFrame.new(0,0.85,0),STONE_DARK,Enum.Material.Slate)
	disc(plaza,"BronzeLip",2,0.18,center*CFrame.new(0,1.4,0),BRONZE,Enum.Material.Metal)
	disc(plaza,"AshBowl",1.8,0.5,center*CFrame.new(0,1.55,0),IRON,Enum.Material.Metal)
	local anchor=part(plaza,"AltarAnchor_"..BONFIRE_ALTAR.Id,Vector3.new(1,0.2,1),center*CFrame.new(0,LAYOUT.PlinthHeight,0),STONE,Enum.Material.Slate,
		{Collide=false,Query=false,Transparency=1,Shadow=false})
	local coals=disc(plaza,"BankedEmbers",1.35,0.1,center*CFrame.new(0,1.84,0),Color3.fromRGB(139,59,28),Enum.Material.Neon,decor())
	for k=0,8 do
		local a=math.rad(k*40)
		part(plaza,"Incense",Vector3.new(0.035,1.2,0.035),center*CFrame.new(math.cos(a)*0.75,2.3,math.sin(a)*0.75)*CFrame.Angles(math.rad(9),0,math.rad(9)),WOOD,Enum.Material.Wood,decor())
	end
	local flame=Instance.new("ParticleEmitter")
	flame.Name="RitualFlame"
	flame.Texture=TEXTURE_FIRE
	flame.Rate=9
	flame.Lifetime=NumberRange.new(0.5,0.85)
	flame.Speed=NumberRange.new(0.7,1.8)
	flame.SpreadAngle=Vector2.new(8,8)
	flame.Size=sequence({{0,0.65},{0.5,0.8},{1,0}})
	flame.Transparency=sequence({{0,0.35},{0.7,0.55},{1,1}})
	flame.Color=colors(LANTERN,Color3.fromRGB(174,67,31))
	flame.LightEmission=0.6
	flame.Parent=coals
	embers(coals,3,15,0.4)
	light(coals,LANTERN,23,1.65,true)
	local smoke=Instance.new("ParticleEmitter")
	smoke.Texture=TEXTURE_SMOKE
	smoke.Rate=2
	smoke.Lifetime=NumberRange.new(4,7)
	smoke.Speed=NumberRange.new(0.5,0.9)
	smoke.Acceleration=Vector3.new(0.15,0.15,0)
	smoke.Size=sequence({{0,0.3},{1,2.5}})
	smoke.Transparency=sequence({{0,0.95},{0.25,0.82},{1,1}})
	smoke.Color=colors(Color3.fromRGB(145,150,145),Color3.fromRGB(95,110,116))
	smoke.Parent=coals
	-- Covered corner cloisters frame the camera with timber, stone and repeated roof profiles.
	for _,position in {{-29,-28},{29,-28},{-29,28},{29,28}} do
		local bay=folder("CornerCloister",plaza)
		local base=center*CFrame.new(position[1],0,position[2])
		part(bay,"RaisedSill",Vector3.new(21,0.4,9),base*CFrame.new(0,0.3,0),STONE_DARK,Enum.Material.Slate)
		for x=-1,1,2 do
			for z=-1,1,2 do
				part(bay,"ColumnFoot",Vector3.new(2.3,0.7,2.3),base*CFrame.new(x*8,0.8,z*2.8),STONE,Enum.Material.Slate)
				part(bay,"LacquerColumn",Vector3.new(1.1,10,1.1),base*CFrame.new(x*8,6.1,z*2.8),BANNER_RED,Enum.Material.Wood)
				part(bay,"ColumnCapital",Vector3.new(2.2,0.45,2.2),base*CFrame.new(x*8,11.2,z*2.8),WOOD,Enum.Material.Wood)
			end
		end
		for z=-1,1,2 do
			part(bay,"Crossbeam",Vector3.new(22,1,1.1),base*CFrame.new(0,11.7,z*3),WOOD,Enum.Material.Wood)
		end
		roof(bay,base*CFrame.new(0,11.5,0),25,12)
		lantern(bay,base*CFrame.new(0,8.5,0),true)
		-- Slatted back screens give a dark background to the warm lantern, without closing paths.
		local back=if position[2]>0 then 3.6 else -3.6
		part(bay,"ScreenSill",Vector3.new(17,1.6,0.3),base*CFrame.new(0,1.5,back),STONE_DARK,Enum.Material.Slate)
		for x=-7,7,1.4 do
			part(bay,"Lattice",Vector3.new(0.13,6,0.16),base*CFrame.new(x,5.3,back),WOOD,Enum.Material.Wood,decor())
		end
		part(bay,"ScreenRail",Vector3.new(17,0.18,0.3),base*CFrame.new(0,7.6,back),WOOD,Enum.Material.Wood,decor())
	end
	-- Low perimeter walls leave the four routes open and stop accidental walks into the clouds.
	for k=0,31 do
		local angle=(k+0.5)*math.pi*2/32
		local axial=math.min(k%8,7-k%8)<1
		if not axial then
			local base=polar(angle,R-1,0)
			part(plaza,"Parapet",Vector3.new(8.9,2.4,1.3),base*CFrame.new(0,1.2,0),STONE_DARK,Enum.Material.Slate)
			part(plaza,"ParapetCap",Vector3.new(9,0.25,1.8),base*CFrame.new(0,2.55,0),STONE,Enum.Material.Slate)
		end
	end
	for _,location in {{-7,17},{7,17},{-7,-21},{7,-21}} do
		lantern(plaza,center*CFrame.new(location[1],0.15,location[2]))
	end
	for _,angle in {45,135,225,315} do
		local base=polar(math.rad(angle),37,0)*CFrame.Angles(0,math.pi,0)
		part(plaza,"MemorialFoot",Vector3.new(3.8,0.5,3),base*CFrame.new(0,0.25,0),STONE_DARK,Enum.Material.Slate)
		part(plaza,"MemorialStele",Vector3.new(2.6,6.8,0.9),base*CFrame.new(0,3.9,0),STONE,Enum.Material.Slate)
		local plaque=part(plaza,"ErodedInscription",Vector3.new(1.8,4.7,0.08),base*CFrame.new(0,4,-0.5),STONE_DARK,Enum.Material.Slate,decor())
		inscription(plaque,"REMEMBER\nDEATH")
		part(plaza,"MemorialCap",Vector3.new(3.4,0.5,1.7),base*CFrame.new(0,7.4,0),STONE_DARK,Enum.Material.Slate)
	end
	return anchor
end

-------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------
-- 2. Ascension Gateway (north, -Z)
-------------------------------------------------------------------------------------------------

local function buildGateway(parent: Folder): BasePart
	local gate=folder("AscensionGateway",parent)
	local center=CFrame.new(ORIGIN)
	local steps,rise,run,width=LAYOUT.StairSteps,LAYOUT.StairRise,LAYOUT.StairRun,LAYOUT.StairWidth
	-- A paved approach joins the courtyard to the staircase.
	part(gate,"Approach",Vector3.new(width+4,0.3,20),center*CFrame.new(0,0.02,-38),FLAG_DARK,Enum.Material.Slate)
	for i=1,steps do
		local height=i*rise+6
		local z=-(STAIR_START+(i-0.5)*run)
		part(gate,"Step"..i,Vector3.new(width,height,run+0.03),center*CFrame.new(0,i*rise-height*0.5,z),FLAG_DARK:Lerp(FLAG_LIGHT,(i%3)*0.2),Enum.Material.Slate)
		part(gate,"TreadNosing",Vector3.new(width,0.12,0.22),center*CFrame.new(0,i*rise+0.03,z+run*0.5-0.1),STONE,Enum.Material.Slate,decor())
		for side=-1,1,2 do
			part(gate,"StairCheek",Vector3.new(1.4,height+2.2,run+0.03),center*CFrame.new(side*(width*0.5+0.7),i*rise-height*0.5+1.1,z),STONE_DARK,Enum.Material.Slate)
		end
		if i==4 or i==12 or i==19 then
			for side=-1,1,2 do lantern(gate,center*CFrame.new(side*(width*0.5+0.7),i*rise+2.2,z)) end
		end
	end
	for _,i in {2,5,9,14} do -- leaves blown onto a few treads
		Leaves.Scatter(gate,center*CFrame.new(0,i*rise,-(STAIR_START+(i-0.5)*run)),Vector2.new(width*0.42,run*0.4),12,i)
	end
	local top=steps*rise
	local landingStart=STAIR_START+steps*run
	part(gate,"Landing",Vector3.new(42,10,LANDING_DEPTH+3),center*CFrame.new(0,top-5,-landingStart-LANDING_DEPTH*0.5),STONE_DARK,Enum.Material.Slate)
	local floor=center*CFrame.new(0,top,-landingStart-ARCH_OFFSET)
	-- Paifang gatehouse: stone jambs, oxblood timber and two tiers of curved tile eaves.
	for side=-1,1,2 do
		for row=0,3 do
			part(gate,"MasonryJamb",Vector3.new(3.2,3.1,4.4),floor*CFrame.new(side*8.6,1.55+row*3.1,0),if row%2==0 then STONE else FLAG_DARK,Enum.Material.Slate)
		end
		part(gate,"JambFoot",Vector3.new(4.4,0.6,5.4),floor*CFrame.new(side*8.6,0.3,0),STONE,Enum.Material.Slate)
		part(gate,"TimberColumn",Vector3.new(1.4,10,1.4),floor*CFrame.new(side*14,5,0),BANNER_RED,Enum.Material.Wood)
		part(gate,"SideScreen",Vector3.new(4.5,7,0.6),floor*CFrame.new(side*12,5,0.3),WOOD,Enum.Material.Wood)
		for y=3,8,1.2 do part(gate,"ScreenLouvre",Vector3.new(3.5,0.13,0.3),floor*CFrame.new(side*12,y,-0.12),BRONZE,Enum.Material.Wood,decor()) end
		lantern(gate,floor*CFrame.new(side*6.6,9.2,2.9),true)
	end
	part(gate,"Lintel",Vector3.new(32,1.4,4.8),floor*CFrame.new(0,12.9,0),WOOD,Enum.Material.Wood)
	part(gate,"LintelInset",Vector3.new(12.8,0.18,0.18),floor*CFrame.new(0,12.2,2.5),BRONZE,Enum.Material.Metal,decor())
	roof(gate,floor*CFrame.new(0,13.3,0),39,13)
	part(gate,"UpperStorey",Vector3.new(15,4.5,5),floor*CFrame.new(0,18,0),WOOD,Enum.Material.Wood)
	local plaque=part(gate,"GateTablet",Vector3.new(8,2.6,0.22),floor*CFrame.new(0,18.2,2.65),SHADOW,Enum.Material.Wood,decor())
	inscription(plaque,"PATH OF THE ASURA",Enum.NormalId.Back)
	roof(gate,floor*CFrame.new(0,20.2,0),23,9)
	-- Restrained jade mist, dark enough to read the gate's frame and the destination beyond it.
	local veilSize=Vector3.new(13,11.4,0.2)
	local cf=floor*CFrame.new(0,5.8,0)
	local veil=part(gate,"PortalVeil",veilSize,cf,Color3.fromRGB(36,65,66),Enum.Material.Glass,
		{Collide=false,Query=false,Transparency=0.2,Reflectance=0.1,Shadow=false})
	for side=-1,1,2 do
		part(gate,"PortalSeam",Vector3.new(0.06,11.3,0.1),cf*CFrame.new(side*6.4,0,0.15),PORTAL,Enum.Material.Neon,decor())
	end
	light(veil,PORTAL,16,0.8,false)
	local mist=Instance.new("ParticleEmitter")
	mist.Texture=TEXTURE_SMOKE
	mist.Rate=4
	mist.Lifetime=NumberRange.new(3,4)
	mist.Speed=NumberRange.new(0.2,0.6)
	mist.SpreadAngle=Vector2.new(30,15)
	mist.Size=sequence({{0,2},{1,6}})
	mist.Transparency=sequence({{0,1},{0.3,0.85},{1,1}})
	mist.Color=colors(PORTAL,Color3.fromRGB(72,103,112))
	mist.LightEmission=0.15
	mist.Parent=veil
	local trigger=part(gate,"PortalTrigger",Vector3.new(13,11.4,2.4),cf,PORTAL,Enum.Material.SmoothPlastic,
		{Collide=false,Query=false,Transparency=1,Shadow=false})
	trigger.CanTouch=true
	Dressing.try("PortalGates", Dressing.PortalGates, gate, cf, 13)
	return trigger
end

-------------------------------------------------------------------------------------------------
-- 3. Blacksmith Loggia
-------------------------------------------------------------------------------------------------

local function buildSmithFigure(parent: Instance, base: CFrame)
	-- Stone-coloured stand-in used only if the avatar rig cannot be created.
	local model = Instance.new("Model")
	model.Name = "MasterSmithGao"
	part(model, "Legs", Vector3.new(2, 2.4, 1), base * CFrame.new(0, 1.2, 0), Color3.fromRGB(40, 34, 30), Enum.Material.Fabric)
	part(model, "Torso", Vector3.new(2.2, 2.4, 1.2), base * CFrame.new(0, 3.6, 0), Color3.fromRGB(70, 48, 36), Enum.Material.Leather)
	part(model, "Head", Vector3.new(1.3, 1.3, 1.3), base * CFrame.new(0, 5.5, 0), Color3.fromRGB(176, 128, 96), Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Ball })
	model.Parent = parent
end

local function spawnSmith(parent: Instance, base: CFrame)
	task.spawn(function()
		local description = Instance.new("HumanoidDescription")
		local skin = Color3.fromRGB(176, 128, 96)
		description.HeadColor = skin
		description.LeftArmColor = skin
		description.RightArmColor = skin
		description.TorsoColor = Color3.fromRGB(70, 48, 36)
		description.LeftLegColor = Color3.fromRGB(40, 34, 30)
		description.RightLegColor = Color3.fromRGB(40, 34, 30)
		local ok, model = pcall(function()
			return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
		end)
		if not running or not parent.Parent then
			if ok and model then
				model:Destroy()
			end
			return
		end
		if not ok or not model then
			warn("[Sanctuary] Blacksmith rig unavailable, using the stone figure: " .. tostring(model))
			buildSmithFigure(parent, base)
			return
		end
		model.Name = "MasterSmithGao"
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local rootPart = model:FindFirstChild("HumanoidRootPart")
		if humanoid then
			humanoid.DisplayName = "Master Smith Gao"
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
			humanoid.NameDisplayDistance = 40
			humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		end
		if rootPart and rootPart:IsA("BasePart") then
			rootPart.Anchored = true
		end
		local animate = model:FindFirstChild("Animate")
		if animate then
			animate:Destroy()
		end
		model:PivotTo(base * CFrame.new(0, 3, 0))
		model.Parent = parent
		-- Idle from the catalog keeps the smith out of a bind pose until a custom idle is set.
		if humanoid then
			local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
			animator.Parent = humanoid
			local idle = Animations.weapon("Unarmed", "Idle")
			local animation = Instance.new("Animation")
			animation.AnimationId = Animations.resolve(idle, "R15")
			local loaded, track = pcall(function()
				return (animator :: Animator):LoadAnimation(animation)
			end)
			if loaded and track then
				track.Looped = true
				track.Priority = Enum.AnimationPriority.Idle
				track:Play(0.2, 1, Animations.speed(idle))
			end
		end
	end)
end

local function buildLoggia(parent: Folder): (ProximityPrompt, ProximityPrompt)
	local loggia = folder("BlacksmithLoggia", parent)
	local base = CFrame.new(LOGGIA)
	local center = CFrame.new(ORIGIN)

	-- Walkway from the plaza's west edge.
	local walkStart, walkEnd = R - 2, (ORIGIN.X - LOGGIA.X) - 17
	local walkLength = walkEnd - walkStart
	local walk = center * CFrame.new(-(walkStart + walkLength * 0.5), 0, 0)
	part(loggia, "Walkway", Vector3.new(walkLength, 3, 12), walk * CFrame.new(0, -1.5, 0), FLAG_DARK, Enum.Material.Slate)
	part(loggia, "WalkwaySupport", Vector3.new(walkLength - 4, 10, 8), walk * CFrame.new(0, -8, 0), ROCK, Enum.Material.Rock, { Shadow = false })
	for side = -1, 1, 2 do
		part(loggia, "WalkRail" .. side, Vector3.new(walkLength, 1.4, 0.8), walk * CFrame.new(0, 0.7, side * 6.4), STONE_DARK, Enum.Material.Slate)
	end

	-- Platform and pavilion.
	part(loggia, "Platform", Vector3.new(36, 6, 36), base * CFrame.new(0, -3, 0), FLAG_LIGHT, Enum.Material.Slate)
	disc(loggia, "PlatformRoot", 16, 30, base * CFrame.new(0, -21, 0), ROCK, Enum.Material.Rock, { Shadow = false })
	local pierHeight = 15
	for _, corner in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		part(loggia, "Pier", Vector3.new(2.6, pierHeight, 2.6), base * CFrame.new(corner[1] * 15, pierHeight * 0.5, corner[2] * 15), STONE, Enum.Material.Slate)
	end
	for index, lintel in { { 0, 15, 32.6, 2.6 }, { 0, -15, 32.6, 2.6 }, { 15, 0, 2.6, 32.6 }, { -15, 0, 2.6, 32.6 } } do
		part(loggia, "Lintel" .. index, Vector3.new(lintel[3], 2.4, lintel[4]), base * CFrame.new(lintel[1], pierHeight + 1.2, lintel[2]), STONE, Enum.Material.Slate)
	end
	-- Arch braces suggest pointed openings on the three open faces.
	for _, face in { { 15, 0 }, { 0, 15 }, { 0, -15 } } do
		for side = -1, 1, 2 do
			local along = if face[1] ~= 0 then CFrame.new(face[1], pierHeight - 2.2, side * 11.5) else CFrame.new(side * 11.5, pierHeight - 2.2, face[2])
			local tilt = if face[1] ~= 0 then CFrame.Angles(side * math.rad(38), 0, 0) else CFrame.Angles(0, 0, -side * math.rad(38))
			part(loggia, "Brace", if face[1] ~= 0 then Vector3.new(2.2, 1.2, 7) else Vector3.new(7, 1.2, 2.2), base * along * tilt, STONE, Enum.Material.Slate)
		end
	end
	roof(loggia, base * CFrame.new(0, pierHeight + 2, 0), 42, 37)
	part(loggia, "BackWall", Vector3.new(1.6, pierHeight, 30), base * CFrame.new(-15.8, pierHeight * 0.5, 0), STONE_DARK, Enum.Material.Slate)
	for side = -1, 1, 2 do
		part(loggia, "LowWall" .. side, Vector3.new(30, 4, 1.2), base * CFrame.new(-0.5, 2, side * 15.6), STONE_DARK, Enum.Material.Slate)
	end

	-- Forge furnace against the back wall.
	part(loggia, "Forge", Vector3.new(7, 6, 6), base * CFrame.new(-12, 3, 0), BRICK, Enum.Material.Brick)
	part(loggia, "ForgeHood", Vector3.new(8, 3, 7), base * CFrame.new(-12, 7.5, 0), STONE_DARK, Enum.Material.Slate)
	part(loggia, "Chimney", Vector3.new(3, 14, 3), base * CFrame.new(-13, 15, 0), BRICK, Enum.Material.Brick)
	local mouth = part(loggia, "ForgeMouth", Vector3.new(0.3, 2.4, 3.4), base * CFrame.new(-8.35, 2.6, 0), Color3.fromRGB(255, 96, 36), Enum.Material.Neon,
		{ Collide = false, Query = false, Shadow = false })
	fire(mouth, 4, 6, Color3.fromRGB(255, 110, 40), Color3.fromRGB(200, 40, 20))
	local forgeEmbers = embers(mouth, 16, 25, 6)
	forgeEmbers.EmissionDirection = Enum.NormalId.Right
	light(mouth, Color3.fromRGB(255, 110, 50), 24, 2.6, true)

	-- Anvil on a stump, and a weapon rack.
	disc(loggia, "Stump", 1.2, 2, base * CFrame.new(-4, 1, 3), WOOD, Enum.Material.Wood)
	part(loggia, "AnvilBody", Vector3.new(1.3, 0.9, 2.8), base * CFrame.new(-4, 2.45, 3), Color3.fromRGB(58, 58, 62), Enum.Material.Metal)
	part(loggia, "AnvilHorn", Vector3.new(1.0, 0.9, 1.3), base * CFrame.new(-4, 2.45, 5.0), Color3.fromRGB(58, 58, 62), Enum.Material.Metal, { Class = "WedgePart" })
	part(loggia, "Rack", Vector3.new(0.5, 4, 6), base * CFrame.new(-14.2, 2, -10), WOOD, Enum.Material.Wood)
	for k = -1, 1 do
		part(loggia, "RackBlade" .. (k + 2), Vector3.new(0.15, 3.8, 0.4), base * CFrame.new(-13.7, 2.6, -10 + k * 1.8) * CFrame.Angles(math.rad(-8), 0, 0),
			Color3.fromRGB(190, 194, 200), Enum.Material.Metal, decor())
	end

	-- The smith stands beside the anvil facing the plaza; prompts live on a fixed anchor so they
	-- work immediately, even while (or if) the avatar rig is still loading.
	local stand = base * CFrame.new(-2, 0, -1)
	local facing = CFrame.lookAt(stand.Position, stand.Position + Vector3.xAxis)
	smithPosition = stand.Position
	spawnSmith(loggia, facing)
	local promptAnchor = part(loggia, "SmithPrompts", Vector3.new(2, 5, 2), facing * CFrame.new(0, 2.5, 0), STONE, Enum.Material.SmoothPlastic,
		{ Collide = false, Query = false, Transparency = 1, Shadow = false })
	local reinforce = Instance.new("ProximityPrompt")
	reinforce.Name = "ReinforcePrompt"
	reinforce.ActionText = "Speak to Master Smith Gao"
	reinforce.ObjectText = "Master Smith Gao"
	reinforce.KeyboardKeyCode = Enum.KeyCode.Z
	reinforce.GamepadKeyCode = Enum.KeyCode.ButtonX
	reinforce.HoldDuration = 0.6
	reinforce.MaxActivationDistance = SMITH_RADIUS
	reinforce.RequiresLineOfSight = false
	reinforce.Parent = promptAnchor
	local refill = Instance.new("ProximityPrompt")
	refill.Name = "RefillPrompt"
	refill.ActionText = "Refill Elixir Gourd"
	refill.ObjectText = "Master Smith Gao"
	refill.KeyboardKeyCode = Enum.KeyCode.C
	refill.GamepadKeyCode = Enum.KeyCode.ButtonStart
	refill.HoldDuration = 0.3
	refill.MaxActivationDistance = SMITH_RADIUS
	refill.RequiresLineOfSight = false
	refill.UIOffset = Vector2.new(0, 72)
	refill.Parent = promptAnchor
	return reinforce, refill
end

-------------------------------------------------------------------------------------------------
-- 4. Colosseum Promenade (east, +X)
-------------------------------------------------------------------------------------------------

local function buildBrazier(parent: Instance, base: CFrame, index: number)
	part(parent, "BrazierStand" .. index, Vector3.new(0.5, 4.2, 0.5), base * CFrame.new(0, 2.1, 0), IRON, Enum.Material.Metal)
	for leg = 0, 2 do
		part(parent, "BrazierLeg" .. index .. leg, Vector3.new(0.3, 1.8, 0.3),
			base * CFrame.Angles(0, math.rad(120 * leg), 0) * CFrame.new(0, 0.8, -0.6) * CFrame.Angles(math.rad(-30), 0, 0), IRON, Enum.Material.Metal, decor())
	end
	disc(parent, "BrazierBowl" .. index, 1.4, 0.8, base * CFrame.new(0, 4.6, 0), IRON, Enum.Material.Metal)
	local coals = disc(parent, "BrazierCoals" .. index, 1.1, 0.2, base * CFrame.new(0, 5.05, 0), EMBER, Enum.Material.Neon, decor())
	fire(coals, 2, 3, Color3.fromRGB(255, 150, 60), Color3.fromRGB(220, 60, 20))
	embers(coals, 6, 30, 3)
	light(coals, Color3.fromRGB(255, 170, 100), 15, 0.8, false)
end

local function buildBanner(parent: Instance, base: CFrame, index: number)
	part(parent, "BannerPole" .. index, Vector3.new(0.6, 16, 0.6), base * CFrame.new(0, 8, 0), IRON, Enum.Material.Metal)
	part(parent, "BannerBar" .. index, Vector3.new(3.8, 0.3, 0.3), base * CFrame.new(0, 15.4, -0.5), IRON, Enum.Material.Metal, decor())
	part(parent, "Banner" .. index, Vector3.new(3.4, 9, 0.12), base * CFrame.new(0, 10.8, -0.6), BANNER_RED, Enum.Material.Fabric, decor())
	part(parent, "BannerBand" .. index, Vector3.new(3.42, 1.1, 0.14), base * CFrame.new(0, 7.2, -0.6), BANNER_BLACK, Enum.Material.Fabric, decor())
	part(parent, "BannerTail" .. index, Vector3.new(3.4, 1.2, 0.12), base * CFrame.new(0, 5.7, -0.6), BANNER_RED, Enum.Material.Fabric, decor())
end

local function buildPromenade(parent: Folder)
	local promenade = folder("ColosseumPromenade", parent)
	local base = CFrame.new(PROMENADE)
	local center = CFrame.new(ORIGIN)

	local walkStart, walkEnd = R - 2, (PROMENADE.X - ORIGIN.X) - BALCONY_APOTHEM + 2
	local walkLength = walkEnd - walkStart
	local walk = center * CFrame.new(walkStart + walkLength * 0.5, 0, 0)
	part(promenade, "Walkway", Vector3.new(walkLength, 3, 12), walk * CFrame.new(0, -1.5, 0), FLAG_DARK, Enum.Material.Slate)
	part(promenade, "WalkwaySupport", Vector3.new(walkLength - 4, 10, 8), walk * CFrame.new(0, -8, 0), ROCK, Enum.Material.Rock, { Shadow = false })
	for side = -1, 1, 2 do
		part(promenade, "WalkRail" .. side, Vector3.new(walkLength, 1.4, 0.8), walk * CFrame.new(0, 0.7, side * 6.4), STONE_DARK, Enum.Material.Slate)
	end

	-- Octagonal balcony (two squares sharing an apothem) jutting over the clouds.
	for index = 0, 1 do
		part(promenade, "Balcony" .. index, Vector3.new(BALCONY_APOTHEM * 2, 5, BALCONY_APOTHEM * 2), base * CFrame.Angles(0, math.rad(45 * index), 0) * CFrame.new(0, -2.5, 0),
			FLAG_LIGHT, Enum.Material.Slate)
	end
	disc(promenade, "Corbel", 26, 18, base * CFrame.new(0, -14, 0), ROCK, Enum.Material.Rock, { Shadow = false })
	disc(promenade, "CorbelRoot", 14, 28, base * CFrame.new(0, -37, 0), ROCK, Enum.Material.Rock, { Shadow = false })

	-- Balustrade on every edge except the west entry (edge 2 faces -X).
	local edge = 2 * BALCONY_APOTHEM * math.tan(math.rad(22.5))
	for k = 0, 7 do
		if k ~= 2 then
			local frame = base * CFrame.Angles(0, math.rad(45 * k), 0) * CFrame.new(0, 0, -(BALCONY_APOTHEM - 0.7))
			part(promenade, "Plinth" .. k, Vector3.new(edge, 0.6, 1.2), frame * CFrame.new(0, 0.3, 0), STONE_DARK, Enum.Material.Slate)
			part(promenade, "Rail" .. k, Vector3.new(edge + 0.8, 0.7, 1.4), frame * CFrame.new(0, 3.35, 0), STONE, Enum.Material.Slate)
			for j = 1, 5 do
				part(promenade, "Baluster" .. k .. "_" .. j, Vector3.new(0.7, 2.4, 0.7), frame * CFrame.new(-edge * 0.5 + (j - 0.5) * edge / 5, 1.8, 0), STONE, Enum.Material.Slate)
			end
		end
	end
	local vertexRadius = BALCONY_APOTHEM / math.cos(math.rad(22.5)) - 1.4
	for k = 0, 7 do
		local angle = math.rad(45 * k + 22.5)
		local vertex = base * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -vertexRadius)
		part(promenade, "Post" .. k, Vector3.new(1.6, 4.4, 1.6), vertex * CFrame.new(0, 2.2, 0), STONE, Enum.Material.Slate)
		if k == 1 or k == 2 then
			buildBrazier(promenade, vertex * CFrame.new(0, 4.4, 0), k)
		else
			buildBanner(promenade, vertex * CFrame.new(0, 4.4, 0), k)
		end
	end
	for index, k in { 0, 4, 6 } do
		local mid = base * CFrame.Angles(0, math.rad(45 * k), 0) * CFrame.new(0, 0, -(BALCONY_APOTHEM - 3.5))
		buildBrazier(promenade, mid, 10 + index)
	end
end

-------------------------------------------------------------------------------------------------
-- 5. Sea of clouds and the horizon
-------------------------------------------------------------------------------------------------

local function buildSky(parent: Folder)
	local sky=folder("ValleyMist",parent)
	-- Soft particle banks replace the opaque cloud slabs and visible plastic spheres.
	for k=0,7 do
		local angle=math.rad(k*45)
		local anchor=part(sky,"MistBank",Vector3.new(150,5,110),CFrame.new(ORIGIN+Vector3.new(math.cos(angle)*190,-48,math.sin(angle)*190)),STONE,Enum.Material.SmoothPlastic,
			{Collide=false,Query=false,Transparency=1,Shadow=false})
		local mist=Instance.new("ParticleEmitter")
		mist.Texture=TEXTURE_SMOKE
		mist.Rate=1.2
		mist.Lifetime=NumberRange.new(18,25)
		mist.Speed=NumberRange.new(0.1,0.5)
		mist.Acceleration=Vector3.new(0.4,0,0.12)
		mist.Shape=Enum.ParticleEmitterShape.Box
		mist.ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume
		mist.Size=sequence({{0,65},{1,110}})
		mist.Transparency=sequence({{0,1},{0.2,0.86},{0.7,0.9},{1,1}})
		mist.Color=colors(Color3.fromRGB(102,128,140),Color3.fromRGB(135,151,157))
		mist.LightInfluence=0.7
		mist.Parent=anchor
	end
end

local function buildHorizon(parent: Folder)
	local horizon=folder("KarstMountains",parent)
	local rng=Random.new(9091)
	for k=0,17 do
		local angle=math.rad(k*20)+rng:NextNumber(-0.1,0.1)
		local distance=rng:NextNumber(260,750)
		local height=rng:NextNumber(150,310)
		local width=rng:NextNumber(65,140)
		local base=CFrame.new(ORIGIN+Vector3.new(math.sin(angle)*distance,-140,math.cos(angle)*distance))*CFrame.Angles(0,angle,0)
		for lobe=-1,1 do
			local h=height*rng:NextNumber(0.6,1.1)
			part(horizon,"KarstFace",Vector3.new(width*0.65,h,width*0.9),base*CFrame.new(lobe*width*0.25,h*0.5,0)*CFrame.Angles(0,rng:NextNumber(-0.5,0.5),math.rad(rng:NextNumber(-10,10))),
				SILHOUETTE:Lerp(ROCK,rng:NextNumber(0.1,0.6)),Enum.Material.Rock,{Class="WedgePart",Collide=false,Query=false,Shadow=false})
		end
		-- A few distant pagoda roofs establish a world beyond this one courtyard.
		if k==3 or k==10 or k==15 then
			local tower=base*CFrame.new(0,height*0.6,0)
			for tier=0,2 do
				part(horizon,"DistantPagoda",Vector3.new(12-tier*2,7,12-tier*2),tower*CFrame.new(0,tier*10,0),SILHOUETTE,Enum.Material.Slate,decor())
				part(horizon,"DistantEave",Vector3.new(20-tier*3,0.8,20-tier*3),tower*CFrame.new(0,tier*10+7,0),SILHOUETTE,Enum.Material.Slate,decor())
			end
		end
	end
end

-------------------------------------------------------------------------------------------------
-- 6. Colossus Asura Sanctuary Dais (matching lobby concept art)
-------------------------------------------------------------------------------------------------

local function buildHeroStatueDais(parent: Folder)
	local statueGroup = folder("ColossusSanctuary", parent)
	local center = CFrame.new(ORIGIN)
	-- Offset behind the central pool (toward North-East at roughly X = 10, Z = -32)
	local daisBase = center * CFrame.new(10, 0, -32)

	-- Monumental tiered ruined stone plinth supporting the colossus
	disc(statueGroup, "StatueBaseTier1", 28, 3.5, daisBase * CFrame.new(0, 1.75, 0), STONE_DARK, Enum.Material.Slate)
	disc(statueGroup, "StatueBaseTier2", 23, 2.8, daisBase * CFrame.new(0, 4.5, 0), STONE, Enum.Material.Slate)
	disc(statueGroup, "StatueBaseTier3", 18, 2.2, daisBase * CFrame.new(0, 7.0, 0), STONE_DARK, Enum.Material.Slate)
	Leaves.Scatter(statueGroup, daisBase * CFrame.new(0, 8.1, 0), Vector2.new(17, 17), 70, 31)
	Leaves.Scatter(statueGroup, daisBase * CFrame.new(0, 5.9, 0), Vector2.new(22, 22), 50, 32)

	-- Flanking ruin columns with warm lanterns
	for side = -1, 1, 2 do
		for k = 1, 3 do
			local pcf = daisBase * CFrame.new(side * (24 + k * 6), 0, -k * 7)
			local h = 32 - k * 5
			part(statueGroup, "RuinColumn", Vector3.new(4.5, h, 4.5), pcf * CFrame.new(0, h * 0.5, 0), STONE, Enum.Material.Slate)
			part(statueGroup, "ColumnCap", Vector3.new(6.0, 1.8, 6.0), pcf * CFrame.new(0, h + 0.9, 0), STONE_DARK, Enum.Material.Slate)
			lantern(statueGroup, pcf * CFrame.new(0, h * 0.5, 3))
		end
	end

	-- Monumental gothic arch framing behind the colossal titan
	part(statueGroup, "ArchPillarL", Vector3.new(6.0, 75, 6.0), daisBase * CFrame.new(-24, 37.5, -16), STONE, Enum.Material.Slate)
	part(statueGroup, "ArchPillarR", Vector3.new(6.0, 75, 6.0), daisBase * CFrame.new(24, 37.5, -16), STONE, Enum.Material.Slate)
	part(statueGroup, "ArchSpan", Vector3.new(54, 6.0, 7.0), daisBase * CFrame.new(0, 75, -16), STONE_DARK, Enum.Material.Slate)

	-- Hero Statue Anchor point (elevated onto the third plinth tier)
	local anchor = part(statueGroup, "AsuraColossusAnchor", Vector3.new(32, 68, 32), daisBase * CFrame.new(0, 8.2, 0) * CFrame.Angles(0, math.rad(-165), 0), STATUE, Enum.Material.SmoothPlastic,
		{ Collide = false, Query = false, Transparency = 1, Shadow = false })

	-- Stand-in meditating stone titan colossus until custom mesh is inserted
	local titan = folder("StoneTitanProxy", statueGroup)
	part(titan, "ColossusTorso", Vector3.new(18, 26, 14), anchor.CFrame * CFrame.new(0, 16, 0), STATUE, Enum.Material.Slate)
	part(titan, "ColossusShoulders", Vector3.new(28, 7, 16), anchor.CFrame * CFrame.new(0, 29, 0), STONE, Enum.Material.Slate)
	part(titan, "ColossusHead", Vector3.new(11, 13, 11), anchor.CFrame * CFrame.new(0, 39, -1.0), STATUE, Enum.Material.Slate)
	part(titan, "ColossusCrown", Vector3.new(12.5, 6.5, 12.5), anchor.CFrame * CFrame.new(0, 46, -1.0), BRONZE, Enum.Material.Metal)
	for r = -2, 2 do
		part(titan, "RootTendril", Vector3.new(3.2, 28, 3.2), anchor.CFrame * CFrame.new(r * 6.5, 14, -8.0 + math.abs(r) * 2) * CFrame.Angles(math.rad(12), 0, math.rad(r * 15)), Color3.fromRGB(215, 210, 202), Enum.Material.Wood, decor())
	end

	-- Uploaded PBR set pieces (ServerStorage.AsuraAssets). The procedural titan stays only if the
	-- asset folder is missing, e.g. in a bare Rojo build without assets/models.
	if Dressing.try("Colossus", Dressing.Colossus, statueGroup, anchor.CFrame, titan) then
		Dressing.try("Roots", Dressing.Roots, statueGroup, daisBase)
	end
	Dressing.try("SacredTree", Dressing.SacredTree, statueGroup, daisBase * CFrame.new(-42, 0, -10))
end

-------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------
-- Behaviour
-------------------------------------------------------------------------------------------------

local function toCFrame(p: World.Placement): CFrame
	return CFrame.new(p.X, p.Y, p.Z) * CFrame.Angles(0, math.rad(p.Yaw), 0)
end

local function result(player: Player, ok: boolean, reason: string)
	player:SetAttribute("AsuraResult", (if ok then "" else "!") .. reason)
end

local function onPortal(hit: BasePart)
	local model = hit:FindFirstAncestorOfClass("Model")
	local player = if model then Players:GetPlayerFromCharacter(model) else nil
	if not player then
		return
	end
	local userId = player.UserId
	local clock = os.clock()
	if (transit[userId] or 0) > clock then
		return
	end
	local e = Characters.GetEntity(userId)
	if not e or e.Model ~= model or e.Fighter.State == "KO" or e.Respawning or Characters.IsInDuel(userId) then
		return
	end
	transit[userId] = clock + PORTAL_COOLDOWN
	Characters.Cinematic(userId, PORTAL_FADE * 2)
	Characters.Cue("PortalTransit", userId, { to = DESTINATION.Id, name = DESTINATION.Name, fade = PORTAL_FADE })
	task.delay(PORTAL_FADE, function()
		local current = Characters.GetEntity(userId)
		if running and current and current.Fighter.State ~= "KO" and not Characters.IsInDuel(userId) then
			Characters.Teleport(userId, toCFrame(DESTINATION.Spawn))
		end
	end)
end

local function poll()
	for _, player in Players:GetPlayers() do
		local userId = player.UserId
		local e = Characters.GetEntity(userId)
		if e and e.Fighter.State ~= "KO" and not e.Respawning and not Characters.IsInDuel(userId) then
			local position = e.Root.Position
			local flat = Vector3.new(position.X - ORIGIN.X, 0, position.Z - ORIGIN.Z)
			-- Ground-level regions below the shrine are destinations, not falls from the clouds.
			local region = World.regionAt(position.X, position.Y, position.Z)
			if (region == nil or region == "Sanctuary") and flat.Magnitude < CATCH_RADIUS and position.Y < ORIGIN.Y - CATCH_DEPTH then
				-- The clouds return those who fall back to the bonfire.
				Characters.Teleport(userId, spawnCFrame)
				Characters.Cue("SanctuaryCatch", userId, {})
			end
		end
	end
end

-------------------------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------------------------

function SanctuaryService.Start()
	assert(not running, "SanctuaryService already started")
	assert(BONFIRE_ALTAR.Region == "Sanctuary", "The starting altar must stand in the Sanctuary")
	assert(DESTINATION ~= nil, "Sanctuary portal destination missing")
	running = true
	local existing = Workspace:FindFirstChild(World.Regions.Sanctuary.MapFolder)
	if existing then
		existing:Destroy()
	end
	local sanctuary = Instance.new("Folder")
	sanctuary.Name = World.Regions.Sanctuary.MapFolder
	root = sanctuary
	spawnCFrame = toCFrame(BONFIRE_ALTAR.Spawn)

	buildPlaza(sanctuary)
	local trigger = buildGateway(sanctuary)
	local reinforce, refill = buildLoggia(sanctuary)
	buildPromenade(sanctuary)
	buildHeroStatueDais(sanctuary)
	buildSky(sanctuary)
	buildHorizon(sanctuary)
	sanctuary.Parent = Workspace

	-- Default checkpoint for anyone without a resolved respawn yet (WorldService's altar hook
	-- supersedes it once a Souls session exists).
	table.insert(disconnectors, Characters.OnEntityAdded(function(id: number, kind: Characters.EntityKind)
		if kind == "Player" then
			Characters.SetRespawnPoint(id, spawnCFrame)
		end
	end))
	table.insert(connections, trigger.Touched:Connect(onPortal))
	table.insert(connections, reinforce.Triggered:Connect(function(player: Player)
		local Dialogue=require(script.Parent.DialogueService)
        Dialogue.Open(player,"Gao")
        local ok,reason=true,"Dialogue"
		if not ok then
			result(player, false, reason)
		end
	end))
	table.insert(connections, refill.Triggered:Connect(function(player: Player)
		local ok, reason = WorldService.RefillElixirs(player.UserId)
		result(player, ok, reason)
	end))
	-- The Interact key beside the smith is the reinforce prompt's own key; acknowledge it quietly.
	table.insert(disconnectors, WorldService.RegisterInteractable(function(_userId: number, position: Vector3): (boolean?, string?)
		if (position - smithPosition).Magnitude <= SMITH_RADIUS + 1 then
			return true, "Smith"
		end
		return nil, nil
	end))
	table.insert(connections, Players.PlayerRemoving:Connect(function(player: Player)
		transit[player.UserId] = nil
	end))
	table.insert(connections, RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator >= POLL_INTERVAL then
			accumulator = 0
			local ok, problem = pcall(poll)
			if not ok then
				warn("[Sanctuary] Poll failed: " .. tostring(problem))
			end
		end
	end))
end

function SanctuaryService.SpawnCFrame(): CFrame
	return spawnCFrame
end

function SanctuaryService.Contains(position: Vector3): boolean
	return World.regionAt(position.X, position.Y, position.Z) == "Sanctuary"
end

function SanctuaryService.Destroy()
	running = false
	for _, disconnect in disconnectors do
		disconnect()
	end
	table.clear(disconnectors)
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(transit)
	local folderRoot = root
	if folderRoot then
		folderRoot:Destroy()
		root = nil
	end
end

return SanctuaryService
