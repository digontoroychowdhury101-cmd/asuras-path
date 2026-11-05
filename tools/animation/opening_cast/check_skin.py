"""Check a bound opening-cast skin template in Studio (Edit) against the Blender piece bounds.

    python tools/animation/opening_cast/check_skin.py monk STUDIO_ID

Welds nothing: for each MeshPart of ServerStorage.AsuraAssets.<template> it places the part exactly as BossSkin.attach
would on a default R15 enemy rig at rest (limb * AsuraBind:Inverse()) and reports the distance between the part's
centre (in root space) and the Blender bounds centre. Also checks PBR completeness and that every R15 limb is covered:
by a rigid chunk bound to it, or (skinned templates) by a Sk_<limb> Bone inside a chunk, with each chunk's bone count reported.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools"))
from studio_mcp import Client  # noqa: E402
from bind_skin import TEMPLATES  # noqa: E402

LUAU = """local PIECES = game:GetService("HttpService"):JSONDecode([==[%s]==])
local t = game:GetService("ServerStorage").AsuraAssets:FindFirstChild("%s")
if not t then return "no template" end
local rig = game:GetService("Players"):CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
local root = rig.HumanoidRootPart
local worst, out, seen = 0, {}, {}
for _, p in t:GetDescendants() do
	if p:IsA("MeshPart") then
		local bone = p:GetAttribute("AsuraBone")
		local limb = rig:FindFirstChild(bone)
		local j = PIECES[p.Name].joint -- helper bone: BossRigs builds it at this root-space point
		local placed = (if j then CFrame.new(j[1], j[2], j[3]) else root.CFrame:ToObjectSpace(limb.CFrame)) * p.AsuraBind.CFrame:Inverse()
		local c = PIECES[p.Name].centre
		local err = (placed.Position - Vector3.new(c[1], c[2], c[3])).Magnitude
		local sa = p:FindFirstChildOfClass("SurfaceAppearance")
		local pbr = sa and sa.ColorMap ~= "" and sa.NormalMap ~= "" and sa.RoughnessMap ~= "" and sa.MetalnessMap ~= ""
		worst = math.max(worst, err)
		seen[bone] = true
		local bones = 0
		for _, b in p:GetDescendants() do
			if b:IsA("Bone") then
				bones += 1
				if b.Name:sub(1, 3) == "Sk_" then seen[b.Name:sub(4)] = true end
			end
		end
		table.insert(out, string.format("%%s %%s err %%.4f pbr %%s collide %%s bones %%d", p.Name, bone, err, tostring(pbr), tostring(p.CanCollide), bones))
	end
end
-- the importer's multi-mesh skeleton lives under the template's RootPart, shared by every chunk
for _, b in t:GetDescendants() do
	if b:IsA("Bone") and b.Name:sub(1, 3) == "Sk_" then seen[b.Name:sub(4)] = true end
end
local missing = {}
for _, b in {"Head","UpperTorso","LowerTorso","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand",
	"LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot"} do
	if not seen[b] then table.insert(missing, b) end
end
rig:Destroy()
return string.format("worst %%.4f studs, missing [%%s]\\n%%s", worst, table.concat(missing, ","), table.concat(out, "\\n"))
"""


def main():
    key, studio = sys.argv[1], sys.argv[2]
    pieces = (ROOT / "work/opening_cast_bake" / key / "pieces.json").read_text()
    c = Client()
    ok, text = c.call("execute_luau", {"code": LUAU % (pieces, TEMPLATES[key][1]), "datamodel_type": "Edit", "studio_id": studio})
    c.close()
    print("OK" if ok else "ERR", text)


if __name__ == "__main__":
    main()
