unit uPerformance;

interface

uses
  SysUtils, DateUtils, Windows, PsAPI, TlHelp32, ShellAPI, Generics.Collections;

type
  TProcessID = DWORD;
  //GlobalMemoryStatus

  function GetTotalCpuUsagePct: Double;
  function GetProcessCpuUsagePct: Double;
  function GetCurrentThreadCnt:Integer;
  function GetProcessMemUse: Cardinal;
  function GetProcessMemUseStr: string;
  function Second2Str(ASecond:double):string;
  function Capacity2Str(ABytes:Cardinal):string;

implementation

type
  TSystemTimesRec = record
    KernelTime: TFileTIme;
    UserTime: TFileTIme;
  end;

  TProcessTimesRec = record
    KernelTime: TFileTIme;
    UserTime: TFileTIme;
  end;

  TProcessCpuUsage = class
    LastSystemTimes: TSystemTimesRec;
    LastProcessTimes: TProcessTimesRec;
    ProcessCPUusagePercentage: Double;
  end;

  TProcessCpuUsageList = TObjectDictionary<TProcessID, TProcessCpuUsage>;

var
  LatestProcessCpuUsageCache : TProcessCpuUsageList;
  LastQueryTime : TDateTime;

  function _GetProcessCpuUsagePct(ProcessID: TProcessID): Double; forward;
(* -------------------------------------------------------------------------- *)

function GetRunningProcessIDs: TArray<TProcessID>;
var
  SnapProcHandle: THandle;
  ProcEntry: TProcessEntry32;
  NextProc: Boolean;
begin
  SnapProcHandle := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if SnapProcHandle <> INVALID_HANDLE_VALUE then
  begin
    try
      ProcEntry.dwSize := SizeOf(ProcEntry);
      NextProc := Process32First(SnapProcHandle, ProcEntry);
      while NextProc do
      begin
        SetLength(Result, Length(Result) + 1);
        Result[Length(Result) - 1] := ProcEntry.th32ProcessID;
        NextProc := Process32Next(SnapProcHandle, ProcEntry);
      end;
    finally
      CloseHandle(SnapProcHandle);
    end;
    TArray.Sort<TProcessID>(Result);
  end;
end;

(* -------------------------------------------------------------------------- *)

function _GetProcessCpuUsagePct(ProcessID: TProcessID): Double;
  function SubtractFileTime(FileTime1: TFileTIme; FileTime2: TFileTIme): TFileTIme;
  begin
    Result := TFileTIme(Int64(FileTime1) - Int64(FileTime2));
  end;

var
  ProcessCpuUsage: TProcessCpuUsage;
  ProcessHandle: THandle;
  SystemTimes: TSystemTimesRec;
  SystemDiffTimes: TSystemTimesRec;
  ProcessDiffTimes: TProcessTimesRec;
  ProcessTimes: TProcessTimesRec;

  SystemTimesIdleTime: TFileTime;
  ProcessTimesCreationTime: TFileTime;
  ProcessTimesExitTime: TFileTime;
begin
  Result := 0.0;

  LatestProcessCpuUsageCache.TryGetValue(ProcessID, ProcessCpuUsage);
  if ProcessCpuUsage = nil then
  begin
    ProcessCpuUsage := TProcessCpuUsage.Create;
    LatestProcessCpuUsageCache.Add(ProcessID, ProcessCpuUsage);
  end;
  // method from:
  // http://www.philosophicalgeek.com/2009/01/03/determine-cpu-usage-of-current-process-c-and-c/
  ProcessHandle := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False, ProcessID);
  if ProcessHandle <> 0 then
  begin
    try
      if GetSystemTimes(SystemTimesIdleTime, SystemTimes.KernelTime, SystemTimes.UserTime) then
      begin
        SystemDiffTimes.KernelTime := SubtractFileTime(SystemTimes.KernelTime, ProcessCpuUsage.LastSystemTimes.KernelTime);
        SystemDiffTimes.UserTime := SubtractFileTime(SystemTimes.UserTime, ProcessCpuUsage.LastSystemTimes.UserTime);
        ProcessCpuUsage.LastSystemTimes := SystemTimes;
        if GetProcessTimes(ProcessHandle, ProcessTimesCreationTime, ProcessTimesExitTime, ProcessTimes.KernelTime, ProcessTimes.UserTime) then
        begin
          ProcessDiffTimes.KernelTime := SubtractFileTime(ProcessTimes.KernelTime, ProcessCpuUsage.LastProcessTimes.KernelTime);
          ProcessDiffTimes.UserTime := SubtractFileTime(ProcessTimes.UserTime, ProcessCpuUsage.LastProcessTimes.UserTime);
          ProcessCpuUsage.LastProcessTimes := ProcessTimes;
          if (Int64(SystemDiffTimes.KernelTime) + Int64(SystemDiffTimes.UserTime)) > 0 then
            Result := (Int64(ProcessDiffTimes.KernelTime) + Int64(ProcessDiffTimes.UserTime)) / (Int64(SystemDiffTimes.KernelTime) + Int64(SystemDiffTimes.UserTime)) * 100;
        end;
      end;
    finally
      CloseHandle(ProcessHandle);
    end;
  end;
end;

(* -------------------------------------------------------------------------- *)

procedure DeleteNonExistingProcessIDsFromCache(const RunningProcessIDs : TArray<TProcessID>);
var
  FoundKeyIdx: Integer;
  Keys: TArray<TProcessID>;
  n: Integer;
begin
  Keys := LatestProcessCpuUsageCache.Keys.ToArray;
  for n := Low(Keys) to High(Keys) do
  begin
    if not TArray.BinarySearch<TProcessID>(RunningProcessIDs, Keys[n], FoundKeyIdx) then
      LatestProcessCpuUsageCache.Remove(Keys[n]);
  end;
end;

(* -------------------------------------------------------------------------- *)

function GetTotalCpuUsagePct(): Double;
var
  ProcessID: TProcessID;
  RunningProcessIDs : TArray<TProcessID>;
begin
  Result := 0.0;
  RunningProcessIDs := GetRunningProcessIDs;

  DeleteNonExistingProcessIDsFromCache(RunningProcessIDs);

  for ProcessID in RunningProcessIDs do
    Result := Result + _GetProcessCpuUsagePct( ProcessID );

end;

(* -------------------------------------------------------------------------- *)


function _GetProcessMemUse(PID: Cardinal): Cardinal;
var
  pmc: PPROCESS_MEMORY_COUNTERS; //uses psApi
  ProcHandle: HWND;
  iSize: DWORD;
begin
  Result := 0;
  ProcHandle := 0;
  iSize := SizeOf(_PROCESS_MEMORY_COUNTERS);
  GetMem(pmc, iSize);
  ZeroMemory(pmc,iSize);
  try
    pmc^.cb := iSize;
    ProcHandle := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ,False, PID); //由PID取得进程对象的句柄
    if GetProcessMemoryInfo(ProcHandle, pmc, iSize) then
      Result := pmc^.WorkingSetSize;
  finally
    FreeMem(pmc);
    if ProcHandle>0 then CloseHandle(ProcHandle);
  end;
end;

function GetProcessMemUse: Cardinal;
begin
  result := _GetProcessMemUse(GetCurrentProcessId);
end;

function GetCurrentThreadCnt:Integer;
var
  hSnap:THandle;
  lppe:TProcessEntry32;
  bMore:BOOL;
begin
  result := 0;
  hSnap := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS,GetCurrentProcessId);
  if hSnap = INVALID_HANDLE_VALUE then Exit;

  lppe.dwSize := sizeof(TProcessEntry32);
  bMore := Process32First(hSnap, lppe);
  while bMore do
  begin
    if lppe.th32ProcessID = GetCurrentProcessId then
    begin
      result := lppe.cntThreads;
      break;
    end;
    bMore := Process32Next(hSnap,lppe);
  end;
  CloseHandle(hSnap);
end;

function Capacity2Str(ABytes:Cardinal):string;
var
  f : double;
  k : integer;
const CapacityStr: array[0..4] of string = ('Byte','KB','MB','GB', 'TB');
begin
  if ABytes <= 1024 then Exit(Format('%dByte',[ABytes]));

  f := ABytes*1.0;
  k := low(CapacityStr);
  while k <= High(CapacityStr) do
  begin
    if (f/1024)<1.0 then break;
    f := f / 1024;
    inc(k);
  end;


  result := Format('%f%s', [f, CapacityStr[k]]);
end;

function Second2Str(ASecond:double):string;
const
  C_DAY_SEC:Integer=24*60*60;
  C_HOUR_SEC : Integer = 60*60;
  C_MINUTE_SEC :Integer = 60;
var
  sec : integer;
begin
  result := '';
  if ASecond < 0 then
    Exit(Format('%d毫秒',[trunc(ASecond*1000)]));
  if ASecond = 0 then
    Exit('0.1秒');

  sec := trunc(ASecond);
  //-------DAY COUNT
  if (sec div C_DAY_SEC)>0 then
  begin
    result := result + Format('%d天',[sec div C_DAY_SEC]);
    sec := sec - (sec div C_DAY_SEC) * C_DAY_SEC;
  end;
  //-------HOUR COUNT
  if (sec div C_HOUR_SEC)>0 then
  begin
    result := result + Format('%d小时',[sec div C_HOUR_SEC]);
    sec := sec - (sec div C_HOUR_SEC) * C_HOUR_SEC;
  end;
  //-------MINUTE COUNT
  if (sec div C_MINUTE_SEC)>0 then
  begin
    result := result + Format('%d分',[sec div C_MINUTE_SEC]);
    sec := sec - (sec div C_MINUTE_SEC) * C_MINUTE_SEC;
  end;
  //-------SECONDS
  if sec>0 then
    result := result + Format('%d秒',[sec]);
end;

function GetProcessMemUseStr: string;
begin
  result := Capacity2Str(GetProcessMemUse);
end;

function GetProcessCpuUsagePct: Double;
begin
  result := _GetProcessCpuUsagePct(GetCurrentProcessId)
end;
initialization
  LatestProcessCpuUsageCache := TProcessCpuUsageList.Create( [ doOwnsValues ] );
  // init:
  GetTotalCpuUsagePct;
finalization
  LatestProcessCpuUsageCache.Free;

end.


