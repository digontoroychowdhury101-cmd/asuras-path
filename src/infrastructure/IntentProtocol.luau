--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/IntentProtocol
-- Pure validation; all client tables have exact keys and bounded flat payloads.
export type Frame = {seq: number,x: number,z: number,yaw: number,guard: boolean,body: boolean}
export type Bucket = { tokens: number, time: number }
local Protocol = {}
local LIMBS: {[string]: boolean}={LeftHand=true,RightHand=true,LeftLeg=true,RightLeg=true,Evade=true,Tap=true,Guard=true,Style=true}
local VARIANTS: {[string]: boolean}={Primary=true,Alternate=true,Up=true,Down=true,Left=true,Right=true,Roll=true,Ironline=true,ApexStriker=true,Groundforge=true,Pass=true,TakeBack=true,Sweep=true,Armbar=true,RNC=true,Guillotine=true,StandUp=true,Takedown=true}
local function finite(v: any,low: number,high: number): boolean
	return type(v)=="number" and v==v and v>=low and v<=high
end
local function keys(t: any,allowed: {[string]: boolean},expected: number): boolean
	if type(t)~="table" then return false end
	local count=0
	for k in pairs(t) do
		count+=1
		if count>expected or type(k)~="string" or not allowed[k] then return false end
	end
	return count==expected
end
function Protocol.Take(bucket: Bucket,now: number,cost: number,rate: number,burst: number): boolean
	bucket.tokens=math.min(burst,bucket.tokens+math.max(0,now-bucket.time)*rate)
	bucket.time=math.max(bucket.time,now)
	if bucket.tokens<cost then return false end
	bucket.tokens-=cost
	return true
end
function Protocol.Movement(packet: any,session: string,lastSequence: number,c: any): ({Frame}?,string?)
	if not keys(packet,{version=true,session=true,frames=true},3) then return nil,"shape" end
	if packet.version~=c.Protocol or packet.session~=session then return nil,"session" end
	if type(packet.frames)~="table" then return nil,"frames" end
	local count=0
	for k in pairs(packet.frames) do
		count+=1
		if count>c.MaxBatch or type(k)~="number" or not finite(k,1,c.MaxBatch) or k%1~=0 then return nil,"batch" end
	end
	if count==0 then return nil,"empty" end
	local result: {Frame}={}
	for i=1,count do
		local f=packet.frames[i]
		if not keys(f,{seq=true,x=true,z=true,yaw=true,guard=true,body=true},6) or type(f.guard)~="boolean" or type(f.body)~="boolean" then return nil,"frame shape" end
		if not finite(f.seq,lastSequence+1,math.min(c.MaxSequence,lastSequence+c.MaxSequenceGap)) or f.seq%1~=0 then return nil,"sequence" end
		if i>1 and f.seq~=result[i-1].seq+1 then return nil,"order" end
		if not finite(f.x,-1,1) or not finite(f.z,-1,1) or f.x*f.x+f.z*f.z>1.00001 then return nil,"axes" end
		if not finite(f.yaw,-math.pi,math.pi) then return nil,"yaw" end
		result[i]={seq=f.seq,x=f.x,z=f.z,yaw=f.yaw,guard=f.guard,body=f.body}
	end
	return result,nil
end
function Protocol.Action(packet: any,session: string,lastSequence: number,c: any): boolean
	if not keys(packet,{version=true,session=true,seq=true,action=true,variant=true,body=true,grapple=true,pressed=true},8) then return false end
	return packet.version==c.Protocol and packet.session==session
		and finite(packet.seq,lastSequence+1,math.min(c.MaxSequence,lastSequence+c.MaxSequenceGap)) and packet.seq%1==0
		and type(packet.action)=="string" and LIMBS[packet.action]==true
		and type(packet.variant)=="string" and VARIANTS[packet.variant]==true
		and type(packet.body)=="boolean" and type(packet.grapple)=="boolean" and type(packet.pressed)=="boolean"
end
local SHOP_FIELDS: {[string]: {[string]: boolean}}={
 SaveSettings={action=true,settings=true},GetProfile={action=true},RollStyle={action=true,useToken=true},
 RollCrate={action=true,crateId=true},BuyCosmetic={action=true,itemId=true},EquipCosmetic={action=true,itemId=true},
 EquipStyle={action=true,styleName=true},BuyBundle={action=true,bundleId=true},
}
function Protocol.Shop(packet: any): boolean
 if type(packet)~="table" or type(packet.action)~="string" then return false end
 local allowed=SHOP_FIELDS[packet.action]
 if not allowed then return false end
 local expected=if packet.action=="GetProfile" then 1 else 2
 if not keys(packet,allowed,expected) then return false end
 if packet.action=="GetProfile" then return true end
 if packet.action=="SaveSettings" then
  local s=packet.settings
  local count=if type(s)=="table" then 3+(if s.keybinds~=nil then 1 else 0)+(if s.comfort~=nil then 1 else 0) else 3
  if not keys(s,{fov=true,sensitivity=true,leftHanded=true,keybinds=true,comfort=true},count) then return false end
  if s.comfort~=nil then -- comfort/readability toggles (batch 25)
   local c=s.comfort
   if not keys(c,{ReducedEffects=true,ReducedMotion=true,ReducedFlashes=true,TextScale=true},4) then return false end
   if type(c.ReducedEffects)~="boolean" or type(c.ReducedMotion)~="boolean" or type(c.ReducedFlashes)~="boolean" then return false end
   if c.TextScale~=1 and c.TextScale~=1.15 and c.TextScale~=1.3 then return false end
  end
  if s.keybinds~=nil then
   if type(s.keybinds)~="table" then return false end
   local n=0
   for k,v in s.keybinds do n+=1;if n>11 or type(k)~="string" or #k>16 or type(v)~="string" or #v>32 then return false end end
  end
  return finite(s.fov,70,90)
   and finite(s.sensitivity,0.5,2) and type(s.leftHanded)=="boolean"
 end
 if packet.action=="RollStyle" then return type(packet.useToken)=="boolean" end
 local id=packet.itemId or packet.styleName or packet.bundleId or packet.crateId
 return type(id)=="string" and #id>0 and #id<=64 and string.match(id,"^[%w_]+$")~=nil
end
function Protocol.QueueEnabled(mode: string,feature: boolean,rankedPassed: boolean,studioQA: boolean): boolean
 return mode=="Casual1v1" or (mode=="Ranked1v1" and ((feature and rankedPassed) or studioQA))
end
function Protocol.Matchmaking(packet: any): boolean
 if type(packet)~="table" then return false end
 if packet.action=="Dequeue" then return keys(packet,{action=true},1) end
 return keys(packet,{action=true,mode=true},2) and packet.action=="Enqueue"
  and (packet.mode=="Ranked1v1" or packet.mode=="Casual1v1")
end
return table.freeze(Protocol)
