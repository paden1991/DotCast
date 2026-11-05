local _,P=...
local function number(v)
 return P:IsPlain(v)and type(v)=='number'and v==v and math.abs(v)~=math.huge
end
function P:PositionMinimap()
 local b=self.minimapButton;if not b or not Minimap then return end
 local angle=self.db.minimapAngle
 if not number(angle)then angle=195 end
 self.db.minimapAngle=angle%360
 local radians=math.rad(self.db.minimapAngle);local x,y=math.cos(radians),math.sin(radians)
 if type(GetMinimapShape)=='function'then
  local ok,shape=pcall(GetMinimapShape)
  if ok and self:IsPlain(shape)and shape=='SQUARE'then
   local edge=math.max(math.abs(x),math.abs(y));x=x/edge;y=y/edge
  end
 end
 b:ClearAllPoints()
 b:SetPoint('CENTER',Minimap,'CENTER',(Minimap:GetWidth()/2+8)*x,(Minimap:GetHeight()/2+8)*y)
end
function P:DragMinimap()
 local cx,cy=Minimap:GetCenter();local x,y=GetCursorPosition();local scale=Minimap:GetEffectiveScale()
 if not(number(cx)and number(cy)and number(x)and number(y)and number(scale))or scale<=0 then return end
 x=x/scale-cx;y=y/scale-cy;if x==0 and y==0 then return end
 local angle
 if x==0 then angle=y>0 and math.pi/2 or -math.pi/2
 else angle=math.atan(y/x);if x<0 then angle=angle+math.pi end end
 self.db.minimapAngle=math.deg(angle)%360;self:PositionMinimap()
end
function P:CreateMinimap()
 if self.minimapButton then self:PositionMinimap();return end
 if not Minimap then return end
 local b=CreateFrame('Button','DotCastMinimapButton',Minimap);b:Hide()
 b:SetSize(32,32);b:SetFrameStrata('MEDIUM');b:SetFrameLevel(Minimap:GetFrameLevel()+8)
 b:RegisterForClicks('LeftButtonUp');b:RegisterForDrag('LeftButton')
 local icon=b:CreateTexture(nil,'ARTWORK');b.icon=icon
 icon:SetSize(20,20);icon:SetPoint('CENTER',b,'CENTER',0,0);icon:SetTexture('Interface\\Icons\\Spell_Shadow_AbominationExplosion')
 local border=b:CreateTexture(nil,'OVERLAY');border:SetTexture('Interface\\Minimap\\MiniMap-TrackingBorder')
 border:SetSize(54,54);border:SetPoint('TOPLEFT',b,'TOPLEFT',0,0)
 b:SetHighlightTexture('Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight')
 b:SetScript('OnMouseDown',function(self)self.dragged=false end)
 b:SetScript('OnClick',function(self,button)
  if self.dragged then self.dragged=false;return end
  if button=='LeftButton'then P:OpenOptions()end
 end)
 b:SetScript('OnDragStart',function(self)
  self.dragged=true;self.hovered=false;if GameTooltip then GameTooltip:Hide()end
  self:SetScript('OnUpdate',function()P:DragMinimap()end)
 end)
 b:SetScript('OnDragStop',function(self)P:DragMinimap();self:SetScript('OnUpdate',nil)end)
 b:SetScript('OnHide',function(self)
  self:SetScript('OnUpdate',nil)
  if self.hovered and GameTooltip then GameTooltip:Hide()end;self.hovered=false
 end)
 b:SetScript('OnEnter',function(self)
  self.hovered=true;if not GameTooltip then return end
  GameTooltip:SetOwner(self,'ANCHOR_LEFT');GameTooltip:SetText('DotCast')
  GameTooltip:AddLine('Left-click: open options',1,.85,.55)
  GameTooltip:AddLine('Drag: move around the minimap',1,.85,.55);GameTooltip:Show()
 end)
 b:SetScript('OnLeave',function(self)self.hovered=false;if GameTooltip then GameTooltip:Hide()end end)
 self.minimapButton=b
 Minimap:HookScript('OnSizeChanged',function()P:PositionMinimap()end)
 self:PositionMinimap();b:Show()
end
function P:TryMinimap()
 -- Launcher failures must not interrupt secure button startup or slash options.
 local ok=pcall(self.CreateMinimap,self)
 if not ok then self:Say('Minimap button unavailable; use /dotcast to open options.')end
end
