--!nonstrict
-- Lune regression for playtest finding #24 (batch 14). Runs the real CastFigures, CostumeKit,
-- FighterAppearance, EnemyAppearance and WeaponModels on Lune-built R15 rigs: the speaking cast
-- stands with its head at the dialogue portrait height facing its approach, each NPC reads as a
-- different silhouette, Gao's attire binds to his live rig, the player's attire rebinds when the
-- avatar loader swaps a limb (the old "folder has children" check kept orphaned pieces), enemy
-- roles read apart, every visual piece is non-colliding and per-character piece counts stay within
-- budget. Geometry uses nominal R15 sizes and an emulated Model:ScaleTo; not a Studio view.
-- Run from the project root: lune run tools/test_cast_visuals.luau
local fs = require("@lune/fs")
local Scene = require("./rig_scene")
local Schema = require("../src/shared/CostumeSchema")
local Catalog = require("../src/shared/NarrativeCatalog")
local Weapons = require("../src/simulation/WeaponSchema")
local V3, CF, Instance = Scene.V3, Scene.CF, Scene.Instance

local passed, failed = 0, 0
local function check(name: string, condition: any)
	if condition then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local function src(path: string): string return fs.readFile(path) end
local Looks = Scene.load("src/shared/LooksCast.luau", { script = { Parent = { CostumeSchema = Schema } } })
local shared = { WaitForChild = function() return { Shared = { CostumeSchema = Schema, LooksCast = Looks }, Simulation = { WeaponSchema = Weapons } } end }
local game = { GetService = function() return shared end }
local Kit = Scene.load("src/server/Services/CostumeKit.luau", { game = game })
local Figures = Scene.load("src/server/Services/CastFigures.luau", { game = game, script = { Parent = { CostumeKit = Kit } } })

-- 1. Cast looks: valid, within budget.
for key, look in Looks do
	local ok, problems = Schema.validate(look)
	check(key .. " look validates (" .. table.concat(problems, "; ") .. ")", ok)
	check(key .. " stays within its piece budget", #look.Pieces <= (look.Budget or 0))
end

-- 2. Standing figures: portrait height, grounded feet, facing, collision only where solid.
local world = Instance.new("Folder")
local figures, silhouettes = {}, {}
for _, id in { "Lin", "Hermit" } do
	local n = Catalog.NPCs[id]
	local model, torso, head = Figures.statue(world, id, V3.new(n.X, n.Y - 1.8, n.Z))
	figures[id] = model
	check(id .. " head sits at the portrait subject height (n.Y + 2 ± 0.5)", math.abs(head.CFrame.Position.Y - (n.Y + 2)) <= 0.5 and head.Name == "Head")
	local foot = model:FindFirstChild("LeftFoot")
	check(id .. " stands on the ground", math.abs((foot.CFrame.Position.Y - foot.Size.Y / 2) - (n.Y - 1.8)) < 0.05)
	local look = Looks[id].Look
	local toward = (V3.new(look[1], n.Y, look[2]) - V3.new(n.X, n.Y, n.Z)).Unit
	check(id .. " faces the way players approach", torso.CFrame.LookVector:Dot(toward) > 0.98)
	local wrong, sighted, top, lo, hi = 0, 0, -math.huge, V3.new(math.huge, math.huge, math.huge), V3.new(-math.huge, -math.huge, -math.huge)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local solid = part.Parent == model and (part.Name == "UpperTorso" or part.Name == "LowerTorso" or string.find(part.Name, "Leg") ~= nil)
			if part.CanCollide ~= solid then wrong += 1 end
			if part.CanQuery ~= solid then sighted += 1 end
			local local_ = torso.CFrame:PointToObjectSpace(part.CFrame.Position)
			lo, hi = V3.new(math.min(lo.X, local_.X), math.min(lo.Y, local_.Y), math.min(lo.Z, local_.Z)), V3.new(math.max(hi.X, local_.X), math.max(hi.Y, local_.Y), math.max(hi.Z, local_.Z))
			top = math.max(top, part.CFrame.Position.Y + part.Size.Y / 2)
		end
	end
	check(id .. " only its torso and legs collide; attire never does", wrong == 0)
	-- F03: Lin's own arm hid her Speak prompt (line of sight to the torso) whenever the camera swung past her.
	check(id .. " non-colliding limbs never block its Speak prompt's line of sight", sighted == 0)
	silhouettes[id] = { Size = hi - lo, Top = top - head.CFrame.Position.Y }
end
check("the Hermit's staff rises well over his head", silhouettes.Hermit.Top > 1.5 and silhouettes.Lin.Top < 1.2)
check("the Hermit carries a pack behind him", figures.Hermit.AsuraAttire.Basket ~= nil and figures.Hermit.AsuraAttire.Staff ~= nil)
check("Lin's skirt reaches the ground and her hair falls down her back", (function()
	local hem = figures.Lin.AsuraAttire.SkirtHem
	return hem.CFrame.Position.Y - hem.Size.Y / 2 - (Catalog.NPCs.Lin.Y - 1.8) < 0.2 and figures.Lin.AsuraAttire.LongHair ~= nil
end)())
check("Lin carries a light that reads in the dark Sanctuary", figures.Lin.AsuraAttire.SoulLantern:FindFirstChildOfClass("PointLight") ~= nil)
check("Lin and the Hermit have different silhouettes", (silhouettes.Lin.Size - silhouettes.Hermit.Size).Magnitude > 0.8)
local projection = figures.Lin:Clone()
check("Lin's figure clones whole for the altar projection", #projection:GetDescendants() == #figures.Lin:GetDescendants())

-- 3. Gao: attire binds to the live rig itself; a broken rig is diagnosed.
local gao = Scene.rig("MasterSmithGao")
local missing = Figures.dress(gao, "Gao")
local welded = 0
for _, piece in gao.AsuraAttire:GetChildren() do
	if piece.AsuraBind.Part0.Parent == gao and not piece.CanCollide and not piece.CanQuery then welded += 1 end
end
check("Gao's blindfold, apron and bracers bind to his live limbs", #missing == 0 and welded == #Looks.Gao.Pieces and gao.AsuraAttire.Blindfold ~= nil)
local broken = Scene.rig("Broken"); broken.LeftHand:Destroy(); broken.RightHand:Destroy()
local lost = Figures.dress(broken, "Gao")
table.sort(lost)
check("a rig missing limbs reports exactly what could not bind", table.concat(lost, ",") == "LeftHand,RightHand")
check("Gao is dressed when the Sanctuary spawns him", string.find(src("src/server/Services/SanctuaryService.luau"), 'Figures.dress(model, "Gao")', 1, true) ~= nil)
check("NPC figures replace the robe blocks", string.find(src("src/server/Services/NarrativeWorld.luau"), "Figures.statue(root,id,", 1, true)
	and not string.find(src("src/server/Services/NarrativeWorld.luau"), '"Sleeve"', 1, true))

-- 4. The player: attire rebinds to replaced limbs (root cause of the "bald block" report).
local deferred = {}
local Fighter = Scene.load("src/server/FighterAppearance.luau", { task = { defer = function(f) table.insert(deferred, f) end } })
local player = Scene.rig("Player")
player.Parent = world
local links = {}
Fighter.Apply(player, links)
local attire = player.AsuraAttire
local count = #attire:GetChildren()
check("player attire is built and welded", Fighter.Attached(player, attire) and count >= 30)
check("player has hair, eyes and brows", attire:FindFirstChild("HairCap") and attire:FindFirstChild("Queue") and attire:FindFirstChild("Eye") and attire:FindFirstChild("Brow"))
local bad = 0
for _, piece in attire:GetChildren() do if piece.CanCollide or piece.CanQuery or piece.CanTouch or not piece.Massless then bad += 1 end end
check("player attire never collides, queries or touches", bad == 0)
check("player piece count stays modest", count <= 48)
local oldHead = player.Head
local newHead = Instance.new("Part"); newHead.Name = "Head"; newHead.Size = V3.new(1.3, 1.3, 1.3); newHead.CFrame = oldHead.CFrame
oldHead.Parent = nil
newHead.Parent = player
check("after the avatar loader swaps the head, the old check would keep the orphaned attire", #attire:GetChildren() > 0 and not Fighter.Attached(player, attire))
Scene.fireChildAdded(player, newHead)
for _, f in deferred do f() end
local rebuilt = player:FindFirstChild("AsuraAttire")
check("the new head is re-dressed and every piece binds to a live limb", rebuilt and rebuilt ~= attire and Fighter.Attached(player, rebuilt)
	and rebuilt.HairCap:FindFirstChildOfClass("WeldConstraint").Part0 == newHead)
local again = #deferred
Fighter.Apply(player, links)
check("re-applying an intact outfit does not rebuild it", player.AsuraAttire == rebuilt and #links <= 1 and #deferred == again)

-- 5. Normal enemies: brawler and swordsman read apart; the training phantom is unmistakable.
local Enemy = Scene.load("src/server/EnemyAppearance.luau", { script = { Parent = { WaitForChild = function() return Fighter end } } })
local looks = {}
for _, id in { "CorruptWanderingMonk", "CursedSwordsman", "SparringPhantom" } do
	local rig = Scene.rig(id)
	check(id .. " has an authored look", Enemy.Apply(rig, id))
	local outfit, hits = rig.AsuraAttire, 0
	for _, piece in outfit:GetChildren() do if piece.CanCollide or piece.CanQuery then hits += 1 end end
	check(id .. " attire is non-colliding and within 40 pieces", hits == 0 and #outfit:GetChildren() <= 40)
	looks[id] = rig
end
check("brawler: iron-knuckled fists on both hands", #(function()
	local list = {}
	for _, p in looks.CorruptWanderingMonk.AsuraAttire:GetChildren() do if p.Name == "IronKnuckles" then table.insert(list, p) end end
	return list
end)() == 2)
check("swordsman: a scabbard at the hip and a kasa", looks.CursedSwordsman.AsuraAttire:FindFirstChild("Scabbard") and looks.CursedSwordsman.AsuraAttire:FindFirstChild("BlackKasa"))
check("phantom: translucent jade body with a training sash", looks.SparringPhantom.UpperTorso.Transparency > 0.2 and looks.SparringPhantom.AsuraAttire:FindFirstChild("TrainingSash"))

-- 6. Stock weapons gain fittings without changing the blade (trail anchor and reach read).
local Models = Scene.load("src/server/Services/WeaponModels.luau", { game = game })
for _, case in { { "Jian", V3.new(0.12, 0.28, 4.2), { "Guard", "GripWrap", "Pommel", "Tassel" } }, { "Dao", V3.new(0.16, 0.5, 3.6), { "Guard", "BackSpine" } },
	{ "Guandao", V3.new(0.22, 0.22, 8.5), { "MoonBlade", "DragonMouth", "Counterweight" } } } do
	local blade = Instance.new("Part"); blade.Name = "AsuraWeapon"; blade.Size = case[2]; blade.CFrame = CF.new(0, 3, 0)
	Models.dress(blade, case[1])
	local ok = (blade.Size - case[2]).Magnitude < 1e-5
	for _, name in case[3] do
		local p = blade:FindFirstChild(name)
		local weld = p and p:FindFirstChildOfClass("WeldConstraint")
		if not (p and not p.CanCollide and not p.CanQuery and p.Massless and weld and weld.Part0 == blade) then ok = false; print("  fitting", case[1], name, p, weld) end
	end
	check(case[1] .. " fittings are welded to an unchanged blade", ok)
end
check("held stock weapons are dressed", string.find(src("src/server/CharacterService.luau"), "WeaponModels.dress(part, e.Fighter.Weapon)", 1, true) ~= nil)
check("phase recolours skip weapon fittings", string.find(src("src/server/CharacterService.luau"), 'descendant.Parent.Name == "AsuraWeapon"', 1, true) ~= nil)
-- Post-F26 step 2: arcs follow the server's committed strike for every actor, boss looks included.
check("weapon arcs follow the validated strike record", string.find(src("src/client/Controllers/WeaponTrails.luau"), 'GetAttribute("AsuraStrike")', 1, true) ~= nil)

print(string.format("cast visuals: %d passed, %d failed", passed, failed))
if failed > 0 then error("cast visuals regression failed") end
