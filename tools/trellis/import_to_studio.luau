--!strict
-- tools/trellis/import_to_studio.luau
-- Loads an asset into workspace by Asset ID or locates recently imported MeshParts.
-- Can be run via Studio Command Bar or StudioMCP (execute_luau).

local InsertService = game:GetService("InsertService")
local Workspace = game:GetService("Workspace")

local function loadAssetIntoStudio(assetId: number, modelName: string?)
    print(string.format("[TRELLIS Loader] Loading Asset ID: %d...", assetId))
    local success, result = pcall(function()
        return InsertService:LoadAsset(assetId)
    end)

    if not success or not result then
        warn(string.format("[TRELLIS Loader] Failed to load asset %d: %s", assetId, tostring(result)))
        return nil
    end

    local model = result
    if modelName and modelName ~= "" then
        model.Name = modelName
    end

    model.Parent = Workspace
    
    -- Position in front of the camera
    local camera = Workspace.CurrentCamera
    if camera then
        local spawnPos = camera.CFrame.Position + camera.CFrame.LookVector * 15
        model:MoveTo(spawnPos)
    end

    print(string.format("[TRELLIS Loader] Successfully placed '%s' into Workspace!", model.Name))
    return model
end

return {
    load = loadAssetIntoStudio
}
