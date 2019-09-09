unit uLog;

interface

uses
  Classes, Types, Sysutils, Dateutils, StrUtils, Math, Windows, ExtCtrls, Forms;

type

{$IFDEF UNICODE}
  StringW = UnicodeString;
{$ELSE}
  StringW = WideString;
{$ENDIF UNICODE}

  TLogLevel = (llDebug, llEmergency, llAlert, llFatal, llError, llWarning, llHint, llMessage);

  TLog = class
  private
    FLock: TRTLCriticalSection;
    FList: TStringList;
    FSavedLogList: TStringList;
    FLogNamePrefix: string;
    FAutoSaveTimer: TTimer;
    FDisplogTimer: TTimer;
    FDispLogTarget: TStrings;
    FDispMaxLineCount: Integer;
    function GetCount: integer;
    procedure SaveLogToFile(Sender: TObject);
    procedure OnDispTimer(Sender: TObject);
    procedure SetDispMaxLineCount(const Value: Integer);
  public
    constructor Create();
    destructor Destroy; override;
    procedure AddLog(msg: string; bAddLogTime: Boolean = True);  //不要写空日志
    procedure Debug(msg: string);
    procedure PrintMemory(const AData; iLen: Integer);
    procedure AddLogFormat(const formatmsg: string; const Args: array of const; bAddLogTime: Boolean = True);
    procedure Flush;
    procedure SetDispLogTarget(ATarget: TStrings);  //设置显示日志对象
    function PopLog: string;  //获取一条日志
    property Count: integer read GetCount;
    property DispMaxLineCount: Integer read FDispMaxLineCount write SetDispMaxLineCount;
    property LogNamePrefix:string read FLogNamePrefix write FLogNamePrefix;
  end;

  TWatch = class
    class var BeginTime: Cardinal;
    class var ElapseTime: Cardinal;
    class procedure Start;
    class procedure Stop;
    class procedure Reset;
  end;

  function Log: TLog;
  function GetAppPath(): string;

  procedure PostLog(ALevel: TLogLevel; const AMsg: StringW); overload;
  procedure PostLog(ALevel: TLogLevel; const fmt: PWideChar; Args: array of const); overload;

  var LOG_DEBUG_MODE:BOOLEAN = TRUE;

implementation

var  _log : TLog;

const  LogLevelText: array [llDebug..llMessage] of StringW = ('[调试]', '[紧急]',  '[变更]', '[失败]', '[错误]', '[警告]', '[提示]', '[消息]');

function Log: TLog;
begin
  if not Assigned(_Log) then
    _Log := TLog.Create();
  result := _Log;
end;

procedure PostLog(ALevel: TLogLevel; const AMsg: StringW); overload;
begin
  if LOG_DEBUG_MODE then
    Log.AddLog(LogLevelText[ALevel]+AMsg)
  else
  begin
    if ALevel > llDebug then
      Log.AddLog(LogLevelText[ALevel]+AMsg)
  end;
end;

procedure PostLog(ALevel: TLogLevel; const fmt: PWideChar; Args: array of const); overload;
begin
  if LOG_DEBUG_MODE then
    log.AddLogFormat(LogLevelText[ALevel]+fmt, args)
  else
  begin
    if ALevel > llDebug then
      log.AddLogFormat(LogLevelText[ALevel]+fmt, args)
  end;
end;

{ TLog }

procedure TLog.AddLog(msg: string; bAddLogTime: Boolean = True);  //不要写空日志
var
  tmp: string;
begin
  EnterCriticalSection(FLock);
  try
    if msg <> '' then
    begin
      //[ThreadID:%-4d] , GetCurrentThreadId
      if bAddLogTime then
        tmp := format('[%s]%s',  [FormatDateTime('yyyy-mm-dd hh:nn:ss:zzz', now), msg])
      else
        tmp := msg;
      FList.Add(tmp);
      FSavedLogList.Add(tmp);
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TLog.AddLogFormat(const formatmsg: string; const Args: array of const; bAddLogTime: Boolean);
begin
  AddLog(format(formatmsg, Args), bAddLogTime);
end;

constructor TLog.Create;
begin
  InitializeCriticalSection(FLock);
  LogNamePrefix := '';
  FDispMaxLineCount := 1500;
  FList := TStringList.Create;
  FSavedLogList := TStringList.Create;

  FAutoSaveTimer := TTimer.Create(nil);
  FAutoSaveTimer.Interval := 60000;
  FAutoSaveTimer.OnTimer := SaveLogToFile;
  FAutoSaveTimer.Enabled := True;

  FDisplogTimer := TTimer.Create(nil);
  FDisplogTimer.Interval := 1500;
  FDisplogTimer.OnTimer := OnDispTimer;
  FDisplogTimer.Enabled := True;
end;

procedure TLog.Debug(msg: string);
begin
//  AddLog(msg);
//  Self.Flush;
end;

destructor TLog.Destroy;
begin
  if Assigned(FAutoSaveTimer) then FAutoSaveTimer.Free;
    
  FDisplogTimer.Enabled := False;
  FDisplogTimer.Free;

  SaveLogToFile(nil);

  DeleteCriticalSection(FLock);
  FList.Free;
  FSavedLogList.Free;
  inherited;
end;

procedure TLog.Flush;
begin
  Self.SaveLogToFile(self.FAutoSaveTimer);
  //OnDispTimer(Self);
end;

function GetAppPath: string;
var
  tmp: string;
  k: dword;
begin
  SetLength(tmp, 400);
  k := GetModuleFileName(HInstance, pchar(tmp), 400);
  SetLength(tmp, k);
  result := ExtractFilePath(tmp);
end;

function TLog.GetCount: integer;
begin
  Result := FList.Count;
end;

procedure TLog.OnDispTimer(Sender: TObject);
var
  tmp: string;
  remaincnt:Integer;
begin
  if log.Count = 0 then exit;

  if Assigned(FDispLogTarget) then
  begin
    FDispLogTarget.BeginUpdate;
    if FDispLogTarget.Count > FDispMaxLineCount then
    begin
      remaincnt := Max(1,FDispMaxLineCount div 2);
      while FDispLogTarget.Count>remaincnt do
        FDispLogTarget.Delete(0);
    end;
    tmp := log.PopLog;
    while tmp <> '' do
    begin
      FDispLogTarget.Add(tmp);
      tmp := log.PopLog;
    end;
    FDispLogTarget.EndUpdate;
  end;
end;

function TLog.PopLog: string;
begin
  EnterCriticalSection(FLock);
  try
    if FList.Count > 0 then
    begin
      Result := FList[0];
      FList.Delete(0);
    end else
      result := '';
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TLog.PrintMemory(const AData; iLen: Integer);
begin
  AddLogFormat('Print Memory, Address: $%8.0x length: %d byte', [Integer(@AData), iLen]);
end;

procedure TLog.SaveLogToFile(Sender: TObject);
var
  F:TextFile;
  logPath, logFilename:string;
  tmpList: TStringList;
  i: integer;
begin
  //获取当前日志
  EnterCriticalSection(FLock);
  tmpList := TStringList.Create;
  tmpList.Assign(FSavedLogList);
  FSavedLogList.Clear;
  LeaveCriticalSection(FLock);

  //写入文件
  try
    logPath := IncludeTrailingPathDelimiter(GetAppPath) + 'Log';
    if not DirectoryExists(LogPath) then
      CreateDir(LogPath);

    logFilename := format('%s\%s%s.txt', [logPath, FLogNamePrefix, FormatDateTime('yyyy-MM-dd',Now)]);

    AssignFile(F,logFilename);
    if FileExists(logFilename) then
      Append(F)
    else
      Rewrite(F);
    for i := 0 to tmpList.Count - 1 do
      Writeln(F, tmpList[i]);
    System.flush(f);
  finally
    CloseFile(F);
    tmpList.Free;
  end;
end;

procedure TLog.SetDispLogTarget(ATarget: TStrings);
begin
  FDispLogTarget := ATarget;
end;

procedure TLog.SetDispMaxLineCount(const Value: Integer);
begin
  if (FDispMaxLineCount <> Value) and (FDispMaxLineCount >= 10) then
  begin
    FDispMaxLineCount := Value;
  end;
end;

{ TWatch }

class procedure TWatch.Reset;
begin
  Self.ElapseTime := 0;
end;

class procedure TWatch.Start;
begin
  Reset;
  BeginTime := GetTickCount;
end;

class procedure TWatch.Stop;
begin
  ElapseTime := GetTickCount - BeginTime;
end;

initialization
  _log := nil;


finalization
  if Assigned(_log) then
    _log.Free;
end.
