--!nonstrict
-- Unmapped Studio-only seeded helper (combat recovery Stage 3). Insert during Play with tools/qa/qa_inject.py (never save). Equips the
-- weapon named by ServerStorage.AsuraStage3Weapon on the first player, so a family's clips can be checked without progressing to it.
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local Characters = require(game:GetService("ServerScriptService"):FindFirstChild("CharacterService", true))
local weapon = ServerStorage:GetAttribute("AsuraStage3Weapon")
local player = Players:GetPlayers()[1]
local ok, why = Characters.EquipWeapon(player.UserId, weapon)
ServerStorage:SetAttribute("AsuraStage3EquipResult", tostring(ok) .. " " .. tostring(why))
