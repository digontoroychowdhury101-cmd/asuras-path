--!strict
-- The one way anything other than a playback owner slows or freezes a fighter's clips (TIMING_CONTRACT §8). Hitstop
-- and cinematics submit a request {model, key, scale, until}; the owner of that model's tracks (FighterAnimations,
-- BossAnimations) multiplies its own phase rate by the lowest live request and is the only code that writes
-- AnimationTrack speed. Nothing here remembers a speed, so no stale speed can be restored.
-- `body` requests also slow the locomotion layer (a finishing shot's slow motion); hitstop leaves it running so the
-- feet keep up with a root the server is still moving.
local Scale = {}

type Request = { Scale: number, Until: number, Body: boolean }
local requests: { [Model]: { [string]: Request } } = setmetatable({}, { __mode = "k" }) :: any

function Scale.request(model: Model, key: string, scale: number, untilClock: number, body: boolean?)
	local list = requests[model]
	if not list then
		list = {}
		requests[model] = list
	end
	local existing = list[key]
	list[key] = {
		Scale = scale,
		Until = if existing and existing.Scale == scale then math.max(existing.Until, untilClock) else untilClock,
		Body = body == true,
	}
end

function Scale.clear(key: string)
	for _, list in requests do
		list[key] = nil
	end
end

-- (action layer scale, body layer scale) at `now`. 1, 1 with nothing live; expired requests are dropped here.
function Scale.of(model: Model, now: number): (number, number)
	local list = requests[model]
	if not list then
		return 1, 1
	end
	local action, body = 1, 1
	for key, request in list do
		if now >= request.Until then
			list[key] = nil
		else
			action = math.min(action, request.Scale)
			if request.Body then
				body = math.min(body, request.Scale)
			end
		end
	end
	if next(list) == nil then
		requests[model] = nil
	end
	return action, body
end

return Scale
