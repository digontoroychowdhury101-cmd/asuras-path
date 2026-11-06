"""Write a Luau snippet that rebuilds exported Shen clips inside a Studio playtest and registers them locally
(AnimationClipProvider:RegisterAnimationClip), so a re-baked clip can be compared with the published one without uploading.

    python3 tools/qa/shen_preview_luau.py OUT.luau GrandmasterShen_P1_Idle [more clip names]

Paste or send OUT.luau to the Client datamodel (MCP execute_luau). It fills _G.ShenPreview[clipName] = temporary animation id.
Nothing is published; the ids only exist in that Studio session.
"""
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DIR = ROOT / "assets/animations/opening_cast/shen"
KEYS = ("X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22")


def pose_rows(item, parent, rows):
    props = item.find("Properties")
    name = props.find("string[@name='Name']").text
    cf = props.find("CoordinateFrame[@name='CFrame']")
    nums = [float(cf.find(k).text) for k in KEYS]
    style = int(props.find("token[@name='EasingStyle']").text)
    direction = int(props.find("token[@name='EasingDirection']").text)
    me = len(rows) + 1
    rows.append("{%d,%q,%s,%d,%d}".replace("%q", '"%s"') % (parent, name, ",".join("%.5g" % v for v in nums), style, direction))
    for child in item.findall("Item[@class='Pose']"):
        pose_rows(child, me, rows)


def clip_luau(name):
    root = ET.parse(DIR / (name + ".rbxmx")).getroot()
    seq = root.find("Item[@class='KeyframeSequence']")
    props = seq.find("Properties")
    loop = props.find("bool[@name='Loop']").text == "true"
    priority = int(props.find("token[@name='Priority']").text)
    frames = []
    for kf in seq.findall("Item[@class='Keyframe']"):
        t = float(kf.find("Properties/float[@name='Time']").text)
        rows = []
        for p in kf.findall("Item[@class='Pose']"):
            pose_rows(p, 0, rows)
        frames.append("{%.4f,{%s}}" % (t, ",".join(rows)))
    return '_G.ShenPreviewBuild("%s",%s,%d,{%s})\n' % (name, "true" if loop else "false", priority, ",".join(frames))


HEAD = '''_G.ShenPreview = _G.ShenPreview or {}
_G.ShenPreviewBuild = function(name, loop, priority, frames)
	local kfs = Instance.new("KeyframeSequence")
	kfs.Name, kfs.Loop, kfs.Priority = name, loop, Enum.AnimationPriority:FromValue(priority) or Enum.AnimationPriority.Action
	for _, f in frames do
		local k = Instance.new("Keyframe")
		k.Time = f[1]
		local made = {}
		for i, r in f[2] do
			local p = Instance.new("Pose")
			p.Name = r[2]
			p.CFrame = CFrame.new(r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10], r[11], r[12], r[13], r[14])
			p.EasingStyle = Enum.PoseEasingStyle:FromValue(r[15]) or Enum.PoseEasingStyle.Linear
			p.EasingDirection = Enum.PoseEasingDirection:FromValue(r[16]) or Enum.PoseEasingDirection.In
			p.Parent = if r[1] == 0 then k else made[r[1]]
			made[i] = p
		end
		k.Parent = kfs
	end
	_G.ShenPreview[name] = game:GetService("AnimationClipProvider"):RegisterAnimationClip(kfs)
end
'''

def clip_json(name):
    """The same clip as JSON: [name, loop, priority, [[time, [[parent, name, x..r22, style, dir], ...]], ...]]"""
    import json
    root = ET.parse(DIR / (name + ".rbxmx")).getroot()
    seq = root.find("Item[@class='KeyframeSequence']")
    props = seq.find("Properties")
    frames = []
    for kf in seq.findall("Item[@class='Keyframe']"):
        rows = []

        def walk(item, parent):
            pp = item.find("Properties")
            cf = pp.find("CoordinateFrame[@name='CFrame']")
            rows.append([parent, pp.find("string[@name='Name']").text] + [round(float(cf.find(k).text), 5) for k in KEYS]
                        + [int(pp.find("token[@name='EasingStyle']").text), int(pp.find("token[@name='EasingDirection']").text)])
            me = len(rows)
            for child in item.findall("Item[@class='Pose']"):
                walk(child, me)
        for p in kf.findall("Item[@class='Pose']"):
            walk(p, 0)
        frames.append([float(kf.find("Properties/float[@name='Time']").text), rows])
    return json.dumps([name, props.find("bool[@name='Loop']").text == "true", int(props.find("token[@name='Priority']").text), frames], separators=(",", ":"))


if __name__ == "__main__":
    if sys.argv[1] == "--json":     # --json OUTDIR [suffix] clips...: one NAME[suffix].json per clip, for a local HTTP server the Studio server fetches
        outdir, suffix = Path(sys.argv[2]), sys.argv[3]
        for n in sys.argv[4:]:
            (outdir / (n + suffix + ".json")).write_text(clip_json(n))
        sys.exit(0)
    out = Path(sys.argv[1])
    out.write_text(HEAD + "".join(clip_luau(n) for n in sys.argv[2:]) + 'local n = 0 for _ in _G.ShenPreview do n += 1 end return "registered " .. n\n')
    print(out, out.stat().st_size, "bytes")
