local _,P=...
-- Targeted, directly cast DoTs. Highest known rank first; client confirms learning.
-- IDs are candidates, never a claim that a spell is learned in this game mode.
P.abilities={
 WARRIOR={{key='rend',kind='Bleed',ids={11574,11573,11572,6548,6547,6546,772}}},
 ROGUE={{key='garrote',kind='Bleed / stealth',ids={11290,11289,8633,8632,8631,703}},{key='rupture',kind='Bleed / finisher',ids={11275,11274,11273,8640,8639,1943}}},
 MAGE={{key='fireball',kind='Fire / direct + DoT',ids={25306,10151,10150,10149,10148,8402,8401,8400,3140,145,143,133}},{key='pyroblast',kind='Fire / direct + DoT',ids={18809,12526,12525,12524,12523,12522,12505,11366}}},
 SHAMAN={{key='flameshock',kind='Fire',ids={29228,10448,10447,8053,8052,8050}}},
 DRUID={{key='moonfire',kind='Arcane',ids={9835,9834,9833,8929,8928,8927,8926,8925,8924,8921}},{key='insectswarm',kind='Nature',ids={24977,24976,24975,24974,5570}},{key='rake',kind='Bleed / cat',ids={9904,9752,1823,1822}},{key='rip',kind='Bleed / cat finisher',ids={9896,9894,9750,9493,9492,1079}}},
 HUNTER={{key='serpentsting',kind='Poison',ids={25295,13555,13554,13553,13552,13551,13550,13549,1978}}},
 PALADIN={}, -- Passive seal procs and ground AoE are not mouseover DoT casts.
 PRIEST={{key='shadowwordpain',kind='Shadow',ids={25367,10894,10893,10892,992,970,594,589}},{key='devouringplague',kind='Disease',ids={19280,19279,19278,19277,19276,2944}},{key='holyfire',kind='Holy / direct + DoT',ids={15261,15267,15266,15265,15264,15263,15262,14914}}},
 WARLOCK={{key='corruption',kind='Shadow',ids={25311,11672,11671,7648,6223,6222,172}},{key='agony',kind='Curse',ids={11713,11712,6217,6216,1014,980}},{key='immolate',kind='Fire',ids={25309,11668,11667,11666,11665,2941,1094,707,348}},{key='siphonlife',kind='Shadow / drain',ids={18881,18880,18879,18265}},{key='doom',kind='Curse / delayed damage',ids={603}}},
}
function P:IsPlain(v)
 if issecretvalue and issecretvalue(v) then return false end
 return true
end
function P:CanReadTable(v)
 if not self:IsPlain(v)or type(v)~='table'then return false end
 if type(canaccesstable)=='function'then
  local ok,allowed=pcall(canaccesstable,v)
  return ok and self:IsPlain(allowed)and allowed==true
 end
 return true
end
function P:Known(id,pet)
 local ok,v
 if IsSpellKnown then ok,v=pcall(IsSpellKnown,id,pet==true)
 elseif C_SpellBook and C_SpellBook.IsSpellKnown then
  local bank=Enum and Enum.SpellBookSpellBank
  if pet and not bank then return false end
  ok,v=pcall(C_SpellBook.IsSpellKnown,id,bank and (pet and bank.Pet or bank.Player))
 elseif not pet and IsPlayerSpell then ok,v=pcall(IsPlayerSpell,id)end
 return ok and self:IsPlain(v) and v==true
end
function P:Spell(id)
 if C_Spell and C_Spell.GetSpellInfo then
  local ok,info=pcall(C_Spell.GetSpellInfo,id)
  if ok and self:CanReadTable(info)and self:IsPlain(info.name)and type(info.name)=='string'then return info.name,self:IsPlain(info.iconID)and info.iconID or nil end
 elseif GetSpellInfo then
  local ok,name,_,icon=pcall(GetSpellInfo,id)
  if ok and self:IsPlain(name)then return name,icon end
 end
end
function P:Candidates(class)
 local out={};local families={}
 for _,row in ipairs(self.abilities[class]or {})do families[#families+1]=row end
 local custom=self.characterDB and self.characterDB.custom or {}
 -- Resolve Forever's new Lacerate through the client's learned spell name.
 -- English name lookup may be unavailable on other locales; custom IDs work there.
 if class=='DRUID'and C_Spell and C_Spell.GetSpellInfo then
  local ok,info=pcall(C_Spell.GetSpellInfo,'Lacerate')
  if ok and self:CanReadTable(info)and self:IsPlain(info.spellID)and type(info.spellID)=='number'then
   families[#families+1]={key='lacerate',kind='Bleed / bear',ids={info.spellID}}
  end
 end
 for _,row in ipairs(custom)do if type(row)=='table'and type(row.id)=='number'then families[#families+1]={key='custom'..row.id,kind='Custom',ids={row.id},auraIDs=row.auraIDs,custom=true}end end
 local names={}
 for _,row in ipairs(families)do
  for _,id in ipairs(row.ids)do if self:Known(id,row.pet)then
   local name,icon=self:Spell(id)
   if name and not names[name]then
    names[name]=true;local matches={}
    for _,auraID in ipairs(row.auraIDs or row.ids)do matches[auraID]=true end
    out[#out+1]={key=row.key,id=id,name=name,icon=icon,kind=row.kind,auraIDs=matches,custom=row.custom}
   end
   break
  end end
 end
 return out
end
-- Return remaining seconds separately from cooldown activity. In combat the
-- client can expose activity while keeping the timing values secret.
function P:Cooldown(id)
 local start,duration,enabled,onGCD,active
 local function plainNumber(v)
  return self:IsPlain(v)and type(v)=='number'and v==v and math.abs(v)~=math.huge
 end
 local function plainBool(v)
  if self:IsPlain(v)and type(v)=='boolean'then return v end
 end
 if C_Spell and type(C_Spell.GetSpellCooldown)=='function'then
  local ok,info=pcall(C_Spell.GetSpellCooldown,id)
  if ok and self:CanReadTable(info)then
   start,duration,enabled,onGCD=info.startTime,info.duration,info.isEnabled,info.isOnGCD
   active=plainBool(info.isActive)
  end
 elseif type(GetSpellCooldown)=='function'then
  local ok;ok,start,duration,enabled=pcall(GetSpellCooldown,id)
  if not ok then start,duration,enabled=nil,nil,nil end
 end
 local remaining
 if self:IsPlain(enabled)and enabled~=false and enabled~=0 and plainNumber(start)and plainNumber(duration)then
  remaining=math.max(0,start+duration-GetTime())
  if plainBool(onGCD)==true then remaining=0 end
 end
 -- Prefer the native duration's activity with the global cooldown excluded.
 -- Never compare or perform arithmetic on a secret return value.
 local nativeActive
 if C_Spell and type(C_Spell.GetSpellCooldownDuration)=='function'then
  local ok,obj=pcall(C_Spell.GetSpellCooldownDuration,id,true)
  if ok and self:IsPlain(obj)and obj~=nil then
   local read,state=pcall(function()
    if type(obj.IsActive)=='function'then
     local value=obj:IsActive();local known=plainBool(value)
     if known~=nil then return known end
    end
    if type(obj.IsZero)=='function'then
     local value=obj:IsZero();local known=plainBool(value)
     if known~=nil then return not known end
    end
   end)
   if read then nativeActive=plainBool(state)end
  end
 end
 local source
 if nativeActive~=nil then
  active=nativeActive;source='native duration'
  if not active then remaining=0 elseif remaining==0 then remaining=nil end
 elseif remaining~=nil then active=remaining>0;source='readable timer'
 elseif active~=nil then source='activity flag'
 else source='unavailable'end
 if active==false then remaining=0 end
 self.cooldownStatus=self.cooldownStatus or {}
 self.cooldownStatus[id]={active=active,source=source}
 return remaining,active
end

-- Resource/form requirements are separate from cooldown readiness. Unknown
-- values do not authorize a ready marker or a refresh glow.
function P:Usability(row)
 local fn=C_Spell and C_Spell.IsSpellUsable or IsUsableSpell
 if type(fn)~='function'then return nil,nil end
 local ok,usable,insufficient=pcall(fn,row.id)
 if not ok then return nil,nil end
 if not self:IsPlain(usable)or type(usable)~='boolean'then usable=nil end
 if not self:IsPlain(insufficient)or type(insufficient)~='boolean'then insufficient=nil end
 if insufficient==true then usable=false end
 return usable,insufficient
end

-- Only a definite false means out of range; invalid/secret data stays unknown.
function P:Range(row,unit)
 local function read(u)
  local ok,value
  if C_Spell and type(C_Spell.IsSpellInRange)=='function'then
   ok,value=pcall(C_Spell.IsSpellInRange,row.id,u)
  elseif type(IsSpellInRange)=='function'then
   ok,value=pcall(IsSpellInRange,row.name,u)
  end
  if not ok or not self:IsPlain(value)then return nil end
  if value==true or value==1 then return true end
  if value==false or value==0 then return false end
 end
 local result=read(unit)
 if result~=nil then return result end
 -- Some client APIs reject nameplate tokens; aliases must match this enemy.
 for _,alias in ipairs({'mouseover','target'})do
  if type(UnitIsUnit)=='function'then
   local ok,same=pcall(UnitIsUnit,alias,unit)
   if ok and self:IsPlain(same)and same==true then
    result=read(alias);if result~=nil then return result end
   end
  end
 end
end
