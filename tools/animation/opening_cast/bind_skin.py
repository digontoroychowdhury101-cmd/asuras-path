"""Bind a freshly imported opening-cast skin in Studio (Edit) and move it into ServerStorage.AsuraAssets.

    python tools/animation/opening_cast/bind_skin.py monk STUDIO_ID

After the 3D Importer (Set Pivot to Scene Origin, 1 stud per unit) the model sits in Workspace as
Scene<Template> with one MeshPart per R15 limb, centred on its bounds and turned 180 degrees about Y (the importer
faces it toward the camera). This step, run over the local StudioMCP proxy:
  - undoes that turn and checks every part's centre against the Blender piece bounds (pieces.json) to 0.01 studs;
  - measures the R15 rest pose of a default enemy rig (CharacterService builds enemies from a blank
    HumanoidDescription) and writes each part's AsuraBone attribute and AsuraBind Attachment, so BossSkin welds the
    part where it sat in the authored root space: part = limb * bind:Inverse();
  - tags weapon pieces AsuraRole=Weapon (pieces.json role) so the skin replaces the procedural weapon;
  - makes every part massless, non-colliding, non-querying, Box collision, and parents the template to
    ServerStorage.AsuraAssets for extract_skin.py.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools"))
from studio_mcp import Client  # noqa: E402

TEMPLATES = {"monk": ("Monk", "AsuraBoss_CorruptWanderingMonk"), "swordsman": ("Swordsman", "AsuraBoss_CursedSwordsman")}

LUAU = """local PIECES = game:GetService("HttpService"):JSONDecode([==[%s]==])
local PREFIX, NAME = "%s_", "%s"
local model = workspace:FindFirstChild("Scene" .. NAME) or workspace:FindFirstChild(NAME)
if not model then return "no imported model " .. NAME end
local origin = model:GetPivot()
local turn = CFrame.Angles(0, math.pi, 0)
local rig = game:GetService("Players"):CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
local root = rig:FindFirstChild("HumanoidRootPart")
local worst, report = 0, {}
local parts = {}
for _, p in model:GetDescendants() do
	if p:IsA("MeshPart") then table.insert(parts, p) end
end
for _, p in parts do
	local info = PIECES[p.Name]
	if not info then rig:Destroy(); return "unknown part " .. p.Name end
	local rest = turn * origin:ToObjectSpace(p.CFrame) -- the part in authored root space
	local c = info.centre
	local err = (rest.Position - Vector3.new(c[1], c[2], c[3])).Magnitude
	worst = math.max(worst, err)
	local limb = rig:FindFirstChild(info.bone)
	if not limb then rig:Destroy(); return "rig lacks " .. info.bone end
	local rl = root.CFrame:ToObjectSpace(limb.CFrame)
	local bind = p:FindFirstChild("AsuraBind") or Instance.new("Attachment")
	bind.Name = "AsuraBind"
	bind.CFrame = rest:Inverse() * rl
	bind.Parent = p
	p:SetAttribute("AsuraBone", info.bone)
	p:SetAttribute("AsuraRole", info.role) -- "Weapon" makes BossSkin hide the costume weapon (OwnsWeapon)
	p.Anchored, p.Massless, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, true, false, false, false, true
	pcall(function() (p :: any).CollisionFidelity = Enum.CollisionFidelity.Box end)
	table.insert(report, string.format("%%s->%%s err %%.4f", p.Name, info.bone, err))
end
rig:Destroy()
if worst > 0.01 then return "MISMATCH worst " .. worst .. "\\n" .. table.concat(report, "\\n") end
-- flatten the importer's per-node Models and park the template at the origin, facing -Z like the rig
for _, p in parts do p.Parent = model end
for _, d in model:GetChildren() do if d:IsA("Model") and #d:GetChildren() == 0 then d:Destroy() end end
model:PivotTo(CFrame.new(0, 0, 0) * turn:Inverse() * CFrame.new())
model.WorldPivot = CFrame.new()
model.Name = NAME
model:SetAttribute("AsuraCastVersion", 1)
local assets = game:GetService("ServerStorage"):FindFirstChild("AsuraAssets")
local old = assets:FindFirstChild(NAME)
if old and old ~= model then old:Destroy() end
model.Parent = assets
return string.format("BOUND %%d parts, worst centre error %%.4f studs\\n%%s", #parts, worst, table.concat(report, "\\n"))
"""


def main():
    key, studio = sys.argv[1], sys.argv[2]
    prefix, name = TEMPLATES[key]
    pieces = (ROOT / "work/opening_cast_bake" / key / "pieces.json").read_text()
    c = Client()
    ok, text = c.call("execute_luau", {"code": LUAU % (pieces, prefix, name), "datamodel_type": "Edit", "studio_id": studio})
    c.close()
    print("OK" if ok else "ERR", text)


if __name__ == "__main__":
    main()
