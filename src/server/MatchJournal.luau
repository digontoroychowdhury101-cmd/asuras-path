--!nonstrict
-- Durable immutable match results, discoverable through each participant's pre-start inbox.
local Journal={};Journal.__index=Journal
function Journal.new(store,retry,now) return setmetatable({store=store,retry=retry,now=now},Journal) end
function Journal:Create(id,players,owner)
 return self.retry(function()
  return self.store:UpdateAsync("Match_"..id,function(old)
   return old or {id=id,players=players,owner=owner,state="Active",expires=self.now()+1200}
  end)
 end)
end
function Journal:Finish(id,results)
 return self.retry(function()
  return self.store:UpdateAsync("Match_"..id,function(old)
   assert(old,"Missing match journal")
   if old.state~="Active" then return old end
   old.state=if results then "Complete" else "Cancelled";old.results=results
   return old
  end)
 end)
end
function Journal:Read(id)
 return self.retry(function()
  return self.store:UpdateAsync("Match_"..id,function(old)
   if old and old.state=="Active" and old.expires<=self.now() then old.state="Cancelled" end
   return old
  end)
 end)
end
return Journal
