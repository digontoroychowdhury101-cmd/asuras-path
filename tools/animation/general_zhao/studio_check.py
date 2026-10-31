"""End-to-end check of an exported clip in Roblox Studio (Edit datamodel, no upload, no Play session).

    python3 tools/animation/general_zhao/studio_check.py GeneralZhao_P1_Guandao_L1 [--keys N] [--bake-dir DIR] > check.luau

Writes a Luau script that rebuilds the clip's .rbxmx KeyframeSequence, registers it with
KeyframeSequenceProvider:RegisterKeyframeSequence (a temporary local id), plays it on a fresh default R15 rig built
the way CharacterService.buildEnemyModel builds bosses, steps the Animator to sample times, and returns each limb's
root-space position error and rotation error against the Python bake (work/zhao_anim_bake/<clip>.json). With
--keys N only N evenly spread keyframes are kept and sampled exactly on them (a small script that still proves the
export format and joint convention). The rig is
destroyed afterwards; nothing is saved into the place.
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
    nums = ",".join("%.4f" % float(cf.find(t).text) for t in TAGS)
    kids = ",".join(pose_lua(k) for k in item.findall("Item[@class='Pose']"))
    return '{"%s",{%s},{%s}}' % (name, nums, kids)


def main():
    name = sys.argv[1]
    keep = int(sys.argv[sys.argv.index("--keys") + 1]) if "--keys" in sys.argv else None
    seq = ET.parse(ROOT / "assets/animations/general_zhao" / (name + ".rbxmx")).getroot().find("Item")
    frames = []
    for kf in seq.findall("Item[@class='Keyframe']"):
        t = float(kf.find("Properties/float[@name='Time']").text)
        frames.append("{%.5f,%s}" % (t, pose_lua(kf.find("Item[@class='Pose']"))))
    if keep:
        step = max(1, (len(frames) - 1) / max(keep - 1, 1))
        frames = [frames[min(len(frames) - 1, round(i * step))] for i in range(keep)]
    bake_dir = Path(sys.argv[sys.argv.index("--bake-dir") + 1]) if "--bake-dir" in sys.argv else ROOT / "work/zhao_anim_bake"
    bake = json.loads((bake_dir / (name + ".json")).read_text())
    picks = [round(bake["length"] * i / 8, 4) for i in range(9)] + list(bake.get("contacts", []))
    if keep:
        picks = [float(f[1:f.index(",")]) for f in frames]
    expect = []
    for t in sorted(set(picks)):
        f = min(bake["frames"], key=lambda fr: abs(fr["t"] - t))
        parts = ",".join('%s={%s}' % (p, ",".join("%.4f" % v for v in m)) for p, m in f["parts"].items()
                         if p != "HumanoidRootPart")
        expect.append("{%.5f,{%s}}" % (f["t"], parts))
    print(LUAU % {"name": name, "frames": ",\n".join(frames), "expect": ",\n".join(expect)})


LUAU = r'''
local FRAMES = {%(frames)s}
local EXPECT = {%(expect)s}
local seq = Instance.new("KeyframeSequence")
seq.Name = "%(name)s"
local function pose(spec, parent)
	local p = Instance.new("Pose")
	p.Name = spec[1]
	p.CFrame = CFrame.new(table.unpack(spec[2]))
	p.Parent = parent
	for _, kid in spec[3] do pose(kid, p) end
end
for _, f in FRAMES do
	local k = Instance.new("Keyframe")
	k.Time = f[1]
	pose(f[2], k)
	k.Parent = seq
end
local id = game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(seq)
local rig = game:GetService("Players"):CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
rig.Parent = workspace
local root = rig:FindFirstChild("HumanoidRootPart")
root.Anchored = true
rig:PivotTo(CFrame.new(0, 50, 0))
local animator = rig:FindFirstChildOfClass("Humanoid"):FindFirstChildOfClass("Animator")
local animation = Instance.new("Animation")
animation.AnimationId = id
local track = animator:LoadAnimation(animation)
track:Play(0, 1, 1) -- a registered sequence loads asynchronously: Length stays 0 until it has
local waited = 0
while track.Length == 0 and waited < 5 do task.wait(0.1); waited += 0.1 end
track:AdjustSpeed(0)
local worstPos, worstAng, where = 0, 0, ""
local samples = 0
for _, e in EXPECT do
	track.TimePosition = math.min(e[1], track.Length - 1e-3) -- exactly Length wraps to the first frame
	animator:StepAnimations(0.03)
	for part, m in e[2] do
		local limb = rig:FindFirstChild(part)
		if limb then
			local got = root.CFrame:ToObjectSpace(limb.CFrame)
			local want = CFrame.new(m[4], m[8], m[12], m[1], m[2], m[3], m[5], m[6], m[7], m[9], m[10], m[11])
			local dp = (got.Position - want.Position).Magnitude
			local _, ang = (want:Inverse() * got):ToAxisAngle()
			ang = math.deg(math.abs(ang))
			if dp > worstPos then worstPos, where = dp, string.format("%%s@%%.3f", part, e[1]) end
			worstAng = math.max(worstAng, ang)
			samples += 1
		end
	end
end
local joints = 0
for _, d in rig:GetDescendants() do if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then joints += 1 end end
local length = track.Length
track:Stop(0)
rig:Destroy()
return { clip = "%(name)s", samples = samples, joints = joints, worst_position = worstPos, worst_degrees = worstAng, at = where, length = length }
'''

if __name__ == "__main__":
    main()
