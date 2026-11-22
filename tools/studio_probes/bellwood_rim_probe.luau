--!nonstrict
-- Bellwood back-rim probe. Question: from the tunnel exit the far rim is missing from the camera although client and server both read
-- occupied Rock there (sol_basin_expanded_exit.jpg). Ranked suspects, each with the step that isolates it:
--   H1 atmosphere + haze + weather + dusk swallow a ~1100-stud-away dark rim     -> steps "no atmosphere", "noon clear"
--   H2 camera / render distance, not streaming (persistent rock segments also failed) -> steps "neon marker", "half distance"
--   H3 the volumetric cloud deck sits over the Y 344 rim top                          -> step "no clouds"
--   H4 the rim is past StreamingTargetRadius (1024) from the exit                      -> Server and Client "streaming" lines
-- Run in a Play session on a seeded avatar standing at the tunnel exit, after BasinSculpted is true (about 290 s in the Mac runs).
--   Server section: Server command bar (or MCP execute_luau in the server context). Prints numbers only.
--   Client section: Client command bar. Walks the steps below, holding the camera at the exit eye aimed at the back rim, one step every
--   STEP_SECONDS. Capture each step (screen_capture or video_capture) and compare it with the baseline frame: the step where the rim
--   appears names the cause. Everything is restored at the end. This script changes nothing the game keeps.
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local STEP_SECONDS = 4
local L = require(ReplicatedStorage.AsurasPath.Shared.LandmarkLayout)
local O = require(ReplicatedStorage.AsurasPath.Shared.Overworld)
local bw = L.Landmarks.Bellwood
local B = bw.Basin

-- Back rim: ring angle 270 deg (Along = -Depth/2, directly opposite the front shore), cap top at the rim's middle.
local THETA = 1.5 * math.pi
local rimX, rimZ = L.basinRing(bw, THETA, B.Thick / 2)
local rimTop = L.rimTop(bw, THETA, O.heightAt)
local floorY = L.basinLevels(bw)
local q, o, a = bw.Tunnel.Passage[#bw.Tunnel.Passage], bw.Origin, math.rad(bw.Yaw)
local exitX = o.X + (-q[1]) * math.cos(a) + q[2] * math.sin(a)
local exitZ = o.Z - (-q[1]) * math.sin(a) + q[2] * math.cos(a)
local EYE = Vector3.new(exitX, floorY + 3.5 + 5.5, exitZ) -- wading depth plus eye height over the lake bed at the exit
local RIM = Vector3.new(rimX, rimTop, rimZ)
local distance = (Vector3.new(rimX, 0, rimZ) - Vector3.new(exitX, 0, exitZ)).Magnitude

local function line(...) print("[rim-probe]", ...) end

local function readColumn(x: number, z: number, y0: number, y1: number): (string, number)
	-- One voxel column (4 studs) from y0 up to y1: the material of each voxel, run-length encoded, and the solid-voxel count.
	local region = Region3.new(Vector3.new(x - 2, y0, z - 2), Vector3.new(x + 2, y1, z + 2)):ExpandToGrid(4)
	local mats, occ = Workspace.Terrain:ReadVoxels(region, 4)
	local size = mats.Size
	local runs, last, n, solid = {}, nil, 0, 0
	for yi = 1, size.Y do
		local m, o2 = mats[1][yi][1], occ[1][yi][1]
		local name = if o2 > 0.5 then m.Name else "Air"
		if o2 > 0.5 and m ~= Enum.Material.Air and m ~= Enum.Material.Water then solid += 1 end
		if name == last then n += 1 else
			if last then table.insert(runs, last .. "x" .. n) end
			last, n = name, 1
		end
	end
	if last then table.insert(runs, last .. "x" .. n) end
	return table.concat(runs, " "), solid
end

local function readRaw(): string
	local out = {}
	for _, name in { "StreamingEnabled", "StreamingTargetRadius", "StreamingMinRadius", "StreamingIntegrityMode", "StreamOutBehavior" } do
		local ok, v = pcall(function() return Workspace[name] end)
		table.insert(out, name .. "=" .. tostring(if ok then v else "unreadable"))
	end
	return table.concat(out, " ")
end

----------------------------------------------------------------------------------------------------------------------------------
-- Server section
----------------------------------------------------------------------------------------------------------------------------------
local function server()
	line("SERVER", readRaw())
	line(string.format("exit eye %.0f %.0f %.0f  back rim cap %.0f %.0f %.0f  flat distance %.0f studs (StreamingTargetRadius 1024: %s)",
		EYE.X, EYE.Y, EYE.Z, RIM.X, RIM.Y, RIM.Z, distance, if distance > 1024 then "RIM IS BEYOND IT" else "inside"))
	-- H4/data: is the rim solid from under the bed to its cap, with no Air hole from the bowl's Air cut (strips to maxTop + 4)?
	local runs, solid = readColumn(rimX, rimZ, floorY - 16, rimTop + 8)
	line("rim column at the cap, bed-16 .. cap+8:", runs, "solid voxels", solid)
	local capRuns = readColumn(rimX, rimZ, rimTop - 6, rimTop + 6)
	line("rim top +-6:", capRuns)
	-- Ray from the exit eye to the rim top (server geometry, the same answer the earlier probes gave: Y 343.94).
	local params = RaycastParams.new()
	params.IgnoreWater = true
	local hit = Workspace:Raycast(EYE, (RIM - EYE).Unit * (distance + 200), params)
	line("ray exit -> rim:", hit and string.format("%s %s at %.0f %.0f %.0f, %.0f studs", hit.Instance.Name, hit.Material.Name, hit.Position.X, hit.Position.Y, hit.Position.Z, (hit.Position - EYE).Magnitude) or "no hit")
	-- Every Persistent or Atomic model on the line of sight past 900 studs: anything that could hide the rim.
	local blockers = Workspace:GetPartBoundsInBox(CFrame.lookAt(EYE:Lerp(RIM, 0.5), RIM), Vector3.new(60, 400, distance), params)
	local names = {}
	for _, p in blockers do if not p:IsA("Terrain") then names[p:GetFullName()] = true end end
	local list = {}
	for n in names do table.insert(list, n) end
	table.sort(list)
	line("parts inside a 60-wide corridor exit -> rim:", #list, table.concat(table.move(list, 1, math.min(#list, 12), 1, {}), " | "))
	-- Lighting and Atmosphere the server holds (clients override per biome, so the client section reads the live values).
	local atmos = Lighting:FindFirstChildOfClass("Atmosphere")
	line("server Atmosphere", atmos and string.format("Density %.3f Offset %.2f Haze %.2f", atmos.Density, atmos.Offset, atmos.Haze) or "none", "ClockTime", Lighting.ClockTime)
	local model = Workspace:FindFirstChild("Landmark_Bellwood", true)
	line("Landmark_Bellwood", model and ("BoreCarved=" .. tostring(model:GetAttribute("BoreCarved")) .. " BasinSculpted=" .. tostring(model:GetAttribute("BasinSculpted"))) or "missing")
end

----------------------------------------------------------------------------------------------------------------------------------
-- Client section
----------------------------------------------------------------------------------------------------------------------------------
local function client()
	local camera = Workspace.CurrentCamera
	local terrain = Workspace.Terrain
	line("CLIENT", readRaw())
	local runs, solid = readColumn(rimX, rimZ, floorY - 16, rimTop + 8)
	line("client voxels at the rim cap column:", runs, "solid", solid)
	local params = RaycastParams.new()
	params.IgnoreWater = true
	local hit = Workspace:Raycast(EYE, (RIM - EYE).Unit * (distance + 200), params)
	line("client ray exit -> rim:", hit and string.format("%s at Y %.2f, %.0f studs", hit.Material.Name, hit.Position.Y, (hit.Position - EYE).Magnitude) or "no hit")
	local focus = Players.LocalPlayer.ReplicationFocus
	line("ReplicationFocus", focus and focus:GetFullName() or "default (character)", "FOV", camera.FieldOfView)

	-- Saved state, restored at the end.
	local atmos = Lighting:FindFirstChildOfClass("Atmosphere")
	local clouds = terrain:FindFirstChildOfClass("Clouds")
	local saved = {
		type = camera.CameraType, cf = camera.CFrame, fov = camera.FieldOfView, clock = Lighting.ClockTime, deco = terrain.Decoration,
		atmos = atmos and { atmos.Density, atmos.Haze, atmos.Offset } or nil, cloudsOn = clouds and clouds.Enabled,
		effects = {},
	}
	for _, e in Lighting:GetChildren() do
		if e:IsA("PostEffect") or e:IsA("SunRaysEffect") or e:IsA("BloomEffect") then table.insert(saved.effects, { e, e.Enabled }) end
	end
	line("live Atmosphere", atmos and string.format("Density %.3f Offset %.2f Haze %.2f Color %s", atmos.Density, atmos.Offset, atmos.Haze, tostring(atmos.Color)) or "none",
		"ClockTime", Lighting.ClockTime, "Clouds", clouds and string.format("Cover %.2f Density %.2f", clouds.Cover, clouds.Density) or "none")

	-- Camera at the exit eye, aimed at the rim top, held every frame so the camera controllers cannot move it.
	local current = CFrame.lookAt(EYE, RIM)
	camera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep("BellwoodRimProbe", Enum.RenderPriority.Camera.Value + 1, function() camera.CFrame = current end)

	local marker: Part?
	local function neon(at: Vector3, size: Vector3)
		-- client-only anchored Neon slab: a part is never streamed, so if it shows at this range the render distance is fine
		if marker then marker:Destroy() end
		marker = Instance.new("Part")
		marker.Anchored, marker.CanCollide, marker.CanQuery, marker.Material = true, false, false, Enum.Material.Neon
		marker.Color, marker.Size, marker.CFrame, marker.Name = Color3.new(1, 0.2, 0.9), size, CFrame.new(at), "RimProbeMarker"
		marker.Parent = Workspace
	end
	local steps = {
		{ "baseline", function() end },
		{ "no atmosphere (H1)", function() if atmos then atmos.Density, atmos.Haze = 0, 0 end end },
		{ "noon, effects off (H1)", function()
			Lighting.ClockTime = 12
			for _, e in saved.effects do e[1].Enabled = false end
		end },
		{ "no clouds (H3)", function() if clouds then clouds.Enabled = false end end },
		{ "terrain decoration off", function() terrain.Decoration = false end },
		{ "neon marker on the rim, 40 x 300 (H2: distance, not streaming)", function() neon(RIM + Vector3.new(0, 150, 0), Vector3.new(40, 300, 40)) end },
		{ "half distance: camera 560 studs closer (H4)", function()
			if marker then marker:Destroy() end
			current = CFrame.lookAt(EYE:Lerp(Vector3.new(rimX, EYE.Y, rimZ), 0.5), RIM)
		end },
	}
	task.spawn(function()
		for i, step in steps do
			step[2]()
			line(string.format("STEP %d/%d  %s  capture now (%d s)", i, #steps, step[1], STEP_SECONDS))
			task.wait(STEP_SECONDS)
		end
		RunService:UnbindFromRenderStep("BellwoodRimProbe")
		if marker then marker:Destroy() end
		if atmos and saved.atmos then atmos.Density, atmos.Haze, atmos.Offset = table.unpack(saved.atmos) end
		if clouds and saved.cloudsOn ~= nil then clouds.Enabled = saved.cloudsOn end
		for _, e in saved.effects do e[1].Enabled = e[2] end
		Lighting.ClockTime, terrain.Decoration = saved.clock, saved.deco
		camera.CameraType, camera.CFrame, camera.FieldOfView = saved.type, saved.cf, saved.fov
		line("restored. Reading: rim returns at 'no atmosphere' = H1 (then tune Density/Haze/Offset at ~1100 studs); only at 'half distance' = H4 "
			.. "(radius vs 1095-stud sightline); the marker invisible while the rim returns nowhere = H2 (render/camera); at 'no clouds' = H3.")
	end)
end

if RunService:IsClient() then client() elseif RunService:IsServer() then server() end
