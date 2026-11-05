
frames={};messages={};combat=false;uptime=10;known={[72]=true,[6552]=true};petKnown={};cooldowns={};class='WARRIOR';rejectAnchor=false
local methods={}
local function restricted(f)if combat and f.secure then error('Protected mutation in combat')end end
function methods:SetScript(k,v)self.scripts[k]=v end
function methods:GetScript(k)return self.scripts[k]end
function methods:HookScript(k,v)local old=self.scripts[k];self.scripts[k]=function(...)if old then old(...)end;v(...)end end
function methods:RegisterEvent(e)self.events[e]=true end
function methods:SetParent(p)restricted(self);if rejectAnchor and p==plate then error('Native anchor rejected')end;self.parent=p end
function methods:SetPoint(...)restricted(self);self.points[#self.points+1]={...}end
function methods:ClearAllPoints()restricted(self);self.points={}end
function methods:SetAttribute(k,v)restricted(self);self.attributes[k]=v end
function methods:GetAttribute(k)return self.attributes[k]end
function methods:Show()restricted(self);self.shown=true end
function methods:Hide()restricted(self);self.shown=false end
function methods:SetSize(w,h)restricted(self);self.width=w;self.height=h end
function methods:GetName()return self.name end
function methods:IsProtected()return self.secure==true end
function methods:IsForbidden()return self.forbidden==true end
function methods:SetTexture(v)self.texture=v end
function methods:SetText(v)self.text=v end
function methods:SetDesaturated(v)self.desaturated=v end
function methods:CreateTexture()return CreateFrame('Texture',nil,self)end
function methods:CreateFontString()return CreateFrame('Font',nil,self)end
function methods:RegisterForClicks(...)self.clickTypes={...}end
function methods:SetPropagateMouseMotion(v)restricted(self);self.propagateMotion=v end
function methods:SetMouseMotionEnabled(v)restricted(self);self.motionEnabled=v end
function methods:SetPropagateMouseClicks(v)restricted(self);self.propagateClicks=v end
function methods:SetMouseClickEnabled(v)restricted(self);self.clickEnabled=v end
function methods:GetHitRectInsets()return unpack(self.insets or {0,0,0,0})end
function methods:SetHitRectInsets()error('Ordinary insets are not native nameplate hit-test points')end
function methods:CanChangeHitTestPoints()return not combat end
function methods:GetHitTestPoints()return self.hitPoints or {}end
function methods:SetHitTestPoints(points)
 if combat then error('Native hit-test mutation in combat')end
 self.hitPoints={};for i,p in ipairs(points)do self.hitPoints[i]={};for k,v in pairs(p)do self.hitPoints[i][k]=v end end
end
function methods:ClearAllHitTestPoints()if combat then error('Native hit-test mutation in combat')end;self.hitPoints={}end
for _,k in ipairs({'SetFrameStrata','SetAllPoints','SetNormalTexture','SetHighlightTexture','SetOwner','AddLine'})do methods[k]=function()end end
-- Sentinel only: offline Lua cannot recreate the native secure execution context.
function SecureActionButton_OnClick()error('The probe must never call the native handler itself')end
function CreateFrame(kind,name,parent,template)
 if combat and template=='SecureActionButtonTemplate'then error('Secure creation in combat')end
 local f=setmetatable({name=name,kind=kind,parent=parent,template=template,secure=template=='SecureActionButtonTemplate',attributes={},scripts={OnClick=template=='SecureActionButtonTemplate'and SecureActionButton_OnClick or nil},events={},points={},shown=true},{__index=methods})
 frames[#frames+1]=f;return f
end
UIParent=CreateFrame('Frame','UIParent');plate=CreateFrame('Frame','NamePlate1',UIParent);health=CreateFrame('Frame','Health',plate);plate.UnitFrame={healthBar=health}
GameTooltip=CreateFrame('Tooltip');SlashCmdList={}
function InCombatLockdown()return combat end
function GetTime()return uptime end
function time()return 10000+uptime end
function UnitClass()return 'Warrior',class end
function UnitIsUnit(u,t)return u=='nameplate1'and t=='target'end
function UnitCanAttack()return true end
function UnitExists()return true end
function SpellIsTargeting()return false end
C_NamePlate={GetNamePlateForUnit=function(u)if u=='nameplate1'then return plate end end}
function IsSpellKnown(id,pet)return (pet and petKnown[id]or not pet and known[id])==true end
C_Spell={GetSpellInfo=function(id)return {name='Spell '..id,iconID=id}end,GetSpellCooldown=function(id)return cooldowns[id]or {startTime=0,duration=0,isEnabled=true}end}
function issecretvalue(v)return type(v)=='table'and v.secret==true end
DEFAULT_CHAT_FRAME={AddMessage=function(_,s)messages[#messages+1]=s end}

MAX_ACCOUNT_MACROS=120;MAX_CHARACTER_MACROS=18;macros={};macroCreates=0;macroEdits=0
function GetMacroInfo(index)
 if type(index)=='string'then for i,r in pairs(macros)do if r.name==index then index=i;break end end end
 local m=macros[index];if m then return m.name,m.icon,m.body end
end
function GetNumMacros()local a,c=0,0;for i in pairs(macros)do if i<=120 then a=a+1 else c=c+1 end end;return a,c end
function CreateMacro(name,icon,body,perCharacter)
 assert(not combat and perCharacter==true);macroCreates=macroCreates+1
 for i=121,138 do if not macros[i]then macros[i]={name=name,icon=icon,body=body};return i end end
 error('No macro slots')
end
function EditMacro(i,name,icon,body)assert(not combat);macroEdits=macroEdits+1;macros[i]={name=name,icon=icon,body=body};return i end
function RunMacro()error('Addon must not call protected macro runner')end
function CastSpellByID()error('No direct casting from addon code')end
function CastSpellByName()error('No direct casting from addon code')end
