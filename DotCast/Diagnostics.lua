local _,P=...
local function plainText(v,fallback,limit)
 if not P:IsPlain(v)or type(v)~='string'then return fallback end
 return v:sub(1,limit)
end
local function records()
 if type(DotCastDiagnosticsDB)~='table'then DotCastDiagnosticsDB={}end
 if type(DotCastDiagnosticsDB.entries)~='table'then DotCastDiagnosticsDB.entries={}end
 local entries=DotCastDiagnosticsDB.entries
 while #entries>8 do table.remove(entries,1)end
 return entries
end
function P:CaptureFailure(context,message,stack)
 local entries=records();local entry
 for _,v in ipairs(entries)do if type(v)=='table'and v.context==context and v.message==message then entry=v;break end end
 if not entry then
  if #entries>=8 then table.remove(entries,1)end
  entry={context=context,message=message,stack=stack,version=self.version,count=0};entries[#entries+1]=entry
 end
 entry.count=(tonumber(entry.count)or 0)+1;entry.lastSeen=time and time()or 0
 self.lastDiagnostic=entry
 if not self.diagnosticNotice then
  self.diagnosticNotice=true
  self:Say('An update failed; the affected tracker will pause if it repeats. /dotcast errors shows the captured error; /dotcast refresh retries.')
 end
end
function P:ResetFailures()self.failures={}end
function P:Guard(context,fn,...)
 self.failures=self.failures or {}
 local fault=self.failures[context];local now=GetTime()
 if fault and (fault.count>=3 or now<fault.nextTry)then return false,'paused'end
 local args,n={...},select('#',...);local trace
 local ok,message=xpcall(function()fn(unpack(args,1,n))end,function(err)
  if type(debugstack)=='function'then
   local got,value=pcall(debugstack,2,12,4)
   if got then trace=plainText(value,'Stack unavailable',3000)end
  end
  return plainText(err,'Error details unavailable',800)
 end)
 if ok then self.failures[context]=nil;return true end
 self.failures[context]={count=(fault and fault.count or 0)+1,nextTry=now+5}
 -- Capturing our own failure must never become another failing frame callback.
 pcall(self.CaptureFailure,self,context,message,trace or 'Stack unavailable')
 return false,'error'
end
function P:ReportErrors()
 local entries=records();local entry=self.lastDiagnostic or entries[#entries]
 if type(entry)~='table'then self:Say('No DotCast callback errors captured.');return end
 self:Say('Latest captured error ('..tostring(entry.count or 1)..' occurrences, '..tostring(entry.version or '?')..'): '..plainText(entry.context,'unknown context',80))
 self:Say(plainText(entry.message,'Message unavailable',800))
 local stack=plainText(entry.stack,'Stack unavailable',3000)
 for line in stack:gmatch('[^\r\n]+')do self:Say(line)end
 self:Say('Reload or log out to save this report to DotCast saved variables.')
end
