local world = require(game.ServerScriptService.AsurasPath.Services.LandmarkWorld)
local ow = require(game.ReplicatedStorage.AsurasPath.Shared.Overworld)
local bellwood = world.Layout.Landmarks.Bellwood
local centre = world.Layout.basinCentre(bellwood)
local frame = assert(workspace:GetAttribute("SolTempleFrame"))
local start = assert(workspace:GetAttribute("SolBasinExit"))
local roadEyes, selected = {}, {}
for _, road in ow.terrainData().Roads do
    for i = 2, #road.Points do
        local p, q = road.Points[i - 1], road.Points[i]
        local a = Vector3.new(p[1], 0, p[2])
        local b = Vector3.new(q[1], 0, q[2])
        local subdivisions = math.max(1, math.ceil((b - a).Magnitude / 20))
        for j = 0, subdivisions do
            local spot = a:Lerp(b, j / subdivisions)
            table.insert(roadEyes, {spot = spot, distance = (spot - Vector3.new(centre.X, 0, centre.Z)).Magnitude})
        end
    end
end
table.sort(roadEyes, function(a, b) return a.distance < b.distance end)
local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = {workspace.Terrain}
terrainOnly.IgnoreWater = true
local sights = {
    threshold = frame * Vector3.new(0, 113, -41),
    hallRoof = frame * Vector3.new(-34, 505, -237),
    crown = frame * Vector3.new(52, 750, -130),
}
local function visible(point)
    local result = {}
    for key, target in sights do
        local hit = workspace:Raycast(point, target - point, terrainOnly)
        result[key] = hit == nil
    end
    return result
end
local eyes = {}
for _, road in roadEyes do
    local far = true
    for _, xz in selected do
        if (road.spot - xz).Magnitude < 80 then far = false; break end
    end
    if not far then continue end
    local above = road.spot + Vector3.new(0, ow.heightAt(road.spot.X, road.spot.Z) + 68, 0)
    local ground = workspace:Raycast(above, Vector3.new(0, -120, 0), terrainOnly)
    if ground then
        local eye = ground.Position + Vector3.new(0, 7.5, 0)
        table.insert(selected, road.spot)
        table.insert(eyes, visible(eye))
        if #eyes == 1 then workspace:SetAttribute("SolBellwoodRoadEye", eye) end
    end
    if #eyes == 8 then break end
end
local away = (frame.Position - start) * Vector3.new(1, 0, 1)
return {road = eyes, exit = visible(start + away.Unit * 12)}
