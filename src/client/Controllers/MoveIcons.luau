--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/MoveIcons
-- Small pictorial move icons drawn from rotated frames, so no image uploads are needed: sword
-- slash, heavy cleave, shield, crossed-blade parry, dash chevrons, weapon-art burst, healing gourd,
-- lock reticle, and one per spell discipline (lightning bolt, flame, void, paper talisman).
-- Icons.draw returns a square CanvasGroup; fade the whole picture with GroupTransparency.
local Shapes = require(script.Parent:WaitForChild("IconShapes") :: ModuleScript)
local Sakura = require(script.Parent:WaitForChild("SakuraKit") :: ModuleScript)

local Icons = {}
local C = Sakura.Colors
local box, line, disc, ring, sword = Shapes.box, Shapes.line, Shapes.disc, Shapes.ring, Shapes.sword

-- Customization ------------------------------------------------------------------------------
Icons.Ink = C.Blossom -- main line colour
Icons.Fill = 0.64 -- icon size as a fraction of its parent

export type Kind = "Light" | "Heavy" | "Block" | "Parry" | "Dash" | "WeaponArt" | "Heal" | "Lock" | "Arsenal"
	| "CelestialThunder" | "CrimsonFlame" | "AbyssalVoid" | "SpiritTalismans" | "Empty"

local DRAW: { [string]: (Instance, number) -> () } = {
	Light = function(i, px)
		ring(i, 0.5, 0.5, 0.92, px * 0.05, C.Sakura, 0.55, 225)
		sword(i, 0.22, 0.78, 0.8, 0.2, 0.09, Icons.Ink)
	end,
	Heavy = function(i, px)
		sword(i, 0.5, 0.08, 0.5, 0.72, 0.16, Icons.Ink)
		for _, side in { -1, 1 } do -- impact cracks
			line(i, 0.5 + side * 0.12, 0.78, 0.5 + side * 0.34, 0.64, 0.06, Shapes.Accent)
			line(i, 0.5 + side * 0.14, 0.86, 0.5 + side * 0.4, 0.82, 0.06, Shapes.Accent)
		end
		line(i, 0.18, 0.92, 0.82, 0.92, 0.06, C.Sakura)
	end,
	Block = function(i)
		box(i, 0.5, 0.36, 0.64, 0.46, 0, Icons.Ink, 0.22)
		box(i, 0.5, 0.56, 0.45, 0.45, 45, Icons.Ink, 0.12)
		box(i, 0.5, 0.46, 0.08, 0.5, 0, C.Plum, 0.5)
		disc(i, 0.5, 0.42, 0.2, Shapes.Accent)
	end,
	Parry = function(i)
		sword(i, 0.18, 0.82, 0.74, 0.22, 0.08, Icons.Ink)
		sword(i, 0.82, 0.82, 0.26, 0.22, 0.08, Icons.Ink)
		for n = 0, 3 do box(i, 0.5, 0.4, 0.46, 0.06, n * 45, Shapes.Accent, 0.5) end
		disc(i, 0.5, 0.4, 0.14, C.Ivory)
	end,
	Dash = function(i)
		for n, x in { 0.24, 0.48, 0.72 } do
			local color = if n == 3 then Icons.Ink else C.Sakura
			line(i, x - 0.12, 0.22, x + 0.08, 0.5, 0.1, color)
			line(i, x - 0.12, 0.78, x + 0.08, 0.5, 0.1, color)
		end
	end,
	WeaponArt = function(i)
		for n = 0, 3 do box(i, 0.5, 0.5, if n % 2 == 0 then 0.94 else 0.6, 0.12, n * 45, if n % 2 == 0 then Icons.Ink else Shapes.Accent, 0.5) end
		disc(i, 0.5, 0.5, 0.3, C.Ivory)
		disc(i, 0.5, 0.5, 0.16, C.Rose)
	end,
	Heal = function(i)
		disc(i, 0.5, 0.66, 0.54, Icons.Ink)
		disc(i, 0.5, 0.32, 0.34, Icons.Ink)
		box(i, 0.5, 0.12, 0.16, 0.12, 0, Shapes.Accent, 0.3)
		box(i, 0.5, 0.48, 0.42, 0.06, 0, C.Rose, 0.5)
		box(i, 0.5, 0.68, 0.22, 0.07, 0, C.Crimson, 0.5)
		box(i, 0.5, 0.68, 0.07, 0.22, 0, C.Crimson, 0.5)
	end,
	Lock = function(i, px)
		ring(i, 0.5, 0.5, 0.66, px * 0.07, Icons.Ink)
		for n = 0, 3 do
			local r = math.rad(n * 90)
			line(i, 0.5 + math.cos(r) * 0.3, 0.5 + math.sin(r) * 0.3, 0.5 + math.cos(r) * 0.48, 0.5 + math.sin(r) * 0.48, 0.08, Shapes.Accent)
		end
		disc(i, 0.5, 0.5, 0.14, C.Crimson)
	end,
	Arsenal = function(i)
		sword(i, 0.2, 0.8, 0.8, 0.2, 0.09, Icons.Ink)
		sword(i, 0.8, 0.8, 0.2, 0.2, 0.09, C.Sakura)
		disc(i, 0.5, 0.5, 0.16, Shapes.Accent)
	end,
	CelestialThunder = function(i)
		local pts = { { 0.64, 0.06 }, { 0.36, 0.5 }, { 0.6, 0.48 }, { 0.36, 0.94 } }
		for n = 1, 3 do line(i, pts[n][1], pts[n][2], pts[n + 1][1], pts[n + 1][2], 0.16, Color3.fromRGB(255, 236, 160)) end
		for n = 1, 3 do line(i, pts[n][1], pts[n][2], pts[n + 1][1], pts[n + 1][2], 0.06, C.Ivory) end
	end,
	CrimsonFlame = function(i)
		local tongues: { { Y: number, D: number, Color: Color3 } } = { { Y = 0.62, D = 0.56, Color = C.Crimson }, { Y = 0.7, D = 0.32, Color = Shapes.Accent } }
		for _, f in tongues do -- teardrop = disc + diamond tip
			disc(i, 0.5, f.Y, f.D, f.Color)
			box(i, 0.5, f.Y - f.D * 0.32, f.D * 0.62, f.D * 0.62, 45, f.Color, 0.18)
		end
		disc(i, 0.24, 0.74, 0.16, C.Rose)
		disc(i, 0.76, 0.74, 0.16, C.Rose)
	end,
	AbyssalVoid = function(i, px)
		ring(i, 0.5, 0.5, 0.9, px * 0.05, C.Qi, 0.45, 30)
		ring(i, 0.5, 0.5, 0.66, px * 0.05, Icons.Ink, 0.45, 210)
		local core = disc(i, 0.5, 0.5, 0.36, C.Ink)
		Shapes.make("UIStroke", core, { Color = C.Qi, Thickness = math.max(1, px * 0.05) })
	end,
	SpiritTalismans = function(i)
		box(i, 0.5, 0.5, 0.42, 0.84, 8, Color3.fromRGB(246, 226, 176), 0.08)
		for n, y in { 0.26, 0.4, 0.54 } do box(i, 0.5 + (n - 2) * 0.01, y, 0.24, 0.05, 8, C.Ink, 0.5) end
		disc(i, 0.53, 0.72, 0.2, C.Crimson)
	end,
	Empty = function(i)
		disc(i, 0.5, 0.5, 0.16, C.Sakura)
	end,
}

function Icons.draw(parent: Instance, kind: string, px: number): CanvasGroup
	local group = Shapes.make("CanvasGroup", parent, {
		Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(Icons.Fill, Icons.Fill), BackgroundTransparency = 1, ZIndex = 3,
	}) :: CanvasGroup
	Shapes.make("UIAspectRatioConstraint", group, { AspectRatio = 1 })
	local draw = DRAW[kind] or DRAW.Empty
	draw(group, px * Icons.Fill)
	return group
end

return table.freeze(Icons)
