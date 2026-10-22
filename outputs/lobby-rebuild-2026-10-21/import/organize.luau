local ServerStorage = game:GetService("ServerStorage")
local src = workspace:FindFirstChild("AsuraLobbyK") or workspace:FindFirstChild("AsuraLobbyKit")
assert(src, "imported kit model missing")
local old = ServerStorage:FindFirstChild("AsuraLobbyKit")
if old then old:Destroy() end
local kit = Instance.new("Model")
kit.Name = "AsuraLobbyKit"
kit:SetAttribute("AsuraKitVersion", 1)
local rows = {{"Roof_Hall","Roof_Hall__Roof",-0.0,4.8692,0.0},{"Roof_Hall","Roof_Hall__Timber",0.0052,3.2574,0.0198},{"Roof_Hall","Roof_Hall__Bronze",-0.0,5.0292,0.0},{"Roof_Square","Roof_Square__Roof",-0.0,2.5268,0.0},{"Roof_Square","Roof_Square__Timber",0.0072,1.6685,0.0186},{"Roof_Square","Roof_Square__Bronze",-0.0,5.5429,0.0},{"Roof_Gallery","Roof_Gallery__Roof",-0.0,1.7494,0.0},{"Roof_Gallery","Roof_Gallery__Timber",-0.0,1.025,0.0},{"Roof_GalleryEnd","Roof_GalleryEnd__Roof",-0.525,1.7994,0.0},{"Roof_GalleryEnd","Roof_GalleryEnd__Timber",-0.45,0.95,0.0},{"Column_Lacquer","Column_Lacquer__Lacquer",-0.0,5.0,0.0},{"Column_Lacquer","Column_Lacquer__Bronze",-0.0,4.95,0.0},{"Column_Base","Column_Base__Stone",-0.0,0.45,0.0},{"Bracket_Set","Bracket_Set__Timber",-0.0,1.395,0.0},{"Beam_Architrave","Beam_Architrave__Timber",-0.0,1.3075,0.0},{"Beam_Architrave","Beam_Architrave__Lacquer",-0.0,0.525,0.0},{"Rail_Bay","Rail_Bay__Stone",-0.0,1.31,0.0},{"Rail_BayStair","Rail_BayStair__Stone",-0.0,1.3225,0.0},{"Rail_Post","Rail_Post__Stone",-0.0,2.08,0.0},{"Lantern_Stone","Lantern_Stone__Stone",-0.0,2.7212,0.0},{"Lantern_Hanging","Lantern_Hanging__Timber",-0.0,-1.305,0.0},{"Lantern_Hanging","Lantern_Hanging__Bronze",-0.0,-1.175,0.0},{"Stele_Dragon","Stele_Dragon__Stone",-0.0,4.02,0.0},{"Stele_Broken","Stele_Broken__Stone",-0.7082,2.2,-0.0052},{"Ruin_Pillar","Ruin_Pillar__Stone",-0.0,5.8883,0.0},{"Ruin_Gate","Ruin_Gate__Stone",0.2986,6.1992,0.0},{"Pool_Rim","Pool_Rim__Stone",-0.0,-0.215,-0.595},{"Pool_Corner","Pool_Corner__Stone",-0.0,-0.22,0.0},{"Dais_Bonfire","Dais_Bonfire__Stone",-0.0,0.59,0.0},{"Dais_Bonfire","Dais_Bonfire__Bronze",-0.0,0.775,0.0},{"Paving_Medallion","Paving_Medallion__Paving",-0.0,0.02,0.0},{"Gate_Plaque","Gate_Plaque__Timber",-0.0,0.0,0.0},{"Gate_Plaque","Gate_Plaque__Bronze",-0.0,0.0,0.0},{"Cliff_Ledge","Cliff_Ledge__Rock",0.9056,-15.0,-0.2181},{"Cliff_Shelf","Cliff_Shelf__Rock",-2.1554,-11.0,-0.9108},{"Cliff_Spur","Cliff_Spur__Rock",-0.0972,-23.0,0.3527},{"Karst_Spire","Karst_Spire__Rock",0.8944,85.0,1.5234},{"Rock_Outcrop","Rock_Outcrop__Rock",-0.2754,1.5,0.2885}}
local byName = {}
for _, d in src:GetDescendants() do if d:IsA("MeshPart") then byName[d.Name] = d end end
local pieces, moved = {}, 0
for _, r in rows do
	local piece = pieces[r[1]]
	if not piece then
		piece = Instance.new("Model")
		piece.Name = r[1]
		piece.Parent = kit
		pieces[r[1]] = piece
	end
	local p = assert(byName[r[2]], "missing part " .. r[2])
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.DoubleSided = false
	p.CollisionFidelity = Enum.CollisionFidelity.Box
	p.RenderFidelity = Enum.RenderFidelity.Automatic
	p.CFrame = CFrame.new(r[3], r[4], r[5])
	p.Parent = piece
	moved += 1
end
for _, piece in pieces do piece.WorldPivot = CFrame.identity end
kit.WorldPivot = CFrame.identity
kit.Parent = ServerStorage
src:Destroy()
local n = 0
for _, d in kit:GetDescendants() do if d:IsA("MeshPart") then n += 1 end end
return string.format("kit pieces=%d parts=%d moved=%d", #kit:GetChildren(), n, moved)
