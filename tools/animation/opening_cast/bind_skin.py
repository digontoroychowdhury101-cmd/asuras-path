"""Bind a freshly imported opening-cast skin in Studio (Edit) and move it into ServerStorage.AsuraAssets.

    python tools/animation/opening_cast/bind_skin.py monk STUDIO_ID

After the 3D Importer (Set Pivot to Scene Origin, 1 stud per unit) the model sits in Workspace as
Scene<Template> with one MeshPart per R15 limb, centred on its bounds and turned 180 degrees about Y (the importer
faces it toward the camera). This step, run over the local StudioMCP proxy:
  - undoes that turn and checks every part's centre against the Blender piece bounds (pieces.json) to 0.01 studs;
  - measures the R15 rest pose of a default enemy rig (CharacterService builds enemies from a blank
    HumanoidDescription) and writes each part's AsuraBone attribute and AsuraBind Attachment, so BossSkin welds the
    part where it sat in the authored root space: part = limb * bind:Inverse();
  - a piece whose pieces.json entry has a "joint" binds to a helper bone that BossRigs builds at that root-space point;
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

TEMPLATES = {"monk": ("Monk", "AsuraBoss_CorruptWanderingMonk"), "swordsman": ("Swordsman", "AsuraBoss_CursedSwordsman"),
             "warden": ("Warden", "AsuraBoss_HollowBellWarden"), "bull": ("Bull", "AsuraBoss_IronBull"),
             "zhao": ("Zhao", "AsuraBoss_GeneralZhao"),
             "shen1": ("Shen1", "AsuraBoss_GrandmasterShen_P1"), "shen2": ("Shen2", "AsuraBoss_GrandmasterShen_P2"),
             "cinnabar": ("Armor", "AsuraArmor_CinnabarGuard"), "ashen": ("Armor", "AsuraArmor_AshenPilgrim"), "ironoath": ("Armor", "AsuraArmor_IronOath")}

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
-- a skinned form has its welded props (the guandao, floating beads) in a second import
local propsModel = workspace:FindFirstChild("Scene" .. NAME .. "_Props") or workspace:FindFirstChild(NAME .. "_Props")
if propsModel then
	propsModel:PivotTo(origin) -- each import lands at its own spot; both pivots are the scene origin
	for _, p in propsModel:GetDescendants() do
		if p:IsA("MeshPart") then table.insert(parts, p) end
	end
end
for _, p in parts do
	local info = PIECES[p.Name]
	if not info then rig:Destroy(); return "unknown part " .. p.Name end
	local rest = turn * origin:ToObjectSpace(p.CFrame) -- the part in authored root space
	local c = info.centre
	local err = (rest.Position - Vector3.new(c[1], c[2], c[3])).Magnitude
	worst = math.max(worst, err)
	-- a helper bone (BossRigs: pauldron, cloth) is not an R15 limb; BossSkin builds it at this root-space joint
	local limb = rig:FindFirstChild(info.bone)
	if not limb and not info.joint then rig:Destroy(); return "rig lacks " .. info.bone end
	local rl = if info.joint then CFrame.new(info.joint[1], info.joint[2], info.joint[3]) else root.CFrame:ToObjectSpace(limb.CFrame)
	local bind = p:FindFirstChild("AsuraBind") or Instance.new("Attachment")
	bind.Name = "AsuraBind"
	bind.CFrame = rest:Inverse() * rl
	bind.Parent = p
	p:SetAttribute("AsuraBone", info.bone)
	p:SetAttribute("AsuraSkinned", if info.skinned then "true" else nil)
	p:SetAttribute("AsuraRole", info.role) -- "Weapon" makes BossSkin hide the costume weapon (OwnsWeapon)
	p.Anchored, p.Massless, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, true, false, false, false, true
	if info.role == "Glow" then -- fissures: an isolated copy of the sculpt's hot texels, lit by Neon, no PBR; only these pieces glow
		local surface = p:FindFirstChildOfClass("SurfaceAppearance")
		if surface then surface:Destroy() end
		p.Material, p.Color, p.CastShadow, p.TextureID = Enum.Material.Neon, Color3.fromRGB(235, 28, 28), false, ""
	end
	pcall(function() (p :: any).CollisionFidelity = Enum.CollisionFidelity.Box end)
	table.insert(report, string.format("%%s->%%s err %%.4f", p.Name, info.bone, err))
end
rig:Destroy()
-- named effect attachments: a blade's edge, the bead hand, the burst origin (pieces.json __fx, shen_fx_points.py)
local byName = {}
for _, p in parts do byName[p.Name] = p end
local firstSkinned = nil
for _, p in parts do if p:GetAttribute("AsuraSkinned") then firstSkinned = p; break end end
for name, fx in PIECES.__fx or {} do
	local p = if fx.limb then firstSkinned else byName[fx.piece]
	if not p then return "no piece for " .. name end
	local a = p:FindFirstChild(name) or Instance.new("Attachment")
	a.Name = name
	a:SetAttribute("AsuraFxLimb", fx.limb) -- BossSkin parents it to the limb: a skinned piece does not ride any one limb
	a.CFrame = (turn * origin:ToObjectSpace(p.CFrame)):Inverse() * CFrame.new(fx.at[1], fx.at[2], fx.at[3])
	a.Parent = p
end
if worst > 0.01 then return "MISMATCH worst " .. worst .. "\\n" .. table.concat(report, "\\n") end
-- a skinned import also brings the skeleton's RootPart, which must stay unseen, and Studio's editor-only pose data
local boneRoot = model:FindFirstChild("RootPart")
if boneRoot and boneRoot:IsA("BasePart") then
	boneRoot.Transparency, boneRoot.Anchored, boneRoot.Massless, boneRoot.CanCollide, boneRoot.CanQuery, boneRoot.CanTouch, boneRoot.CastShadow = 1, true, true, false, false, false, false
end
local poses = model:FindFirstChild("InitialPoses")
if poses then poses:Destroy() end
-- flatten the importer's per-node Models and park the template at the origin, facing -Z like the rig
for _, p in parts do p.Parent = model end
for _, d in model:GetChildren() do if d:IsA("Model") and #d:GetChildren() == 0 then d:Destroy() end end
if propsModel then propsModel:Destroy() end
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
