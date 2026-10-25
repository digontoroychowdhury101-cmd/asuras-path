--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/SakuraHud
-- Owns the sakura HUD furniture that is not tied to combat state: the compass, the minimap (with
-- its Respite / Controls buttons) and a light drift of screen-space petals. Hidden with the rest
-- of the HUD during the prologue and the death screen. Petals are decoration: they thin out and
-- fade during fights (and with reduced effects) so warnings stay the brightest thing on screen.
local Players = game:GetService("Players")
local Effects = require(game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath"):WaitForChild("Shared"):WaitForChild("EffectsPreference") :: ModuleScript)
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)
local Visibility = require(script.Parent:WaitForChild("HudVisibility") :: ModuleScript)
local Sakura = require(script.Parent:WaitForChild("SakuraKit") :: ModuleScript)
local Compass = require(script.Parent:WaitForChild("SakuraCompass") :: ModuleScript)
local Minimap = require(script.Parent:WaitForChild("SakuraMinimap") :: ModuleScript)

local Controller = {}
Controller.__index = Controller
local C = Sakura.Colors

-- Customization ------------------------------------------------------------------------------
local PETALS = 14 -- 0 disables the overlay
local FALL = { 28, 64 } -- pixels per second
local SWAY = 26 -- pixels
local ENGAGE_RADIUS = 45 -- a live hostile this close (or a boss encounter) counts as a fight
local BLEND = 2.5 -- density change per second

type Petal = { Gui: Frame, X: number, Y: number, Speed: number, Phase: number, Spin: number, Size: number, Alpha: number }
export type SakuraHud = typeof(setmetatable({} :: {
	Ui: any, State: any, Compass: Compass.View, Minimap: Minimap.View, Layer: Frame, Petals: { Petal }, Random: Random,
	Density: number, Engaged: boolean, Probe: number,
}, Controller))

-- In an active fight: a boss encounter, or a live hostile within ENGAGE_RADIUS.
local function engaged(state: any): boolean
	local boss = Players.LocalPlayer:GetAttribute("AsuraEncounter")
	if type(boss) == "string" and boss ~= "" then
		return true
	end
	local own = state:Own()
	if not own or not own.Root then
		return false
	end
	for _, entity in state.Entities do
		if entity.Root and state:IsHostile(entity) and state:IsAlive(entity)
			and (entity.Root.Position - own.Root.Position).Magnitude <= ENGAGE_RADIUS then
			return true
		end
	end
	return false
end

function Controller.new(state: any, ui: any, pause: any, controls: any): SakuraHud
	local layer = HudKit.make("Frame", ui.Gui, {
		Name = "SakuraPetals", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 0, Active = false,
	}) :: Frame
	local rng = Random.new()
	local petals: { Petal } = {}
	for _ = 1, PETALS do
		local size = rng:NextNumber(8, 14)
		local alpha = rng:NextNumber(0.15, 0.45)
		local gui = HudKit.make("Frame", layer, {
			AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size, size * 0.62), BorderSizePixel = 0,
			BackgroundColor3 = if rng:NextNumber() < 0.5 then C.BloodPetal else C.EmberPetal, BackgroundTransparency = alpha,
		}) :: Frame
		HudKit.make("UICorner", gui, { CornerRadius = UDim.new(1, 0) })
		table.insert(petals, {
			Gui = gui, X = rng:NextNumber(), Y = rng:NextNumber(-40, 900), Speed = rng:NextNumber(FALL[1], FALL[2]),
			Phase = rng:NextNumber(0, math.pi * 2), Spin = rng:NextNumber(-90, 90), Size = size, Alpha = alpha,
		})
	end
	local buttons = {
		{ Glyph = "≡", Angle = 305, Press = function() pause:Toggle() end },
		{ Glyph = "?", Angle = 55, Press = function() controls:SetOpen(not controls.Open) end },
	}
	return setmetatable({
		Ui = ui, State = state, Compass = Compass.new(ui.Gui), Minimap = Minimap.new(ui.Gui, state, buttons), Layer = layer, Petals = petals,
		Random = rng, Density = 1, Engaged = false, Probe = 0,
	}, Controller)
end

function Controller.Update(self: SakuraHud, dt: number)
	local hidden = not Visibility.of(self.Ui).Decor
	self.Compass.Root.Visible = not hidden
	self.Minimap.Root.Visible = not hidden
	self.Layer.Visible = not hidden
	if hidden then return end
	Compass.step(self.Compass)
	Minimap.step(self.Minimap, self.Ui.Route)
	self.Probe -= dt
	if self.Probe <= 0 then
		self.Probe, self.Engaged = 0.25, engaged(self.State)
	end
	local target = Effects.decor(self.Engaged)
	self.Density += math.clamp(target - self.Density, -BLEND * dt, BLEND * dt)
	local shown = math.ceil(#self.Petals * self.Density - 1e-3)
	local contrast = if self.Engaged then Effects.CombatContrast else 1
	local height = math.max(self.Layer.AbsoluteSize.Y, 1)
	for index, p in self.Petals do
		p.Gui.Visible = index <= shown
		p.Gui.BackgroundTransparency = 1 - (1 - p.Alpha) * contrast
		p.Y += p.Speed * dt
		p.Phase += dt * 1.6
		if p.Y > height + 20 then
			p.Y, p.X = -20, self.Random:NextNumber()
		end
		p.Gui.Position = UDim2.new(p.X, math.sin(p.Phase) * SWAY, 0, p.Y)
		p.Gui.Rotation += p.Spin * dt
		p.Gui.Size = UDim2.fromOffset(p.Size * (0.35 + 0.65 * math.abs(math.cos(p.Phase * 0.8))), p.Size * 0.62) -- tumbling flip
	end
end

function Controller.Destroy(self: SakuraHud)
	self.Compass.Root:Destroy()
	self.Minimap.Root:Destroy()
	self.Layer:Destroy()
end

return Controller
