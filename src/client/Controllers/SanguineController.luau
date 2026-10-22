--!strict
-- Presentation-only bridge for VFX place 99240829139422. Existing controllers retain all ownership.
local RunService = game:GetService("RunService")
local Runtime = require(script.Parent.SanguineRuntime)
local Dispatch = require(script.Parent.SanguineDispatch)
local Combat = require(script.Parent.SanguineCombat)
local Visibility = require(script.Parent.HudVisibility)
local Weapons = require(game:GetService("ReplicatedStorage").AsurasPath.Simulation.WeaponSchema) :: any
local Controller = {}
Controller.__index = Controller
function Controller.new(state: any, ui: any): any
	assert(RunService:IsClient(), "Sanguine effects are client-only")
	local self = setmetatable({ State = state, Ui = ui, Context = Runtime.new(workspace),
		Last = {}, Disconnects = {}, Alive = true, Failed = false }, Controller)
	table.insert(self.Disconnects, state:OnEvent(function(event: any) self:Safe(Dispatch.event, event) end))
	table.insert(self.Disconnects, state:OnCue(function(cue: any) self:Safe(Dispatch.cue, cue) end))
	return self
end
function Controller.Blocked(self: any): boolean
	local own = self.State:Own()
	return not self.Alive or self.Failed or not own or not own.Root or not own.Snapshot
		or own.Snapshot.State == "KO" or not Visibility.of(self.Ui).Combat or Visibility.flags(self.Ui).Altar
		or workspace:GetAttribute("AsuraSanguineVFXEnabled") == false
end
function Controller.Near(self: any, point: any): boolean
	local own = self.State:Own()
	return typeof(point) == "Vector3" and own ~= nil and own.Root ~= nil and (point - own.Root.Position).Magnitude <= 65
end
function Controller.Clear(self: any)
	self.Context:Clear(); table.clear(self.Last)
end
function Controller.Safe(self: any, fn: any, value: any)
	if not self.Alive or self.Failed then return end
	local ok, problem = pcall(fn, self, value)
	if not ok then
		self.Failed = true; self:Clear()
		warn("[Asura VFX] Sanguine layer disabled; existing effects remain: " .. tostring(problem))
	end
end
local function step(self: any, dt: number)
	self.Context:Update(dt)
	if self:Blocked() then self:Clear(); return end
	for id in self.Last do if not self.State.Entities[id] then self.Last[id] = nil end end
	for id, entity in self.State.Entities do
		local snap, root = entity.Snapshot, entity.Root
		if not snap or not root or not self:Near(root.Position) then self.Last[id] = nil; continue end
		local previous = self.Last[id]
		local active = snap.State == "Active"
		local newSwing = active and (not previous or previous.State ~= "Active" or previous.Move ~= snap.Move or snap.StateElapsed < previous.Elapsed)
		if newSwing and snap.Move then
			local weapon = Weapons.Weapons[snap.Weapon] -- snapshots carry family keys (Jian), not asset ids (Jian_Sword).
			local move = if weapon then Weapons.findMove(weapon, snap.Move) else nil
			if move then Combat.slash(self.Context, root, move) end
		end
		self.Last[id] = { State = snap.State, Move = snap.Move, Elapsed = snap.StateElapsed }
	end
end
function Controller.Update(self: any, dt: number) self:Safe(step, dt) end
function Controller.Destroy(self: any)
	if not self.Alive then return end
	self.Alive = false
	for _, disconnect in self.Disconnects do disconnect() end
	table.clear(self.Disconnects); table.clear(self.Last); self.Context:Destroy()
end
return Controller
