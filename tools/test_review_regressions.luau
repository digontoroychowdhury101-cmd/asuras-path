--!strict
-- Run through test_review_regressions.py to inject the unchanged production functions.
local Combat = require("../src/simulation/CombatRules")
local World = require("../src/shared/WorldDefinitions")
local Protocol = require("../src/infrastructure/IntentProtocol")
local checks = 0
local function check(value: any, label: string) assert(value, label); checks += 1 end
local V: any = {}
V.__index = function(v: any, k: string): any
	if k == "Magnitude" then return math.sqrt(v.X*v.X + v.Y*v.Y + v.Z*v.Z) end
end
local function vec(x: number, y: number, z: number): any return setmetatable({X=x,Y=y,Z=z}, V) end
V.__sub = function(a: any, b: any): any return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
local Vector3 = {new=vec}
do
	local ORIGIN = vec(World.Sanctuary.Origin.X, World.Sanctuary.Origin.Y, World.Sanctuary.Origin.Z)
	local CATCH_RADIUS, CATCH_DEPTH = 1300, 40
	local e: any = {Root={},Fighter={State="Idle"}}
	local returned = false
	local Players = {GetPlayers=function() return {{UserId=1}} end}
	local settling = false
	local Characters = {GetEntity=function() return e end, IsInDuel=function() return false end,
		Teleport=function() returned=true end, Cue=function() end, IsSettling=function() return settling end}
	local spawnCFrame = {}
	local Recovery = require("../src/server/RecoveryRules")
	local fallState: any = {}
	local CATCH_LIMITS = {Radius=CATCH_RADIUS, FloorY=ORIGIN.Y-CATCH_DEPTH}
	-- POLL_INSERT
	local altar = World.Altars.Altar_SanctuaryDepths.Spawn
	for _, position in {vec(520,3,988),vec(520,3,880),vec(altar.X,altar.Y,altar.Z)} do
		returned=false;e.Root.Position=position;poll()
		check(not returned,"Crypt entrance, arena and checkpoint remain accessible")
	end
	e.Root.Position=vec(0,550,900);poll();check(returned,"A fall from the shrine is still recovered")
	returned=false;e.Root.Position=vec(0,603,920);poll();check(not returned,"Shrine ground is safe")
	e.Root.Position=vec(0,3,-900);poll();check(not returned,"Monastery is safe")
	-- Batch 01: a later-altar respawn displaced to the engine default spawn is never sent to the bonfire.
	settling=true;e.Root.Position=vec(0,100,0);poll();check(not returned,"Settling respawn is not caught")
	settling=false;poll();check(not returned,"Unclaimed ground below the shrine is not a Sanctuary fall")
end
do
	local entities: any = {}
	local frameEvents: {Combat.Event} = {}
	local eventPoints: any = {}
	local TICK, FACING_DOT = 1/60, 0.15
	local region = "LeftLeg"
	local Lag = {queryHit=function() return {Region=region,Point=vec(0,0,0)} end}
	local function weaponSegment(...: any): (any,any) return vec(0,0,0),vec(0,0,0) end
	local function weaponRadius(...: any): number return 0.3 end
	local function alive(...: any): boolean return true end
	local function hostile(...: any): boolean return true end
	local function facingDot(...: any): number return 1 end
	local function awardXp(...: any) end
	-- CONTACT_INSERT
	local function setup(weak: boolean, hitRegion: string): (any,any)
		table.clear(frameEvents);region=hitRegion
		local a,b=Combat.new(1,"Jian",0),Combat.new(-1,"Guandao",0)
		assert(Combat.tryAttack(a,"Light",0));a.State="Active"
		local model={GetAttribute=function() return if weak then "Ankles" else nil end}
		entities={{Id=1,Fighter=a,Root={CFrame={}}},{Id=-1,Fighter=b,Model=model,History={}}}
		return a,b
	end
	local a,b=setup(false,"LeftLeg");resolveContacts(entities[1],0.2);local ordinary=b.Posture
	a,b=setup(true,"LeftLeg");resolveContacts(entities[1],0.2)
	check(math.abs(b.Posture-ordinary-a.Move.PostureDamage*1.8)<1e-6,"Clean ankle hits retain bonus posture")
	local posture=b.Posture;resolveContacts(entities[1],0.2);check(b.Posture==posture,"Bonus applies once per move")
	a,b=setup(true,"Torso");resolveContacts(entities[1],0.2);check(b.Posture==ordinary,"Other hurtboxes receive no bonus")
	a,b=setup(true,"LeftLeg");b.Posture=Combat.maxPosture(b)-1;Combat.cinematic(b,0.2,2.8)
	posture=b.Posture;resolveContacts(entities[1],0.2)
	check(b.Posture==posture and b.State=="Recovery" and b.ActiveHP==b.MaxHP,"Invulnerable Titan cannot be staggered")
	a,b=setup(true,"LeftLeg");b.Posture=Combat.maxPosture(b)-1
	assert(Combat.tryDeflect(b,0.2,0.2));resolveContacts(entities[1],0.2)
	check(b.State=="Deflecting" and b.ActiveHP==b.MaxHP,"Near-broken Titan retains a successful deflect")
	a,b=setup(false,"LeftLeg");b.State="Blocking";resolveContacts(entities[1],0.2);ordinary=b.Posture
	a,b=setup(true,"LeftLeg");b.State="Blocking";resolveContacts(entities[1],0.2)
	check(b.Posture==ordinary and b.State=="Blockstun","Blocked ankle hits respect guard")
	a,b=setup(true,"LeftLeg");b.Posture=Combat.maxPosture(b)-1;b.WardUntil=30;resolveContacts(entities[1],0.2)
	check(b.State~="StanceBroken" and b.WardUntil==0,"One ward absorbs the combined posture strike")
end
do
	local received: {any} = {}
	local player: any = {UserId=901,Parent=true,Attributes={}}
	function player:GetAttribute(key: string): any return self.Attributes[key] end
	function player:SetAttribute(key: string,value: any) self.Attributes[key]=value end
	function player:Kick(message: string) error(message) end
	local loaded, unloaded = false, false
	local profile={inventory={Materials={}},souls={inventory={spellSlots={"JadeAegis","EmberCataclysm"}}}}
	local Persistence={Get=function() return if loaded then profile else nil end,PublicProfile=function() return profile end,
		Load=function() loaded=true end,Unload=function() unloaded=true end}
	local remote={FireClient=function(_self: any,_player: any,packet: any) table.insert(received,packet) end}
	local shopRemote=remote
	local Magic={Cooldowns=function() return {JadeAegis=123} end}
	local Loot={}
	-- LOOT_SYNC_INSERT
	-- PROFILE_SYNC_INSERT
	local loading: {[number]: boolean} = {}
	local shuttingDown=false
	local Colosseum={Recover=function() return true end}
	local Characters={RefreshRoster=function() end,RefreshProgression=function() end}
	local LOAD_RETRY_DELAY=0
	local task={wait=function() error("Unexpected recovery retry") end}
	local function trace(message: any): string return tostring(message) end
	local Config={Network={ShopBurst=5,ShopPerSecond=2}}
	local shopBudgets: any = {}
	local shopBusy: any = {}
	-- HYDRATE_INSERT
	-- SHOP_INSERT
	local function statePacket(): any
		for _,packet in received do if packet.action=="State" then return packet end end
		return nil
	end
	Loot.Sync(player);onShop(player,{action="GetProfile"})
	check(statePacket()==nil,"Early requests wait for loaded inventory")
	hydrate(player)
	local packet=statePacket()
	check(packet and packet.inventory.spellSlots[1]=="JadeAegis" and packet.inventory.spellSlots[2]=="EmberCataclysm","Slow profile load pushes saved slots automatically")
	check(packet.cooldowns.JadeAegis==123 and not packet.open,"Sync preserves cooldowns without opening arsenal")
	table.clear(received);player.Attributes={};loaded=false;hydrate(player)
	check(#received==0,"Hydration waits for a listening client")
	onShop(player,{action="GetProfile"});check(statePacket()~=nil,"Late client handshake receives saved arsenal")
	table.clear(received);player.Parent=nil;loaded=false;hydrate(player)
	check(unloaded and #received==0,"Departed players receive no hydration messages")
end
print(string.format("Review regressions: %d checks passed",checks))
