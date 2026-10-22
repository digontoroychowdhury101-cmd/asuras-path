--!strict
-- Read-only: run in Studio's edit-mode command bar after importing/renaming the media.
-- Save the printed JSON to a file; register_uploads.py applies the real references to source.
local data: any = {Audio={},Textures={},Sky={},Models={}}
local SoundService = game:GetService("SoundService")
local ServerStorage = game:GetService("ServerStorage")
local function id(value: string): string
 local number=string.match(value,"[?&]id=(%d+)") or string.match(value,"rbxassetid://(%d+)")
 return if number then "rbxassetid://"..number else ""
end
local audio=SoundService:FindFirstChild("AsuraAudio")
if audio then for _,sound in audio:GetChildren() do if sound:IsA("Sound") and sound.SoundId~="" then data.Audio[sound.Name]=id(sound.SoundId) end end end
for category,folderName in {Textures="AsuraTextures",Sky="AsuraArenaSky"} do
 local folder=ServerStorage:FindFirstChild(folderName)
 if folder then
  for _,decal in folder:GetChildren() do
   if decal:IsA("Decal") and decal.Texture~="" then data[category][decal.Name]=id(decal.Texture) end
  end
 end
end
local library=ServerStorage:FindFirstChild("AsuraAssets")
if library then
 for _,model in library:GetChildren() do
  if not model:IsA("Model") then continue end
  local parts={}
  for _,p in model:GetDescendants() do
   if not p:IsA("MeshPart") then continue end
   local s=p:FindFirstChildOfClass("SurfaceAppearance")
   if not s then warn(p:GetFullName()..": missing PBR");continue end
   table.insert(parts,{Name=p.Name,MeshId=id(p.MeshId),ColorMap=id(s.ColorMap),NormalMap=id(s.NormalMap),RoughnessMap=id(s.RoughnessMap),MetalnessMap=id(s.MetalnessMap)})
  end
  if #parts>0 then data.Models[model.Name]=parts end
 end
end
print(game:GetService("HttpService"):JSONEncode(data))
