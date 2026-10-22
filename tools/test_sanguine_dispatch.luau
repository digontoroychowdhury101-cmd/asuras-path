--!nonstrict
-- Exercise the real visual dispatcher with state/render adapters, without Roblox or live profiles.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local V = roblox.Vector3
local calls, clears, blocked, checks = {}, 0, false, 0
local function mark(name) return function() table.insert(calls, name) end end
local env = { Vector3 = V, Combat = { parry=mark("parry"), hit=mark("hit") },
	Ghost = { dodge=mark("dodge") }, Magic = { phase=mark("phase"), death=mark("death"), impact=mark("impact"), spell=mark("spell") },
	Spells = { get=function() return { Discipline="CelestialThunder" } end } }
local source = fs.readFile("src/client/Controllers/SanguineDispatch.luau")
for _, name in {"Combat", "Ghost", "Magic", "Spells"} do
	source = source:gsub("local " .. name .. " = [^\n]+", "local " .. name .. " = " .. name)
end
local dispatch = luau.load(source, {environment=env})()
local own = { Id=1, Root={Position=V.new(0,3,0)}, Model={GetExtentsSize=function() return V.new(2,6,2) end} }
local other = { Id=2, Root={Position=V.new(0,3,2)}, Model={} }
local state = { Entities={[1]=own,[2]=other} }
function state:Own() return own end
function state:Get(id) return self.Entities[id] end
local self = {State=state,Context={}}
function self:Clear() clears+=1 end
function self:Blocked() return blocked end
function self:Near(point) return point~=nil and (point-own.Root.Position).Magnitude<65 end
local function check(name, yes) checks+=1;assert(yes,name) end
local function event(kind, sourceId, targetId) dispatch.event(self,{Kind=kind,Source=sourceId,Target=targetId}) end
local function cue(kind, sourceId, data) dispatch.cue(self,{Kind=kind,Source=sourceId,Data=data or {}}) end
event("Rest",2,2);check("foreign rest preserves local effects",clears==0)
event("Rest",1,1);check("own rest clears effects",clears==1)
cue("BossReset",2,{participants={2}});check("foreign encounter reset preserves local effects",clears==1)
cue("BossReset",2,{participants={1,2}});check("participant reset clears effects",clears==2)
cue("BossParticipantLeft",2);check("another participant leaving preserves local effects",clears==2)
cue("BossParticipantLeft",1);check("own encounter exit clears effects",clears==3)
cue("AltarTravel",2);check("foreign travel preserves local effects",clears==3)
cue("AltarTravel",1);check("own travel clears effects",clears==4)
event("KO",1,2);check("another defeat does not clear all effects",clears==4)
event("KO",2,1);check("own death clears effects",clears==5)
blocked=true;event("DeflectSpark",1,2);cue("BossPhase",1)
check("modal suppression blocks decorative calls",#calls==0)
blocked=false
for _, kind in {"DeflectSpark","Hit","CounterHit","Armored","Deathblow","Block","GuardBreak","StanceBreak","Dash"} do
	local before=#calls;event(kind,1,2);check("routes authoritative "..kind,#calls==before+1)
end
for _, kind in {"BossPhase","BossEnrage","BossDefeated","Shockwave","SpellStartup","SpellRelease","SpellPulse","ProjectileParry"} do
	local before=#calls;cue(kind,1,{spell="ThunderPalm"});check("routes authoritative "..kind,#calls==before+1)
end
local before=#calls;cue("Telegraph",1,{radius=20});cue("BossHazard",1,{radius=20})
check("existing danger telegraphs are not replaced",#calls==before)
other.Root.Position=V.new(1000,3,0);event("Hit",1,2)
check("distant effects are culled",#calls==before)
print("sanguine dispatch: "..checks.." passed, 0 failed (state/render adapters; Studio visual acceptance separate)")
