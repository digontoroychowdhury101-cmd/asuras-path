--!strict
local Protocol={}
local FIELDS: {[string]: {[string]: boolean}}={State={action=true},UseTalisman={action=true},Cast={action=true,slot=true},Forge={action=true,id=true},
 EquipSpell={action=true,id=true,slot=true},EquipWeapon={action=true,id=true,offhand=true}}
function Protocol.valid(packet: any): boolean
 if type(packet)~="table" or type(packet.action)~="string" then return false end
 local fields=FIELDS[packet.action];if not fields then return false end
 local count=0;for key in packet do if not fields[key] then return false end;count+=1 end
 local expected=if (packet.action=="State" or packet.action=="UseTalisman") then 1 elseif packet.action=="EquipSpell" or packet.action=="EquipWeapon" then 3 else 2
 if count~=expected then return false end
 if fields.slot and packet.slot~=1 and packet.slot~=2 then return false end
 if fields.id and (type(packet.id)~="string" or #packet.id<1 or #packet.id>48 or not string.match(packet.id,"^[%w_]+$")) then return false end
 if fields.offhand and type(packet.offhand)~="boolean" then return false end
 return true
end
return table.freeze(Protocol)
