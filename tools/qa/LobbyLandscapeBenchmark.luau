-- Client during Play. Fixed-camera, fixed-quality diagnostic. Focus is observed, never assumed.
local Run=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local Stats=game:GetService("Stats")
local SAS=game:GetService("SceneAnalysisService")
local camera=workspace.CurrentCamera
local original={CFrame=camera.CFrame,Focus=camera.Focus,Fov=camera.FieldOfView,Type=camera.CameraType,Quality=settings().Rendering.QualityLevel}
local focused=false
local links={UIS.WindowFocused:Connect(function()focused=true end),UIS.WindowFocusReleased:Connect(function()focused=false end)}
local target,focus,fov=camera.CFrame,camera.Focus,camera.FieldOfView
Run:BindToRenderStep("LobbyFinishBenchmark",Enum.RenderPriority.Last.Value+20,function()camera.CameraType=Enum.CameraType.Scriptable;camera.CFrame=target;camera.Focus=focus;camera.FieldOfView=fov end)
local function distribution(values)
 table.sort(values);local total=0;for _,v in values do total+=v end
 return {n=#values,mean=total/#values,p50=values[math.ceil(#values*.5)],p95=values[math.ceil(#values*.95)],max=values[#values]}
end
local out={kind="Studio fixed-camera diagnostic; foreground only when observed through WindowFocused",views={}}
local ok,err=xpcall(function()
 for _,view in {{name="entrance",at=Vector3.new(0,606,935),to=Vector3.new(0,650,817),fov=67.5},{name="elevated",at=Vector3.new(175,735,1100),to=Vector3.new(0,650,815),fov=60},{name="crevice",at=Vector3.new(-61,604,950),to=Vector3.new(-49,598,932),fov=65}} do
  target,focus,fov=CFrame.lookAt(view.at,view.to),CFrame.new(view.to),view.fov
  task.wait(2)
  local dt,cpu,foreground={},{},{}
  for i=1,120 do local t=Run.RenderStepped:Wait()*1000;table.insert(dt,t);table.insert(cpu,Stats.RenderCPUFrameTime*1000);if focused then table.insert(foreground,t)end end
  local p=game.Players.LocalPlayer
  table.insert(out.views,{name=view.name,quality=tostring(settings().Rendering.QualityLevel),viewport=tostring(camera.ViewportSize),frames=distribution(dt),renderCPU=distribution(cpu),foregroundFrames=#foreground,triangles=SAS:GetTriangleCompositionAsync(),tier=p:GetAttribute("LandscapeTier"),hidden=p:GetAttribute("LandscapeHiddenMeshes"),lights=p:GetAttribute("LandscapeActiveLights"),particles=p:GetAttribute("LandscapeParticleCeiling"),memoryMb=Stats:GetTotalMemoryUsageMb()})
 end
end,debug.traceback)
Run:UnbindFromRenderStep("LobbyFinishBenchmark")
for _,link in links do link:Disconnect()end
camera.CFrame,camera.Focus,camera.FieldOfView,camera.CameraType=original.CFrame,original.Focus,original.Fov,original.Type
settings().Rendering.QualityLevel=original.Quality
out.error=if ok then nil else err
_G.LobbyFinishBenchmark=out
return game:GetService("HttpService"):JSONEncode(out)
