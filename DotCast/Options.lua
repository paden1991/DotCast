local _,P=...
local function combat()return InCombatLockdown and InCombatLockdown()end
local defaults={size=0,customSize=32,offsetX=0,offsetY=0,idleAlpha=.35,cooldownAlpha=.15,castGlow=true}
local limits={size={16,64},offsetX={-100,100},offsetY={-80,80},idleAlpha={0,1},cooldownAlpha={0,1}}
function P:SetAppearance(key,value)
 if not self.initialized then return end
 if key=='castGlow'then
  if type(value)~='boolean'then return end
 else
  local range=limits[key]
  if not range or not self:IsPlain(value)or type(value)~='number'or value~=value then return end
  if not(key=='size'and value==0)and (value<range[1]or value>range[2])then return end
 end
 if self.db[key]==value then return end
 self.db[key]=value
 if key=='size'and value>0 then self.db.customSize=value end
 if key=='size'or key=='offsetX'or key=='offsetY'then
  -- Coalesce slider movement; never touch protected layout while in combat.
  self.dirty=true;if combat()then self.pending=true end
 else self:Update()end
 if self.options then self:RefreshOptions()end
end
function P:ResetAppearance()
 for key,value in pairs(defaults)do self.db[key]=value end
 self.dirty=true;if combat()then self.pending=true end
 self:Update();self:RefreshOptions()
end
local function label(parent,value,x,y,font)
 local t=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontNormal')
 t:SetPoint('TOPLEFT',parent,'TOPLEFT',x,-y);t:SetText(value);return t
end
local function checkbox(parent,title,x,y,changed)
 local b=CreateFrame('CheckButton',nil,parent,'UICheckButtonTemplate')
 b:SetPoint('TOPLEFT',parent,'TOPLEFT',x,-y);b:SetSize(26,26)
 label(parent,title,x+31,y+6,'GameFontHighlight')
 b:SetScript('OnClick',function(self)if not parent.refreshing then changed(self:GetChecked()==true)end end)
 return b
end
local function slider(parent,title,key,y,low,high,percent)
 local s=CreateFrame('Slider',nil,parent)
 s:SetPoint('TOPLEFT',parent,'TOPLEFT',30,-(y+23));s:SetSize(540,18)
 s:SetOrientation('HORIZONTAL');s:SetMinMaxValues(low,high);s:SetValueStep(1)
 if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true)end
 local track=s:CreateTexture(nil,'BACKGROUND');track:SetColorTexture(.2,.25,.3,1)
 track:SetPoint('LEFT',s,'LEFT',0,0);track:SetPoint('RIGHT',s,'RIGHT',0,0);track:SetHeight(4)
 s:SetThumbTexture('Interface\\Buttons\\UI-SliderBar-Button-Horizontal')
 local thumb=s:GetThumbTexture();thumb:SetSize(28,28)
 label(parent,title,30,y)
 s.valueLabel=label(parent,'',475,y,'GameFontHighlight')
 s:SetScript('OnValueChanged',function(_,v)
  if parent.refreshing then return end
  local rounded=math.floor(v+.5)
  P:SetAppearance(key,percent and rounded/100 or rounded)
 end)
 return s
end
function P:RefreshOptions()
 local f=self.options;if not f or not self.db then return end
 f.refreshing=true
 f.auto:SetChecked(self.db.size==0);f.glow:SetChecked(self.db.castGlow)
 local custom=self.db.size>0 and self.db.size or self.db.customSize
 f.size:SetValue(custom);f.size.valueLabel:SetText(self.db.size==0 and 'Auto' or custom..' px')
 for _,key in ipairs({'offsetX','offsetY'})do
  f[key]:SetValue(self.db[key]);f[key].valueLabel:SetText(string.format('%+d px',self.db[key]))
 end
 for _,key in ipairs({'idleAlpha','cooldownAlpha'})do
  local percent=math.floor(self.db[key]*100+.5)
  f[key]:SetValue(percent);f[key].valueLabel:SetText(percent..'% opacity')
 end
 local size=self.db.size>0 and self.db.size or 32
 local row=self.rows[1];local icon=row and row.icon or 'Interface\\Icons\\Spell_Shadow_AbominationExplosion'
 for i,b in ipairs(f.previews)do
  b:SetSize(size,size);b.icon:SetTexture(icon);b.glow:SetSize(size*1.7,size*1.7)
  local alpha=i==1 and 1 or self:EffectAlpha({state='active',remaining=i==2 and 12 or 1.5},false,GetTime())
  self:Paint(b,alpha,false,i==2 and '12'or i==3 and '2'or '',i~=2,i~=2 and self.db.castGlow and alpha or 0)
  if i==3 then b.icon:SetVertexColor(1,.75,.3)end
 end
 f.notice:SetText(combat()and 'Opacity and glow apply now. Size and position apply after combat.'or 'Saved account-wide. Size and position apply on the next update.')
 f.refreshing=false
end
function P:OpenOptions()
 if not self.initialized then return end
 if self.options then self:RefreshOptions();self.options:Show();return end
 local f=CreateFrame('Frame','DotCastOptions',UIParent)
 self.options=f;f:SetSize(600,670);f:SetPoint('CENTER',UIParent,'CENTER');f:SetFrameStrata('DIALOG')
 local sw,sh=UIParent:GetWidth(),UIParent:GetHeight()
 if sw and sh and sw>0 and sh>0 then f:SetScale(math.min(1,(sw-24)/600,(sh-24)/670))end
 local bg=f:CreateTexture(nil,'BACKGROUND');bg:SetAllPoints();bg:SetColorTexture(.055,.075,.10,.98)
 f:EnableMouse(true);f:SetMovable(true);f:SetClampedToScreen(true);f:RegisterForDrag('LeftButton')
 f:SetScript('OnDragStart',function(self)self:StartMoving()end)
 f:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
 f:SetScript('OnHide',function(self)self:StopMovingOrSizing()end)
 local close=CreateFrame('Button',nil,f,'UIPanelCloseButton');close:SetPoint('TOPRIGHT',f,'TOPRIGHT',-5,-5)
 close:SetScript('OnClick',function()f:Hide()end);f.close=close
 UISpecialFrames=UISpecialFrames or {};table.insert(UISpecialFrames,'DotCastOptions')
 label(f,'DotCast | Appearance',30,25,'GameFontNormalLarge')
 label(f,'Your effects on each enemy. Click an icon to apply its spell.',30,55,'GameFontHighlightSmall')
 f.auto=checkbox(f,'Match health-bar thickness',26,82,function(checked)P:SetAppearance('size',checked and 0 or P.db.customSize)end)
 f.glow=checkbox(f,'Glow for missing / expiring DoTs',310,82,function(checked)P:SetAppearance('castGlow',checked)end)
 f.size=slider(f,'Button size (drag to use a custom size)','size',122,16,64)
 f.offsetX=slider(f,'Horizontal offset: left (-) / right (+)','offsetX',184,-100,100)
 f.offsetY=slider(f,'Vertical offset: down (-) / up (+)','offsetY',246,-80,80)
 f.idleAlpha=slider(f,'Opacity while your DoT is active','idleAlpha',308,0,100,true)
 f.cooldownAlpha=slider(f,'Opacity while the ability is on cooldown','cooldownAlpha',370,0,100,true)
 label(f,'0% = invisible   |   100% = solid   |   Cooldown: the fainter setting wins.',30,422,'GameFontHighlightSmall')
 label(f,'Preview: active fades; under 2 seconds flashes (auto: 32 px)',30,452,'GameFontNormalSmall')
 f.previews={}
 for i,title in ipairs({'Missing / apply','Active / faded','Under 2s / flashing'})do
  local x=30+(i-1)*185
  local bgbar=f:CreateTexture(nil,'BACKGROUND');bgbar:SetColorTexture(.55,.10,.13,1)
  bgbar:SetPoint('TOPLEFT',f,'TOPLEFT',x,-488);bgbar:SetSize(160,32)
  local b=CreateFrame('Frame',nil,f);b:SetPoint('RIGHT',bgbar,'RIGHT',-2,0)
  b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetAllPoints()
  b.glow=b:CreateTexture(nil,'OVERLAY');b.glow:SetTexture('Interface\\Buttons\\UI-ActionButton-Border');b.glow:SetBlendMode('ADD');b.glow:SetPoint('CENTER',b,'CENTER')
  b.count=b:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');b.count:SetPoint('CENTER',b,'CENTER')
  b.ready=b:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');b.ready:SetPoint('BOTTOM',b,'TOP',0,1)
  f.previews[i]=b;label(f,title,x,542,'GameFontHighlightSmall')
 end
 f.notice=label(f,'',30,572,'GameFontHighlightSmall')
 label(f,'Large offsets may leave the nameplate mouseover area.',30,592,'GameFontHighlightSmall')
 label(f,'At 0%, the click area remains active during combat.',30,608,'GameFontHighlightSmall')
 local reset=CreateFrame('Button',nil,f,'UIPanelButtonTemplate');reset:SetSize(160,24);reset:SetPoint('BOTTOMLEFT',f,'BOTTOMLEFT',30,16);reset:SetText('Reset appearance')
 reset:SetScript('OnClick',function()P:ResetAppearance()end);f.reset=reset
 local spells=CreateFrame('Button',nil,f,'UIPanelButtonTemplate');spells:SetSize(150,24);spells:SetPoint('BOTTOM',f,'BOTTOM',0,16);spells:SetText('Spells / warning');spells:SetScript('OnClick',function()P:OpenSpells()end)
 local done=CreateFrame('Button',nil,f,'UIPanelButtonTemplate');done:SetSize(100,24);done:SetPoint('BOTTOMRIGHT',f,'BOTTOMRIGHT',-30,16);done:SetText('Done');done:SetScript('OnClick',function()f:Hide()end)
 f:SetScript('OnShow',function()P:RefreshOptions()end)
 local elapsed=0;f:SetScript('OnUpdate',function(_,dt)elapsed=elapsed+dt;if elapsed>.1 then elapsed=0;P:RefreshOptions()end end)
 self:RefreshOptions();f:Show()
end
