--!strict
-- Run in the Studio SERVER command bar during Play. Read-only; never publishes or uploads.
local Services = game:GetService("ServerScriptService").AsurasPath.Services
local Audit = require(Services.PresentationAudit)
local Assets = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.PresentationAssets)
local missing = { Audio = {}, Textures = {} }
for category, list in {Audio=Assets.Audio,Textures=Assets.Textures} do
 for key,id in list do if id=="" then table.insert((missing :: any)[category],key) end end
end
for _, name in {"Sanctuary","Map_DesecratedMonastery"} do
 local root = workspace:FindFirstChild(name)
 if root then Audit.Run(root) end
end
local library = game:GetService("ServerStorage"):FindFirstChild("AsuraAssets")
if library then Audit.Run(library) end
print("[Asura AV Uploads Missing] "..game:GetService("HttpService"):JSONEncode(missing))
print("Measure draw calls, GPU time and device memory with Studio Rendering/Performance stats during combat; instance counts cannot certify them.")
