-- Studio QA (Client, via tools/qa/lobby_capture.py calls STUDIO tools/qa/lobby_walk.json): where the local
-- character stands and the region/altar attributes, after each scripted walk step.

local p = game:GetService("Players").LocalPlayer
local c = p.Character
local root = c and (c:FindFirstChild("HumanoidRootPart") :: BasePart?)
local h = c and c:FindFirstChildOfClass("Humanoid")
local attrs = {}
for k, v in p:GetAttributes() do if string.find(k, "Region") or string.find(k, "Result") or string.find(k, "Altar") or string.find(k, "Rest") then table.insert(attrs, k .. "=" .. tostring(v)) end end
return string.format("pos=%s state=%s | %s", root and tostring(root.Position) or "nil", h and h:GetState().Name or "-", table.concat(attrs, " "))
