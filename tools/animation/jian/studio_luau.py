"""Luau that rebuilds an exported Jian KeyframeSequence inside Studio (Edit datamodel), for publishing and checks.

    python tools/animation/jian/studio_luau.py CLIP [--publish] > out.luau

Without --publish the script parents the sequence to ServerStorage.AsuraJianReview (unsaved review copies) and returns
its keyframe count. With --register (Studio Play, Client datamodel) it registers a temporary id and sets the LocalPlayer attribute
AsuraAnimReview_<slot>, which FighterAnimations plays in Studio only. With --publish it uploads it through AssetService:CreateAssetAsync (an Animation asset owned by the
signed-in Studio user), loads the new id back with KeyframeSequenceProvider and returns the id with the round-trip
keyframe count and length, so a clip only counts as published once it has been read back.
"""
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TAGS = ["X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"]


def pose_lua(item):
    props = item.find("Properties")
    name = props.find("string[@name='Name']").text
    cf = props.find("CoordinateFrame[@name='CFrame']")
    nums = ",".join("%.5f" % float(cf.find(t).text) for t in TAGS)
    kids = ",".join(pose_lua(k) for k in item.findall("Item[@class='Pose']"))
    weight = props.find("float[@name='Weight']").text
    return '{"%s",{%s},{%s},%s}' % (name, nums, kids, weight)


def script(name, publish, folder="assets/animations/jian", description="Asura's Path jian combat clip"):
    seq = ET.parse(ROOT / folder / (name + ".rbxmx")).getroot().find("Item")
    props = seq.find("Properties")
    loop = props.find("bool[@name='Loop']").text == "true"
    priority = int(props.find("token[@name='Priority']").text)
    frames = []
    for kf in seq.findall("Item[@class='Keyframe']"):
        t = float(kf.find("Properties/float[@name='Time']").text)
        frames.append("{%.5f,%s}" % (t, pose_lua(kf.find("Item[@class='Pose']"))))
    body = """local FRAMES = {%s}
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
""" % (",".join(frames), name, "true" if loop else "false", priority)
    if publish == "register":
        slot = json.loads((ROOT / "assets/animations/jian/manifest.json").read_text())["clips"][name]["slot"]
        body += """local id = game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(seq)
game:GetService("Players").LocalPlayer:SetAttribute("AsuraAnimReview_%s", id)
return { slot = "%s", id = id, keyframes = #seq:GetKeyframes() }
""" % (slot, slot)
    elif publish:
        body += """local AssetService = game:GetService("AssetService")
local ok, result, id = pcall(function()
	return AssetService:CreateAssetAsync(seq, Enum.AssetType.Animation, { Name = seq.Name, Description = "%s" })
end)
if not ok then return { error = tostring(result) } end
if result ~= Enum.CreateAssetResult.Success then return { error = tostring(result) } end
local back = game:GetService("KeyframeSequenceProvider"):GetKeyframeSequenceAsync("rbxassetid://" .. id)
local last = 0
for _, k in back:GetKeyframes() do last = math.max(last, k.Time) end
return { id = id, keyframes = #back:GetKeyframes(), sent = #FRAMES, length = last, loop = back.Loop, priority = tostring(back.Priority) }
""" % description
    else:
        body += """local folder = game:GetService("ServerStorage"):FindFirstChild("AsuraJianReview") or Instance.new("Folder")
folder.Name = "AsuraJianReview"
folder.Parent = game:GetService("ServerStorage")
local old = folder:FindFirstChild(seq.Name)
if old then old:Destroy() end
seq.Parent = folder
return { name = seq.Name, keyframes = #seq:GetKeyframes() }
"""
    return body


if __name__ == "__main__":
    sys.stdout.write(script(sys.argv[1], "register" if "--register" in sys.argv else "--publish" in sys.argv))
