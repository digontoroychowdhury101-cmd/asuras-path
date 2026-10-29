-- Studio Client: attach before foregrounding the Play viewport. The sampler may use the most
-- recent actual focus event; no initial focus state is guessed. Set _G.AsuraFocusProbeStop=true before running to clean up.
local old = _G.AsuraFocusProbe
if old then old.a:Disconnect(); old.b:Disconnect() end
_G.AsuraFocusProbe = nil
if _G.AsuraFocusProbeStop then _G.AsuraFocusProbeStop = nil return "focus observer stopped" end
local state = { events = {} }
_G.AsuraFocusProbe = state
local input = game:GetService("UserInputService")
state.a = input.WindowFocused:Connect(function()
	table.insert(state.events, { focused = true, time = os.clock() })
end)
state.b = input.WindowFocusReleased:Connect(function()
	table.insert(state.events, { focused = false, time = os.clock() })
end)
return "focus observer attached; foreground the viewport, then inspect the observed events"
