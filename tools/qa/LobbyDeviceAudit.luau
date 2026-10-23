-- Client during Studio Device Simulator. Reports live, visible button rectangles.
local player=game.Players.LocalPlayer
local gui=player.PlayerGui
local out={viewport=tostring(workspace.CurrentCamera.ViewportSize),device=player:GetAttribute("AsuraInputDevice"),tier=player:GetAttribute("LandscapeTier"),buttons={},failures={}}
local function visible(o)
 local n=o
 while n and n~=gui do
  if n:IsA("GuiObject") and not n.Visible then return false end
  if n:IsA("ScreenGui") and not n.Enabled then return false end
  n=n.Parent
 end
 return true
end
for _,root in {gui:FindFirstChild("AsuraTouchControls"),gui.AsuraHUD:FindFirstChild("QiSpellSlots"),gui.AsuraHUD:FindFirstChild("Minimap")} do
 if not root then continue end
 for _,b in root:GetDescendants() do
  if b:IsA("GuiButton") and visible(b) then
   local p,s=b.AbsolutePosition,b.AbsoluteSize
   local canvas=b:FindFirstAncestorOfClass("ScreenGui");local cp,cs=canvas.AbsolutePosition,canvas.AbsoluteSize
   local row={name=b:GetFullName(),x=p.X,y=p.Y,w=s.X,h=s.Y}
   table.insert(out.buttons,row)
   if p.X<cp.X-.5 or p.Y<cp.Y-.5 or p.X+s.X>cp.X+cs.X+.5 or p.Y+s.Y>cp.Y+cs.Y+.5 then table.insert(out.failures,"Clipped: "..b:GetFullName()) end
   if out.device=="Touch" and (s.X<43.5 or s.Y<43.5) then table.insert(out.failures,"Small touch target: "..b:GetFullName().." "..tostring(s))end
  end
 end
end
for i,a in out.buttons do for j=i+1,#out.buttons do local b=out.buttons[j];local w=math.min(a.x+a.w,b.x+b.w)-math.max(a.x,b.x);local h=math.min(a.y+a.h,b.y+b.h)-math.max(a.y,b.y);if w>1 and h>1 then table.insert(out.failures,"Overlap: "..a.name.." / "..b.name)end end end
out.passed=#out.failures==0
return game:GetService("HttpService"):JSONEncode(out)
