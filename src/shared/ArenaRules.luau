--!strict
local Rules={}
function Rules.rank(elo: number,games: number): string
 if games==0 then return "Unranked" end
 if elo<1100 then return "Ash Disciple" elseif elo<1400 then return "Iron Vanguard"
 elseif elo<1800 then return "Sword Saint" else return "Asura Sovereign" end
end
function Rules.normalized(): {[string]: number}
 return {Vigor=20,Endurance=20,Strength=20,Dexterity=20,ArcaneQi=20}
end
function Rules.validWager(amount: any): boolean
 return type(amount)=="number" and amount==amount and amount>=50 and amount<=500 and amount%1==0
end
function Rules.place(p: any,matchId: string,fighter: number,amount: number)
 assert(Rules.validWager(amount),"Wager must be 50–500 Qi")
 assert(not p.arenaWagers[matchId],"One wager per duel");assert(p.qiEssence>=amount,"Not enough Qi")
 p.qiEssence-=amount;p.arenaWagers[matchId]={Fighter=fighter,Amount=amount,State="Pending"}
end
function Rules.settle(p: any,matchId: string,winner: number?,refund: boolean): number
 local bet=p.arenaWagers[matchId];if not bet or bet.State~="Pending" then return 0 end
 local payout=if refund then bet.Amount elseif bet.Fighter==winner then math.floor(bet.Amount*1.8) else 0
 bet.State="Settled";p.qiEssence+=payout;return payout
end
return table.freeze(Rules)
