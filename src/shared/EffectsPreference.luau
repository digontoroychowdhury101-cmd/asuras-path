--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/EffectsPreference
-- The one shared switch for comfort and decoration. Decoration thins out during active fights so
-- telegraphs, damage numbers and counter prompts stay dominant; "reduced effects" thins it further
-- everywhere (screen petals, drifting ash, particle density). Batch 25 adds reduced motion (camera
-- shake/kick and scripted camera moves), reduced flashes (screen blooms and impact flashes) and a
-- text scale. Warnings and hit feedback are never removed by these, only calmed. The values are
-- persisted in profile.settings.comfort (ProfileSchema) and applied by the bootstrap; `sanitize`
-- is the single validator for both sides.
local Effects = {}

export type Prefs = { ReducedEffects: boolean, ReducedMotion: boolean, ReducedFlashes: boolean, TextScale: number }

-- Share of the authored decorative density that stays visible.
Effects.Decor = table.freeze({ Explore = 1, Combat = 0.25, ReducedExplore = 0.3, ReducedCombat = 0 })
-- Decorative petals lose contrast in fights as well as count.
Effects.CombatContrast = 0.45
Effects.TextScales = table.freeze({ 1, 1.15, 1.3 })
Effects.FlashFloor = 0.35 -- reduced flashes keep this share of a bloom's strength (still visible)
Effects.MotionFloor = 0.25 -- reduced motion keeps this share of shake / kick (impacts still felt)
Effects.Default = table.freeze({ ReducedEffects = false, ReducedMotion = false, ReducedFlashes = false, TextScale = 1 })

local prefs: Prefs = table.clone(Effects.Default) :: Prefs
local listeners: { (boolean) -> () } = {}

-- Accepts anything (a saved table, a client packet) and returns valid preferences.
function Effects.sanitize(raw: any): Prefs
	local source = if type(raw) == "table" then raw else {}
	local scale = 1
	for _, allowed in Effects.TextScales do
		if source.TextScale == allowed then scale = allowed end
	end
	return {
		ReducedEffects = source.ReducedEffects == true,
		ReducedMotion = source.ReducedMotion == true,
		ReducedFlashes = source.ReducedFlashes == true,
		TextScale = scale,
	}
end

function Effects.get(): Prefs
	return table.clone(prefs)
end

-- Applies a (partial) preference table; listeners hear about any change.
function Effects.set(partial: any)
	local merged = table.clone(prefs) :: any
	if type(partial) == "table" then
		for key, value in partial do merged[key] = value end
	end
	local nextPrefs = Effects.sanitize(merged)
	local changed = false
	for key, value in nextPrefs :: any do
		if (prefs :: any)[key] ~= value then changed = true end
	end
	if not changed then return end
	prefs = nextPrefs
	for _, listener in table.clone(listeners) do
		task.spawn(listener, prefs.ReducedEffects)
	end
end

function Effects.reduced(): boolean
	return prefs.ReducedEffects
end

function Effects.setReduced(value: boolean)
	Effects.set({ ReducedEffects = value })
end

function Effects.reducedMotion(): boolean
	return prefs.ReducedMotion
end

function Effects.reducedFlashes(): boolean
	return prefs.ReducedFlashes
end

function Effects.textScale(): number
	return prefs.TextScale
end

-- Listener receives the reduced-effects flag; read the other getters inside it as needed.
function Effects.onChanged(listener: (boolean) -> ()): () -> ()
	table.insert(listeners, listener)
	return function()
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end
end

-- Decorative density multiplier (0..1) for the current situation.
function Effects.decor(engaged: boolean): number
	local d = Effects.Decor
	if prefs.ReducedEffects then
		return if engaged then d.ReducedCombat else d.ReducedExplore
	end
	return if engaged then d.Combat else d.Explore
end

-- Screen bloom / flash strength after the comfort setting.
function Effects.flash(strength: number): number
	return if prefs.ReducedFlashes then strength * Effects.FlashFloor else strength
end

-- Camera shake / kick magnitude after the comfort setting.
function Effects.motion(magnitude: number): number
	return if prefs.ReducedMotion then magnitude * Effects.MotionFloor else magnitude
end

return table.freeze(Effects)
