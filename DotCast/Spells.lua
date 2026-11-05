local _,P=...
local function label(parent,title,x,y,font)
 local t=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontHighlightSmall');t:SetPoint('TOPLEFT',parent,'TOPLEFT',x,-y);t:SetText(title);return t
end
function P:AddCustom(arg)
 local cast,aura=(arg or ''):match('^%s*(%d+)%s*(%d*)%s*$');cast=tonumber(cast);aura=tonumber(aura)
 if not cast or not self:Known(cast)or not self:Spell(cast)then self:Say('Use /dotcast add SPELLID [AURAID] with a learned targeted spell.');return end
 if aura and not self:Spell(aura)then self:Say('Aura ID was not found.');return end
 local list=self.characterDB.custom
 for _,row in ipairs(list)do if row.id==cast then row.auraIDs={aura or cast};self.dirty=true;self:Say('Custom effect updated.');return end end
 if #list>=8 then self:Say('Maximum 8 custom spells per character. Remove one first.');return end
 list[#list+1]={id=cast,auraIDs={aura or cast}};self.dirty=true
 self:Say('Added '..self:Spell(cast)..'. Use /dotcast abilities to choose visible spells.')
end
function P:RemoveCustom(arg)
 local id=tonumber(arg)
 for i,row in ipairs(self.characterDB.custom)do if row.id==id then table.remove(self.characterDB.custom,i);self.dirty=true;self:Say('Removed custom spell.');return end end
 self:Say('Use /dotcast remove SPELLID for a custom spell.')
end
function P:RefreshSpells()
 local f=self.spellsPanel;if not f then return end
 local _,class=UnitClass('player');local rows=self:Candidates(class)
 for _,b in ipairs(f.buttons)do b:Hide()end
 for i,row in ipairs(rows)do
  local b=f.buttons[i]
  if not b then
   b=CreateFrame('CheckButton',nil,f,'UICheckButtonTemplate');b:SetSize(26,26)
   b.title=label(b,'',32,6,'GameFontHighlight');b:SetScript('OnClick',function(self)
    P.characterDB.disabled[self.key]=not self:GetChecked();P.dirty=true
    if InCombatLockdown()then P.pending=true end
   end);f.buttons[i]=b
  end
  b:SetPoint('TOPLEFT',f,'TOPLEFT',24,-(100+(i-1)*29));b.key=row.key
  b.title:SetText(row.name..'  |  '..row.kind);b:SetChecked(not self.characterDB.disabled[row.key]);b:Show()
 end
 f.empty:SetText(#rows==0 and 'No supported learned targeted DoTs found for this character.\nPassive procs and ground effects are not clickable DoT spells.'or '')
 f.warning:SetText('Expiring warning: '..self.db.warnSeconds..' seconds')
end
function P:OpenSpells()
 if self.spellsPanel then self:RefreshSpells();self.spellsPanel:Show();return end
 local f=CreateFrame('Frame','DotCastSpells',UIParent);self.spellsPanel=f;f.buttons={}
 f:SetSize(620,690);f:SetPoint('CENTER',UIParent,'CENTER');f:SetFrameStrata('FULLSCREEN_DIALOG')
 f:SetScale(math.min(1,(UIParent:GetWidth()-24)/620,(UIParent:GetHeight()-24)/690))
 local bg=f:CreateTexture(nil,'BACKGROUND');bg:SetAllPoints();bg:SetColorTexture(.055,.075,.10,.99)
 f:EnableMouse(true);f:SetMovable(true);f:SetClampedToScreen(true);f:RegisterForDrag('LeftButton')
 f:SetScript('OnDragStart',function(self)self:StartMoving()end);f:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
 local close=CreateFrame('Button',nil,f,'UIPanelCloseButton');close:SetPoint('TOPRIGHT',f,'TOPRIGHT',-5,-5);close:SetScript('OnClick',function()f:Hide()end)
 UISpecialFrames=UISpecialFrames or {};table.insert(UISpecialFrames,'DotCastSpells')
 label(f,'DotCast | Spells',28,26,'GameFontNormalLarge')
 label(f,'Choose this character\'s buttons. Changes apply outside combat.',28,59)
 label(f,'Only your own effects count. Form, stealth and combo points still apply.',28,78)
 f.empty=label(f,'',28,120,'GameFontHighlight')
 f.warning=label(f,'',28,514,'GameFontNormal')
 for i,delta in ipairs({-1,1})do
  local b=CreateFrame('Button',nil,f,'UIPanelButtonTemplate');b:SetSize(36,24);b:SetPoint('TOPLEFT',f,'TOPLEFT',320+(i-1)*44,-506);b:SetText(delta<0 and '-'or '+')
  b:SetScript('OnClick',function()P.db.warnSeconds=math.max(1,math.min(10,P.db.warnSeconds+delta));P:RefreshSpells();P:Update()end)
 end
 label(f,'Missing: +   Active: seconds   Expiring: amber   Unavailable: ? / *',28,554)
 label(f,'Custom learned spell: /dotcast add SPELLID [AURAID]',28,583)
 label(f,'Remove a custom spell: /dotcast remove SPELLID',28,604)
 label(f,'Warning is a reminder, not an optimal-refresh or resource recommendation.',28,633)
 self:RefreshSpells();f:Show()
end
