local counts, lights, emitters, tris = {}, 0, 0, 0
for _, d in workspace.Sanctuary:GetDescendants() do
	if d:IsA("Model") and d.Parent and d:FindFirstChildWhichIsA("MeshPart") then
		counts[d.Name] = (counts[d.Name] or 0) + 1
	elseif d:IsA("Light") then lights += 1
	elseif d:IsA("ParticleEmitter") or d:IsA("Fire") then emitters += 1 end
end
local rows = {}
for k, v in counts do table.insert(rows, { k, v }) end
table.sort(rows, function(a, b) return a[2] > b[2] end)
local out = {}
for _, r in rows do table.insert(out, r[1] .. "=" .. r[2]) end
local parts, collide = 0, 0
for _, d in workspace.Sanctuary:GetDescendants() do
	if d:IsA("BasePart") and not d:IsA("MeshPart") then parts += 1 if d.CanCollide then collide += 1 end end
end
return table.concat(out, " ") .. " | lights=" .. lights .. " emitters=" .. emitters .. " primitives=" .. parts .. " colliding=" .. collide
