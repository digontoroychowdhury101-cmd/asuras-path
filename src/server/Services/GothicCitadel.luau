--!strict
-- Vesperhold. Local +Z faces the approach. Origin is the top of the gate threshold.
local CollectionService = game:GetService("CollectionService")
local Kit = require(script.Parent:WaitForChild("SanctuaryKit") :: ModuleScript)
local Props = require(script.Parent:WaitForChild("SanctuaryProps") :: ModuleScript)
local Pbr = require(script.Parent:WaitForChild("PbrAssets") :: ModuleScript)
local Citadel = {}

local V, C = Vector3.new, CFrame.new
local rgb, M = Color3.fromRGB, Enum.Material
local stone = rgb(93, 101, 106)
local basal = rgb(85, 91, 103)
local limestone = rgb(117, 116, 107)
local chalk = rgb(141, 140, 131)
local slate = rgb(56, 69, 84)
local lead = rgb(87, 101, 110)
local iron = rgb(55, 53, 51)
local copper = rgb(154, 125, 80)
local garnet = rgb(104, 41, 53)
local glass = rgb(156, 106, 64)
local shadow = rgb(43, 48, 54)
local timber = rgb(87, 68, 58)
local decor = { Collide = false, Query = false }
local wedge = { Class = "WedgePart", Collide = false, Query = false }

local function section(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

-- Flat ashlar, hammered lead and pale projecting limestone have different light responses.
local function box(p: Instance, name: string, cf: CFrame, w: number, h: number, d: number, color: Color3, material: Enum.Material?, solid: boolean?): BasePart
	return Kit.part(p, name, V(w,h,d), cf, color, material or M.Limestone, if solid then nil else decor)
end

local function rod(p: Instance, name: string, a: Vector3, b: Vector3, width: number, depth: number, color: Color3, material: Enum.Material?)
	local dir = (b-a).Unit
	local guide = if math.abs(dir:Dot(Vector3.yAxis)) > 0.98 then Vector3.zAxis else Vector3.yAxis
	box(p, name, CFrame.lookAt((a+b)/2, b, guide), width, depth, (b-a).Magnitude + 0.09, color, material)
end

-- Split a triangle at the altitude to its longest edge. Both WedgeParts share that
-- edge without overlap. This makes pitched roofs, real arch spandrels and polygonal
-- spires independent of imported meshes or runtime CSG.
local function triangle(p: Instance, name: string, a: Vector3, b: Vector3, c: Vector3, thick: number, color: Color3, mat: Enum.Material)
	local ab, ac, bc = b-a, c-a, c-b
	if ab.Magnitude > ac.Magnitude and ab.Magnitude > bc.Magnitude then
		c, a = a, c
	elseif ac.Magnitude > bc.Magnitude then
		a, b = b, a
	end
	ab, ac, bc = b-a, c-a, c-b
	local normal, back = ac:Cross(ab).Unit, bc.Unit
	local up = bc:Cross(normal).Unit
	local h = math.abs(ab:Dot(up))
	local l, r = math.abs(ab:Dot(back)), math.abs(ac:Dot(back))
	if l > 0.03 then
		Kit.part(p, name, V(thick,h,l), CFrame.fromMatrix((a+b)/2,normal,up,back), color, mat, wedge)
	end
	if r > 0.03 then
		Kit.part(p, name, V(thick,h,r), CFrame.fromMatrix((a+c)/2,-normal,up,-back), color, mat, wedge)
	end
end

local function faceTri(p: Instance, name: string, cf: CFrame, a: Vector3, b: Vector3, c: Vector3, thick: number, color: Color3, mat: Enum.Material)
	triangle(p, name, cf*a, cf*b, cf*c, thick, color, mat)
end

-- A two-centred lancet with dressed arch stones and actual open space underneath.
-- Omit head on an arcade to leave open sky above the dressed stone.
local function arch(p: Instance, frame: CFrame, half: number, spring: number, rise: number, band: number, depth: number, head: number?)
	for _, s in {-1,1} do
		box(p, "EngagedShaft", frame*C(s*(half+band/2),spring/2,0), band, spring, depth, limestone)
		box(p, "Impost", frame*C(s*(half+band/2),spring,0), band+0.55,0.75,depth+0.65,chalk)
		-- Sample a circular arc from the spring point on the opposite side's radius.
		local center = (rise*rise-half*half)/(2*half)
		local radius = half+center
		local angle = math.atan2(rise,center)
		local function point(i: number): Vector3
			local t = angle*i/3
			return V(s*(radius*math.cos(t)-center),spring+radius*math.sin(t),0)
		end
		for i = 1, 3 do
			local a, b = point(i-1), point(i)
			local outer = V((b.Y-a.Y)*s, math.abs(b.X-a.X), 0).Unit
			local pos = (a+b)*0.5 + outer*(band*0.48)
			local tangent = (b-a).Unit
			local block = frame*CFrame.fromMatrix(pos,tangent,outer,tangent:Cross(outer))
			box(p, "CutVoussoir", block, (b-a).Magnitude+0.22,band,depth, if i==2 then stone else limestone)
			if head then
				local topLeft, topRight = V(a.X,head,0), V(b.X,head,0)
				if (topLeft-a).Magnitude > 0.02 then
					faceTri(p,"Spandrel",frame,a,b,topLeft,depth-0.5,stone,M.Limestone)
				end
				if (topRight-b).Magnitude > 0.02 then
					faceTri(p,"Spandrel",frame,b,topRight,topLeft,depth-0.5,stone,M.Limestone)
				end
			end
		end
	end
end

local function octagonal(p: Instance, frame: CFrame, radius: number, h: number, color: Color3, material: Enum.Material, solid: boolean?)
	local halfAngle = math.pi/8
	for i = 0,3 do
		box(p, "OctagonalCourse", frame*C(0,h/2,0)*CFrame.Angles(0,i*math.pi/4,0),
			2*radius*math.sin(halfAngle),h,2*radius*math.cos(halfAngle),color,material,solid)
	end
end

local function spire(p: Instance, frame: CFrame, radius: number, height: number, sides: number, seams: boolean?)
	local apex = V(0,height,0)
	for i = 0,sides-1 do
		local angle = (i+0.5)*2*math.pi/sides
		local nextAngle = angle+2*math.pi/sides
		local a = V(math.sin(angle)*radius,0,math.cos(angle)*radius)
		local b = V(math.sin(nextAngle)*radius,0,math.cos(nextAngle)*radius)
		faceTri(p,"FoldedSpire",frame,a,b,apex,0.24, if i%2==0 then slate else rgb(67,81,92),M.Slate)
		if seams and i%2==0 then rod(p,"StandingSeam",frame*a,frame*apex,0.31,0.31,lead,M.Metal) end
	end
	box(p,"WeatherIron",frame*C(0,height+1.3,0),0.35,4.5,0.35,copper,M.Metal)
end

-- The window lies behind deep jambs. The open Y-tracery retains a readable silhouette
-- even on simple graphics settings; only the smaller inhabited panes emit light.
local function lancet(p: Instance, cf: CFrame, w: number, h: number, glowing: boolean)
	local s, peak = h*0.65,h*0.35
	local tint = if glowing then glass else rgb(73,89,99)
	local mat = M.SmoothPlastic
	box(p,"RecessShadow",cf*C(0,s/2,0.12),w+0.8,s+0.6,0.36,shadow,M.Slate)
	box(p,"LeadGlass",cf*C(0,s/2,0.34),w-0.8,s-0.4,0.18,tint,mat)
	faceTri(p,"LancetCrown",cf*C(0,0,0.29),V(-w/2,s,0),V(w/2,s,0),V(0,h,0),0.23,tint,mat)
	for _, sign in {-1,1} do
		box(p,"WindowReveal",cf*C(sign*(w/2+0.3),s/2,0.65),0.65,s,1.5,limestone)
		rod(p,"HoodMould",cf*V(sign*(w/2+0.32),s,0.75),cf*V(0,h+0.5,0.75),0.72,0.72,limestone)
		rod(p,"ForkedTracery",cf*V(0,s*0.78,0.65),cf*V(sign*w*0.31,s+peak*0.39,0.65),0.24,0.24,iron,M.Metal)
	end
	if glowing then
		box(p,"OxbloodPane",cf*C(-w*0.21,s*0.56,0.48),w*0.34,s*0.78,0.14,rgb(113,62,60),M.SmoothPlastic)
		box(p,"LastWatchLight",cf*C(w*0.21,s*0.33,0.49),w*0.29,s*0.25,0.14,rgb(139,93,60),M.Neon)
	end
	box(p,"Mullion",cf*C(0,s*0.40,0.66),0.27,s*0.8,0.25,iron,M.Metal)
	box(p,"Sill",cf*C(0,0,0.65),w+2,0.65,2.1,chalk)
end

local function pinnacle(p: Instance, frame: CFrame, w: number, h: number)
	box(p,"PinnaclePedestal",frame*C(0,w*0.52,0),w,w*1.04,w,limestone)
	box(p,"PinnacleCollar",frame*C(0,w*1.04,0),w+0.6,0.55,w+0.6,chalk)
	spire(p,frame*C(0,w*1.04+0.2,0),w*0.82,h,4)
end

local function hips(p: Instance, frame: CFrame, lower: number, upper: number, h: number, sides: number)
	for i=0,sides-1 do
		local a,b = (i+0.5)*2*math.pi/sides,(i+1.5)*2*math.pi/sides
		local u,v = V(math.sin(a),0,math.cos(a)),V(math.sin(b),0,math.cos(b))
		local c,d = v*upper+V(0,h,0),u*upper+V(0,h,0)
		faceTri(p,"LeadHips",frame,u*lower,v*lower,c,0.25,slate,M.Slate)
		faceTri(p,"LeadHips",frame,u*lower,c,d,0.25,slate,M.Slate)
	end
end

local function battlement(p: Instance, frame: CFrame, radius: number, ruined: boolean)
	for i=0,7 do
		local bay=frame*CFrame.Angles(0,i*math.pi/4,0)*C(0,0,radius*0.92)
		local h=if ruined and i%3==1 then 1.4 else 4.2
		box(p,"BartizanParapet",bay*C(0,0.95,0),radius*0.78,2,1.75,stone,M.Brick)
		box(p,"Embrasure",bay*C(-1.25,1.95+h/2,0),2.7,h,1.95,if ruined and i%3==1 then basal else stone,M.Brick)
		if h>2 then box(p,"CopedMerlon",bay*C(-1.25,h+2.1,0),3.05,0.5,2.4,limestone) end
		box(p,"Machicolation",bay*C(0,-1.45,0),1.9,3.4,2.5,limestone)
	end
end

local function tower(p: Instance, frame: CFrame, r: number, shaft: number, roof: number, lit: boolean, crown: string?)
	octagonal(p,frame*C(0,-4,0),r,shaft+4,stone,M.Brick,true)
	octagonal(p,frame*C(0,shaft*0.34,0),r+0.65,1.2,limestone,M.Limestone)
	octagonal(p,frame*C(0,shaft-6,0),r+0.8,1.4,limestone,M.Limestone)
	octagonal(p,frame*C(0,shaft-1.1,0),r+1.4,1.4,chalk,M.Limestone)
	local foot = frame*C(0,shaft+0.15,0)
	if crown=="parapet" or crown=="breach" then
		battlement(p,foot,r,crown=="breach")
	elseif crown=="helmet" then
		hips(p,foot,r+2.5,r*0.46,roof*0.42,8)
		octagonal(p,foot*C(0,roof*0.42,0),r*0.47,4.1,basal,M.Slate)
		spire(p,foot*C(0,roof*0.42+4,0),r*0.64,roof*0.85,8,true)
	else
		spire(p,foot,r+2.5,roof,8,true)
	end
	local apothem = r*math.cos(math.pi/8)
	for i = 0,3 do
		local wall = frame*CFrame.Angles(0,i*math.pi/2,0)*C(0,shaft-20,apothem)
		lancet(p,wall,math.min(r*0.44,4.6),12,lit and i%2==0)
	end
end

local function portal(p: Instance, f: CFrame, w: number, spring: number, rise: number, wing: number, depth: number)
	local head = spring+rise+2.5
	for _, s in {-1,1} do
		box(p,"PortalWing",f*C(s*(w/2+wing/2),head/2,0),wing,head,depth,stone,M.Brick,true)
	end
	arch(p,f,w/2,spring,rise,1.5,depth,head)
	arch(p,f*C(0,0,depth/2+0.68),w/2+1.15,spring,rise+1.1,1.1,1.55)
	local coping = box(p,"GateCoping",f*C(0,head+0.2,0),w+wing*2+1,1.2,depth+1.5,chalk,nil,true)
	CollectionService:AddTag(coping,"AsuraShelter")
end

local function stair(p: Instance, f: CFrame, width: number, run: number, lift: number)
	-- One simple smooth solid supports all the visible half-stud treads.
	local a, b = f.Position, f*V(0,lift,-run)
	local pitch = CFrame.lookAt((a+b)/2,b)
	box(p,"StairRamp",pitch*C(0,-0.65,0),width,1.3,(b-a).Magnitude+0.25,basal,M.Slate,true)
	local n = math.ceil(math.abs(lift)/0.58)
	for i=1,n do
		local t = (i-0.5)/n
		box(p,"WornTread",f*C(0,t*lift,-t*run),width,0.48,run/n+0.03,if i%6==0 then limestone else stone,M.Limestone)
	end
end

local function rail(p: Instance, f: CFrame, length: number)
	box(p,"OverlookKerb",f*C(0,0.6,0),length,1.2,1.5,limestone,nil,true)
	box(p,"ParapetRail",f*C(0,3.25,0),length,0.45,0.55,iron,M.Metal,true)
	local n = math.ceil(length/5.5)
	for i=0,n do
		box(p,"RailUpright",f*C(-length/2+length*i/n,2,0),0.44,2.75,0.44,iron,M.Metal)
	end
end

local function curtain(p: Instance, f: CFrame, length: number, h: number)
	box(p,"CurtainMasonry",f*C(0,(h-5)/2,0),length,h+5,4.8,stone,M.Brick,true)
	box(p,"BasalBatter",f*C(0,2.4,0),length+0.1,5,6.8,basal,M.Slate,true)
	box(p,"WallWalkCornice",f*C(0,h-0.5,0),length,1.25,6.6,limestone)
	-- Lift the wall from the ground in stepped defensive piers. A few repaired
	-- courses show through the paler facing beneath the arrow loops.
	local piers = math.floor(length/20)
	for i=1,piers do
		local x = ((i-0.5)/piers-0.5)*length
		box(p,"SplayedWallFoot",f*C(x,2.1,3.4),5.7,4.2,4.8,basal,M.Slate,true)
		box(p,"BatteredSpur",f*C(x,6.1,3.1),4.45,6.4,4.1,stone,M.Brick,true)
		box(p,"SpurWeathering",f*C(x,9.45,3.3),4.9,0.65,4.45,limestone)
		box(p,"EngagedSpur",f*C(x,12.6,2.65),2.95,6.2,3.2,stone,M.Brick)
		local slitX = x+5.8
		box(p,"ArrowLoopRecess",f*C(slitX,10.3,2.48),0.72,4.5,0.22,shadow,M.Slate)
		box(p,"LoopHood",f*C(slitX,12.6,2.65),1.55,0.5,0.8,limestone)
		box(p,"LoopSill",f*C(slitX,7.9,2.65),1.65,0.42,0.8,limestone)
		for course=1,3 do
			local dz=course*0.03
			local span=(4-course)*0.94
			box(p,"WeatheredAshlar",f*C(x-4.1+(course%2)*1.2,3.3+course*0.72,2.52+dz),span,0.61,0.32,
				if course==1 then basal else rgb(105,112,116),M.Slate)
		end
	end
	local bays = math.max(1,math.floor(length/11))
	for i=1,bays do
		local x = ((i-0.5)/bays-0.5)*length
		local height = if i%4==0 then 2.1 else 3.5
		box(p,"Merlon",f*C(x,h+height/2-0.4,0.5),5.3,height,3.5,stone)
		if height>3 then box(p,"MerlonWeathering",f*C(x,h+3.1,0.5),5.9,0.55,4.1,chalk) end
	end
end

local function gatehouse(p: Instance, f: CFrame)
	portal(p,f*C(0,0,-4),21,13.5,12,11,11)
	for i=-3,3 do
		box(p,"RaisedGrille",f*C(i*1.55,22.4,-0.5),0.43,4.5-math.abs(i)*0.45,0.6,iron,M.Metal)
	end
	box(p,"GrilleStrap",f*C(0,23,-0.5),12,0.6,0.8,iron,M.Metal)
	for _, s in {-1,1} do
		local frame = f*C(s*25,0,-5)
		tower(p,frame,10.3,if s==1 then 39 else 43,if s==1 then 20 else 26,false,if s==1 then "parapet" else "helmet")
		Props.brazier(p,f*C(s*12.5,0,4),21)
		-- Banners drape from the paired gate towers, cut to two unequal swallowtails.
		local flag = f*C(s*25,24,4.9)
		box(p,"IronBannerStaff",flag*C(0,0.3,0),7.5,0.3,0.5,copper,M.Metal)
		box(p,"OxbloodGateBanner",flag*C(0,-4.3,0),5.9,8.6,0.18,garnet,M.Fabric)
		faceTri(p,"Swallowtail",flag,V(-2.95,-8.6,0),V(0,-8.6,0),V(-2.95,-12,0),0.18,garnet,M.Fabric)
		faceTri(p,"Swallowtail",flag,V(0,-8.6,0),V(2.95,-8.6,0),V(2.95,-11.1,0),0.18,garnet,M.Fabric)
		rod(p,"StandardSigil",flag*V(-1.8,-4,0.21),flag*V(0,-6,0.21),0.34,0.34,copper)
		rod(p,"StandardSigil",flag*V(0,-6,0.21),flag*V(1.8,-3,0.21),0.34,0.34,copper)
	end
	-- Tiny oculus above the open teeth catches the last light in the approach.
	box(p,"RoyalLozenge",f*C(0,26.2,2.8)*CFrame.Angles(0,0,math.pi/4),3.8,3.8,0.55,copper,M.Metal)
	box(p,"RoyalLozenge",f*C(0,26.2,3.2)*CFrame.Angles(0,0,math.pi/4),2.5,2.5,0.32,garnet,M.Slate)
end

local function outerWard(p: Instance, f: CFrame)
	-- Deep foundations meet the escarpment under both rings of defences.
	box(p,"CurtainFooting",f*C(0,-4,-50),165,8,112,basal,M.Slate,true)
	Kit.slab(p,"CourtyardSetts",V(162,1.2,109),f*C(0,-0.6,-48.5),"Paving")
	Kit.slab(p,"ProcessionalWay",V(17,0.16,86),f*C(0,0.035,-37),"PavingPath",decor)
	for _,s in {-1,1} do
		curtain(p,f*C(s*55,0,-6),52,15)
		for _, sectionZ in { { -24,36 }, {-78,48} } do
			curtain(p,f*C(s*81,0,sectionZ[1])*CFrame.Angles(0,math.pi/2,0),sectionZ[2],16)
		end
		tower(p,f*C(s*78,0,-9),7.5,if s==1 then 26 else 30,if s==1 then 13 else 16,false,if s==1 then "breach" else "parapet")
		tower(p,f*C(s*78,0,-99),9,if s==1 then 47 else 34,if s==1 then 23 else 14,false,if s==1 then "helmet" else "breach")
	end
	-- The eastern postern is flush with the valley trail. The western curtain is closed.
	portal(p,f*C(81,0,-48)*CFrame.Angles(0,math.pi/2,0),12,7.5,5.5,1,4.8)
	curtain(p,f*C(-81,0,-48)*CFrame.Angles(0,math.pi/2,0),12,16)
	for _,s in {-1,1} do
		local aisle = f*C(s*14.5,0,-89)
		box(p,"StairCheek",aisle*C(0,2,-5),1.8,4,24,stone,M.Limestone,true)
		pinnacle(p,f*C(s*15,0,-80),2.8,4.7)
	end
	stair(p,f*C(0,0,-80),26,28,12)
	box(p,"UpperWardFoundation",f*C(0,3.25,-153),147,17.5,90,basal,M.Brick,true)
	Kit.slab(p,"UpperWardFlags",V(147,0.4,90),f*C(0,11.8,-153),"PavingPath")
	-- The soldiers' covered rampart joins the lower yard and the keep's west door.
	stair(p,f*C(-52,0,-36),10,54,20)
	box(p,"WatchGallery",f*C(-59.5,18.5,-97),25,3,16,stone,nil,true)
	for _,x in {-69,-51} do
		for _,z in {-92,-102} do box(p,"GalleryPier",f*C(x,9,z),3.2,18,3.4,stone,M.Brick,true) end
	end
	rail(p,f*C(-72,20,-97)*CFrame.Angles(0,math.pi/2,0),16)
	rail(p,f*C(-64,20,-89),15)
	rail(p,f*C(-64,20,-105),15)
	-- This portion of the west approach lies above the upper terrace rather than behind it.
	stair(p,f*C(-52,20,-104),10,24,-8)
	for _,s in {-1,1} do
		for _, z in {-39,-65} do Props.bench(p,f*C(s*38,0,z)*CFrame.Angles(0,s*math.pi/2,0)) end
	end
end

local function greatWheel(p: Instance, cf: CFrame, r: number)
	local wine, petrol, ochre = rgb(104,42,53),rgb(44,81,88),rgb(139,99,61)
	local plum, smoke = rgb(86,62,80),rgb(42,48,49)
	local palette = {wine,petrol,ochre,plum,petrol,wine,plum,ochre}
	local function relief(frame: CFrame, a: Vector3, b: Vector3, width: number, depth: number, color: Color3, material: Enum.Material)
		-- Align the rectangular section's depth perpendicular to the glass,
		-- including around the nearly vertical ends of the lancets.
		local tangent=(b-a).Unit
		local side=V(-tangent.Y,tangent.X,0)
		local pose=frame*CFrame.fromMatrix((a+b)/2,tangent,side,Vector3.zAxis)
		box(p,"RoseTracery",pose,(b-a).Magnitude+width*0.28,width,depth,color,material)
	end
	local function boss(frame: CFrame, name: string, rad: number, thickness: number, color: Color3, material: Enum.Material)
		local result=box(p,name,frame*CFrame.Angles(0,math.pi/2,0),thickness,rad*2,rad*2,color,material) :: Part
		result.Shape=Enum.PartType.Cylinder
	end
	boss(cf*C(0,0,0.22),"RecessedGlassBed",r,0.42,smoke,M.Slate)
	-- The weathered outer hood stands proud of an inner roll. A dark undercut
	-- between them is real depth, visible when climbing the stair at an angle.
	for _,course in {{1.035,0.128,0.42,1.24},{0.925,0.064,0.74,0.61}} do
		for i=0,23 do
			local angle,nextAngle=i*math.pi/12,(i+1)*math.pi/12
			local radius=course[1]*r
			local a=V(math.sin(angle)*radius,math.cos(angle)*radius,course[3])
			local b=V(math.sin(nextAngle)*radius,math.cos(nextAngle)*radius,course[3])
			relief(cf,a,b,course[2]*r,course[4],if i%6==2 then stone else limestone,M.Limestone)
		end
	end
	for i=0,7 do
		local frame=cf*CFrame.Angles(0,0,i*math.pi/4)
		local tint=palette[i+1]
		local function pane(a: Vector3,b: Vector3,c: Vector3,color: Color3)
			faceTri(p,"PotMetalGlass",frame*C(0,0,0.53),a*r,b*r,c*r,0.1,color,M.SmoothPlastic)
		end
		local root, l, u, v, q, tip = V(0,0.12,0),V(-0.15,0.49,0),V(-0.167,0.64,0),
			V(0.167,0.64,0),V(0.15,0.49,0),V(0,0.883,0)
		pane(root,l,q,tint)
		pane(l,u,q,tint:Lerp(smoke,0.22))
		pane(u,v,q,tint:Lerp(ochre,0.11))
		pane(u,tip,v,tint)
		-- Split the returning ogives with a cusp facing in on each side. Fine
		-- lead cames divide the glass into individually coloured pieces below.
		for _,sign in {-1,1} do
			local profile={root,V(sign*0.114,0.33,0),V(sign*0.174,0.49,0),
				V(sign*0.171,0.565,0),V(sign*0.116,0.60,0),V(sign*0.162,0.65,0),tip}
			for j=1,#profile-1 do
				relief(frame*C(0,0,0.77),profile[j]*r,profile[j+1]*r,r*0.031,0.39,limestone,M.Limestone)
			end
			relief(frame*C(0,0,0.627),V(sign*0.142*r,0.49*r,0),V(0,0.405*r,0),r*0.011,0.10,iron,M.Metal)
		end
		relief(frame*C(0,0,0.625),u*r,q*r,r*0.011,0.1,iron,M.Metal)
		-- Small quatrefoil lights occupy the pockets between the larger petals.
		-- Four cut lobes sit into each raised stone spandrel.
		local eye=frame*CFrame.Angles(0,0,math.pi/8)*C(0,r*0.72,0)
		boss(eye*C(0,0,0.61),"QuatrefoilSpandrel",r*0.112,0.45,limestone,M.Limestone)
		for k=0,3 do
			local angle=k*math.pi/2
			boss(eye*C(math.cos(angle)*r*0.042,math.sin(angle)*r*0.042,0.852+k*0.002),
				"QuatrefoilEye",r*0.041,0.05,if i%2==0 then petrol else wine,M.SmoothPlastic)
		end
	end
	boss(cf*C(0,0,0.65),"OculusMould",r*0.131,0.52,limestone,M.Limestone)
	boss(cf*C(0,0,0.929),"Oculus",r*0.089,0.06,rgb(122,79,52),M.Neon)
end

local function buttress(p: Instance, frame: CFrame, extent: number)
	-- Exterior flyer runs from a freestanding counterfort up to the nave wall.
	box(p,"CounterfortPlinth",frame*C(extent,2.7,0),5.4,5.4,7.3,basal,M.Slate,true)
	box(p,"Counterfort",frame*C(extent,12,0),3.7,22,5.7,stone,M.Brick,true)
	box(p,"CounterfortCap",frame*C(extent,22.7,0),5.1,1.2,6.5,chalk)
	pinnacle(p,frame*C(extent,23.4,0),3.2,8)
	local a, b = V(extent,21,0), V(0,36,0)
	-- The straight weathering leads rain down above an arched underside.
	local mid = V(extent*0.55,30.9,0)
	rod(p,"FlyingWeathering",frame*a,frame*b,2.7,3.3,limestone)
	faceTri(p,"FlyingArchHaunch",frame,V(extent,16,0),a,mid,2.65,stone,M.Limestone)
	faceTri(p,"FlyingArchHaunch",frame,V(0,32.8,0),b,mid,2.65,stone,M.Limestone)
	rod(p,"FlyingArchRib",frame*V(extent,16.4,0),frame*mid,1.0,2.7,limestone)
	rod(p,"FlyingArchRib",frame*mid,frame*V(0,33,0),1.0,2.7,limestone)
end

local function pitchedRoof(p: Instance, f: CFrame, half: number, rise: number, run: number)
	local ridgeA, ridgeB = V(0,rise,0),V(0,rise,-run)
	for _,s in {-1,1} do
		local a,b = V(s*half,0,0),V(s*half,0,-run)
		local pitch = math.atan2(rise,half)*-s
		box(p,"NaveSlates",f*C(s*half/2,rise/2,-run/2)*CFrame.Angles(0,0,pitch),math.sqrt(half*half+rise*rise),1.25,run,
			if s==1 then slate else rgb(68,77,88),M.Slate)
		rod(p,"GableVerge",f*a,f*ridgeA,1.2,1.2,chalk)
		rod(p,"GableVerge",f*b,f*ridgeB,1.2,1.2,chalk)
		rod(p,"LeadGutter",f*a,f*b,1.1,1.1,lead,M.Metal)
		for i=1,4 do
			local z = -run*i/5
			rod(p,"LeadRoll",f*V(s*half,0.7,z),f*V(0,rise+0.7,z),0.35,0.35,lead,M.Metal)
		end
	end
	rod(p,"Cresting",f*ridgeA,f*ridgeB,1.0,1.0,copper,M.Metal)
end

local function nave(p: Instance, frame: CFrame)
	-- The keep's axial hall is a full-height inhabited structure. Separate the west
	-- doorway from the wall slabs so a returning player can use the gallery shortcut.
	portal(p,frame,17,9.5,10.5,21.5,5)
	box(p,"WestFrontClerestory",frame*C(0,32,-0.05),60,19.5,5,stone,M.Brick,true)
	faceTri(p,"FrontGable",frame,V(-30,41.5,0),V(30,41.5,0),V(0,68,0),4.5,stone,M.Brick)
	greatWheel(p,frame*C(0,32,2.7),6.4)
	for _,s in {-1,1} do
		-- Corner piers extend above the gable verges, articulating the west front.
		local pier = frame*C(s*28.2,0,2)
		box(p,"PortalPier",pier*C(0,21,0),5.3,42,7.8,limestone,nil,true)
		box(p,"PierSetback",pier*C(0,9,1.2),6.6,18,8.0,stone,nil,true)
		pinnacle(p,pier*C(0,42,0),5.1,12)
		local niche=frame*C(s*12.9,0,3.1)
		box(p,"FigureRecess",niche*C(0,6.9,-0.37),3.8,9.0,0.67,shadow,M.Slate)
		box(p,"ImageCorbel",niche*C(0,2.65,0.5),3.8,1.25,3.15,limestone)
		Pbr.place(p,"AsuraColossusStatue",niche*C(0,3.28,0.65)*CFrame.Angles(0,math.pi,0),6.6)
		box(p,"ImageCanopy",niche*C(0,10.7,0.39),4.05,0.72,3.4,chalk)
		spire(p,niche*C(0,11.04,0.35),2.6,3.8,4)
		local outer = frame*C(s*18.7,0,2.65)
		lancet(p,outer*C(0,23.5,0),4.0,12.8,s<0)
		-- Pilgrim doors at human scale make the adjacent monumental portal legible.
		box(p,"DoorSetback",outer*C(0,3.7,0.25),5.4,7.4,0.8,shadow,M.Slate)
		box(p,"OakenWicket",outer*C(0,3.5,0.71),4.15,7,0.25,timber,M.WoodPlanks)
		for _,y in {1.6,5.6} do box(p,"WicketStrap",outer*C(0,y,0.95),3.95,0.31,0.22,iron,M.Metal) end
		Props.brazier(p,frame*C(s*10.8,0,4.7),18)
	end
	portal(p,frame*C(0,0,-71.5),21,9,11,19.5,4)
	box(p,"NarthexRearSpandrel",frame*C(0,32,-71.5),60,20,4,stone,M.Brick,true)
	faceTri(p,"ApseGable",frame*C(0,0,-71.5),V(-30,41.5,0),V(30,41.5,0),V(0,68,0),4,stone,M.Brick)
	for _, s in {-1,1} do
		local wall = frame*C(s*29,0,0)
		if s==-1 then
			-- The return gallery meets the side porch between z=-2.5 and -14.5.
			box(p,"SideDoorLintel",wall*C(0,27,-8.5),4,29,14,stone,M.Brick,true)
			box(p,"AisleWall",wall*C(0,20.8,-43.5),4,41.6,57,stone,M.Brick,true)
			local porch = frame*C(-29,0,-8.7)*CFrame.Angles(0,-math.pi/2,0)
			arch(p,porch,6,7,5,1.2,5,13)
		else
			box(p,"AisleWall",wall*C(0,20.8,-36),4,41.6,72,stone,M.Brick,true)
		end
		box(p,"NaveStringcourse",wall*C(0,38.5,-35),5.8,1.2,72,limestone)
		for i,z in {-19,-39,-59} do
			local facing = frame*C(s*31.1,0,z)*CFrame.Angles(0,s*math.pi/2,0)
			lancet(p,facing*C(0,16.5,0),6.2,18.0,i==2 and s==-1)
			buttress(p,frame*C(s*30,0,z-5)*CFrame.Angles(0,if s==-1 then math.pi else 0,0),13)
			-- From within the two shaded side aisles, carved transverse ribs
			-- converge overhead. Their feet leave 30 studs across the central floor.
			local x = s*21
			box(p,"NaveColumnFoot",frame*C(x,0.8,z),4.5,1.6,4.8,basal,nil,true)
			box(p,"NaveColumn",frame*C(x,11,z),2.9,21,3.1,limestone,nil,true)
			box(p,"NaveCapital",frame*C(x,21.7,z),4.6,1.2,4.8,chalk)
			rod(p,"VaultRib",frame*V(x,22,z),frame*V(s*14,33,z),1.1,1.1,limestone)
			rod(p,"VaultRib",frame*V(s*14,33,z),frame*V(0,42,z),1.1,1.1,limestone)
		end
	end
	-- The visible masonry vault also shelters the hall. Its highest point is 43
	-- studs over the floor, below WeatherController's sixty-stud test.
	for _,s in {-1,1} do
		local profile = {V(30,23,0),V(21,23,0),V(14,34,0),V(0,43,0)}
		for i=1,#profile-1 do
			local a,b=profile[i],profile[i+1]
			local center=(a+b)/2
			local tilt=-s*math.atan2(b.Y-a.Y,a.X-b.X)
			local ceiling=box(p,"NaveVault",frame*C(s*center.X,center.Y,-36)*CFrame.Angles(0,0,tilt),
				(b-a).Magnitude+0.1,1.1,72,basal,M.Limestone,true)
			CollectionService:AddTag(ceiling,"AsuraShelter")
		end
	end
	pitchedRoof(p,frame*C(0,41.7,3.8),32.5,28,80)
	-- Side altar keeps the processional axis open through the narthex into the cathedral.
	local altar = frame*C(16,0,0)
	box(p,"Dais",altar*C(0,0.45,-59),22,0.9,12,limestone,nil,true)
	box(p,"VotiveTable",altar*C(0,2.0,-61),10,2.5,3.5,basal,nil,true)
	box(p,"VotiveSlab",altar*C(0,3.45,-61),11.2,0.6,4.2,chalk)
	greatWheel(p,altar*C(0,15.8,-69.2),6)
	for i=0,6 do
		local h = 0.8+((i*3)%5)*0.21
		local cf = altar*C((i-3)*1.15,3.75,-61+(i%2)*0.5)
		box(p,"Tallow",cf*C(0,h/2,0),0.33,h,0.33,chalk,M.SmoothPlastic)
		if i==1 or i==5 then
			local flame = box(p,"VotiveFlame",cf*C(0,h+0.18,0),0.18,0.36,0.18,glass,M.Neon)
			Kit.light(flame,rgb(244,168,97),15,0.7,false)
		end
	end
	for _,s in {-1,1} do
		for _,z in {-22,-37,-52} do Props.bench(p,frame*C(s*12.5,0,z)) end
	end
end

local function lantern(p: Instance, frame: CFrame)
	-- Four masonry ribs carry the high crossing lantern over the ridgeline.
	octagonal(p,frame,17.5,50,stone,M.Brick)
	for _,y in {17,35,48} do
		octagonal(p,frame*C(0,y,0),18.2,1.5,if y==48 then chalk else limestone,M.Limestone)
	end
	for i=0,7 do
		local bay = frame*CFrame.Angles(0,i*math.pi/4,0)*C(0,0,16)
		lancet(p,bay*C(0,21,0),6,17,i%3==0)
		box(p,"CrownPier",bay*C(-6.4,53.3,-1),2.8,11.5,3.2,limestone)
	end
	octagonal(p,frame*C(0,58.6,0),17.8,2.2,chalk,M.Limestone)
	-- Set the octagonal lantern back twice. The tall needle is framed by four
	-- freestanding, crocketed corner spires silhouetted against sky.
	hips(p,frame*C(0,60.5,0),20,10.8,15,8)
	octagonal(p,frame*C(0,75.3,0),10.8,12,basal,M.Brick)
	octagonal(p,frame*C(0,86.7,0),11.8,1.2,limestone,M.Limestone)
	for i=0,3 do
		lancet(p,frame*CFrame.Angles(0,i*math.pi/2,0)*C(0,76.8,10),3.4,8.6,false)
	end
	spire(p,frame*C(0,87.8,0),13.1,52,8,true)
	box(p,"FinialStem",frame*C(0,142.8,0),0.52,8.5,0.52,iron,M.Metal)
	box(p,"FinialVane",frame*C(0,144.2,0)*CFrame.Angles(0,0,math.rad(14)),5,0.55,0.45,copper,M.Metal)
	for _,x in {-14,14} do
		for _,z in {-14,14} do
			local corner = frame*C(x,0,z)
			box(p,"CrossingCorner",corner*C(0,32,0),4.3,65,4.3,limestone)
			box(p,"PinnacleTabernacle",corner*C(0,65.4,0),5.4,5.8,5.4,stone,M.Brick)
			box(p,"PinnacleDrip",corner*C(0,68.5,0),6.3,0.7,6.3,chalk)
			spire(p,corner*C(0,68.9,0),4.8,22,4,true)
			for tier=1,3 do
				local k = 1-tier*0.18
				for _,sign in {-1,1} do
					rod(p,"Crocket",corner*V(sign*2.4*k,69+tier*4,0),corner*V(sign*(2.4*k+1),71+tier*4,0),0.55,0.7,limestone)
				end
			end
		end
	end
end

local function bellTower(p: Instance, cf: CFrame)
	box(p,"BellTowerBase",cf*C(0,24,0),20,52,19,stone,M.Brick,true)
	for _, x in {-8.9,8.9} do
		for _,z in {-8.5,8.5} do
			box(p,"BellTowerQuoin",cf*C(x,26,z),3.0,54,3.0,limestone)
			box(p,"BellPier",cf*C(x,62,z),3.5,21,3.5,limestone)
		end
	end
	box(p,"BellSill",cf*C(0,50.7,0),22.8,2.3,21.8,chalk)
	box(p,"BellCrown",cf*C(0,73,0),23,2.4,22.8,chalk)
	for i=0,3 do
		arch(p,cf*CFrame.Angles(0,i*math.pi/2,0)*C(0,55.7,8.8),6.9,7.3,8.6,1.05,2,16.5)
	end
	box(p,"BellYoke",cf*C(0,68,0),15,1.1,1.2,timber,M.Wood)
	Kit.disc(p,"BellShoulder",3.9,4.3,cf*C(0,63.5,0),copper,M.Metal,decor)
	Kit.disc(p,"BellLip",5.1,1.5,cf*C(0,61,0),copper,M.Metal,decor)
	box(p,"Clapper",cf*C(0,59.9,0),1,2,1,iron,M.Metal)
	spire(p,cf*C(0,74,0),16.9,25,4,true)
	for _,s in {-1,1} do
		lancet(p,cf*C(s*4.4,25,9.7),3.5,15,false)
	end
end


-- The winter minster is a later, far larger building behind the military narthex.
-- Open crowns and deep-set stone cores leave sky between the fine outer ribs.
local soot = rgb(76,75,74)
local ash = rgb(104,104,99)
local ashLight = rgb(126,124,115)
local oldLead = rgb(62,72,76)

local function shaft(p: Instance, f: CFrame, name: string, w: number, h: number, d: number, color: Color3, solid: boolean?): BasePart
	local piece = box(p,name,f*C(0,h/2,0),w,h,d,color,M.Slate,solid)
	piece.MaterialVariant = Kit.Surface.Stone.Variant
	return piece
end

local function line(p: Instance, f: CFrame, name: string, a: Vector3, b: Vector3, width: number, color: Color3)
	rod(p,name,f*a,f*b,width,width,color,M.Limestone)
end

-- Two-centred tracery light. Unlike a flat pointed overlay this is a freestanding
-- set of carved members. It is shared by belfry openings, high galleries and spires.
local function tracery(p: Instance, f: CFrame, half: number, sill: number, spring: number, peak: number, width: number, color: Color3)
	for _,s in {-1,1} do
		local a,b,c = V(s*half,spring,0),V(s*half*0.71,spring+(peak-spring)*0.58,0),V(0,peak,0)
		if spring>sill then box(p,"TraceryShaft",f*C(s*half,(spring+sill)/2,0),width,spring-sill,width,color) end
		line(p,f,"TraceryHaunch",a,b,width,color)
		line(p,f,"TraceryPoint",b,c,width,color)
	end
end

local function ring(p: Instance, f: CFrame, name: string, radius: number, y: number, thickness: number, color: Color3)
	for i=0,7 do
		local a,b=(i+0.5)*math.pi/4,(i+1.5)*math.pi/4
		line(p,f,name,V(radius*math.sin(a),y,radius*math.cos(a)),V(radius*math.sin(b),y,radius*math.cos(b)),thickness,color)
	end
end

local function stoneNeedle(p: Instance, f: CFrame, w: number, h: number)
	-- Carved corner tabernacle, a hollow canopy and a slender weathered finial.
	shaft(p,f,"Tabernacle",w,h*0.18,w,ash)
	for _,x in {-1,1} do for _,z in {-1,1} do
		box(p,"CanopyColonette",f*C(x*w*0.36,h*0.295,z*w*0.36),w*0.17,h*0.23,w*0.17,ashLight)
	end end
	box(p,"CanopyCorbel",f*C(0,h*0.415,0),w*1.13,h*0.032,w*1.13,ashLight)
	local cap=f*C(0,h*0.43,0)
	local top=V(0,h*0.57,0)
	for i=0,3 do
		local a,b=(i+0.5)*math.pi/2,(i+1.5)*math.pi/2
		local ba,bb=V(w*0.76*math.sin(a),0,w*0.76*math.cos(a)),V(w*0.76*math.sin(b),0,w*0.76*math.cos(b))
		faceTri(p,"PinnacleStone",cap,ba,bb,top,0.32,if i%2==0 then ash else ashLight,M.Limestone)
	end
end

local function towerFoot(p: Instance, f: CFrame, sign: number)
	-- Squat, battered lowest stage. The clustered piers emerge from it and
	-- carry the upper tower through several successive setbacks.
	shaft(p,f,"WestTowerPlinth",75,7,67,basal,true)
	shaft(p,f*C(0,7,-1),"TowerLowerStage",68,96,58,ash,true)
	for i=0,3 do
		local face=f*CFrame.Angles(0,i*math.pi/2,0)*C(0,0,if i%2==0 then 28.5 else 33.7)
		lancet(p,face*C(-7.6,27,1.1),10.8,49,false)
		lancet(p,face*C(7.6,27,1.1),10.8,49,false)
		tracery(p,face*C(0,0,1.5),15.5,24,63,91,1.3,ashLight)
	end
	for _,x in {-1,1} do for _,z in {-1,1} do
		local corner=f*C(x*31.3,0,z*27.5)
		shaft(p,corner,"BundledPier",12,112,12,soot,true)
		shaft(p,corner*C(x*3.5,0,z*3.5),"ButtressFoot",11,59,11,ash,true)
		shaft(p,corner*C(x*6.6,0,z*6.6),"SteppedButtress",10,29,10,ashLight,true)
		shaft(p,corner*C(x*4,58,z*4),"ButtressOffset",7.3,69,7.3,ashLight)
		stoneNeedle(p,corner*C(x*4,126,z*4),7.3,30)
	end end
	box(p,"LowerGalleryCornice",f*C(0,105,0),70,3.4,60,ashLight)
	-- Soot washes and small old repairs sit in the recesses beneath the first cornice.
	for i=-2,2 do
		local x=i*6.8
		local h=7+(i+2)*2.7
		box(p,"Rainwash",f*C(x,102-h/2,28.28),1.1+(i%2),h,0.18,soot,M.Slate)
	end
	local saint=f*C(sign*21,10,30)
	box(p,"StatueCorbel",saint*C(0,-1.2,0),6.7,2.4,6.1,ashLight)
	Pbr.place(p,"AsuraColossusStatue",saint*CFrame.Angles(0,math.pi,0),13)
	stoneNeedle(p,saint*C(0,13.4,0),5.8,12)
end

local function belfryStage(p: Instance, f: CFrame, r: number, h: number, lower: boolean)
	-- Each side carries paired subordinate lancets beneath one larger pointed arch.
	local faceR=r*math.cos(math.pi/8)
	local half=r*math.sin(math.pi/8)
	-- The octagonal masonry core steps in behind the window jambs.
	local inner=r*(if lower then 0.82 else 0.73)
	octagonal(p,f,inner,h*0.86,soot,M.Slate)
	octagonal(p,f*C(0,h*0.855,0),inner*0.9,h*0.15,ash,M.Slate)
	for side=0,3 do
		local sideFace=f*CFrame.Angles(0,side*math.pi/2,0)*C(0,0,inner*math.cos(math.pi/8))
		for _,s in {-1,1} do
			box(p,"BlindLanternRecess",sideFace*C(s*inner*0.20,h*0.39,0.28),inner*0.25,h*0.65,0.65,shadow,M.Slate)
			tracery(p,sideFace*C(s*inner*0.20,h*0.07,0.8),inner*0.14,0,h*0.52,h*0.74,1.35,ashLight)
		end
	end
	for i=0,7 do
		local angle=i*math.pi/4
		local face=f*CFrame.Angles(0,angle,0)*C(0,0,faceR)
		local corner=face*C(half,0,0)
		shaft(p,corner,"LanternPier",if lower then 6.3 else 4.1,h+1,if lower then 6.3 else 4.1,ash)
		tracery(p,face,half-1.5,0,h*0.66,h*0.955,if lower then 2.85 else 2.0,ashLight)
		-- Paired lancets leave large fields of open sky around the bell frame.
		local sub=half*0.44
		for _,s in {-1,1} do tracery(p,face*C(s*sub,0,0.7),sub,0,h*0.44,h*0.68,if lower then 1.35 else 1.0,soot) end
	end
	ring(p,f,"PierHeadRing",r,h-0.6,3.3,ashLight)
	ring(p,f,"BellGallerySill",r,0,3.0,ashLight)
end

local function openSpire(p: Instance, f: CFrame, radius: number, height: number, broken: boolean)
	-- Octagonal curved taper. Each lift contains a forked quatrefoil-like lattice,
	-- with diminishing members towards the crown.
	local levels={ {0,1},{0.23,0.79},{0.46,0.56},{0.67,0.33},{0.835,0.17},{0.96,0.045} }
	for j=1,#levels-1 do
		local lo,hi=levels[j],levels[j+1]
		local y0,y1=lo[1]*height,hi[1]*height
		local r0,r1=lo[2]*radius,hi[2]*radius
		local width=math.max(0.95,4.25*(1-lo[1]))
		-- A recessed, tapered stone backing catches the colour of the sky
		-- between its pilasters. Opening an entire row at every spring point
		-- keeps true pierced bands around a substantially solid silhouette.
		local coreHeight=(y1-y0)*(if j<4 then 0.86 else 1)
		local shrink=if j==1 then 0.83 else 0.79
		hips(p,f*C(0,y0,0),r0*shrink,(r0+(r1-r0)*coreHeight/(y1-y0))*shrink,coreHeight,8)
		ring(p,f,"OpenworkBelt",r0,y0,width,if j%2==0 then soot else ashLight)
		for i=0,7 do
			local angle=(i+0.5)*math.pi/4
			local nextAngle=angle+math.pi/4
			local a=V(math.sin(angle),0,math.cos(angle))
			local b=V(math.sin(nextAngle),0,math.cos(nextAngle))
			local p0,p1=a*r0+V(0,y0,0),a*r1+V(0,y1,0)
			local q0,q1=b*r0+V(0,y0,0),b*r1+V(0,y1,0)
			line(p,f,"SpireRib",p0,p1,width,ashLight)
			if j<5 then
				local fork=(p1+q1)*0.5
				local left=p0:Lerp(p1,0.42)
				local right=q0:Lerp(q1,0.42)
				line(p,f,"SpireTrefoil",left,fork,width*0.5,ash)
				line(p,f,"SpireTrefoil",right,fork,width*0.5,ash)
				if j<3 then
					local mid=(p0+q0)*0.5
					line(p,f,"SpireMullion",mid,mid:Lerp(fork,0.55),width*0.48,ash)
					line(p,f,"TraceryFork",mid:Lerp(fork,0.55),left:Lerp(fork,0.4),width*0.43,ashLight)
					line(p,f,"TraceryFork",mid:Lerp(fork,0.55),right:Lerp(fork,0.4),width*0.43,ashLight)
				end
			end
			if i%2==0 and j<5 then
				local root=p0:Lerp(p1,0.5)
				line(p,f,"SpireCrocket",root,root+a*width*1.5+V(0,width*2.1,0),width*0.75,ashLight)
			end
		end
	end
	spire(p,f*C(0,height*0.833,0),radius*0.175,height*0.174,8,true)
	local tip=f*C(0,height*0.954,0)
	stoneNeedle(p,tip,2.4,height*0.051)
	local endY=height*1.006
	box(p,"IronFleche",f*C(0,endY+2.4,0),0.65,8,0.65,iron,M.Metal)
	if not broken then
		box(p,"MeteorologicalCross",f*C(0,endY+4.5,0),4.8,0.8,0.8,copper,M.Metal)
	end
end

local function cathedralTower(p: Instance, f: CFrame, sign: number)
	towerFoot(p,f,sign)
	-- Four square buttress piers rise behind the projecting stair turrets. From
	-- ground level the tall belfries read as one continuous vertical composition.
	local upper=f*C(0,106,0)
	shaft(p,upper,"ClockTowerCore",45,94,40,soot)
	shaft(p,upper*C(0,94,0),"ClockTowerSetback",41,26,36,soot)
	for i=0,3 do
		local side=upper*CFrame.Angles(0,i*math.pi/2,0)*C(0,0,if i%2==0 then 20.3 else 22.8)
		for _,s in {-1,1} do
			box(p,"GreatBelfryRecess",side*C(s*8.5,58,0),10.5,62,0.6,shadow,M.Slate)
			tracery(p,side*C(s*8.5,23.5,0.7),5.5,0,64,86,1.1,ashLight)
		end
	end
	for _,x in {-1,1} do for _,z in {-1,1} do
		local corner=upper*C(x*25.5,0,z*23.3)
		shaft(p,corner,"BelfryCluster",9.5,136,9.5,soot)
		shaft(p,corner*C(x*2.8,0,z*2.5),"BelfryFillet",4.2,137,4.2,ashLight)
		stoneNeedle(p,corner*C(0,136,0),9.6,54)
	end end
	-- Two tall, recessed front lights fill the lower, more solid clock stage.
	for i=0,3 do
		local face=upper*CFrame.Angles(0,i*math.pi/2,0)*C(0,0,if i%2==0 then 23.3 else 25.5)
		tracery(p,face,21.8,0,72,117,4.0,ashLight)
		for _,s in {-1,1} do
			tracery(p,face*C(s*10,0,1.3),9.3,1.3,51,81,2.3,ash)
		end
		if i==0 or i==2 then
			box(p,"ShadowedLouvreField",face*C(0,36,-5.5),38,67,1,soot,M.WoodPlanks)
			for j=1,5 do box(p,"BelfryOakLouvre",face*C(0,7+j*8,-4.45)*CFrame.Angles(math.rad(18),0,0),38.2,1.4,2.4,timber,M.Wood) end
		end
	end
	ring(p,upper,"BelfryCoping",35,119,3.4,ashLight)
	hips(p,upper*C(0,115,0),39,34,12,8)
	local first=upper*C(0,120,0)
	belfryStage(p,first,34.5,83,true)
	-- The perimeter stair turrets spring from the tower's square corner
	-- buttresses and climb in staggered groups into the octagonal belfry.
	for _,x in {-1,1} do for _,z in {-1,1} do
		local shoulder=first*C(x*23,0,z*23)
		shaft(p,shoulder,"OctagonStairTurret",11,63,11,soot)
		shaft(p,shoulder*C(x*1.4,0,z*1.4),"TurretCornerRoll",5.8,70,5.8,ashLight)
		stoneNeedle(p,shoulder*C(0,63,0),12,74)
	end end
	hips(p,first*C(0,79,0),34,28.5,11,8)
	local second=first*C(0,83,0)
	belfryStage(p,second,28.5,81,false)
	-- Pinacles frame the whittled octagonal crown; their roofs frame actual sky.
	for i=0,7 do
		local angle=(i+0.5)*math.pi/4
		local u=V(math.sin(angle),0,math.cos(angle))
		local outrigger=first*C(u*34)
		shaft(p,outrigger,"CrownCounterfort",4.5,86,4.5,ash)
		stoneNeedle(p,outrigger*C(0,86,0),6.7,if i%2==0 then 55 else 37)
	end
	local crown=second*C(0,81,0)
	ring(p,crown,"CrownSill",32,0,4.0,ashLight)
	hips(p,crown*C(0,-4.7,0),30.8,36.3,5.4,8)
	openSpire(p,crown,36.7,if sign==-1 then 280 else 258,sign==1)
end

local function glassBay(p: Instance, f: CFrame, half: number, h: number)
	-- Three slowly changing bands of stained glass are set back behind the hood and
	-- separated by deep stone mullions. The patterned openings read on both faces.
	local lightColors={rgb(75,106,111),rgb(116,70,66),rgb(114,106,79)}
	local spring=h*0.66
	box(p,"ClerestoryRecess",f*C(0,spring/2,-1.8),2*half,spring,0.75,shadow,M.Slate)
	faceTri(p,"ClerestoryHead",f*C(0,0,-1.8),V(-half,spring,0),V(half,spring,0),V(0,h,0),0.8,shadow,M.Slate)
	for i=-1,1 do
		local x=i*half*0.65
		local paneH=spring*(if i==0 then 1.1 else 0.84)
		local tint=lightColors[i+2]
		box(p,"AntiqueGlass",f*C(x,paneH/2,-1.28),half*0.55,paneH,0.25,tint,M.SmoothPlastic)
		faceTri(p,"GlassLightHead",f*C(x,0,-1.28),V(-half*0.275,paneH,0),V(half*0.275,paneH,0),
			V(0,paneH+half*0.48,0),0.28,tint,M.SmoothPlastic)
		for j=1,3 do
			box(p,"SaddleBar",f*C(x,paneH*j/4,-1.02),half*0.6,0.33,0.38,iron,M.Metal)
		end
	end
	tracery(p,f,half,0,spring,h,math.max(0.8,half*0.13),ashLight)
	for _,s in {-1,1} do
		tracery(p,f*C(s*half*0.48,0,0),half*0.48,0,spring*0.76,spring*1.08,math.max(0.5,half*0.064),ash)
	end
end

local function stoneGable(p: Instance, f: CFrame, half: number, rise: number)
	faceTri(p,"BrokenGable",f,V(-half,0,0),V(half,0,0),V(0,rise,0),4.3,soot,M.Slate)
	for _,s in {-1,1} do
		local foot,tip=V(s*half,0,2.4),V(0,rise,2.4)
		line(p,f,"CarvedGableVerge",foot,tip,2.35,ashLight)
		for k=1,5 do
			local at=foot:Lerp(tip,k/6)
			line(p,f,"GableCrocket",at,at+V(s*1.5,2.9,0),1.1,ash)
		end
	end
	stoneNeedle(p,f*C(0,rise,0),3.8,12)
end

local function westFront(p: Instance, f: CFrame)
	portal(p,f,38,24,26,25,12)
	arch(p,f*C(0,0,7.6),21,24,29,2.1,3.6)
	arch(p,f*C(0,0,9.3),23.4,24,31.8,1.95,2.3)
	stoneGable(p,f*C(0,43,7.8),31,32)
	for _,s in {-1,1} do
		shaft(p,f*C(s*35.8,0,0),"WestFacadePier",14,155,15,soot,true)
		shaft(p,f*C(s*35.8,0,8.7),"Respond",7.2,148,6.5,ash)
		shaft(p,f*C(s*38.2,0,13.6),"PortalButtress",7.6,69,9.8,ashLight,true)
		stoneNeedle(p,f*C(s*38.2,69,13.6),8,37)
		stoneNeedle(p,f*C(s*35.8,150,7.5),9.5,49)
		local shrine=f*C(s*27.8,0,9.2)
		shaft(p,shrine,"FigurePedestal",6.4,4,6.3,ash,true)
		Pbr.place(p,"AsuraColossusStatue",shrine*C(0,4.2,0)*CFrame.Angles(0,math.pi,0),14)
		stoneNeedle(p,shrine*C(0,18.6,0),5.9,12)
	end
	-- Deep central recess: daylight enters through a monumental tracery window
	-- while the two towers remain the dominant elements of the west front.
	for _,s in {-1,1} do
		shaft(p,f*C(s*28.8,54,0),"GreatWindowReveal",8.2,96,12,ash,true)
		shaft(p,f*C(s*22.5,53,0),"GreatWindowJamb",4.4,46,10.5,ashLight)
	end
	box(p,"TriforiumSill",f*C(0,57,0),75,3,15,ashLight,nil,true)
	glassBay(p,f*C(0,60,0),22.2,86)
	greatWheel(p,f*C(0,119,1.4),9.1)
	box(p,"GableCorbel",f*C(0,149,0),81,4,16,ashLight)
	stoneGable(p,f*C(0,150,0),44,53)
	for k=-3,3 do
		local h=25-math.abs(k)*4.4
		tracery(p,f*C(k*6.1,150,2.9),2.65,0,h*0.62,h,0.85,ashLight)
	end
end

local function cathedralFlyer(p: Instance, f: CFrame)
	-- Local +X runs out from the wall. The two open arcs are at different
	-- levels, the lower one receives the thrust of the aisle and the upper one
	-- receives the main vault. Snow settles on their stepped weatherings.
	shaft(p,f*C(38,0,0),"Abutment",11.5,46,13.5,soot,true)
	shaft(p,f*C(37.2,46,0),"AbutmentSetback",8.8,32,10.1,ash)
	shaft(p,f*C(36.2,78,0),"AbutmentHead",6,18,7.5,ashLight)
	stoneNeedle(p,f*C(36.2,96,0),6.4,34)
	for _,tier in {{42,73},{73,113}} do
		local low,high=tier[1],tier[2]
		local a,b,c=V(36.5,low,0),V(19,low+(high-low)*0.82,0),V(0,high,0)
		line(p,f,"FlyerWeathering",a+V(0,8,0),c+V(0,5,0),3.2,ashLight)
		line(p,f,"FlyerIntrados",a,b,3.7,ash)
		line(p,f,"FlyerIntrados",b,c,3.2,ash)
		faceTri(p,"FlyerSpandrel",f,a,a+V(0,8,0),b,3.4,soot,M.Slate)
		faceTri(p,"FlyerSpandrel",f,c,c+V(0,5,0),b,3.4,soot,M.Slate)
	end
end

local function vaultDeck(p: Instance, f: CFrame, half: number, eave: number, crown: number, run: number)
	local midY=eave+(crown-eave)*0.62
	local profile={V(half,eave,0),V(half*0.66,midY,0),V(0,crown,0)}
	for _,s in {-1,1} do for i=1,2 do
		local a,b=profile[i],profile[i+1]
		local center=(a+b)*0.5
		local tilt=-s*math.atan2(b.Y-a.Y,a.X-b.X)
		local stonework=box(p,"CathedralVault",f*C(s*center.X,center.Y,-run/2)*CFrame.Angles(0,0,tilt),
			(b-a).Magnitude+0.3,1.8,run,ash,M.Limestone,true)
		CollectionService:AddTag(stonework,"AsuraShelter")
	end end
end

local function highNave(p: Instance, f: CFrame)
	-- Four lateral arcades articulate the long choir; a fifth bay is opened up
	-- as the crossing. Its arms project beyond the entire width of the west front.
	local run=208
	for _,s in {-1,1} do
		local rotation=if s==1 then math.pi/2 else -math.pi/2
		for i=1,6 do
			local z= -((i-0.5)*34)
			local bay=f*C(s*47.5,0,z)*CFrame.Angles(0,rotation,0)
			-- The long clerestory physically recesses the stained lights between piers.
			for _,k in {-1,1} do
				shaft(p,bay*C(k*15.3,64,0),"ClerestoryJamb",3.9,64,6.3,soot)
			end
			box(p,"ClerestorySill",bay*C(0,66,0),34,6,6.6,ash)
			box(p,"ClerestoryLintel",bay*C(0,123.5,0),34,8.7,6.6,soot)
			glassBay(p,bay*C(0,69.1,1),11.5,49.3)
			if i~=3 and i~=4 then
				tracery(p,bay,15.1,0,40,63.5,3.3,ashLight)
			elseif i==3 then
				local crossing=f*C(s*47.5,0,-102)*CFrame.Angles(0,rotation,0)
				tracery(p,crossing,31,0,37,66,4.5,ashLight)
			end
			if i~=3 then
				local pillar=f*C(s*47.5,0,z-17)
				shaft(p,pillar,"NaveCompoundPier",7.2,129,7.2,soot,true)
				shaft(p,pillar*C(-s*3.1,0,0),"VaultRespond",3,112,3,ashLight,true)
			end
			local outer=f*C(s*80,0,z)*CFrame.Angles(0,rotation,0)
			if i~=3 and i~=4 then
				box(p,"OuterAisleWall",outer*C(0,20,0),34.1,40,5,ash,M.Brick,true)
				lancet(p,outer*C(0,13,2.6),8,20,i==6)
			end
			-- The aisle lean-to rises into the main arcade without floating eaves.
			local aisle=box(p,"AisleRoof",f*C(s*63.5,52,z)*CFrame.Angles(0,0,-s*math.atan2(23,35)),
				math.sqrt(35^2+23^2),1.6,34.3,slate,M.Slate,true)
			CollectionService:AddTag(aisle,"AsuraShelter")
			if i~=3 and i~=4 then
				cathedralFlyer(p,f*C(s*48,0,z-3)*CFrame.Angles(0,if s==1 then 0 else math.pi,0))
			end
			local a=V(s*45,113,z-17)
			local middle=V(s*31,137,z-8)
			line(p,f,"VaultDiagonal",a,middle,2.15,ashLight)
			line(p,f,"VaultDiagonal",middle,V(0,153,z),1.95,ashLight)
		end
	end
	vaultDeck(p,f,47.5,114,153.8,run)
	pitchedRoof(p,f*C(0,128.5,0),51,39.6,run)
	box(p,"ChoirScreen",f*C(0,58,-run),99,116,6,soot,M.Brick,true)
	faceTri(p,"EasternGable",f*C(0,0,-run),V(-48,116,0),V(48,116,0),V(0,166,0),5,ash,M.Slate)
	greatWheel(p,f*C(0,80,-run+3.5),15)
	for _,s in {-1,1} do
		lancet(p,f*C(s*26,35,-run+3.2),11,50,true)
		tracery(p,f*C(s*26,35,-run+4.2),6.3,0,49,62,1.65,ashLight)
		Pbr.place(p,"AsuraColossusStatue",f*C(s*27,1.3,-run+11)*CFrame.Angles(0,math.pi,0),19)
	end
	box(p,"ChoirDaisStep",f*C(0,0.24,-run+18),38,0.48,15,ashLight,nil,true)
	box(p,"ChoirDais",f*C(0,0.64,-run+15.5),34,0.8,12,ash,nil,true)
	box(p,"Mensa",f*C(0,2.1,-run+13.8),10.7,2.5,3.5,soot,nil,true)
	box(p,"MensaLid",f*C(0,3.6,-run+13.8),11.8,0.6,4.2,ashLight)
	for i=1,6 do
		local x=(i-3.5)*1.48
		local y=if i%3==0 then 1.35 else 0.82
		box(p,"VotiveWax",f*C(x,3.9+y/2,-run+13.8),0.42,y,0.42,chalk,M.SmoothPlastic)
		if i~=2 then
			local wick=box(p,"Votive",f*C(x,4.09+y,-run+13.8),0.2,0.35,0.19,glass,M.Neon)
			if i==4 then Kit.light(wick,rgb(213,145,89),21,0.8,false) end
		end
	end
	for _,s in {-1,1} do
		for i=1,4 do
			local side=f*C(s*22,0,-36*i)
			Props.bench(p,side)
			if i==1 or i==4 then Props.brazier(p,side*C(s*8,0,0),27) end
		end
	end
end

local function transept(p: Instance, f: CFrame)
	-- Two transverse arms connect to the aisle where the outer wall is omitted.
	-- Their brightly lit end windows close a clear east–west vista across the crossing.
	for _,s in {-1,1} do
		local fArm=f*C(s*165,0,-101)*CFrame.Angles(0,s*math.pi/2,0)
		shaft(p,fArm,"TranseptFront",61,84,6,soot,true)
		stoneGable(p,fArm*C(0,84,0),32,36)
		glassBay(p,fArm*C(0,17,3.5),15.6,58)
		greatWheel(p,fArm*C(0,59,4.7),7.5)
		glassBay(p,fArm*C(0,17,-3.3)*CFrame.Angles(0,math.pi,0),15.6,58)
		for _,k in {-1,1} do
			local side=fArm*C(k*29.5,0,-43)
			shaft(p,side,"TranseptReturn",4.2,72,85,ash,true)
			stoneNeedle(p,fArm*C(k*27.8,69,0),6,35)
			for j=1,2 do
				local q=fArm*C(k*31.7,18,-j*31)*CFrame.Angles(0,k*math.pi/2,0)
				lancet(p,q,8.1,38,false)
			end
		end
		pitchedRoof(p,fArm*C(0,73,1.8),32,36,91)
		-- The lower crossing roof catches snowfall below the main vault.
		vaultDeck(p,fArm,29.5,55,72.5,88)
	end
end

local function highCathedral(castle: Instance, origin: CFrame)
	local terrace=section(castle,"CathedralClose")
	-- Each plinth sits on the extended escarpment; the choir and transept have
	-- different footprints so the ridge still shows between the buttresses.
	for _,slab in {{252,-225.5,55},{202,-265,24},{342,-312,70},{202,-386.5,79}} do
		local f=origin*C(0,-12,slab[2])
		shaft(terrace,f,"CathedralRetainingWall",slab[1],23.8,slab[3],basal,true)
		Kit.slab(terrace,"WornCloseSetts",V(slab[1],0.42,slab[3]),origin*C(0,11.79,slab[2]),"Paving")
	end
	local front=origin*C(0,12,-210)
	westFront(section(castle,"GreatWestFront"),front)
	for _,s in {-1,1} do
		cathedralTower(section(castle,if s==-1 then "SpireOfTheFirstKing" else "SpireOfTheLastKing"),
			origin*C(s*76,12,-228),s)
	end
	highNave(section(castle,"SepulchralChoir"),front)
	transept(section(castle,"TranseptOfExiles"),front)
end

function Citadel.build(parent: Instance, origin: CFrame): Model
	local castle = Instance.new("Model")
	castle.Name = "Vesperhold"
	castle.WorldPivot = origin
	local gate = section(castle,"Gatehouse")
	gatehouse(gate,origin)
	outerWard(section(castle,"PilgrimsWard"),origin)
	local keep = section(castle,"HighKeep")
	nave(keep,origin*C(0,12,-121))
	lantern(section(castle,"CrossingLantern"),origin*C(0,65,-159))
	bellTower(section(castle,"MourningBelfry"),origin*C(-57,12,-170))
	tower(section(castle,"ArchivistsNeedle"),origin*C(57,12,-151),10.7,78,46,true)
	-- The archive's enclosed bridge spans the leeward terrace well above head height.
	local crossing = section(castle,"ArchiveBridge")
	box(crossing,"BridgeDeck",origin*C(44,44,-151),27,2.4,8,basal,M.Slate,true)
	for _,s in {-1,1} do
		local base = origin*C(44,45,-151+s*3.7)
		box(crossing,"BridgeParapet",base*C(0,1.3,0),27,2.6,1.1,limestone)
		for i=-1,1 do arch(crossing,base*C(i*8.3,2.5,0),3.8,3,4.6,0.68,1.2) end
	end
	box(crossing,"GalleryRoof",origin*C(44,55,-151),28.5,1.45,10,slate,M.Slate)
	highCathedral(castle,origin)
	castle.Parent = parent
	return castle
end

return table.freeze(Citadel)
