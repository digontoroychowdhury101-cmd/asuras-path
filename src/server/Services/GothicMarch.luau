--!strict
-- The east fork from Snow Refuge. Coordinates are local to the castle threshold, in studs.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath").Shared
local Overworld = require(Shared.Overworld)
local Layout = require(Shared.VesperholdLayout)
local Kit = require(script.Parent.MonasteryKit)
local Decor = require(script.Parent.RegionDecor)
local SanctuaryKit = require(script.Parent.SanctuaryKit)

local Pbr = require(script.Parent.PbrAssets)
local VespKit = require(script.Parent.VesperholdKit) :: any

local March = {}
local V, F, A = Vector3.new, CFrame.new, CFrame.Angles
local rad, rgb, M = math.rad, Color3.fromRGB, Enum.Material
local slate, trim, lime = rgb(102,108,113), rgb(147,149,145), rgb(171,169,154)
local cap, rock, gravel = rgb(91,98,102), rgb(92,102,109), rgb(116,112,106)
local oak, iron, rust = rgb(100,81,66), rgb(71,72,73), rgb(129,84,64)
local deco = { Collide = false, Query = false }
local lane = Layout.Lane -- shared with the layout so the dead trees follow the road
-- Trestle followed by a cliff gallery, turning back to the east postern.
local postern = {
	V(0,-20,183), V(31,-23,178), V(59,-26,151), V(77,-23,122), V(96,-18,101),
	V(114,-13,72), V(124,-9,38), V(132,-6,11), V(132,-4,-19), V(115,0,-48), V(78,0,-48),
}

local function group(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name, m.Parent = name,parent
	return m
end

local function ground(origin: CFrame, x: number, z: number): number
	local w = origin * V(x,0,z)
	return Overworld.surfaceAt(w.X,w.Z) - origin.Y
end

-- Sample the footprint on the same canonical terrain used by the voxel writer.
local function foundation(o: CFrame,x: number,z: number,yaw: number,width: number,depth: number): (number,number)
	local localFrame=F(x,0,z)*A(0,rad(yaw),0)
	local low,high=math.huge,-math.huge
	for _,u in {-0.5,0,0.5} do
		for _,v in {-0.5,0,0.5} do
			local p=localFrame*V(u*width,0,v*depth)
			local g=ground(o,p.X,p.Z)
			low,high=math.min(low,g),math.max(high,g)
		end
	end
	return low-2,high+0.7
end

local function stone(parent: Instance, frame: CFrame, name: string, x: number, y: number, z: number,
	w: number, h: number, d: number, tint: Color3, material: Enum.Material?, solid: boolean?): BasePart
	return Kit.part(parent, name, V(w,h,d), frame*F(x,y,z), tint, material or M.Slate, if solid then nil else deco)
end

local function rail(parent: Instance, frame: CFrame, name: string, a: Vector3, b: Vector3,
	width: number, height: number, tint: Color3, material: Enum.Material, solid: boolean?): BasePart
	return Kit.part(parent, name, V(width,height,(b-a).Magnitude), frame*CFrame.lookAt((a+b)*0.5,b), tint,material, if solid then nil else deco)
end

local function deck(parent: Instance, frame: CFrame, name: string, a: Vector3, b: Vector3, width: number, depth: number, tint: Color3, material: Enum.Material)
	local axis = CFrame.lookAt((a+b)*0.5,b)
	-- Offset in the local normal so the upper face interpolates exactly between both foot points.
	return Kit.part(parent,name,V(width,depth,(a-b).Magnitude+0.7),frame*axis*F(0,-depth/2,0),tint,material)
end

local function roadHeight(o: CFrame,x: number,z: number): number
	-- The rounded four-stud terrain voxels crest above the sampled mathematical surface.
	local clearance = 0.75 + 1.65 * math.clamp((585-z)/24,0,1)
	local h = ground(o,x,z)+clearance
	-- The gravel lane takes a backing of dry stone as it climbs clear of the gully.
	if z < 305 then
		local t = math.clamp((305-z)/122,0,1)
		local start = ground(o,-13,305)+clearance
		h = math.max(h, start + (-20-start)*t)
	end
	if z <= 183 then return -20 + (183-z)*2/26 end
	return h
end

local function pilgrimLane(parent: Instance,o: CFrame)
	local m = group(parent,"The Pilgrim Road")
	for i=1,#lane-1 do
		local aa,bb = lane[i],lane[i+1]
		local a,b = V(aa[1],0,aa[2]), V(bb[1],0,bb[2])
		local count = math.ceil((a-b).Magnitude/15)
		local side = (b-a).Unit:Cross(Vector3.yAxis)
		for j=1,count do
			local p,q = a:Lerp(b,(j-1)/count),a:Lerp(b,j/count)
			p += Vector3.yAxis*roadHeight(o,p.X,p.Z)
			q += Vector3.yAxis*roadHeight(o,q.X,q.Z)
			local depth = if p.Z > 305 then 2 else math.max(3,p.Y-ground(o,p.X,p.Z)+6,q.Y-ground(o,q.X,q.Z)+6)
			-- A narrow ramp carries collision; deep vertical retaining faces stay out of the walk surface.
			if depth>4 then
				local middle = (p+q)*0.5
				local flat = V(q.X-p.X,0,q.Z-p.Z)
				local footing = (math.min(p.Y,q.Y)-1+math.min(ground(o,q.X,q.Z),ground(o,p.X,p.Z))-4)/2
				local wallH = 2*(math.min(p.Y,q.Y)-1-footing)
				if wallH>0 then
					Kit.part(m,"Road revetment",V(15.3,wallH,flat.Magnitude+1.4),o*CFrame.lookAt(V(middle.X,footing,middle.Z),V(middle.X,footing,middle.Z)+flat),slate,M.Cobblestone,deco)
				end
			end
			local surface=deck(m,o,"Worn pilgrim road",p,q,16,2.6,rgb(182,178,165),M.Ground)
			surface.MaterialVariant="AsuraGravel"
			if j==1 and i%2==0 then
				local center=p:Lerp(q,0.58)
				local direction=(q-p).Unit
				for k=-1,1 do
					local at=center+side*(k*3.3+0.2*i%2)
					local flag=rail(m,o,"Surviving pavers",at-direction*2.1+V(0,0.09,0),at+direction*2.1+V(0,0.09,0),3.1,0.25,rgb(139,141,132),M.Slate)
					flag.MaterialVariant="AsuraStone"
				end
			end
			if (i+j)%3 ~= 0 then
				local s = if (i+j)%2==0 then -7.05 else 7.05
				local off = side*s + V(0,0.12,0)
				rail(m,o,"Worn kerb",p:Lerp(q,0.12)+off,p:Lerp(q,0.88)+off,1.35,0.55,trim,M.Cobblestone)
			end
		end
	end
end

local function viaduct(parent: Instance,o: CFrame)
	-- Same deck path and levels as before; piers now run down to the terrain in 30-stud bays (layout: VesperholdLayout.Viaduct).
	local m = group(parent,"The Processional Bridge")
	local W = Layout.Viaduct
	local level = Layout.viaductLevel
	local dark,mid = rgb(34,35,38),rgb(54,56,61)
	local bay,count = W.Bay,5
	local meshBays = VespKit.has("Viaduct_Bay") -- GothicCitadel places the kit bays from the layout slots; the arch stand-ins are the fallback
	local a,b = V(0,level(W.Z0),W.Z0),V(0,-18,W.Z1)
	local paving=deck(m,o,"Processional deck",a,b,W.Width,3.5,rgb(86,88,92),M.Slate)
	paving.MaterialVariant="AsuraPaving"
	for _, s in {-1,1} do
		local x=s*W.Rail
		rail(m,o,"Drip ledge",a+V(x,-2,0),b+V(x,-2,0),1.6,0.85,mid,M.Slate)
		for i=0,count do
			local first=W.Z0+bay*i
			local last=math.min(first+bay,W.Z1)
			local notch=first+bay*(if i%2==0 then 0.38 else 0.62)
			local ranges=if last-first>20 then {{first,notch-1.25},{notch+1.25,last}} else {{first,last}}
			local chipped=(s==-1 and i==3) or (s==1 and i==1)
			for j,range in ranges do
				local lo,hi=range[1],range[2]
				local height=if chipped and j==2 then 1.65 else 2.8
				local p,q=V(x,level(lo)+height/2,lo),V(x,level(hi)+height/2,hi)
				rail(m,o,"Parapet",p,q,1.8,height,dark,M.Slate,true)
				if not (chipped and j==2) then
					rail(m,o,"Coping",p+V(0,height/2+0.2,0),q+V(0,height/2+0.2,0),2.25,0.55,mid,M.Slate)
				end
			end
		end
	end
	for i=0,count do
		local z=W.Z0+i*bay
		local g=ground(o,0,z)-5
		local y=level(z)
		stone(m,o,"Battered pier",0,(g+y-7)/2,z,22,y-7-g,8,dark,M.Slate,true)
		stone(m,o,"Springer course",0,y-12,z,23.3,2,9.4,mid,M.Slate)
		for _, s in {-1,1} do
			stone(m,o,"Guard pier",s*W.Rail,y+2,z,2.75,4.7,2.75,dark,M.Slate)
			stone(m,o,"Pier cap",s*W.Rail,y+4.55,z,3.4,0.7,3.4,mid,M.Slate)
		end
		if i==count then break end
		if meshBays then continue end
		-- One marked Model per bay holds the arch stand-ins (not built once the kit has Viaduct_Bay).
		local at=z+bay/2
		local stand=group(m,"Viaduct bay")
		stand:SetAttribute("VespKitSlot","Viaduct_Bay")
		stand:SetAttribute("VespBay",i+1)
		local stages=math.max(1,math.floor((level(at)-12-(ground(o,0,at)-5))/50))
		for t=0,stages-1 do
			local function arc(theta: number): Vector3
				local zz=at-0.5*bay*math.cos(theta)
				return V(0,level(zz)-17-t*50+12*math.sin(theta),zz)
			end
			for j=1,8 do
				local p,q=arc((j-1)*math.pi/8),arc(j*math.pi/8)
				if t==0 then
					local midPoint=(p+q)/2
					local top=level(midPoint.Z)-3
					local fill=top-math.max(p.Y,q.Y)
					if fill>0 then
						stone(stand,o,"Tympanum",0,top-fill/2,midPoint.Z,17.8,fill+0.5,q.Z-p.Z+0.12,dark,M.Slate)
					end
				end
				rail(stand,o,"Arch vault",p,q,19.8,3.4,if j%3==0 then mid else dark,M.Slate)
			end
		end
	end
end

local function posternWalk(parent: Instance,o: CFrame)
	local m = group(parent,"The Pallbearers' Gallery")
	for i=1,#postern-1 do
		local a,b = postern[i],postern[i+1]
		deck(m,o,"Gallery walk",a,b,9.5,1.1,oak,M.WoodPlanks)
		local cross = (b-a):Cross(Vector3.yAxis).Unit
		for _, k in {-1,1} do
			local offset = k*4.7*cross
			local footA,footB = a+offset,b+offset
			rail(m,o,"Oak sill",footA-V(0,1.15,0),footB-V(0,1.15,0),1,1.8,oak,M.Wood)
			if i>1 and i<#postern-1 then
				rail(m,o,"Handrail",footA+V(0,3.1,0),footB+V(0,3.1,0),0.48,0.65,oak,M.Wood,true)
			end
		end
		if i>1 then
			local g=ground(o,a.X,a.Z)-4
			for _, k in {-1,1} do
				local q = a + cross*(k*4.2)
				local plinth = g+math.max(4,(q.Y-g)*0.3)
				stone(m,o,"Trestle foot",q.X,(plinth+g)/2,q.Z,3.4,plinth-g,3.6,slate,M.Cobblestone)
				stone(m,o,"Gallery piles",q.X,(q.Y+3+plinth)/2,q.Z,1.5,q.Y+3-plinth,1.5,oak,M.Wood)
				for j=1,math.max(1,math.floor((a.Y-plinth)/12)) do
					local low=plinth+(j-1)*12
					local high=math.min(low+12,a.Y-3)
					local opposite=a-cross*(k*4.2)
					rail(m,o,"Wind brace",V(q.X,low,q.Z),V(opposite.X,high,opposite.Z),0.75,0.8,oak,M.Wood)
				end
				rail(m,o,"Knee brace",q-V(0,5,0),q+(b-a).Unit*7-V(0,1.3,0),0.85,0.85,oak,M.Wood)
			end
			local span = a + V(0,-6,0)
			rail(m,o,"Cross tie",span-cross*5.7,span+cross*5.7,1.3,1.3,oak,M.Wood)
		end
		if i>1 and i<#postern-1 then
			Kit.disc(m,"Turning platform",6,1.4,o*F(a-V(0,0.75,0)),oak,M.WoodPlanks)
		end
	end
end

-- A masonry ring with a jagged wound running down the valley-facing side.
local function watchtower(parent: Instance,o: CFrame,x: number,z: number,yaw: number,factor: number)
	local m=group(parent,"Broken ward tower")
	local f=o*F(x,ground(o,x,z)-1,z)*A(0,rad(yaw),0)
	local crown={1,2,5,6,6,5,4,3,3,1}
	local radius=7.7*factor
	for bay,h in crown do
		local angle=2*math.pi*(bay-1)/#crown
		local base=f*A(0,angle,0)
		local height=h*3.1*factor
		local width=2*radius*math.tan(math.pi/#crown)+0.5
		stone(m,base,"Torn ashlar drum",0,(height-8)/2,radius,width,height+8,2.4*factor,slate,M.Brick,true)
		stone(m,base,"Weathered wall head",0,height+0.2,radius,width+0.4,0.7,2.8*factor,trim,M.Limestone)
		if h>=5 then
			stone(m,base,"Archer slit",0,height-4.8,radius+1.23*factor,0.55*factor,3.7*factor,0.12,iron,M.Basalt)
			stone(m,base,"Corbel",0,height-1.3,radius+0.8*factor,0.8,1.7,1.8*factor,cap,M.Slate)
		end
		if bay%3==0 then
			stone(m,base,"Broken merlon",0.45,height+1.4,radius,width*0.47,2.6,2.3*factor,slate,M.Brick)
		end
	end
	rail(m,f,"Fallen hoarding",V(-3,8*factor,1),V(4,0.4,7*factor),1,1.1,oak,M.Wood)
	Pbr.place(m,"AsuraRuinPillar",f*F(-9*factor,-0.5,8*factor)*A(0,rad(47),rad(75)),5,"Longest")
end

local function pointedBay(m: Instance, f: CFrame, x: number,z: number, spring: number, radius: number, rise: number)
	for _,s in {-1,1} do
		stone(m,f,"Lancet jamb",x+s*radius,spring/2,z,1.45,spring,2.5,lime,M.Limestone,true)
		rail(m,f,"Shoulder of arch",V(x+s*radius,spring,z),V(x+s*radius*0.66,spring+rise*0.59,z),1.5,1.6,lime,M.Limestone)
		rail(m,f,"Arch crown",V(x+s*radius*0.66,spring+rise*0.59,z),V(x,spring+rise,z),1.5,1.6,lime,M.Limestone)
	end
end

local function chapel(parent: Instance,o: CFrame)
	local m=group(parent,"Chapel of the Ninth Vigil")
	local x,z=-70,253
	local foot,y=foundation(o,x,z,17,23,35)
	local f=o*F(x,y,z)*A(0,rad(17),0)
	local door=(o:ToObjectSpace(f)*F(0,0,16)).Position
	local branch=V(-13,roadHeight(o,-13,305),305)
	local bend=V(-41,ground(o,-41,290)+0.4,290)
	deck(m,o,"Funeral path",branch,bend,9,2,gravel,M.Pebble)
	deck(m,o,"Chapel approach",bend,door,9,2.2,gravel,M.Pebble)
	stone(m,f,"Chapel footing",0,(foot-y)/2,0,23,y-foot,35,slate,M.Cobblestone,true)
	stone(m,f,"Chancel pavement",0,0.12,0,23,0.28,35,trim,M.Cobblestone,true)
	pointedBay(m,f,0,12,7.4,4.5,5.4)
	for _, s in {-1,1} do
		stone(m,f,"Narthex",s*7.6,4.15,12,5.1,8.3,3,slate,M.Brick,true)
		stone(m,f,"Eroded nave wall",s*10,2.15,-1,2.2,4.3,23,slate,M.Brick,true)
		for _, p in {-12,-2,10} do
			local h = if s==1 and p==-2 then 5.1 else 10.8
			stone(m,f,"Nave pier",s*10,h/2,p,3,h,2.7,slate,M.Brick,true)
			stone(m,f,"Nave impost",s*10,h,p,3.5,1,3.2,trim,M.Limestone)
			rail(m,f,"Weathered buttress",V(s*13.8,0,p),V(s*10.5,h*0.73,p),2.8,2.7,trim,M.Limestone)
		end
		stone(m,f,"Sanctuary wall",s*7.8,6.7,-13,5.6,13.4,3,slate,M.Brick,true)
		rail(m,f,"Raking cornice",V(s*10.5,13.2,-13),V(0,21,-13),2.15,2.15,trim,M.Limestone)
		rail(m,f,"Burnt hammerbeam",V(s*9.7,10.4,-7.5),V(s*5.7,13.5,-7.5),0.95,1.15,oak,M.Wood)
	end
	stone(m,f,"East window sill",0,2,-13,11,4,2.9,slate,M.Brick,true)
	pointedBay(m,f,0,-13,11,4.8,6.8)
	for _,s in {-1,1} do
		stone(m,f,"Mullion",s*1.65,7.3,-13,0.48,6.6,0.65,trim,M.Limestone)
		rail(m,f,"Tracery",V(s*1.65,10.5,-13),V(0,14.3,-13),0.48,0.55,trim,M.Limestone)
	end
	for i, t in {{-3.1,7.9,1.9,6.5},{0,7.5,2.15,5},{3.1,5.8,1.9,2.7}} do
		local pane=stone(m,f,"Surviving glass",t[1],t[2],-13.15,t[3],t[4],0.15,if i==1 then rgb(121,108,92) else rgb(75,106,118),M.Glass)
		pane.Transparency=0.32
	end
	stone(m,f,"Vigil table",0,1.85,-8.5,6,0.65,2.7,lime,M.Limestone,true)
	for _, s in {-1,1} do stone(m,f,"Table foot",s*2.1,0.8,-8.5,1.2,1.6,1.8,cap,M.Slate,true) end
	Pbr.place(m,"AsuraBrassLantern",f*F(-2,2.18,-8.5),1.3)
	-- Burials extend out of the lost north aisle; some stones have subsided into the scree.
	for i,t in {{-23,-6,-7},{-25,4,4},{-23,12,-4},{-32,-6,7},{-31,2,-2},{-33,13,12},{-42,1,-9},{-42,12,3}} do
		local p=(o:ToObjectSpace(f)*F(t[1],0,t[2])).Position
		local base=o*F(p.X,ground(o,p.X,p.Z)-0.35,p.Z)*A(0,rad(17+t[3]),rad(t[3]))
		Decor.han(m,"AsuraLobbyKit",if i%3==0 then "Stele_Broken" else "Stele_Dragon",base,if i%3==0 then 0.57 else 0.41)
		stone(m,base,"Grave curb",0,0,1.4,2.7,0.6,4.9,cap,M.Cobblestone)
	end
end

-- Settlement remnants: a hearth, chimney and fragments of a timber roof identify former dwellings.
local function dwelling(m: Instance,o: CFrame,x: number,z: number,yaw: number,whole: boolean)
	local foot,y=foundation(o,x,z,yaw,18,14)
	local f=o*F(x,y,z)*A(0,rad(yaw),0)
	stone(m,f,"Croft floor",0,(foot-y)/2,0,18,y-foot,14,slate,M.Cobblestone,true)
	for _, s in {-1,1} do
		stone(m,f,"Dwarf wall",s*8,1.5,0,1.5,3,13.4,slate,M.Cobblestone,true)
		for j,cz in {-6.1,0,6.1} do
			local h=if whole or (j==1 and s==-1) then 7.7 else (3.2+0.6*j)
			stone(m,f,"Oak upright",s*8,h/2,cz,1,h,1,oak,M.Wood)
		end
		stone(m,f,"Gable wall",s*5.3,1.83,-6.1,6.6,3.66,1.6,slate,M.Cobblestone,true)
		if whole then
			rail(m,f,"Eaves plate",V(s*8,7.5,-6.7),V(s*8,7.5,6.7),1,1,oak,M.Wood)
			for _,zz in {-6,0,6} do
				rail(m,f,"Exposed rafter",V(s*8.8,7.15,zz),V(0,12.2,zz),0.8,0.8,oak,M.Wood)
			end
			if s==-1 then
				local p=Kit.part(m,"Surviving shale roof",V(10.5,0.65,10.8),f*F(-4.3,10.0,-0.8)*A(0,0,rad(29)),cap,M.Slate,deco)
				p.MaterialVariant="AsuraRoofTile"
			end
		end
	end
	local h=if whole then 14.1 else 8.6
	stone(m,f,"Stone chimney",5.5,h/2,-5.7,3.3,h,3.5,slate,M.Brick,true)
	stone(m,f,"Chimney cap",5.5,h+0.25,-5.7,3.9,0.7,4,trim,M.Limestone)
	if not whole then
		rail(m,f,"Collapsed ridge pole",V(-4,0.7,4.1),V(5,3.2,-4),1,1,oak,M.Wood)
	end
end

local function wheel(m: Instance,f: CFrame)
	local radius=2
	for i=1,10 do
		local t,u=(i-1)*math.pi/5,i*math.pi/5
		local p,q=V(0,math.cos(t)*radius,math.sin(t)*radius),V(0,math.cos(u)*radius,math.sin(u)*radius)
		rail(m,f,"Rim",p,q,0.32,0.33,iron,M.CorrodedMetal)
		if i%2==0 then rail(m,f,"Spoke",V(0,0,0),q,0.19,0.22,oak,M.Wood) end
	end
end

local function journey(m: Instance,o: CFrame)
	local x,z=-4,390
	local f=o*F(x,ground(o,x,z)+2.2,z)*A(0,rad(29),rad(-11))
	stone(m,f,"Abandoned cart bed",0,0,0,5.8,0.75,8.5,oak,M.WoodPlanks)
	for _,s in {-1,1} do
		stone(m,f,"Cart side",s*2.7,0.95,-0.2,0.38,1.6,8.2,oak,M.WoodPlanks)
		rail(m,f,"Shaft",V(s*2,-0.5,-2),V(s*1.5,-1.2,-11),0.48,0.48,oak,M.Wood)
	end
	wheel(m,f*F(3.15,0,1))
	local wheelX,wheelZ=x-4,z+7
	wheel(m,o*F(wheelX,ground(o,wheelX,wheelZ)+0.5,wheelZ)*A(rad(7),rad(-15),rad(76)))
	for i,t in {{-0.4,0.85,1.6},{-1.1,0.9,-0.3},{0.4,1.15,-2.1}} do
		local bag=stone(m,f,"Pilgrim baggage",t[1],t[2],t[3],2.3,1.25,1.75,if i==1 then gravel else rust,M.Fabric)
		if bag:IsA("Part") then bag.Shape=Enum.PartType.Ball end
	end
end

local function sealBridge(parent: Instance,o: CFrame)
	local m=group(parent,"The bridge ward")
	for _,s in {-1,1} do
		local f=o*F(s*12.5,-19.1,156)
		stone(m,f,"Plinth foot",0,-7,0,7.2,14,7,slate,M.Brick,true)
		stone(m,f,"Pilgrim plinth",0,1.4,0,5.9,3,5.9,slate,M.Brick,true)
		stone(m,f,"Statue socle",0,3,0,6.7,0.65,6.7,trim,M.Limestone)
		if s==-1 then
			Pbr.place(m,"AsuraColossusStatue",f*F(0,3.32,0)*A(0,rad(175),0),12)
		else
			Pbr.place(m,"AsuraRuinPillar",f*F(0,3.32,0),4)
			local crown=stone(m,f,"Watch fire",0,7.2,0,0.9,1.3,0.85,rgb(250,169,98),M.Neon)
			Kit.light(crown,rgb(255,183,123),15,0.65,false)
		end
	end
end

-- Frost-killed beech. The leader and forks taper along the prevailing wind; bark shoulders are set into soil.
local function snag(parent: Instance,frame: CFrame,scale: number,turn: number)
	local m=group(parent,"Wind-thrown beech")
	local f=frame*A(0,rad(turn),0)
	local function limb(a: Vector3,b: Vector3,diameter: number,pale: boolean?)
		local p,q=f*(a*scale),f*(b*scale)
		local bough=Kit.part(m,"Weathered bough",V((q-p).Magnitude+diameter*scale*0.2,diameter*scale,diameter*scale),
			CFrame.lookAt((p+q)/2,q)*A(0,math.pi/2,0),if pale then rgb(164,153,138) else rgb(117,109,101),M.Wood,deco)
		if bough:IsA("Part") then bough.Shape=Enum.PartType.Cylinder end
	end
	local foot,knuckle,elbow,fork,tip=V(0,-0.6,0),V(0.4,3.2,-0.4),V(-0.3,6.8,0.7),V(1.8,9.7,1.25),V(3.8,12.2,1.8)
	limb(foot,knuckle,1.24)
	limb(knuckle,elbow,1.01)
	limb(elbow,fork,0.78)
	limb(fork,tip,0.49)
	limb(tip,V(5.9,13.3,2.2),0.28,true)
	limb(V(4.4,12.5,1.9),V(4.8,13.9,1.5),0.17)
	limb(elbow,V(-2.4,8.6,-0.3),0.54)
	limb(V(-2.4,8.6,-0.3),V(-2.9,10.8,-1.4),0.31)
	limb(V(-2.9,10.8,-1.4),V(-1.6,12.2,-1.9),0.18,true)
	limb(knuckle,V(-2.25,4.7,1.3),0.55)
	limb(V(-2.25,4.7,1.3),V(-3.5,5.2,2.0),0.31,true)
	limb(fork,V(1.9,11.6,-1.2),0.39)
	limb(V(1.9,11.6,-1.2),V(3.7,12.9,-2.1),0.22)
	limb(V(1.9,11.6,-1.2),V(1.4,12.5,-1.7),0.16,true)
end

local function verges(parent: Instance,o: CFrame)
	local m=group(parent,"Windward slopes")
	for i,t in {{-33,545,1.17},{37,519,0.83},{-51,466,0.78},{64,385,1.3},
		{-46,332,0.9},{61,283,1.08},{-117,220,0.8},{115,158,0.92}} do
		local x,z=t[1],t[2]
		local f=o*F(x,ground(o,x,z)-0.7,z)
		-- A kit thorn replaces the Part snag when uploaded; without it the snag stays.
		local kitTree=VespKit.place("Thorn_Twisted",f*A(0,rad(21+(i*19)%66),0),V(1,1,1)*(t[3]*0.4),{Group="Tree",Seed=i})
		if kitTree then kitTree.Parent=m else snag(m,f,t[3],21+(i*19)%66) end
	end
	for i,t in {{-23,559,9},{-57,449,8},{54,367,6.5},{-49,298,7},{84,237,6},{-77,119,9}} do
		local f=o*F(t[1],ground(o,t[1],t[2])-1.3,t[2])*A(0,rad(i*71),0)
		Pbr.place(m,"AsuraDeadTrunk",f,t[3],"Longest")
	end
	-- Exposed strata follow each shoulder's fall line. The scanned stone fragments sit partly buried
	-- around the ridges, making a ragged outcrop rather than one silhouette per placement.
	local rockRng=Random.new(2821)
	for i,t in {{-69,523,27},{-92,506,32},{47,488,18},{64,475,32},{83,484,26},
		{-90,419,29},{-69,400,23},{121,326,35},{138,316,21},{-108,293,26},
		{66,220,24},{82,205,31},{-58,189,26},{-76,173,30},{-60,132,17},
		{151,86,29},{160,59,34},{-147,48,35},{-135,16,27}} do
		local x,z,width=t[1],t[2],t[3]
		local yaw=rad(38+(i%4)*12)
		local dx,dz=math.cos(yaw),-math.sin(yaw)
		local atL,atR=ground(o,x-dx*width/2,z-dz*width/2),ground(o,x+dx*width/2,z+dz*width/2)
		local height=width*0.32
		local tilt=math.clamp(math.atan((atR-atL)/width),-0.42,0.42)
		local base=math.min(ground(o,x,z),(atL+atR)/2)-height*0.48
		SanctuaryKit.place(m,"Vista_Ridge",o*F(x,base,z)*A(0,yaw,0)*A(0,0,tilt),
			V(width/156.5,height/155.2,width*0.43/62.3))
		for k=1,3 do
			local sign=if k==2 then -1 else 1
			local u=sign*rockRng:NextNumber(width*0.19,width*0.56)
			local rx,rz=x+dx*u+rockRng:NextNumber(-3,3),z+dz*u+rockRng:NextNumber(-3,3)
			local span=rockRng:NextNumber(2.5,6)
			Decor.nature(m,"AsuraStone",o*F(rx,ground(o,rx,rz)-span*0.22,rz)*A(0,rockRng:NextNumber(0,math.pi),0),span)
		end
	end
	local rng=Random.new(961)
	for i=1,42 do
		local t=lane[1+(i*7)%11]
		local side=if i%2==0 then -1 else 1
		local x,z=t[1]+side*rng:NextNumber(18,42),t[2]+rng:NextNumber(-12,12)
		local f=o*F(x,ground(o,x,z)-0.3,z)*A(0,rng:NextNumber(0,math.pi),0)
		Decor.nature(m,"AsuraStone",f,rng:NextNumber(2.1,7.5))
	end
end

local function waystone(parent: Instance,o: CFrame,x: number,z: number,yaw: number,title: string)
	local frame=o*F(x,ground(o,x,z),z)*A(0,rad(yaw),0)
	stone(parent,frame,"Waystone plinth",0,0.35,0,5.2,1.5,2.9,slate,M.Cobblestone,true)
	local body=stone(parent,frame,"Carved waystone",0,3.75,0,4.7,5.5,1.75,cap,M.Limestone,true)
	stone(parent,frame,"Weathering course",0,6.65,0,5.1,0.55,2.25,trim,M.Limestone)
	local gui=Instance.new("SurfaceGui")
	gui.Name,gui.Face,gui.LightInfluence,gui.MaxDistance="Inscription",Enum.NormalId.Back,1,48
	gui.SizingMode,gui.PixelsPerStud=Enum.SurfaceGuiSizingMode.PixelsPerStud,44
	gui.Parent=body
	local text=Instance.new("TextLabel")
	text.Size,text.BackgroundTransparency=UDim2.fromScale(0.92,0.52),1
	text.Position,text.Text,text.Font=UDim2.fromScale(0.04,0.27),title,Enum.Font.Garamond
	text.TextColor3,text.TextScaled,text.TextWrapped=lime,true,true
	text.Parent=gui
end

local function dressMarch(parent: Instance,o: CFrame)
	-- The tower stump and the opposing tall fir frame the first complete reveal.
	watchtower(parent,o,-49,524,36,1.15)
	watchtower(parent,o,-42,163,-20,1.58)
	chapel(parent,o)
	local crofts=group(parent,"The deserted crofts")
	dwelling(crofts,o,65,362,-19,true)
	dwelling(crofts,o,84,334,11,false)
	dwelling(crofts,o,-50,383,32,false)
	journey(crofts,o)
	waystone(crofts,o,8,574,-12,"VESPERHOLD")
	waystone(crofts,o,-47,292,30,"NINTH VIGIL")
	sealBridge(parent,o)
	-- Real scanned roots kink around the bridge abutment and beneath a wayside grave.
	for i,t in {{-50,192,18},{-107,254,13},{-55,508,19},{44,392,15}} do
		local x,z=t[1],t[2]
		Decor.nature(crofts,"AsuraRoots",o*F(x,ground(o,x,z)-0.6,z)*A(0,rad(i*51),0),t[3])
	end
	verges(parent,o)
end

function March.build(parent: Instance, origin: CFrame)
	local march=group(parent,"Vesper March")
	pilgrimLane(march,origin)
	viaduct(march,origin)
	posternWalk(march,origin)
	dressMarch(march,origin)
	return march
end
return March
