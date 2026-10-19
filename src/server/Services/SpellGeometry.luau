--!strict
local Workspace=game:GetService("Workspace")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
local World=require(Shared.Shared.WorldDefinitions)
local Characters=require(script.Parent.CharacterService)
local Geometry={}
function Geometry.params(): RaycastParams
 local excluded: {Instance}={}
 for _,e in Characters.Entities() do table.insert(excluded,e.Model) end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances=excluded
 params.RespectCanCollide=true
 return params
end
function Geometry.endpoint(origin: Vector3,direction: Vector3,range: number): Vector3
 local hit=Workspace:Raycast(origin,direction*range,Geometry.params())
 return origin+direction*(if hit then math.max(0,(hit.Position-origin).Magnitude-2) else range)
end
function Geometry.clear(a: Vector3,b: Vector3): boolean
 return (a-b).Magnitude<0.01 or Workspace:Raycast(a,b-a,Geometry.params())==nil
end
function Geometry.targets(source: any,origin: Vector3,range: number): {any}
 local targets={}
 for _,e in Characters.Entities() do
  if e.Fighter.State~="KO" and e.Root.Parent and Characters.IsHostile(source.Id,e.Id) and (e.Root.Position-origin).Magnitude<=range and Geometry.clear(origin,e.Root.Position) then
   table.insert(targets,e)
  end
 end
 table.sort(targets,function(a: any,b: any): boolean return (a.Root.Position-origin).Magnitude<(b.Root.Position-origin).Magnitude end)
 return targets
end
function Geometry.segment(point: Vector3,a: Vector3,b: Vector3): number
 local delta=b-a
 local t=if delta:Dot(delta)>0 then math.clamp((point-a):Dot(delta)/delta:Dot(delta),0,1) else 0
 return (point-(a+delta*t)).Magnitude
end
function Geometry.teleport(e: any,destination: Vector3): boolean
 local origin=e.Root.Position
 local clipped=Geometry.endpoint(origin,if (destination-origin).Magnitude>0.01 then (destination-origin).Unit else e.Root.CFrame.LookVector,(destination-origin).Magnitude)
 local params=Geometry.params()
 local floor=Workspace:Raycast(clipped+Vector3.new(0,5,0),Vector3.new(0,-15,0),params)
 if not floor or floor.Normal.Y<0.6 then return false end
 local point=floor.Position+Vector3.new(0,3,0)
 if World.regionAt(origin.X,origin.Y,origin.Z)~=World.regionAt(point.X,point.Y,point.Z) then return false end
 -- The full body must fit; narrow gaps and ceilings cannot be bypassed by a point ray.
 for _,offset in {Vector3.new(1.5,0,0),Vector3.new(-1.5,0,0),Vector3.new(0,2,0),Vector3.new(0,0,1.5),Vector3.new(0,0,-1.5)} do
  if Workspace:Raycast(point,offset,params) then return false end
 end
 Characters.Teleport(e.Id,CFrame.lookAt(point,point+e.Root.CFrame.LookVector))
 return true
end
return table.freeze(Geometry)
