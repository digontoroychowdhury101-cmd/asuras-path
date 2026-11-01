"""Luau that rebuilds an exported opening-cast KeyframeSequence inside Studio (Edit datamodel), for publishing and checks.

    python tools/animation/opening_cast/studio_luau.py monk Monk_L1 [--publish | --register] > out.luau

Same contract as tools/animation/jian/studio_luau.py: without a flag the sequence is parented to
ServerStorage.AsuraCastReview (unsaved review copy); --register (Studio Play, Client) registers a temporary id and sets
AsuraAnimReview_<slot>, which FighterAnimations plays in Studio only; --publish uploads it with
AssetService:CreateAssetAsync and reads the new id back with KeyframeSequenceProvider, so a clip only counts as
published once it has been read back.
"""
import importlib.util
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
# the Jian tool shares this module's name, so load its pose serializer by path
_spec = importlib.util.spec_from_file_location("jian_studio_luau", ROOT / "tools/animation/jian/studio_luau.py")
_jian = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_jian)
pose_lua = _jian.pose_lua

BUILD = """local FRAMES = {%s}
local PRIORITIES = {[0]=Enum.AnimationPriority.Idle, [1]=Enum.AnimationPriority.Movement, [2]=Enum.AnimationPriority.Action,
	[3]=Enum.AnimationPriority.Action2, [4]=Enum.AnimationPriority.Action3, [5]=Enum.AnimationPriority.Action4, [1000]=Enum.AnimationPriority.Core}
local seq = Instance.new("KeyframeSequence")
seq.Name, seq.Loop, seq.Priority = "%s", %s, PRIORITIES[%d]
local function pose(spec, parent)
	local p = Instance.new("Pose")
	p.Name = spec[1]
	local c = spec[2]
	p.CFrame = CFrame.new(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
	p.EasingStyle, p.EasingDirection = Enum.PoseEasingStyle.Linear, Enum.PoseEasingDirection.In
	p.Weight = spec[4]
	for _, child in spec[3] do pose(child, p) end
	p.Parent = parent
end
for _, f in FRAMES do
	local k = Instance.new("Keyframe")
	k.Time = f[1]
	pose(f[2], k)
	k.Parent = seq
end
"""

REGISTER = """local id = game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(seq)
game:GetService("Players").LocalPlayer:SetAttribute("AsuraAnimReview_%s", id)
return { slot = "%s", id = id, keyframes = #seq:GetKeyframes() }
"""

PUBLISH = """local AssetService = game:GetService("AssetService")
local ok, result, id = pcall(function()
	return AssetService:CreateAssetAsync(seq, Enum.AssetType.Animation, { Name = seq.Name, Description = "Asura's Path %s clip" })
end)
if not ok then return { error = tostring(result) } end
if result ~= Enum.CreateAssetResult.Success then return { error = tostring(result) } end
local back = game:GetService("KeyframeSequenceProvider"):GetKeyframeSequenceAsync("rbxassetid://" .. id)
local last = 0
for _, k in back:GetKeyframes() do last = math.max(last, k.Time) end
return { name = seq.Name, id = id, keyframes = #back:GetKeyframes(), sent = #FRAMES, length = last, loop = back.Loop, priority = tostring(back.Priority) }
"""

REVIEW = """local folder = game:GetService("ServerStorage"):FindFirstChild("AsuraCastReview") or Instance.new("Folder")
folder.Name = "AsuraCastReview"
folder.Parent = game:GetService("ServerStorage")
local old = folder:FindFirstChild(seq.Name)
if old then old:Destroy() end
seq.Parent = folder
return { name = seq.Name, keyframes = #seq:GetKeyframes() }
"""


def script(key, name, mode):
    base = ROOT / "assets/animations/opening_cast" / key
    seq = ET.parse(base / (name + ".rbxmx")).getroot().find("Item")
    props = seq.find("Properties")
    loop = props.find("bool[@name='Loop']").text == "true"
    priority = int(props.find("token[@name='Priority']").text)
    frames = []
    for kf in seq.findall("Item[@class='Keyframe']"):
        t = float(kf.find("Properties/float[@name='Time']").text)
        frames.append("{%.5f,%s}" % (t, pose_lua(kf.find("Item[@class='Pose']"))))
    body = BUILD % (",".join(frames), name, "true" if loop else "false", priority)
    if mode == "register":
        slot = json.loads((base / "manifest.json").read_text())["clips"][name]["slot"]
        return body + REGISTER % (slot, slot)
    if mode == "publish":
        return body + PUBLISH % key
    return body + REVIEW


if __name__ == "__main__":
    flags = sys.argv[3:]
    mode = "register" if "--register" in flags else "publish" if "--publish" in flags else "review"
    sys.stdout.write(script(sys.argv[1], sys.argv[2], mode))
