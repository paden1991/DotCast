local addon,P=...;_G.DotCast=P
P.version='0.1.3-beta';P.bars={};P.units={};P.rows={}
local function combat()return InCombatLockdown and InCombatLockdown()end
local function number(v)return P:IsPlain(v)and type(v)=='number'and v==v and v~=math.huge and v~=-math.huge end
local function text(v)return P:IsPlain(v)and type(v)=='string'and v or nil end
local function call(fn,...)
 if type(fn)~='function'then return nil end
 local ok,v=pcall(fn,...);if ok and P:IsPlain(v)then return v end
end
function P:Say(message)if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cffffcc55DotCast:|r '..message)end end
function P:Error(message)
 self.lastError=message
 if self.reportedError~=message then self.reportedError=message;self:Say(message)end
end
function P:Remember(root)
 if not root or call(root.IsForbidden,root)==true then return end
 local bar=self.bars[root]
 if not bar then bar={root=root,buttons={},prepared=false};self.bars[root]=bar end
 return bar
end
function P:Root(unit)
 return C_NamePlate and call(C_NamePlate.GetNamePlateForUnit,unit)
end
function P:Geometry(root,count)
 local x,y,height,width= -2,0,28,nil
 local ok,rx,ry,rh,rw=pcall(function()
  local uf=root.UnitFrame
  local bar=uf and ((uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar)or uf.healthBar)
  if not bar then return end
  local _,by=bar:GetCenter();local _,py=root:GetCenter()
  local br,pr=bar:GetRight(),root:GetRight()
  local bs,ps=bar:GetEffectiveScale(),root:GetEffectiveScale()
  local h,w=bar:GetHeight(),bar:GetWidth()
  if not(number(by)and number(py)and number(br)and number(pr)and number(bs)and number(ps)and number(h)and number(w))or ps<=0 or bs<=0 or h<=0 or w<=0 then return end
  return (br*bs-pr*ps)/ps-2,(by*bs-py*ps)/ps,h*bs/ps,w*bs/ps
 end)
 if ok and number(rx)and number(ry)and number(rh)and number(rw)then x,y,height,width=rx,ry,rh,rw end
 width=width or 180
 local reserved=0
 local cc=_G.CounterCast
 if cc and cc.appliedEnabled and cc.rows and #cc.rows>0 and type(cc.Geometry)=='function'then
  local cx,cy,cs=cc:Geometry(root,#cc.rows)
  if number(cx)and number(cy)and number(cs)and math.abs(cy-y)<cs then
   reserved=math.max(0,x-(cx-(#cc.rows*cs+(#cc.rows-1)*2)))+4
  end
 end
 local size=self.db.size>0 and self.db.size or math.max(24,math.min(48,height))
 local available=width-4-reserved
 -- Refuse an overlapping click surface rather than spill into CounterCast.
 if count>0 and available<count*12+(count-1)*2 then error('Nameplate too narrow for both addons. Reduce CounterCast size or disable some DotCast spells.')end
 if count>0 then size=math.min(size,math.floor((available-(count-1)*2)/count))end
 return x-width+4+(self.db.offsetX or 0),y+(self.db.offsetY or 0),size
end
function P:Detach(bar)
 if combat()then self.pending=true;return end
 for _,b in ipairs(bar.buttons)do
  b:Hide();b:SetAttribute('type',nil);b:SetAttribute('macro',nil)
  b:ClearAllPoints();b:SetParent(UIParent)
 end
 bar.prepared=false
end
function P:NewButton(bar)
 local b=CreateFrame('Button',nil,UIParent,'SecureActionButtonTemplate')
 b:Hide();b:SetFrameStrata('HIGH');b:RegisterForClicks('LeftButtonDown','LeftButtonUp')
 b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetAllPoints()
 b:SetNormalTexture('Interface\\Buttons\\UI-Quickslot2')
 b:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square','ADD')
 b.normal=b:GetNormalTexture();b.highlight=b:GetHighlightTexture()
 b.glow=b:CreateTexture(nil,'OVERLAY');b.glow:SetTexture('Interface\\Buttons\\UI-ActionButton-Border');b.glow:SetBlendMode('ADD');b.glow:SetPoint('CENTER',b,'CENTER');b.glow:SetAlpha(0)
 b.count=b:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');b.count:SetPoint('CENTER',b,'CENTER')
 b.stacks=b:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');b.stacks:SetPoint('BOTTOMRIGHT',b,'BOTTOMRIGHT',-1,1)
 b.ready=b:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');b.ready:SetPoint('BOTTOM',b,'TOP',0,1)
 b:HookScript('PreClick',function(button,mouse,down)
  if mouse~='LeftButton'or down then return end
  local matches=bar.unit and call(UnitIsUnit,'mouseover',bar.unit)
  P.lastClick={spell=button.row.name,matched=matches==true,readable=type(matches)=='boolean',at=GetTime()}
 end)
 -- Do not replace the native secure handler or propagate the click into the world.
 if type(b.SetMouseMotionEnabled)~='function'or type(b.SetMouseClickEnabled)~='function'then error('Separate mouse-motion/click APIs unavailable')end
 b:SetMouseMotionEnabled(false);b:SetMouseClickEnabled(true)
 if b.SetPropagateMouseMotion then b:SetPropagateMouseMotion(true)end
 if b.SetPropagateMouseClicks then b:SetPropagateMouseClicks(false)end
 b:SetAttribute('checkselfcast',false);b:SetAttribute('checkfocuscast',false);b:SetAttribute('useOnKeyDown',false)
 return b
end
function P:Configure(bar)
 if combat()then self.pending=true;return false end
 if not self.appliedEnabled or #self.rows==0 or not bar.unit or self:Root(bar.unit)~=bar.root or call(UnitCanAttack,'player',bar.unit)~=true then self:Detach(bar);return false end
 local ok,err=pcall(function()
  local x,y,size=self:Geometry(bar.root,#self.rows)
  for i,row in ipairs(self.rows)do
   local b=bar.buttons[i]
   if not b then b=self:NewButton(bar);bar.buttons[i]=b end
   b.row=row;b:SetParent(bar.root);b:ClearAllPoints()
   b:SetPoint('LEFT',bar.root,'RIGHT',x+(i-1)*(size+2),y)
   b:SetSize(size,size);b.glow:SetSize(size*1.7,size*1.7)
   b.icon:SetTexture(row.icon or 134400);b:SetAttribute('type','macro');b:SetAttribute('macro',row.macro)
   self:Paint(b,0,false,'',false,0);b:Show()
  end
  for i=#self.rows+1,#bar.buttons do local b=bar.buttons[i];b:Hide();b:SetAttribute('type',nil);b:SetAttribute('macro',nil)end
  bar.prepared=true;bar.size=size
 end)
 if not ok then self:Detach(bar);self:Error('Could not attach a nameplate: '..(text(err)or 'client restriction'));return false end
 return true
end
function P:Added(unit)
 if not text(unit)then return end
 if not text(unit)then return end
 local root=self:Root(unit);local bar=self:Remember(root);if not bar then return end
 if bar.unit then self.units[bar.unit]=nil end
 bar.auraCache=nil;bar.unit=unit;bar.enemy=call(UnitCanAttack,'player',unit)==true;self.units[unit]=bar
 if combat()then if not bar.prepared then self.pending=true end
 elseif self.initialized then self:Configure(bar)end
end
function P:Scan()
 for i=1,40 do local unit='nameplate'..i;if self:Root(unit)then self:Added(unit)end end
end
function P:Rebuild()
 if combat()then self.pending=true;return end
 self.pending=false;self.dirty=false;self.lastError=nil;self.rows={}
 self.units={}
 for _,bar in pairs(self.bars)do self:Detach(bar);bar.unit=nil end
 self.appliedEnabled=self.db.enabled
 if not self.appliedEnabled then return end
 local _,class=UnitClass('player');local candidates=self:Candidates(class)
 for _,row in ipairs(candidates)do
  if not self.characterDB.disabled[row.key] then self.rows[#self.rows+1]=row end
 end
 for i,row in ipairs(self.rows)do
  if not text(row.name)or row.name:find('[\r\n;%[%]]')then self.rows={};self:Error('Invalid spell name; no actions were armed.');return end
  local body='/cast [@mouseover,harm,nodead] '..row.name
  local name,err=self:EnsureCastMacro(i,body,row.icon)
  if not name then self.rows={};self:Error(err or 'Could not prepare character macros.');return end
  row.macro=name
 end
 self.reportedError=nil
 -- Configure only after every macro has been prepared and read back successfully.
 for i=1,40 do
  local unit='nameplate'..i;local root=self:Root(unit);local bar=self:Remember(root)
  if bar then bar.auraCache=nil;bar.unit=unit;bar.enemy=call(UnitCanAttack,'player',unit)==true;self.units[unit]=bar end
 end
 for _,bar in pairs(self.bars)do self:Configure(bar)end
end
function P:Paint(b,alpha,outOfRange,label,ready,glow)
 -- Only artwork changes during combat; secure visibility/actions stay fixed.
 b.icon:SetDesaturated(false)
 b.icon:SetVertexColor(1,outOfRange and .18 or 1,outOfRange and .18 or 1)
 b.icon:SetAlpha(alpha)
 if b.normal then b.normal:SetAlpha(alpha)end
 if b.highlight then b.highlight:SetAlpha(alpha)end
 b.count:SetText(label);b.count:SetAlpha(alpha>0 and math.max(alpha,.45)or 0)
 if b.stacks then b.stacks:SetText('');b.stacks:SetAlpha(alpha>0 and math.max(alpha,.45)or 0)end
 b.ready:SetText(ready and '+'or '');b.ready:SetAlpha(alpha)
 b.glow:SetAlpha(glow)
end
function P:ClearVisuals(bar)
 for _,b in ipairs(bar.buttons)do b.flashing=false;self:Paint(b,0,false,'',false,0)end
end
function P:Status()
 local prepared,waiting=0,0
 for _,bar in pairs(self.bars)do if bar.unit then if bar.prepared then prepared=prepared+1 else waiting=waiting+1 end end end
 local version,build,_,interface=GetBuildInfo();self:Say('Client '..tostring(version)..'.'..tostring(build)..' / '..tostring(interface))
 self:Say(self.version..' | '..(self.appliedEnabled and 'On'or 'Off')..' | '..#self.rows..' abilities | '..prepared..' prepared plates | '..waiting..' waiting')
 if self.pending or self.dirty then self:Say(combat()and 'Changes/new plates queued until combat ends.'or 'Refresh pending.')end
 if self.unavailableEvents and #self.unavailableEvents>0 then self:Say('Unavailable events: '..table.concat(self.unavailableEvents,', '))end
 if self.lastError then self:Say(self.lastError)end
 for _,row in ipairs(self.rows)do
  local state=self:EffectState(row,'target')
  self:Say(row.name..': target '..state.state..(state.remaining and (' '..math.ceil(state.remaining)..'s')or ''))
 end
 if self.lastClick then self:Say('Last click: '..self.lastClick.spell..'; mouseover '..(self.lastClick.matched and 'matched plate'or self.lastClick.readable and 'did not match plate'or 'identity unavailable')..'. This is not cast confirmation.')end
end
function P:Setting(name,value)
 self.db[name]=value;self.dirty=true
 if name=='size'and value>0 then self.db.customSize=value end
 if combat()then self.pending=true;self:Say('Saved. Buttons keep their current actions until combat ends.')else self:Rebuild()end
end
function P:Initialize()
 if self.initialized then return end
 DotCastDB=type(DotCastDB)=='table'and DotCastDB or {}
 DotCastCharacterDB=type(DotCastCharacterDB)=='table'and DotCastCharacterDB or {}
 self.db=DotCastDB;self.characterDB=DotCastCharacterDB
 if type(self.db.enabled)~='boolean'then self.db.enabled=true end
 for key,default in pairs({idleAlpha=.35,cooldownAlpha=.15,offsetX=0,offsetY=0})do
  local limit=(key=='idleAlpha'or key=='cooldownAlpha')and 1 or (key=='offsetX'and 100 or 80)
  local low=(key=='idleAlpha'or key=='cooldownAlpha')and 0 or -limit
  if not number(self.db[key])or self.db[key]<low or self.db[key]>limit then self.db[key]=default end
 end
 if type(self.db.castGlow)~='boolean'then self.db.castGlow=true end
 if not number(self.db.customSize)or self.db.customSize<16 or self.db.customSize>64 then self.db.customSize=32 end
 if not number(self.db.size)or self.db.size~=0 and (self.db.size<16 or self.db.size>64)then self.db.size=0 end
 self.characterDB.disabled=type(self.characterDB.disabled)=='table'and self.characterDB.disabled or {}
 self.characterDB.custom=type(self.characterDB.custom)=='table'and self.characterDB.custom or {}
 if not number(self.db.warnSeconds)or self.db.warnSeconds<1 or self.db.warnSeconds>10 then self.db.warnSeconds=3 end
 self.initialized=true;self.dirty=true
 self:TryMinimap()
 self:Say(self.version..' loaded. /dotcast status')
end
local f=CreateFrame('Frame');P.frame=f
f:SetScript('OnEvent',function(_,event,arg)
 if event=='PLAYER_REGEN_ENABLED'then P:ResetFailures()end
 P:Guard('event '..event,function()
 if event=='ADDON_LOADED'then if arg==addon then P:Initialize()end;return end
 if not P.initialized and (event=='PLAYER_LOGIN'or event=='PLAYER_ENTERING_WORLD')then P:Initialize()end
 if not P.initialized then return end
 if event=='NAME_PLATE_CREATED'then
  local bar=P:Remember(arg)
  if bar then if combat()then P.pending=true else P:Configure(bar)end end
 elseif event=='NAME_PLATE_UNIT_ADDED'then P:Added(arg)
 elseif event=='NAME_PLATE_UNIT_REMOVED'then
  local bar=text(arg)and P.units[arg];if bar then bar.auraCache=nil;bar.unit=nil;bar.enemy=nil;P.units[arg]=nil;P:ClearVisuals(bar);if not combat()then P:Detach(bar)end end
 elseif event=='UNIT_AURA'then
  if text(arg)then local bar=P.units[arg];if bar then bar.auraCache=nil else for _,other in pairs(P.bars)do other.auraCache=nil end end end
 elseif event=='PLAYER_TARGET_CHANGED'then
  for _,bar in pairs(P.bars)do bar.auraCache=nil end
 elseif event=='PLAYER_REGEN_ENABLED'then
  if P.dirty then P:Rebuild()else P:Scan();for _,bar in pairs(P.bars)do P:Configure(bar)end;P.pending=false end
 elseif event=='PLAYER_LOGIN'or event=='PLAYER_ENTERING_WORLD'then P.dirty=true;P:TryMinimap()
 elseif event=='SPELLS_CHANGED'or event=='UNIT_PET'and arg=='player'then P.dirty=true;if combat()then P.pending=true end
 end
 end)
end)
local elapsed=0
f:SetScript('OnUpdate',function(_,dt)
 if not P.initialized then return end
 elapsed=elapsed+dt;if elapsed<.15 then return end;elapsed=0
 P:Guard('update',function()
 if not combat()then
  local cc=_G.CounterCast;local sig=cc and cc.db and type(cc.rows)=='table'and tostring(cc.appliedEnabled)..':'..tostring(#cc.rows)..':'..tostring(cc.db.size)..':'..tostring(cc.db.offsetX)..':'..tostring(cc.db.offsetY)or ''
  if P.counterCastLayout~=sig then P.counterCastLayout=sig;P.dirty=true end
 end
 if P.dirty and not combat()then P:Rebuild()end
 P:Update()
 end)
end)
SLASH_DOTCAST1='/dotcast';SLASH_DOTCAST2='/dcast'
SlashCmdList.DOTCAST=function(message)
 if not P.initialized then return end
 local command,arg=(message or ''):lower():match('^%s*(%S*)%s*(.-)%s*$')
 if command==''or command=='options'then P:OpenOptions()
 elseif command=='on'or command=='off'then P:Setting('enabled',command=='on')
 elseif command=='abilities'then P:OpenSpells()
 elseif command=='add'then P:AddCustom(arg)
 elseif command=='remove'then P:RemoveCustom(arg)
 elseif command=='size'then
  local n=arg=='auto'and 0 or tonumber(arg)
  if n==0 or number(n)and n>=16 and n<=64 then P:Setting('size',n)else P:Say('Use /dotcast size auto or a size from 16 to 64.')end
 elseif command=='spells'then
  for _,row in ipairs(P.rows)do P:Say(row.name..' | '..row.kind..(row.pet and ' | requires pet'or ''))end
 elseif command=='errors'then P:ReportErrors()
 elseif command=='refresh'then P:ResetFailures();P.dirty=true;if combat()then P.pending=true;P:Say('Refresh queued until combat ends.')else P:Rebuild()end
 elseif command=='status'then
  P:Status();if command==''then P:Say('/dotcast options | on | off | size auto/16-64 | abilities | add SPELLID [AURAID] | remove SPELLID | spells | refresh | status')end
 else P:Say('/dotcast options | on | off | size auto/16-64 | abilities | add SPELLID [AURAID] | remove SPELLID | spells | refresh | status')end
end

-- Install handlers and slash commands before registering client-version-dependent
-- events. A rejected event must never abort the remainder of addon startup.
-- SPELLS_CHANGED covers learned spells; LEARNED_SPELL_IN_TAB is obsolete here.
P.unavailableEvents={}
for _,event in ipairs({'ADDON_LOADED','PLAYER_LOGIN','PLAYER_ENTERING_WORLD','PLAYER_REGEN_ENABLED','NAME_PLATE_CREATED','NAME_PLATE_UNIT_ADDED','NAME_PLATE_UNIT_REMOVED','SPELLS_CHANGED','UNIT_PET','UNIT_AURA','PLAYER_TARGET_CHANGED'})do
 local ok=pcall(f.RegisterEvent,f,event)
 if not ok then P.unavailableEvents[#P.unavailableEvents+1]=event end
end
