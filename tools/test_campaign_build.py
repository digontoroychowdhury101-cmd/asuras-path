#!/usr/bin/env python3
"""Batches 16-21: run the real region builders offline (CampaignWorld, RegionDecor, the five dressings,
SanctuaryApproach) on tools/roblox_shim.luau, since Lune is not installed locally.

Checks they build without errors or warnings, that the only colliding parts are the layout boxes the
reachability suite walks (all dressing is decor), the material vocabulary (no Neon or SmoothPlastic),
and part / light / emitter budgets per region. Not covered: rendering, meshes, physics, Studio.
"""
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SERVER = ["MonasteryKit", "MonasteryFx", "RegionDecor", "PbrAssets", "CampaignBounds", "CampaignTerrain", "BambooDressing", "ColosseumDressing",
          "CryptDressing", "PagodaDressing", "CitadelDressing", "CampaignWorld", "SanctuaryKit", "SanctuaryRails",
          "SanctuaryFrame", "SanctuaryApproach"]

loaders = []
for name in SERVER:
    source = (ROOT / f"src/server/Services/{name}.luau").read_text()
    source = re.sub(r"^export type", "type", source, flags=re.M)
    loaders.append(f"sources[{name!r}] = function(script, require, game, workspace)\n{source}\nend")

harness = r'''
local Shim = require("../tools/roblox_shim")
Vector3, CFrame, Color3, Enum, Instance = Shim.Vector3, Shim.CFrame, Shim.Color3, Shim.Enum, Shim.Instance
Random, NumberSequence, NumberSequenceKeypoint, ColorSequence, NumberRange = Shim.Random, Shim.NumberSequence, Shim.NumberSequenceKeypoint, Shim.ColorSequence, Shim.NumberRange
Vector2, UDim2 = Shim.Vector2, Shim.UDim2
task = { spawn = function() end, wait = function() return 0.2 end, delay = function() end }
local warnings = {}
warn = function(...) table.insert(warnings, table.concat({ ... }, " ")) end
local printed = print
print = function() end

local shared = {
	WorldDefinitions = require("../src/shared/WorldDefinitions"), CampaignZones = require("../src/shared/CampaignZones"),
	RegionLayout = require("../src/shared/RegionLayout"), PresentationAssets = require("../src/shared/PresentationAssets"),
	SanctuaryRoutes = require("../src/shared/SanctuaryRoutes"),
}
local function finder(t) t.WaitForChild = function(self, n) return self[n] end; return t end
local replicated = finder({ AsurasPath = finder({ Shared = finder(shared) }) })
local Workspace = Shim.new("Workspace")
local services = { ReplicatedStorage = replicated, Workspace = Workspace, ServerStorage = Shim.new("ServerStorage"),
	Players = { GetPlayers = function() return {} end } }
local game = { GetService = function(_, n) return services[n] end }
local sources, modules = {}, {}
local folder = { WaitForChild = function(_, n) return n end }
setmetatable(folder, { __index = function(_, n) return n end })
local function load(name)
	if type(name) == "table" then return name end -- an already-loaded shared module
	if modules[name] == nil then
		if name == "CharacterService" then modules[name] = {} else
			modules[name] = sources[name]({ Parent = folder }, load, game, Workspace)
		end
	end
	return modules[name]
end
-- LOADERS

local passed, failed = 0, 0
local function check(label, ok) if ok then passed += 1 else failed += 1; printed("FAIL " .. label) end end

local okStart, problem = pcall(function() load("CampaignWorld").Start() end)
check("CampaignWorld.Start runs: " .. tostring(problem), okStart)
check("no builder warnings: " .. table.concat(warnings, " | "), #warnings == 0)
local Campaign = shared.CampaignZones
local function audit(label, root, solids, budget)
	local parts, colliding, lights, emitters, flat = 0, 0, 0, 0, 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			if d.CanCollide then colliding += 1 end
			local m = d.Material and d.Material.Name
			local housedPaper = label == "Sanctuary routes" and d.Parent and d.Parent.Name == "FrostedLanternChamber"
				and ((d.Name == "FrostedPaperPane" and d.Size.Z <= 0.03) or d.Name == "ShelteredFlame")
			if (m == "Neon" and not housedPaper) or m == "SmoothPlastic" then flat += 1 end
		elseif d.ClassName == "PointLight" or d.ClassName == "SpotLight" then lights += 1
		elseif d.ClassName == "ParticleEmitter" then emitters += 1 end
	end
	printed(string.format("  %-16s %5d parts  %3d colliding  %2d lights  %2d emitters", label, parts, colliding, lights, emitters))
	check(label .. " collides only with its layout boxes", colliding == solids)
	check(label .. " uses crafted materials; emissive paper stays inside framed lanterns", flat == 0)
	check(label .. " stays inside its budget", parts <= budget.Parts and lights <= budget.Lights and emitters <= budget.Emitters)
end
for _, layout in Campaign.Layouts do
	local map = Workspace:FindFirstChild(shared.WorldDefinitions.Regions[layout.Region].MapFolder)
	check(layout.Region .. " map is raised", map ~= nil and map:GetAttribute("AsuraRegion") == layout.Region)
	if map then audit(layout.Region, map, #layout.Solids, { Parts = 2600, Lights = 40, Emitters = 40 }) end
end
-- Batch 26: Start/Destroy cycles leave no region map behind and rebuild identically.
local function total() local n = 0; for _, d in Workspace:GetDescendants() do if d:IsA("BasePart") then n += 1 end end; return n end
local first = total()
local stable = true
for _ = 1, 3 do
	load("CampaignWorld").Destroy()
	local leftover = 0
	for _, layout in Campaign.Layouts do
		local map = Workspace:FindFirstChild(shared.WorldDefinitions.Regions[layout.Region].MapFolder)
		if map and map.Parent == Workspace then leftover += 1 end
	end
	if leftover > 0 or total() ~= 0 then stable = false end
	load("CampaignWorld").Start()
	if total() ~= first then stable = false end
end
check(string.format("CampaignWorld Start/Destroy x3 leaves nothing behind and rebuilds the same %d parts", first), stable)
local sanctuary = Shim.new("Folder")
local okRoutes, routeProblem = pcall(function() load("SanctuaryApproach").Build(sanctuary) end)
check("SanctuaryApproach.Build runs: " .. tostring(routeProblem), okRoutes)
audit("Sanctuary routes", sanctuary, #shared.SanctuaryRoutes.Solids, { Parts = 600, Lights = 20, Emitters = 20 })
printed(string.format("campaign build: %d passed, %d failed", passed, failed))
if failed > 0 then error("campaign build regression failed") end
'''
source = harness.replace("-- LOADERS", "\n".join(loaders))
output = ROOT / "work/test_campaign_build.generated.luau"
output.parent.mkdir(exist_ok=True)
output.write_text(source)
result = subprocess.run([str(ROOT / "work/bin/luau/luau"), str(output)], cwd=ROOT / "tools")
output.unlink()
sys.exit(result.returncode)
