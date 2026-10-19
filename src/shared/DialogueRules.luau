--!strict
local hasScript=pcall(function() return script.Parent end)
local Catalog: any=if hasScript then require(script.Parent.NarrativeCatalog) else require("./NarrativeCatalog")
local Rules={}
function Rules.node(npc: string,node: string): any
 local n=Catalog.NPCs[npc];return if n then n.Nodes[node] else nil
end
function Rules.choose(npc: string,node: string,index: number): any
 local n=Rules.node(npc,node);if not n or index%1~=0 then return nil end
 local c=n.Choices[index];if not c then return nil end
 if c.Close then return {Close=true} end
 if not Rules.node(npc,c.Next) then return nil end
 return {Next=c.Next,Action=c.Action}
end
function Rules.valid(packet: any): boolean
 if type(packet)~="table" or type(packet.action)~="string" then return false end
 local shapes={Choose={action="string",index="number",revision="number"},Close={action="string"},
  Upgrade={action="string",revision="number"},Infuse={action="string",id="string",revision="number"},
  Level={action="string",id="string",revision="number"},Trade={action="string",id="string",revision="number"},Codex={action="string"}}
 local shape=shapes[packet.action];if not shape then return false end
 local count=0;local expected=0;for _ in shape do expected+=1 end
 for key,v in packet do
  count+=1;if type(v)~=shape[key] then return false end
  if type(v)=="string" and #v>64 then return false end
  if type(v)=="number" and (v~=v or v%1~=0 or math.abs(v)>2147483647) then return false end
 end
 return count==expected
end
return table.freeze(Rules)
