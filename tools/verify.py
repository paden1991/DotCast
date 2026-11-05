from pathlib import Path
import sys,json,traceback
ROOT=Path(__file__).resolve().parents[1]
from lupa.lua51 import LuaRuntime
FIXTURE='''
class='WARLOCK';known={[172]=true,[980]=true,[348]=true};auras={};auraCalls=0
function GetBuildInfo()return '1.60.1','70755','Nov 3 2026',16001 end
function UnitIsDeadOrGhost()return false end
function issecretvalue(v)return type(v)=='table'and rawget(v,'secret')==true end
function canaccesstable(v)return not rawget(v,'blocked')end
function sealed()return setmetatable({blocked=true},{__index=function()error('restricted table indexed')end})end
function debugstack()return 'DotCast test callback stack'end
C_Spell.IsSpellUsable=function()return true,false end
function UnitIsUnit(a,b)return a==b or a=='mouseover'and b==hover end
C_UnitAuras={GetAuraDataByIndex=function(unit,index,filter)
 assert(filter=='HARMFUL|PLAYER');auraCalls=auraCalls+1
 return (auras[unit]or {})[index]
end}
function dot(id,left,source)
 return {spellId=id,name='Spell '..id,sourceUnit=source or 'player',expirationTime=uptime+left,duration=18,applications=1}
end
'''
def runtime(pre=''):
    l=LuaRuntime(unpack_returned_tuples=True)
    l.execute((ROOT/'tools/mock.lua').read_text()+(ROOT/'tools/mock-extra.lua').read_text()+FIXTURE+pre)
    p=l.table();loader=l.eval('function(s,p)assert(loadstring(s))("DotCast",p)end')
    for f in (ROOT/'DotCast/DotCast.toc').read_text().splitlines():
        if f.endswith('.lua'):loader((ROOT/'DotCast'/f).read_text(),p)
    l.globals().P=p;l.execute("event('ADDON_LOADED','DotCast');tick()")
    return l,p
results=[]
def test(name,code,pre='',allow_errors=False):
    try:
        l,p=runtime(pre);l.execute(code)
        if not allow_errors:l.execute("assert(P.lastDiagnostic==nil,'Unexpected captured callback failure')")
        results.append({'name':name,'passed':True})
    except Exception as e:
        results.append({'name':name,'passed':False,'error':str(e)});print('FAIL',name,str(e))

test('Startup and independent namespace',"assert(P==DotCast and CounterCast==nil and P.initialized and #P.rows==3)")
test('Known ranks only',"assert(#P.rows==1 and P.rows[1].id==11672)","known={[172]=true,[11672]=true}")
for cls,ids,count in [('WARRIOR','772',1),('ROGUE','703,1943',2),('DRUID','8921,5570,1822,1079',4),('MAGE','133,11366',2),('SHAMAN','8050',1),('HUNTER','1978',1),('PRIEST','589,2944,14914',3),('PALADIN','',0)]:
    test(f'{cls} learned selection',f'assert(#P.rows=={count})',f"class='{cls}';known={{"+','.join(f'[{i}]=true'for i in ids.split(',')if i)+'}')
test('All Warlock families',"assert(#P.rows==5)","known={[172]=true,[980]=true,[348]=true,[18265]=true,[603]=true}")
test('Secure mouseover action no target change',"for _,row in ipairs(P.rows)do local _,_,body=GetMacroInfo(row.macro);assert(body=='/cast [@mouseover,harm,nodead] '..row.name)end;assert(bar().buttons[1].attributes.type=='macro' and bar().buttons[1].scripts.OnClick==SecureActionButton_OnClick)")
test('Reuse owned unchanged macros',"local n=macroCreates;P:Rebuild();assert(macroCreates==n)")
test('Protect user edited macro',"macros[121].body='/say preserved';P:Rebuild();assert(macros[121].body=='/say preserved' and macroCreates==4)")
test('Full macro slots fail safely',"assert(#P.rows==0 and P.lastError:find('full'))", "for i=121,138 do macros[i]={name='User '..i,body='/say user'}end")
test('Empty aura enumeration means missing',"assert(bar().buttons[1].effectState=='missing' and bar().buttons[1].ready.text=='+')")
test('Own DoT timer',"auras.nameplate1={dot(172,12)};event('UNIT_AURA','nameplate1');tick();local b=bar().buttons[1];assert(b.effectState=='active' and b.count.text=='12' and b.icon.alpha==.35)")
test('Other player DoT does not satisfy',"auras.nameplate1={dot(172,12,'party1')};event('UNIT_AURA','nameplate1');tick();assert(bar().buttons[1].effectState=='missing')")
test('Pet ownership not treated as player',"auras.nameplate1={dot(172,12,'pet')};event('UNIT_AURA','nameplate1');tick();assert(bar().buttons[1].effectState=='missing')")
test('Unknown ownership stays unknown',"local a=dot(172,12);a.sourceUnit={secret=true};auras.nameplate1={a};event('UNIT_AURA','nameplate1');tick();assert(bar().buttons[1].effectState=='unknown')")
test('Nil ownership stays unknown',"local a=dot(172,12);a.sourceUnit=nil;auras.nameplate1={a};event('UNIT_AURA','nameplate1');tick();assert(bar().buttons[1].effectState=='unknown')")
test('Expiring warning remains faded at exactly two seconds',"auras.nameplate1={dot(172,2)};event('UNIT_AURA','nameplate1');tick();local b=bar().buttons[1];assert(b.effectState=='expiring' and b.count.text=='2' and b.glow.alpha==.35 and b.icon.tint[2]==.75 and b.flashing==false)")
test('Expiration never invents a recast',"auras.nameplate1={dot(172,0)};event('UNIT_AURA','nameplate1');tick();assert(bar().buttons[1].effectState=='unknown')")
test('Removed aura becomes missing',"auras.nameplate1={dot(172,12)};event('UNIT_AURA','nameplate1');tick();auras.nameplate1={};event('UNIT_AURA','nameplate1');tick();assert(bar().buttons[1].effectState=='missing')")
test('Secret timer retains known presence',"local a=dot(172,12);a.expirationTime={secret=true};auras.nameplate1={a};event('UNIT_AURA','nameplate1');tick();assert(bar().buttons[1].effectState=='active' and bar().buttons[1].count.text=='*')")
test('Secret aura data stays unknown',"C_UnitAuras.GetAuraDataByIndex=function()return {secret=true}end;event('UNIT_AURA','nameplate1');tick();assert(bar().buttons[1].count.text=='?')")
test('Unavailable aura API stays unknown',"C_UnitAuras=nil;event('UNIT_AURA','nameplate1');tick();assert(bar().buttons[1].effectState=='unknown')")
test('Aura API exception stays unknown',"C_UnitAuras.GetAuraDataByIndex=function()error('restricted')end;event('UNIT_AURA','nameplate1');tick();assert(bar().buttons[1].effectState=='unknown')")
test('Secret identifiers not compared',"local a=dot(172,12);a.spellId={secret=true};a.name={secret=true};auras.nameplate1={a};event('UNIT_AURA','nameplate1');tick();assert(bar().buttons[1].effectState=='unknown')")
test('Bounded scan never fabricates absence',"for i=1,255 do auras.nameplate1=auras.nameplate1 or {};auras.nameplate1[i]=dot(99999,20)end;event('UNIT_AURA','nameplate1');tick();assert(bar().buttons[1].effectState=='unknown')")
test('Multi target independence',"local p2=addplate('nameplate2');event('NAME_PLATE_UNIT_ADDED','nameplate2');auras.nameplate1={dot(172,12)};event('UNIT_AURA','nameplate1');tick();assert(bar().buttons[1].effectState=='active' and P.bars[p2].buttons[1].effectState=='missing')")
test('Cache scans once per unit not per spell',"event('UNIT_AURA','nameplate1');auraCalls=0;tick();assert(auraCalls==1);tick();assert(auraCalls==1);uptime=uptime+1;tick();assert(auraCalls==2)")
test('Aura event updates during combat',"combat=true;auras.nameplate1={dot(172,12)};event('UNIT_AURA','nameplate1');tick();assert(bar().buttons[1].effectState=='active')")
test('Out of range only on definite false',"C_Spell.IsSpellInRange=function()return false end;tick();assert(bar().buttons[1].icon.tint[2]==.18 and bar().buttons[1].glow.alpha==0)")
test('Secret range does not tint red',"C_Spell.IsSpellInRange=function()return {secret=true}end;tick();assert(bar().buttons[1].icon.tint[2]==1)")
test('Cooldown zero alpha includes all art',"P:SetAppearance('cooldownAlpha',0);cooldowns[172]={startTime={secret=true},duration={secret=true},isActive=true};combat=true;tick();local b=bar().buttons[1];assert(b.icon.alpha==0 and b.normal.alpha==0 and b.count.alpha==0 and b.glow.alpha==0)")
test('Active effect zero alpha includes all art',"P:SetAppearance('idleAlpha',0);auras.nameplate1={dot(172,12)};event('UNIT_AURA','nameplate1');combat=true;tick();local b=bar().buttons[1];assert(b.icon.alpha==0 and b.count.alpha==0 and b.glow.alpha==0)")
test('New roots in combat defer preparation',"combat=true;local p2=addplate('nameplate2');event('NAME_PLATE_UNIT_ADDED','nameplate2');tick();assert(P.pending and not P.bars[p2].prepared);combat=false;event('PLAYER_REGEN_ENABLED');tick();assert(P.bars[p2].prepared)")
test('Recycled plate clears old effect',"auras.nameplate1={dot(172,12)};event('UNIT_AURA','nameplate1');tick();combat=true;event('NAME_PLATE_UNIT_REMOVED','nameplate1');assert(bar().buttons[1].icon.alpha==0);plates.nameplate1=nil;plates.nameplate2=plate;event('NAME_PLATE_UNIT_ADDED','nameplate2');tick();assert(bar().buttons[1].effectState=='missing')")
test('Friendly plate clears artwork',"UnitCanAttack=function()return false end;combat=true;tick();assert(bar().buttons[1].icon.alpha==0)")
test('Dead plate clears artwork',"UnitIsDeadOrGhost=function()return true end;combat=true;tick();assert(bar().buttons[1].icon.alpha==0)")
test('Appearance deferred safely in combat',"local b=bar().buttons[1];local width=b.width;combat=true;P:SetAppearance('size',20);tick();assert(b.width==width and P.pending);combat=false;event('PLAYER_REGEN_ENABLED');assert(b.width==20)")
test('Spell choice deferred safely in combat',"combat=true;P:OpenSpells();local b=P.spellsPanel.buttons[1];b:SetChecked(false);b.scripts.OnClick(b);tick();assert(#P.rows==3);combat=false;event('PLAYER_REGEN_ENABLED');assert(#P.rows==2)")
test('Disabled per-character spell persists',"assert(#P.rows==2)","DotCastCharacterDB={disabled={corruption=true}}")
test('Settings restored and invalid values repaired',"assert(P.db.idleAlpha==.7 and P.db.warnSeconds==3 and P.db.size==0)","DotCastDB={idleAlpha=.7,warnSeconds=99,size=-5}")
test('Options open preview and reset',"P:OpenOptions();assert(P.options.shown and #P.options.previews==3);P:SetAppearance('idleAlpha',.8);P:ResetAppearance();assert(P.db.idleAlpha==.35)")
test('Minimap opens options',"P.minimapButton.scripts.OnClick(P.minimapButton,'LeftButton');assert(P.options.shown)")
test('Custom spell requires learned ID',"P:AddCustom('999');assert(#P.characterDB.custom==0)")
test('Custom spell and separate aura ID',"known[999]=true;P:AddCustom('999 888');tick();assert(#P.rows==4);auras.nameplate1={dot(888,12)};event('UNIT_AURA','nameplate1');tick();assert(bar().buttons[4].effectState=='active');P:RemoveCustom('999');tick();assert(#P.rows==3)")
test('Disable leaves no armed buttons outside combat',"P:Setting('enabled',false);assert(not bar().prepared and bar().buttons[1].attributes.type==nil)")
test('No borrowing CounterCast ownership',"assert(macroCreates==3 and macros[121].body=='/say preserved')", "CounterCastCharacterDB={ownedMacros={{name='CounterCast 1',body='/say preserved'}}};macros[121]={name='CounterCast 1',body='/say preserved'}")
test('CounterCast footprint reserved',"local x,y,size=P:Geometry(plate,3);assert(size<=32 and x+3*size+4 < -60)","CounterCast={appliedEnabled=true,rows={{}},db={size=64,offsetX=0,offsetY=0},Geometry=function()return -2,0,64 end}")
test('Too narrow plate fails without overlapping',"assert(P.lastError and not bar().prepared)","CounterCast={appliedEnabled=true,rows={{}},db={size=180,offsetX=0,offsetY=0},Geometry=function()return -2,0,180 end}")
test('Status command reports build and effect',"SlashCmdList.DOTCAST('status');assert(messages[#messages]:find('missing') or messages[#messages]:find('unknown'))")
test('Unavailable event cannot abort startup',"assert(P.initialized and #P.unavailableEvents==1)","local m=getmetatable(plate).__index;local old=m.RegisterEvent;m.RegisterEvent=function(self,e)if e=='UNIT_AURA'then error('unavailable')end;old(self,e)end")
test('Stack count rendered and cleared',"local a=dot(172,12);a.applications=3;auras.nameplate1={a};event('UNIT_AURA','nameplate1');tick();assert(bar().buttons[1].stacks.text=='3');auras.nameplate1={};event('UNIT_AURA','nameplate1');tick();assert(bar().buttons[1].stacks.text=='')")
test('Forever Lacerate resolves learned current ID',"assert(#P.rows==1 and P.rows[1].id==999123)","class='DRUID';known={[999123]=true};local old=C_Spell.GetSpellInfo;C_Spell.GetSpellInfo=function(id)if id=='Lacerate'then return {name='Lacerate',spellID=999123,iconID=132131}end;return old(id)end")
test('Unknown Lacerate never creates button',"assert(#P.rows==0)","class='DRUID';known={}")
test('Moonfire never selects Starfire ID',"assert(#P.rows==1 and P.rows[1].id==8921)","class='DRUID';known={[25298]=true,[8921]=true}")
test('Rake highest rank tracks and warns',"assert(P.rows[1].id==9904);auras.nameplate1={dot(9904,9)};event('UNIT_AURA','nameplate1');tick();assert(bar().buttons[1].count.text=='9');uptime=uptime+7;tick();assert(bar().buttons[1].effectState=='expiring' and bar().buttons[1].count.text=='2')","class='DRUID';known={[1822]=true,[9904]=true}")
test('Rake ignores another druid',"auras.nameplate1={dot(9904,9,'party1')};event('UNIT_AURA','nameplate1');tick();assert(bar().buttons[1].effectState=='missing')","class='DRUID';known={[9904]=true}")

test('Flash strictly below two seconds with distinct phases',"auras.nameplate1={dot(172,1.999)};event('UNIT_AURA','nameplate1');tick();local b=bar().buttons[1];assert(b.flashing and math.abs(b.icon.alpha-1)<.001);uptime=10.25;tick();assert(b.flashing and math.abs(b.icon.alpha-.2)<.001 and math.abs(b.glow.alpha-.2)<.001);uptime=10.5;tick();assert(math.abs(b.icon.alpha-1)<.001)")
test('Early warning still uses active opacity',"auras.nameplate1={dot(172,2.5)};event('UNIT_AURA','nameplate1');tick();assert(bar().buttons[1].effectState=='expiring' and bar().buttons[1].icon.alpha==.35 and not bar().buttons[1].flashing)")
test('Flash remains under two even with customized early warning',"P.db.warnSeconds=1;auras.nameplate1={dot(172,1.5)};event('UNIT_AURA','nameplate1');tick();assert(bar().buttons[1].effectState=='active' and bar().buttons[1].flashing and bar().buttons[1].icon.alpha>.99)")
test('Refresh immediately stops flashing and restores configured fade',"P.db.idleAlpha=.6;auras.nameplate1={dot(172,1.5)};event('UNIT_AURA','nameplate1');tick();auras.nameplate1={dot(172,9)};event('UNIT_AURA','nameplate1');tick();assert(not bar().buttons[1].flashing and bar().buttons[1].icon.alpha==.6)")
test('Removal stops flashing and returns bright missing icon',"auras.nameplate1={dot(172,1.5)};event('UNIT_AURA','nameplate1');tick();auras.nameplate1={};event('UNIT_AURA','nameplate1');uptime=10.25;tick();assert(not bar().buttons[1].flashing and bar().buttons[1].icon.alpha==1 and bar().buttons[1].effectState=='missing')")
test('Restricted timing never flashes',"local a=dot(172,1);a.expirationTime={secret=true};auras.nameplate1={a};event('UNIT_AURA','nameplate1');tick();assert(not bar().buttons[1].flashing and bar().buttons[1].icon.alpha==.35 and bar().buttons[1].count.text=='*')")
test('Combat flashing changes artwork without secure mutation',"local b=bar().buttons[1];local macro=b.attributes.macro;local w=b.width;combat=true;auras.nameplate1={dot(172,1.8)};event('UNIT_AURA','nameplate1');tick();uptime=10.25;tick();assert(b.flashing and math.abs(b.icon.alpha-.2)<.001 and b.attributes.macro==macro and b.width==w and b.shown)")
test('Flash respects cooldown zero opacity',"P.db.cooldownAlpha=0;cooldowns[172]={isActive=true,startTime={secret=true},duration={secret=true}};auras.nameplate1={dot(172,1.8)};event('UNIT_AURA','nameplate1');tick();local b=bar().buttons[1];assert(b.flashing and b.icon.alpha==0 and b.count.alpha==0 and b.glow.alpha==0)")
test('Flash dims within cooldown ceiling',"P.db.cooldownAlpha=.15;cooldowns[172]={isActive=true,startTime={secret=true},duration={secret=true}};auras.nameplate1={dot(172,1.8)};event('UNIT_AURA','nameplate1');tick();local b=bar().buttons[1];assert(math.abs(b.icon.alpha-.15)<.001);uptime=10.25;tick();assert(math.abs(b.icon.alpha-.03)<.001)")
test('Flash independent across targets',"local p2=addplate('nameplate2');event('NAME_PLATE_UNIT_ADDED','nameplate2');auras.nameplate1={dot(172,1.8)};auras.nameplate2={dot(172,9)};event('UNIT_AURA','nameplate1');event('UNIT_AURA','nameplate2');tick();assert(bar().buttons[1].flashing and not P.bars[p2].buttons[1].flashing and P.bars[p2].buttons[1].icon.alpha==.35)")
test('Flashing survives glow disabled',"P.db.castGlow=false;auras.nameplate1={dot(172,1.8)};event('UNIT_AURA','nameplate1');tick();uptime=10.25;tick();assert(bar().buttons[1].flashing and math.abs(bar().buttons[1].icon.alpha-.2)<.001 and bar().buttons[1].glow.alpha==0)")
test('Options preview uses production flashing',"P:OpenOptions();uptime=10.25;P:RefreshOptions();assert(math.abs(P.options.previews[3].icon.alpha-.2)<.001 and P.options.previews[2].icon.alpha==.35)")

test('Unreadable aura table remains unknown without indexing',"C_UnitAuras.GetAuraDataByIndex=function()return sealed()end;event('UNIT_AURA','nameplate1');tick();assert(bar().buttons[1].effectState=='unknown' and bar().buttons[1].count.text=='?')")
test('Unreadable cooldown table never authorizes ready marker',"C_Spell.GetSpellCooldown=function()return sealed()end;tick();assert(bar().buttons[1].ready.text=='' and P.cooldownStatus[172].active==nil)")
test('Unreadable spell information safely omitted',"C_Spell.GetSpellInfo=function()return sealed()end;assert(P:Spell(172)==nil)")
test('Rejected table access predicate remains unknown',"auras.nameplate1={dot(172,8)};canaccesstable=function()error('access denied')end;event('UNIT_AURA','nameplate1');tick();assert(bar().buttons[1].effectState=='unknown')")
test('Low mana removes ready marker and glow',"C_Spell.IsSpellUsable=function()return false,true end;tick();local b=bar().buttons[1];assert(b.ready.text=='' and b.glow.alpha==0 and b.attributes.type=='macro' and b.shown)")
test('Resource recovery restores readiness',"C_Spell.IsSpellUsable=function()return false,true end;tick();C_Spell.IsSpellUsable=function()return true,false end;tick();assert(bar().buttons[1].ready.text=='+')")
test('Wrong form or other unusable state removes readiness',"C_Spell.IsSpellUsable=function()return false,false end;tick();assert(bar().buttons[1].ready.text=='' and bar().buttons[1].glow.alpha==0)")
test('Secret usability never authorizes readiness',"C_Spell.IsSpellUsable=function()return {secret=true},{secret=true}end;tick();assert(bar().buttons[1].ready.text=='')")
test('Missing usability API never authorizes readiness',"C_Spell.IsSpellUsable=nil;tick();assert(bar().buttons[1].ready.text=='')")
test('Usability API failure keeps tracker alive',"C_Spell.IsSpellUsable=function()error('unavailable')end;auras.nameplate1={dot(172,8)};event('UNIT_AURA','nameplate1');tick();assert(bar().buttons[1].effectState=='active' and bar().buttons[1].ready.text=='')")
test('Low energy preserves flash without fake cast-ready glow',"combat=true;C_Spell.IsSpellUsable=function()return false,true end;auras.nameplate1={dot(172,1.5)};event('UNIT_AURA','nameplate1');tick();local b=bar().buttons[1];assert(b.flashing and b.ready.text=='' and b.glow.alpha==0 and b.icon.alpha>.99)")
test('Usability sampled once per spell across plates',"local r=addplate('nameplate2');event('NAME_PLATE_UNIT_ADDED','nameplate2');local calls=0;C_Spell.IsSpellUsable=function()calls=calls+1;return true,false end;tick();assert(calls==#P.rows)")
test('Fault in one plate does not stop healthy plate updates',"local r=addplate('nameplate2');event('NAME_PLATE_UNIT_ADDED','nameplate2');local original=P.EffectState;P.EffectState=function(self,row,u,c)if u=='nameplate1'then error('fixture display fault')end;return original(self,row,u,c)end;auras.nameplate2={dot(172,8)};event('UNIT_AURA','nameplate2');tick();assert(P.bars[r].buttons[1].effectState=='active' and bar().buttons[1].icon.alpha==0 and P.lastDiagnostic.context=='plate nameplate1' and P.lastDiagnostic.stack:find('callback'))",allow_errors=True)
test('Repeated failure backs off and pauses after three attempts',"local calls=0;P.EffectState=function()calls=calls+1;error('fixture display fault')end;tick();for i=1,100 do tick()end;assert(calls==1);uptime=uptime+5;tick();uptime=uptime+5;tick();uptime=uptime+100;tick();assert(calls==3 and P.lastDiagnostic.count==3);local notices=0;for _,m in ipairs(messages)do if m:find('An update failed')then notices=notices+1 end end;assert(notices==1)",allow_errors=True)
test('Explicit refresh recovers paused tracker and retains diagnostic',"local original=P.EffectState;P.EffectState=function()error('fixture display fault')end;tick();P.EffectState=original;SlashCmdList.DOTCAST('refresh');tick();assert(bar().buttons[1].ready.text=='+' and #DotCastDiagnosticsDB.entries==1)",allow_errors=True)
test('Combat end recovers paused tracker',"local original=P.EffectState;combat=true;P.EffectState=function()error('fixture combat fault')end;tick();P.EffectState=original;combat=false;event('PLAYER_REGEN_ENABLED');tick();assert(bar().buttons[1].ready.text=='+')",allow_errors=True)
test('Diagnostics limited to eight distinct entries',"for i=1,20 do P:Guard('test '..i,function()error('fixture '..i)end)end;assert(#DotCastDiagnosticsDB.entries==8 and DotCastDiagnosticsDB.entries[8].context=='test 20')",allow_errors=True)
test('Diagnostic command exposes captured failure without global hook',"P:Guard('test',function()error('fixture visible error')end);SlashCmdList.DOTCAST('errors');local found=false;for _,m in ipairs(messages)do if m:find('fixture visible error')then found=true end end;assert(found)",allow_errors=True)
test('Core update fault is bounded and recorded',"P.Update=function()error('fixture core fault')end;tick();for i=1,30 do tick()end;assert(P.lastDiagnostic.context=='update' and P.lastDiagnostic.count==1)",allow_errors=True)
test('Partially initialized CounterCast cannot break update',"CounterCast={db={}};tick();assert(bar().buttons[1].ready.text=='+')")
test('Diagnostics survive addon initialization',"SlashCmdList.DOTCAST('errors');assert(#DotCastDiagnosticsDB.entries==1)","DotCastDiagnosticsDB={entries={{context='previous',message='old error',stack='old stack',count=1,version='old'}}}")
test('Event callback failure is captured and rate limited',"local calls=0;P.Added=function()calls=calls+1;error('fixture event fault')end;for i=1,40 do event('NAME_PLATE_UNIT_ADDED','nameplate1')end;assert(calls==1 and P.lastDiagnostic.context=='event NAME_PLATE_UNIT_ADDED')",allow_errors=True)

test('Full character macro cache restores icons across fifty rebuilds',"tick();assert(#P.rows==1 and bar().prepared and bar().buttons[1].shown and P.lastError==nil);for i=1,50 do P:Rebuild();tick()end;assert(macroCreates==0 and macroEdits==0 and bar().prepared);assert(bar().buttons[1].attributes.macro=='DotCast 1')","Constants={MacroConsts={MAX_ACCOUNT_MACROS=120,MAX_CHARACTER_MACROS=30}};class='DRUID';known={[8921]=true};C_Spell.GetSpellInfo=function()return {name='Moonfire',iconID=8921}end;for i=121,150 do macros[i]={name='Preserved '..i,body='/say keep'}end;macros[149]={name='DotCast 1',body='/cast [@mouseover,harm,nodead] Moonfire'..string.char(10)};DotCastCharacterDB={ownedMacros={{name='DotCast 1',body='/cast [@mouseover,harm,nodead] Moonfire'}}}")

report={'version':'0.1.3-beta','runtime':'Lua 5.1 with synthetic API fixtures','passed':sum(x['passed']for x in results),'total':len(results),'liveGameVerified':False,'checks':results}
(ROOT/'docs/verification.json').write_text(json.dumps(report,indent=2)+'\n')
print(f"{report['passed']}/{report['total']} checks passed")
sys.exit(0 if report['passed']==report['total'] else 1)
