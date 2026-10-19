--!strict
local Run=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage").AsurasPath
local Config=require(Shared.Config) :: any
local Store=require(script.Parent.ProfileStore)
local Journal=require(script.Parent.MatchJournal) :: any
local mock: {[string]: any}={}
local db: any
if Run:IsStudio() and not Config.Backend.StudioLiveData then
 db={UpdateAsync=function(_: any,key: string,fn: (any)->any): any
  local result=fn(Store.Copy(mock[key]));if result then mock[key]=Store.Copy(result) end;return Store.Copy(result)
 end}
else db=game:GetService("DataStoreService"):GetDataStore("AsuraSpectatorWagers_v1") end
return Journal.new(db,function(fn: ()->any): (boolean,any)
 local last: any=nil
 for n=1,4 do local ok,result=pcall(fn);if ok then return true,result end;last=result;if n<4 then task.wait(n*0.25) end end
 return false,last
end,os.time)
