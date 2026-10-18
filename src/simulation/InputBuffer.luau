--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Simulation/InputBuffer
-- Fixed-capacity circular input buffer. Slots are allocated once; pushes overwrite in place.
-- Consuming a buffered input never bypasses MoveSchema.canAct at the moment it is executed.
local hasScript = pcall(function()
	return script.Parent
end)
local Settings: any
if hasScript then
	Settings = require(script.Parent.Parent.Shared.CombatSettings)
else
	Settings = require("../shared/CombatSettings")
end

export type BufferedAction =
	"Light"
	| "Heavy"
	| "RunningAttack"
	| "WeaponArt"
	| "Roll"
	| "Dash"
	| "Deflect"
	| "Block"
	| "Heal"
	| "Equip"

export type Slot = {
	Live: boolean,
	Action: BufferedAction,
	Priority: number,
	Time: number,
	Sequence: number,
	Variant: string,
	DirX: number,
	DirZ: number,
}

export type Buffer = {
	Slots: { Slot },
	Capacity: number,
	Window: number,
	Head: number,
	Count: number,
	Sequence: number,
}

export type Filter = (action: BufferedAction, variant: string) -> boolean

local InputBuffer = {}

local PRIORITY: { [string]: number } = Settings.Input.Priority
local DEFAULT_WINDOW: number = Settings.Input.BufferWindow
local DEFAULT_CAPACITY: number = Settings.Input.BufferCapacity
local DUPLICATE_WINDOW: number = Settings.Input.DuplicateWindow

function InputBuffer.priority(action: BufferedAction): number
	local value = PRIORITY[action]
	assert(value ~= nil, "Unbuffered action " .. tostring(action))
	return value
end

function InputBuffer.new(capacity: number?, window: number?): Buffer
	local size = capacity or DEFAULT_CAPACITY
	assert(size % 1 == 0 and size >= 1 and size <= 64, "InputBuffer capacity must be an integer in 1..64")
	local lifetime = window or DEFAULT_WINDOW
	assert(lifetime == lifetime and lifetime > 0 and lifetime <= 1, "InputBuffer window must be in (0, 1]")
	local slots: { Slot } = table.create(size) :: any
	for index = 1, size do
		slots[index] = {
			Live = false,
			Action = "Light",
			Priority = 0,
			Time = 0,
			Sequence = 0,
			Variant = "",
			DirX = 0,
			DirZ = 0,
		}
	end
	return {
		Slots = slots,
		Capacity = size,
		Window = lifetime,
		Head = 1,
		Count = 0,
		Sequence = 0,
	}
end

local function slotIndex(buffer: Buffer, offset: number): number
	return (buffer.Head - 1 + offset) % buffer.Capacity + 1
end

-- Advances Head past consumed or expired slots so Count always spans live-or-pending entries.
local function compact(buffer: Buffer)
	while buffer.Count > 0 and not buffer.Slots[buffer.Head].Live do
		buffer.Head = buffer.Head % buffer.Capacity + 1
		buffer.Count -= 1
	end
	if buffer.Count == 0 then
		buffer.Head = 1
	end
end

function InputBuffer.flush(buffer: Buffer, now: number): number
	local removed = 0
	for offset = 0, buffer.Count - 1 do
		local slot = buffer.Slots[slotIndex(buffer, offset)]
		if slot.Live and now - slot.Time > buffer.Window then
			slot.Live = false
			removed += 1
		end
	end
	compact(buffer)
	return removed
end

function InputBuffer.clear(buffer: Buffer)
	for _, slot in buffer.Slots do
		slot.Live = false
	end
	buffer.Head = 1
	buffer.Count = 0
end

-- Removes every live entry for an action (e.g. a released Block or a cancelled Heal).
function InputBuffer.discard(buffer: Buffer, action: BufferedAction): number
	local removed = 0
	for offset = 0, buffer.Count - 1 do
		local slot = buffer.Slots[slotIndex(buffer, offset)]
		if slot.Live and slot.Action == action then
			slot.Live = false
			removed += 1
		end
	end
	compact(buffer)
	return removed
end

function InputBuffer.push(buffer: Buffer, action: BufferedAction, now: number, variant: string?, dirX: number?, dirZ: number?): boolean
	assert(now == now, "InputBuffer.push requires a timestamp")
	local priority = InputBuffer.priority(action)
	local tag = variant or ""
	InputBuffer.flush(buffer, now)

	-- Repeated presses inside the duplicate window refresh the existing entry instead of stacking.
	for offset = buffer.Count - 1, 0, -1 do
		local slot = buffer.Slots[slotIndex(buffer, offset)]
		if slot.Live and slot.Action == action and slot.Variant == tag and now - slot.Time <= DUPLICATE_WINDOW then
			slot.Time = now
			slot.DirX = dirX or slot.DirX
			slot.DirZ = dirZ or slot.DirZ
			return false
		end
	end

	if buffer.Count == buffer.Capacity then
		-- Full: evict the oldest entry by advancing Head.
		buffer.Slots[buffer.Head].Live = false
		buffer.Head = buffer.Head % buffer.Capacity + 1
		buffer.Count -= 1
	end

	buffer.Sequence += 1
	local slot = buffer.Slots[slotIndex(buffer, buffer.Count)]
	slot.Live = true
	slot.Action = action
	slot.Priority = priority
	slot.Time = now
	slot.Sequence = buffer.Sequence
	slot.Variant = tag
	slot.DirX = dirX or 0
	slot.DirZ = dirZ or 0
	buffer.Count += 1
	return true
end

-- Highest priority wins; equal priority resolves to the earliest press so input order is respected.
local function choose(buffer: Buffer, now: number, filter: Filter?): Slot?
	InputBuffer.flush(buffer, now)
	local best: Slot? = nil
	for offset = 0, buffer.Count - 1 do
		local slot = buffer.Slots[slotIndex(buffer, offset)]
		if slot.Live and (filter == nil or filter(slot.Action, slot.Variant)) then
			local current = best
			if current == nil or slot.Priority > current.Priority or (slot.Priority == current.Priority and slot.Sequence < current.Sequence) then
				best = slot
			end
		end
	end
	return best
end

function InputBuffer.peek(buffer: Buffer, now: number, filter: Filter?): (BufferedAction?, number?, string?)
	local slot = choose(buffer, now, filter)
	if slot == nil then
		return nil, nil, nil
	end
	return slot.Action, slot.Time, slot.Variant
end

-- Returns (action, pressTime, variant, dirX, dirZ) without allocating; nil when nothing eligible.
function InputBuffer.pop(buffer: Buffer, now: number, filter: Filter?): (BufferedAction?, number?, string?, number?, number?)
	local slot = choose(buffer, now, filter)
	if slot == nil then
		return nil, nil, nil, nil, nil
	end
	slot.Live = false
	local action, time, variant, dirX, dirZ = slot.Action, slot.Time, slot.Variant, slot.DirX, slot.DirZ
	compact(buffer)
	return action, time, variant, dirX, dirZ
end

function InputBuffer.count(buffer: Buffer, now: number?): number
	if now ~= nil then
		InputBuffer.flush(buffer, now)
	end
	local live = 0
	for offset = 0, buffer.Count - 1 do
		if buffer.Slots[slotIndex(buffer, offset)].Live then
			live += 1
		end
	end
	return live
end

function InputBuffer.has(buffer: Buffer, action: BufferedAction, now: number): boolean
	InputBuffer.flush(buffer, now)
	for offset = 0, buffer.Count - 1 do
		local slot = buffer.Slots[slotIndex(buffer, offset)]
		if slot.Live and slot.Action == action then
			return true
		end
	end
	return false
end

return table.freeze(InputBuffer)
