--!strict
-- Studio command-bar check. Typed instances avoid interpreting WAV asset IDs as images.
task.spawn(function()
	local assets = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.PresentationAssets)
	local items: {Instance} = {}
	for _, id in assets.Audio do
		if id == "" then continue end
		local sound=Instance.new("Sound");sound.SoundId=id;table.insert(items,sound)
	end
	for _, section in {assets.Textures,assets.Sky} do
		for _, id in section do
			if id == "" then continue end
			local decal=Instance.new("Decal");decal.Texture=id;table.insert(items,decal)
		end
	end
	local result: {[string]: string} = {}
	local ok, reason = pcall(function()
		game:GetService("ContentProvider"):PreloadAsync(items,function(id,status) result[id]=status.Name end)
	end)
	for _, item in items do item:Destroy() end
	print("[Asura AV Media] "..game:GetService("HttpService"):JSONEncode(result))
	if not ok then warn(reason) end
end)
