local run = game:GetService("RunService")
local samples = {}
local elapsed = 0
while elapsed < 5 do
    local dt = run.RenderStepped:Wait()
    elapsed += dt
    table.insert(samples, dt * 1000)
end
table.sort(samples)
return {
    frames = #samples,
    averageFps = #samples / elapsed,
    p50Ms = samples[math.ceil(#samples * .50)],
    p95Ms = samples[math.ceil(#samples * .95)],
    worstMs = samples[#samples],
    camera = tostring(workspace.CurrentCamera.CFrame),
}
