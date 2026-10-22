--!strict
local Pbr = require(script.Parent.PbrAssets)
local Assets = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.PresentationAssets)
local Dressing = {}
local function floorOf(p: BasePart): CFrame return p.CFrame - Vector3.yAxis * p.Size.Y/2 end
function Dressing.Build(root: Instance): number
	local old = root:FindFirstChild("Phase5Pbr")
	if old then old:Destroy() end
	local folder = Instance.new("Folder"); folder.Name,folder.Parent = "Phase5Pbr",root
	local placed = 0
	-- Replace discrete decorative objects, preserving all floor/platform collisions and prompts.
	for _, p in root:GetDescendants() do
		if not p:IsA("BasePart") or p:IsDescendantOf(folder) or p.Transparency >= 1 then continue end
		if placed >= Assets.Limits.Scenery then break end
		local name: string? = nil
		local axis: string? = nil
		local size: number? = nil
		if p.Name == "Rubble" then name,axis,size = "AsuraStone","X",p.Size.X
		elseif p.Name == "IdolBody" then name,axis,size = "AsuraColossusStatue","Y",8
		elseif p.Name == "Stele" then name,axis,size = "AsuraSpeakingStones","Y",p.Size.Y
		elseif p.Name == "Pillar" and p.Size.Y > 8 then name,axis,size = "AsuraRuinPillar","Y",p.Size.Y
		end
		if name and size and Pbr.place(folder,name,floorOf(p),size,axis,p) then placed += 1 end
	end
	if root.Name == "Map_DesecratedMonastery" then
		local placements: {{any}} = {
			{"AsuraRuinArch", CFrame.new(0,0.3,-861),17,"Y"},
			{"AsuraBrassLantern",CFrame.new(-16,0.3,-766),3,"Y"},
			{"AsuraBrassLantern",CFrame.new(16,0.3,-846),3,"Y"},
			{"AsuraFirePit",CFrame.new(0,0.3,-812),8,"X"},
			{"AsuraFoundationRuin",CFrame.new(-68,0.3,-1090),14,"X"},
		}
		for _, spec in placements do
			if Pbr.place(folder,spec[1] :: string,spec[2] :: CFrame,spec[3] :: number,spec[4] :: string) then placed += 1 end
		end
		local bridge = root:FindFirstChild("RavineBridge",true)
		if bridge then
			for side = -1,1,2 do for z = -944,-984,-10 do
				if Pbr.place(folder,"AsuraRomanRail",CFrame.new(side*8.5,0.3,z),10,"Longest") then placed += 1 end
			end end
		end
	end
	root:SetAttribute("AsuraPbrPlacements",placed)
	return placed
end
return Dressing
