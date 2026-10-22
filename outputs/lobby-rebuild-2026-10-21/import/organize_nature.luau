local ServerStorage = game:GetService("ServerStorage")
local kit = ServerStorage:FindFirstChild("AsuraLobbyKit")
assert(kit, "kit library missing")
local src
for _, c in workspace:GetChildren() do
	if c:IsA("Model") and c:FindFirstChild("Cloud_A__Cloud", true) then src = c end
end
assert(src, "imported nature model missing")
local rows = {{"Cloud_A","Cloud_A__Cloud",-3.6992,6.8087,-0.631},{"Cloud_B","Cloud_B__Cloud",0.238,5.4927,2.0329},{"Cloud_C","Cloud_C__Cloud",-5.2541,10.7242,3.4793},{"Tree_Maple","Tree_Maple__Bark",-0.4534,5.6699,0.7606},{"Tree_Maple","Tree_Maple__Foliage",-0.6605,9.6206,1.1217},{"Tree_MapleSmall","Tree_MapleSmall__Bark",-0.7761,4.3084,0.3921},{"Tree_MapleSmall","Tree_MapleSmall__Foliage",-0.7009,7.7175,0.4064},{"Shrub_Crimson","Shrub_Crimson__Foliage",-1.1333,1.0161,0.1032},{"Banner_Cloth","Banner_Cloth__Banner",-0.0,-4.3,0.1321}}
local byName = {}
for _, d in src:GetDescendants() do if d:IsA("MeshPart") then byName[d.Name] = d end end
local pieces, moved, bad = {}, 0, {}
for _, r in rows do
	local piece = pieces[r[1]]
	if not piece then
		local old = kit:FindFirstChild(r[1])
		if old then old:Destroy() end
		piece = Instance.new("Model")
		piece.Name = r[1]
		piece.Parent = kit
		pieces[r[1]] = piece
	end
	local p = byName[r[2]]
	if not p then table.insert(bad, r[2]) continue end
	if p.MeshId == "" then table.insert(bad, r[2] .. ":nomesh") end
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.DoubleSided = true, false, false, false, true, r[1] == "Banner_Cloth"
	p.CollisionFidelity = Enum.CollisionFidelity.Box
	p.RenderFidelity = Enum.RenderFidelity.Automatic
	p.CFrame = CFrame.new(r[3], r[4], r[5])
	p.Parent = piece
	moved += 1
end
for _, piece in pieces do piece.WorldPivot = CFrame.identity end
src:Destroy()
return string.format("nature moved=%d bad=%s kitPieces=%d", moved, table.concat(bad, ","), #kit:GetChildren())
