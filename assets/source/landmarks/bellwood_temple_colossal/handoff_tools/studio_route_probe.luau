local world = require(game.ServerScriptService.AsurasPath.Services.LandmarkWorld)
local map = workspace:FindFirstChild("Map_Overworld")
local landmark = map and map:FindFirstChild("Landmark_Bellwood", true)
local uptime = workspace.DistributedGameTime
if not (landmark and landmark:GetAttribute("BasinSculpted")) then
    return {ready = false, uptime = uptime, landmarkExists = landmark ~= nil}
end
local layout = world.Layout
local bellwood = layout.Landmarks.Bellwood
local candidate = assert(bellwood.Basin.ColossalTemple)
local pack = assert(landmark:FindFirstChild(candidate.Model), "Fallback hall loaded")
local frame = world.templeFrame(bellwood, candidate)
local gate = world.gateFrame(bellwood)
local route = layout.route(bellwood, world.Height)
local exit = world.kitToWorld(bellwood, bellwood.Tunnel.Passage[#bellwood.Tunnel.Passage])
local start = exit - Vector3.new(0, 8, 0)
local toe = frame * Vector3.new(0, .6, 258)
local join = toe:Lerp(start, .24)
local gateToe = gate * Vector3.new(0, .4, bellwood.Basin.Gate.Steps + 4)
local points = {}
local function add(at, kind)
    table.insert(points, {X = at.X, Y = at.Y, Z = at.Z, Kind = kind})
end
local function connect(at, kind)
    local prev = points[#points]
    local origin = Vector3.new(prev.X, prev.Y, prev.Z)
    local segments = math.max(1, math.ceil((at - origin).Magnitude / 5))
    for i = 1, segments do add(origin:Lerp(at, i / segments), kind) end
end
add(start, "exit")
connect(join, "causeway")
connect(toe, "causeway")
for i = 0, 127, 2 do add(frame * Vector3.new(0, .60 + i * .88, 257 - i * 2.35), "temple stair") end
connect(frame * Vector3.new(0, 113, -96), "temple interior")
connect(frame * Vector3.new(0, 113, -42), "temple interior")
for i = 127, 0, -2 do add(frame * Vector3.new(0, .60 + i * .88, 257 - i * 2.35), "temple descent") end
connect(toe, "stair toe")
connect(join, "causeway")
connect(gateToe, "gate causeway")
connect(gate * Vector3.new(0, bellwood.Basin.Gate.Landing, -bellwood.Basin.Gate.Back + 12), "gate stair")
for _, point in route.Points do
    local last = points[#points]
    if (point.X - last.X)^2 + (point.Z - last.Z)^2 > 2 then table.insert(points, point) end
end
local boundsFrame, boundsSize = pack:GetBoundingBox()
local rays = RaycastParams.new()
rays.FilterType = Enum.RaycastFilterType.Include
rays.FilterDescendantsInstances = {workspace.Terrain, landmark}
rays.IgnoreWater = true
local misses, rises, deviations = {}, {}, {}
local previous
for i, p in points do
    local origin = Vector3.new(p.X, p.Y + (if p.Kind == "gate stair" then 12 else 8), p.Z)
    local hit = workspace:Raycast(origin, Vector3.new(0, -24, 0), rays)
    if hit then
        local delta = hit.Position.Y - p.Y
        deviations[p.Kind] = math.max(deviations[p.Kind] or 0, math.abs(delta))
        if previous and hit.Position.Y - previous > 3 then
            table.insert(rises, {index = i, kind = p.Kind, climb = hit.Position.Y - previous})
        end
        previous = hit.Position.Y
        p.Y = previous
    else
        table.insert(misses, {index = i, kind = p.Kind, position = p})
        previous = nil
    end
end
local count, invalid, maps = 0, {}, 0
for _, item in pack:GetDescendants() do
    if item:IsA("MeshPart") then
        count += 1
        if item.CanCollide or item.CanQuery or item.CanTouch or not item.Anchored then table.insert(invalid, item.Name) end
        local mat = item:FindFirstChildOfClass("SurfaceAppearance")
        if mat and mat.ColorMap ~= "" and mat.NormalMap ~= "" and mat.RoughnessMap ~= "" then maps += 1 end
    end
end
workspace:SetAttribute("SolBasinRoutePoints", game.HttpService:JSONEncode(points))
workspace:SetAttribute("SolBasinExit", exit)
workspace:SetAttribute("SolTempleFrame", frame)
workspace:SetAttribute("SolBasinGateFrame", gate)
return {
    ready = true, uptime = uptime, points = #points, missingGround = misses, rises = rises, deviations = deviations,
    rescues = map:GetAttribute("Rescues") or 0, meshCount = count, invalidDecor = invalid, mappedMeshes = maps,
    bounds = {mid = tostring(boundsFrame.Position), size = tostring(boundsSize)},
    oldHallAlsoPresent = landmark:FindFirstChild(bellwood.Basin.Temple.Model) ~= nil,
}
