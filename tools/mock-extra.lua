
local methods=getmetatable(plate).__index
function methods:GetFrameLevel()return self.level or 1 end
function methods:SetFrameLevel(v)self.level=v end
Minimap=CreateFrame('Frame','Minimap',UIParent);Minimap.width=140;Minimap.height=140
cursorX=500;cursorY=200
function GetCursorPosition()return cursorX,cursorY end

function methods:SetHeight(v)self.height=v end
function methods:SetScale(v)self.scale=v end
function methods:SetColorTexture(...)self.color={...}end
function methods:SetOrientation(v)self.orientation=v end
function methods:SetMinMaxValues(a,b)self.min=a;self.max=b end
function methods:SetValueStep(v)self.step=v end
function methods:SetObeyStepOnDrag(v)self.obey=v end
function methods:SetThumbTexture(v)self.thumb=self:CreateTexture();self.thumb:SetTexture(v)end
function methods:GetThumbTexture()return self.thumb end
function methods:SetValue(v)self.value=v;if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,v)end end
function methods:GetValue()return self.value end
function methods:SetChecked(v)self.checked=v end
function methods:GetChecked()return self.checked end
for _,k in ipairs({'EnableMouse','SetMovable','SetClampedToScreen','RegisterForDrag','StartMoving','StopMovingOrSizing'})do methods[k]=function()end end

function methods:SetAlpha(v)assert(not self.secure,'Only artwork may fade');self.alpha=v end
function methods:SetVertexColor(r,g,b)self.tint={r,g,b}end
function methods:SetNormalTexture(v)self.normal=self.normal or self:CreateTexture();self.normal:SetTexture(v)end
function methods:GetNormalTexture()return self.normal end
function methods:SetHighlightTexture(v)self.highlight=self.highlight or self:CreateTexture();self.highlight:SetTexture(v)end
function methods:GetHighlightTexture()return self.highlight end
function methods:SetBlendMode(v)self.blend=v end
function methods:GetCenter()return self.cx or 400,self.cy or 200 end
function methods:GetRight()return self.right or 500 end
function methods:GetEffectiveScale()return self.scale or 1 end
function methods:GetHeight()return self.height or 32 end
function methods:GetWidth()return self.width or 200 end
plates={nameplate1=plate};casts={};hover='nameplate1'
C_NamePlate.GetNamePlateForUnit=function(u)return plates[u]end
function UnitIsUnit(a,b)return a=='mouseover'and b==hover end
function UnitCastingInfo(u)return casts[u]end
function UnitChannelInfo()end
function addplate(u)
 local root=CreateFrame('Frame',u,UIParent);local hb=CreateFrame('Frame',nil,root)
 root.UnitFrame={healthBar=hb};plates[u]=root;return root
end
function event(e,arg)if P.frame.events[e]then P.frame.scripts.OnEvent(nil,e,arg)end end
function tick()P.frame.scripts.OnUpdate(nil,.2)end
function bar()return P.bars[plate]end
