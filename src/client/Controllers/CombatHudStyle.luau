--!strict
local rgb = Color3.fromRGB
local palette = require(script.Parent.HudKit).Palette

return table.freeze({
	Ink = palette.Ink,
	Raised = rgb(45, 43, 35),
	Track = rgb(38, 33, 28),
	Edge = rgb(155, 125, 83),
	Patina = rgb(62, 49, 34),
	Shade = rgb(11, 12, 10),
	Gold = palette.Gold,
	Ivory = palette.Ivory,
	Muted = palette.Muted,
	Blood = rgb(205, 79, 56),
	Danger = rgb(255, 149, 122),
	Rally = rgb(216, 146, 81),
	Scar = rgb(85, 48, 42),
	Bone = rgb(224, 206, 161),
	Jade = palette.Jade,
})
