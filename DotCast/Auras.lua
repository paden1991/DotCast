local _,P=...
local function number(v)return P:IsPlain(v)and type(v)=='number'and v==v and math.abs(v)~=math.huge end
local function call(fn,...)
 if type(fn)~='function'then return nil end
 local ok,value=pcall(fn,...);if ok and P:IsPlain(value)then return value end
end

-- Enumerate once per unit, with the engine's player-only filter. Explicit foreign
-- ownership is still rejected. No combat-log inference or guessed durations.
function P:ReadAuras(unit)
 local result={byID={},byName={},complete=false,at=GetTime()}
 if not C_UnitAuras or type(C_UnitAuras.GetAuraDataByIndex)~='function'then return result end
 for index=1,255 do
  local ok,aura=pcall(C_UnitAuras.GetAuraDataByIndex,unit,index,'HARMFUL|PLAYER')
  if not ok or not self:IsPlain(aura)then return result end
  if aura==nil then result.complete=true;return result end
  if not self:CanReadTable(aura)then return result end
  local source=aura.sourceUnit
  local owned
  if self:IsPlain(source)and type(source)=='string'then
   if source=='player'then owned=true else owned=call(UnitIsUnit,source,'player')end
  end
  -- Unknown ownership is not evidence of our debuff, even if filter was passed.
  if owned==nil then return result end
  if owned then
   local id,name=aura.spellId,aura.name
   local hasID=number(id);local hasName=self:IsPlain(name)and type(name)=='string'
   if not hasID and not hasName then return result end
   local entry={}
   local expiration,duration=aura.expirationTime,aura.duration
   if number(expiration)and expiration>0 and number(duration)and duration>0 then
    entry.expires=expiration;entry.duration=duration
   end
   if number(aura.applications)and aura.applications>1 then entry.stacks=aura.applications end
   if hasID then result.byID[id]=entry end
   if hasName then result.byName[name]=entry end
  end
 end
 -- A capped enumeration cannot prove that an effect is missing.
 return result
end
function P:EffectState(row,unit,cache)
 cache=cache or self:ReadAuras(unit)
 local found
 for id in pairs(row.auraIDs)do if cache.byID[id]then found=cache.byID[id];break end end
 found=found or cache.byName[row.name]
 if found then
  local left=found.expires and math.max(0,found.expires-GetTime())
  -- An expired observation is unknown until an authoritative rescan removes it.
  if left==0 then return {state='unknown'}end
  return {state=left and left<=self.db.warnSeconds and 'expiring'or 'active',remaining=left,stacks=found.stacks}
 end
 return {state=cache.complete and 'missing'or 'unknown'}
end
-- Flash only a confirmed own effect with readable time strictly below 2 seconds.
-- Fade artwork, never the protected button or its clickable footprint.
function P:EffectAlpha(state,cooldown,now)
 local present=state.state=='active'or state.state=='expiring'
 local flashing=present and number(state.remaining)and state.remaining>0 and state.remaining<2
 local alpha=present and self.db.idleAlpha or 1
 if flashing then alpha=.2+.8*(.5+.5*math.cos((now or GetTime())*4*math.pi))end
 -- Preserve the user's cooldown opacity, including completely hidden artwork.
 if cooldown==true then
  alpha=flashing and alpha*self.db.cooldownAlpha or math.min(alpha,self.db.cooldownAlpha)
 end
 return alpha,flashing
end
function P:Update()
 if not self.appliedEnabled or #self.rows==0 then return end
 local active,usable={},{}
 for i,row in ipairs(self.rows)do local _,value=self:Cooldown(row.id);active[i]=value;usable[i]=self:Usability(row)end
 for _,bar in pairs(self.bars)do
  if bar.prepared then
   local ok,reason=self:Guard('plate '..(bar.unit or 'unassigned'),function()
   local mapped=bar.unit and self:Root(bar.unit)==bar.root
   local attackable=mapped and call(UnitCanAttack,'player',bar.unit)
   local enemy=mapped and (attackable==true or attackable==nil and bar.enemy==true)
   local dead=mapped and call(UnitIsDeadOrGhost,bar.unit)
   if not enemy or dead==true then
    self:ClearVisuals(bar)
    if not InCombatLockdown()then self:Detach(bar)end
   else
    local now=GetTime()
    if not bar.auraCache or now-bar.auraCache.at>=.5 then bar.auraCache=self:ReadAuras(bar.unit)end
    for i,row in ipairs(self.rows)do
     local state=self:EffectState(row,bar.unit,bar.auraCache)
     local range=self:Range(row,bar.unit)
     local alpha,flashing=self:EffectAlpha(state,active[i],now)
     local needs=state.state=='missing'or state.state=='expiring'or flashing
     local label=state.remaining and tostring(math.ceil(state.remaining))or state.state=='unknown'and '?'or state.state=='active'and '*'or ''
     local ready=needs and active[i]==false and range~=false and usable[i]==true
     local b=bar.buttons[i];b.effectState=state.state;b.flashing=flashing
     self:Paint(b,alpha,range==false,label,ready,ready and self.db.castGlow and alpha or 0)
     if state.stacks then b.stacks:SetText(tostring(state.stacks))end
     if (state.state=='expiring'or flashing)and range~=false then b.icon:SetVertexColor(1,.75,.3)end
    end
   end
   end)
   if not ok and reason=='error'then pcall(self.ClearVisuals,self,bar)end
  end
 end
end
