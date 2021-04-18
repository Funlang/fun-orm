
########################################
# lib-os
########################################
#  Copyright (c) 2011, funlang.org
########################################
use 'lib-set.fun';

//==============================================================
// utils
//==============================================================
fun isUnicode()
  result = 0x1234.toChar().toByte() > 0xff;
end fun;

fun charSize()
  if isUnicode() then
    result = 2;
  else
    result = 1;
  end if;
end fun;

fun fixHalfHanz(s)
  result = s;
  if result.match(/[\x80-\xff]++$/).@@().length() mod 2 = 1 then
    result = result.substr(len: -1);
  end if;
end fun;

var Hexs = [0,1,2,3,4,5,6,7,8,9,'a','b','c','d','e','f'];
fun str2hex(s)
  result = '';
  if isUnicode() then
    for i = 0 to s.length() -1 do
      var b = s.toByte(i);
      result &= Hexs[b >> 4 bit and 0x0f] & Hexs[b      bit and 0x0f]
              & Hexs[b >> 12]             & Hexs[b >> 8 bit and 0x0f];
    end do;
  else
    for i = 0 to s.length() - 1 do
      var b = s.toByte(i);
      result &= Hexs[b >> 4] & Hexs[b bit and 0x0f];
    end do;
  end if;
end fun;

fun hex2str(s)
  result = '';
  if isUnicode() then
    if s.length() mod 4 <> 0 then
      s &= '00';
    end if;
    for i = 0 to s.length() -1 step 4 do
      result &= ('x' & s.substr(i+2, 2) & s.substr(i, 2)).toChar();
    end do;
  else
    for i = 0 to s.length() - 1 step 2 do
      result &= ('x' & s.substr(i, 2)).toChar();
    end do;
  end if;
end fun;

fun byte2hex(byte)
  var b = byte mod 256;
  result = Hexs[b >> 4] & Hexs[b bit and 0x0f];
end fun;

fun num2hex(num)
  result = '';
  for i = 3 to 0 step -1 do
    var b = (num >> i*8) mod 256;
    result &= Hexs[b >> 4] & Hexs[b bit and 0x0f];
  end do;
end fun;

fun int2hex(int)
  result = '';
  for i = 0 to 3 do
    var b = (int >> i*8) mod 256;
    result &= Hexs[b >> 4] & Hexs[b bit and 0x0f];
  end do;
  result = result.upper();
end fun;

fun str2int(str, start)
  result = str.toByte(3+start) << 24 +
           str.toByte(2+start) << 16 +
           str.toByte(1+start) << 8  +
           str.toByte(  start);
end fun;

fun int2str(int, packed)
  if packed and isUnicode() then
    result  = (int mod 2^16).toChar() & (int >> 16).toChar();
  else
    result = '';
    for i = 0 to 3*8 step 8 do
      var b = int >> i;
      result &= (b mod 256).toChar();
    end do;
  end if;
end fun;

fun ip2int(ip)
  if ip.subpos('.') > 0 then
    var m = ip.match(/(\d++)\.(\d++)\.(\d++)\.(\d++)/);
    return m.@(4).toNum() << 24 + m.@(3).toNum() << 16 + m.@(2).toNum() << 8 + m.@(1).toNum();
  else
    return ip.toNum();
  end if;
end fun;

fun int2ip(int)
  result = int mod 256;
  for i = 1 to 3 do
    int = int div 256;
    result &= '.' & int mod 256;
  end do;
end fun;

//==============================================================
// ...
//==============================================================
var shell32  = 'shell32';
var kernel32 = 'kernel32';
var user32 = 'user32';
var psapi = 'psapi';

var INFINITE = 0xffffffff;
var FILE_NOTIFY_CHANGE_SIZE = 0x00000008;
var FILE_NOTIFY_CHANGE_LAST_WRITE = 0x00000010;
var PROCESS_VM_READ           = 0x0010;
var PROCESS_QUERY_INFORMATION = 0x0400;
var PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;
var FILE_ATTRIBUTE_READONLY = 0x1;

var sleep    = kernel32.getapi('Sleep', 'i:');
var wait     = kernel32.getapi('WaitForSingleObject', 'ii:i');
var waits    = kernel32.getapi('WaitForMultipleObjects', 'isii:i'); // nCount, lpHandles, bWaitAll, dwMilliseconds
var close    = kernel32.getapi('CloseHandle', 'i:i');
var createEvent = kernel32.getapi('CreateEvent', 'piip:i');
var setEvent    = kernel32.getapi('SetEvent', 'i:i');
var resetEvent  = kernel32.getapi('ResetEvent', 'i:i');
var InitializeCriticalSection = kernel32.getapi('InitializeCriticalSection', 's:');
var EnterCriticalSection      = kernel32.getapi('EnterCriticalSection', 's:');
var LeaveCriticalSection      = kernel32.getapi('LeaveCriticalSection', 's:');
var fileChanged = kernel32.getapi('FindFirstChangeNotification', 'sii:i');
var nextChanged = kernel32.getapi('FindNextChangeNotification',  'i:i');

var EnumProcesses       = psapi.getapi('EnumProcesses', 'sis:i');
var GetModuleFileNameEx = psapi.getapi('GetModuleFileNameEx', 'iipi:i');
var GetProcessTimes = kernel32.getapi('GetProcessTimes', 'issss:i');
var GetPId          = kernel32.getapi('GetCurrentProcessId', ':i');
var OpenProcess     = kernel32.getapi('OpenProcess', 'iii:i');
var CreateThread    = kernel32.getapi('CreateThread', 'piipip:i');
var TerminateThread = kernel32.getapi('TerminateThread', 'ii:i');
var LoadLibrary     = kernel32.getapi('LoadLibrary', 's:i');

var SetFileAttributes = kernel32.getapi('SetFileAttributes', 'si:i');
var GetFileAttributes = kernel32.getapi('GetFileAttributes', 's:i');

var CoInitialize = 'ole32'.getapi('CoInitialize', 'i:i');

var _internetConnected = 'Wininet'.getapi('InternetGetConnectedState', 'pi:i');

//==============================================================
// tryExec and tryExecWait
//==============================================================
fun tryExec(fn, ps, dir, show, op, win)
  fn = tryFind(fn, dir);
  result = exec(fn, ps, dir, show, op, win);
end fun;

fun tryExecWait(fn, ps, dir, show, noWait, timeout, pid)
  fn = tryFind(fn, dir);
  result = execWait(fn, ps, dir, show, noWait, timeout, pid);
end fun;

fun tryFind(fn, dir)
  result = fn;
  var f = fn;
  if fn.substr(1,1) <> ':' then
    f = '$dir\$fn'.eval();
  end if;
  if not f.size() then
    f = f.replace(/(?=\.\w++$)/, '.*'); //?. f;
    var fs = f.find();
    if fs then
      result = result.replace(/(?=\.\w++$)/, fs[0].match(/(\.\w++)(?=\.\w++$)/).@@());
    end if;
  end if;
end fun;

//==============================================================
// exec
//==============================================================
//HINSTANCE ShellExecute(
//    HWND hwnd,
//    LPCTSTR lpOperation,
//    LPCTSTR lpFile,
//    LPCTSTR lpParameters,
//    LPCTSTR lpDirectory,
//    INT nShowCmd
//   );
var _ShellExecute = shell32.getapi('ShellExecute', 'issssi:i');

fun exec(fn, ps, dir, show, op, win)
  result = _ShellExecute(win, op, fn, ps, dir, show);
end fun;
var execShow(fn, ps, dir) = exec(fn, ps, dir, 1);

//==============================================================
// execWait
//==============================================================
//Function Run(Command As String, [WindowStyle], [WaitOnReturn]) As Long
var _sh = 'Wscript.Shell'.newobj();

fun execWait(fn, ps, dir, show, noWait, timeout, pid)
  if dir <> '' then
    _sh.CurrentDirectory = dir; // must set as a local drive for fast speed !
  else
    _sh.CurrentDirectory = GetTempPath(); // * default local drive * fast * !
  end if;
  var cmd = fn;
  if cmd.subpos(' ') >= 0 and cmd.substr(0, 1) <> '"' then
    cmd = '"' & cmd & '"';
  end if;
  if ps <> '' then
    cmd &= ' ' & ps;
  end if; //?. cmd;
  try
    if not noWait and timeout > 0 then
      var ex = _sh.Exec(cmd);
      var tim = 1.time();
      timeout = timeout / 1000 / 60 / 60 / 24;
      while ex.Status = 0 and 1.time() - tim < timeout loop
        sleep(6);
      end loop;
      if pid then
        result = ex.ProcessID;
        if pid = 7 then
          ex.Terminate();
        end if;
        pid = result;
        return;
      end if; //?, 'timeout';
      //?, ex.Status;
      //ex.Terminate(); //?. ex.Status;
      if ex.Status = 1 then
        result = ex.StdOut.ReadAll();
      else
        result = ex.StdOut.ReadAll() & ex.StdErr.ReadAll();
      end if;
      //?. ex.Status;
      if ex.Status = 0 then
        ex.Terminate();
      end if;
    else
      return _sh.Run(cmd, show, not noWait);
    end if;
  except
    raise @ & '(' & cmd & ' in ' + _sh.CurrentDirectory + ')';
  end try;
end fun;
var execWaitShow(fn, ps, dir, noWait) = execWait(fn, ps, dir, 1, noWait);
var exec@Show(fn, ps, dir) = execWaitShow(fn, ps, dir, true);

//==============================================================
// exec@Wait
//==============================================================
var _sa = int2str(4 * 3)  & 0.toChar().x(4) & int2str(1);
var _si = int2str(4 * 17) & 0.toChar().x(4 * 16); //'c:\temp\admin\s.i'.save(_si);
var _CreateProcess = kernel32.getapi('CreateProcess', 'sssslipsss:i'); // fn, cmdLine, sa, sa ...
var _CreatePipe    = kernel32.getapi('CreatePipe',    'sssi:i');  // pRead, pWrite, sa, 0
var _ReadFile      = kernel32.getapi('ReadFile',      'isipp:i'); // handle, buf, buflen, pLen, 0
var CreateProcess(fn, ps, dir, pi, si) = _CreateProcess(fn, ps, _sa, _sa, 1, 0x20, 0, dir, si, pi);
var CreatePipe(pRead, pWrite) = _CreatePipe(pRead, pWrite, _sa, 0);
var ReadFile(handle, buf, bufLen, pLen) = _ReadFile(handle, buf, bufLen, pLen, 0);
fun exec@Wait(fn, ps, dir, show, timeout, getStdOut)
  var std = new [out: 0];
  if getStdOut then
    std.out  = 0.toChar().x(4);
    std.read = 0.toChar().x(4);
    CreatePipe(std.read, std.out);
    std.read = str2int(std.read); ?, 'std read'; ?. std.read;
    std.out  = str2int(std.out);  ?, 'std out';  ?. std.out;
  end if;
  var si = int2str(4 * 17)  & 0.toChar().x(4 * 10) &
           int2str(0x101)   & 0.toChar().x(4 * 3)  & //STARTF_USESTDHANDLES = $100
           int2str(std.out) & 0.toChar().x(4); //cb...hStdIn, hStdOut, hStdErr
  var pi = 0.toChar().x(4 * 4); //hProcess, hThread, dwProcessId, dwThreadId
  result = CreateProcess(0, fn & ' ' & ps, dir, pi, si); //'c:\temp\admin\s.i'.save(si);
  if result then
    var hp = str2int(pi);
    if timeout = 0 then
      timeout = INFINITE;
    end if;
    wait(hp, timeout);
    if getStdOut then ?. 'getStdOut';
       var ret = 0.x(2^16);
       var len = int2str(0);
       result = '';
       loop
         if ReadFile(std.read, ret, 2^16, len) then
           var l = str2int(len);
           result &= ret.substr(len: l);
           exit when l < 2^16;
         else
           ?. 'read StdOut: %s'.format(showLastError());
           exit;
         end if;
       end loop;
       close(std.read);
       close(std.out);
    end if;
  else
    ?. 'exec %s %s: %s'.format(fn, ps, showLastError());
  end if;
end fun;
var exec@WaitShow(fn, ps, dir) = exec@Wait(fn, ps, dir, 1);

//==============================================================
// errors
//==============================================================
var GetLastError   = kernel32.getapi('GetLastError',  ':i');
var _FormatMessage = kernel32.getapi('FormatMessage', 'iiiipii:i');

fun FormatMessage(code)
  result = ' '.x(1025);
  _FormatMessage(0x1200, 0, code, 0, result, 1024, 0);
  result = 'Error ' & code & ': ' & result.replace(/[\s\0]++$/, '');
end fun;

fun ShowLastError()
  result = FormatMessage(GetLastError());
end fun;

//==============================================================
// env
//==============================================================
var MAX_PATH     = 260;
var _GetTempPath = kernel32.getapi('GetTempPath', 'ip:i');
var _GetCurrPath = kernel32.getapi('GetCurrentDirectory', 'ip:i');
var _GetFullPath = kernel32.getapi('GetFullPathName', 'sipp:i');
var _GetWinPath  = kernel32.getapi('GetWindowsDirectory', 'pi:i');
var _GetACP      = kernel32.getapi('GetACP', ':i');
var _GetTimeZone = kernel32.getapi('GetTimeZoneInformation', 's:i');

fun GetTempPath(p)
  result = ' '.x(MAX_PATH + 1);
  var ln = _GetTempPath(MAX_PATH, result);
  result = result.substr(len: ln) & p;
end fun;

fun GetCurrPath()
  result = ' '.x(MAX_PATH + 1);
  var ln = _GetCurrPath(MAX_PATH, result);
  result = result.substr(len: ln);
end fun;

fun GetFullPath(f)
  result = ' '.x(MAX_PATH + 1);
  var r = '';
  var ln = _GetFullPath(f, MAX_PATH, result, r);
  result = result.substr(len: ln);
end fun;

fun GetWinPath()
  result = ' '.x(MAX_PATH + 1);
  var ln = _GetWinPath(result, MAX_PATH);
  result = result.substr(len: ln);
end fun;

fun ClearTempPath(path, init)
  path = path.replace(/\\++$/, '');
  if init then
    var f = path & '\' & 0;
    try
      f.save(); f.move();
    except
      ?. @;
    end try;
  end if;

  for f in (path & '\*.*').find(true) do
    f.move();
  end do;
  (path & '\*.*\').find(true).@each((d){
    d.move();
  }, true);
  if not init then
    path.move();
  end if;
end fun;

fun SafeDelete(f)
  var t =  f & 0.random();
  f.move(t);
  t.move(); f.move();
end fun;

fun GetCodePage()
  return _GetACP();
end fun;

fun GetUTCBias()
  result = 0.toChar().x(1024);
  _GetTimeZone(result); //?. result; 'c:\temp\admin\1.1'.save(result);
  result = (str2int(result) - 2^32) / 60;
end fun;

//==============================================================
// window
//==============================================================
fun GetWindowInfo(h, getFileName)
  result = new [];
  var s = 0.x(4);
  result.ThreadId = user32.getapi('GetWindowThreadProcessId', 'ip:i').call(h, s);
  result.PId = s.toNum(1);
  if result.PId <> nil and getFileName then
    result.FileName = GetProcName(result.PId);
  end if;
end fun;

fun GetProcName(pid, handle) //?, 'GetProcName:'; ?. pid;
  result = ' '.x(MAX_PATH + 1);
  var h = handle;
  if h = nil then
    h = OpenProcess(PROCESS_QUERY_INFORMATION bit or PROCESS_VM_READ, false, pid);
  end if;
  if h then
    var i = GetModuleFileNameEx(h, 0, result, MAX_PATH);
    if handle = nil then
      close(h); //?. s;
    end if;
    result = result.replace(/\x00.*$/, '');//.substr(len: i);
  else
    result = '';
    try
      result = FindByWMI(pid).ExecutablePath; //?. result;
    except
      ?. '$@ at $@@()'.eval();
    end try;
  end if; //?, pid; ?. result;
end fun;

fun FindbyWMI(pid)
  result = [];
  var lo = 'WbemScripting.SWbemLocator'.newobj();
  var sv = lo.ConnectServer('.', 'Root\Cimv2');
  var ps = sv.ExecQuery("SELECT * FROM Win32_Process WHERE ProcessId=$pid".eval());
  for p in ps do
    return p;
  end do;
end fun;

fun GetIPs()
  result = new [];
  try //raise 0;
    var lo = 'WbemScripting.SWbemLocator'.newobj();
    var sv = lo.ConnectServer('.', 'Root\Cimv2');
    var ps = sv.ExecQuery("SELECT IPAddress, ServiceName FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled=true");
    for p in ps do
      try
        for i = 0 to 9 do
          var ip = p.IPAddress.toStr(i); exit when ip = nil; next when ip =~ /^[0\.]++$|:/ or find(result, v -> v = ip);
          result.@add(ip);
        end do;
      except
      end try;
    end do;
  except
  end try;
  if not result then
    var ret = result;
    var t = 1.time()*1;
    var f = GetTempPath(t);
    execWait('cmd.exe', '/c ipconfig | findstr IP > $t'.eval(), GetTempPath());
    if f.size() then
      f.load().match(/\b(\d++(\.\d++){3})\b/g, (m){
        if not find(ret, v -> v = m.@@()) then
          ret.@add(m.@@());
        end if;
      });
      f.move();
    end if;
  end if;
end fun;

var VK_LSHIFT = 160;
var VK_SHIFT  = 0x10;
fun GetKeyState(key)
  result = user32.getapi('GetKeyState', 'i:i').call(key);
end fun;

var PostMessage = user32.getapi('PostMessage', 'iiii:i');
var FindWindow  = user32.getapi('FindWindow', 'ss:i');

//==============================================================
// file change
//==============================================================
fun waitFileChange(f)
  var t = f.time(1);
  var h = fileChanged(f.replace(/\\[^\\]++$/, ''), false, FILE_NOTIFY_CHANGE_SIZE bit or FILE_NOTIFY_CHANGE_LAST_WRITE);
  loop
    wait(h, INFINITE);
    exit when t <> f.time(1);
    nextChanged(h);
  end loop;
end fun;

//==============================================================
// internet
//==============================================================
fun internetConnected()
  var s = '    ';
  return _internetConnected(s, 0);
end fun;