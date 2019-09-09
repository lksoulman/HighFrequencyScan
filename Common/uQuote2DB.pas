unit uQuote2DB;

interface

uses

  Classes, types, SysUtils, StrUtils, DateUtils, IOUtils, Windows, Math,
  ADODB,  ActiveX, Generics.Collections, SyncObjs, Variants,
  uQuoteFile, uQuoteBroadcast, uDES,
  QWorker, zmq, uAlarm,
  clHttp,
  uLog, QJson, uDBSync, uSyncDefine,
  utils.queues;

type

  TTimeRange = packed record
    StartTime: TDateTime;
    EndTime  : TDateTime;
  end;

  TQuoteFileConfig = record
    Path:string;
    AliasName:string;
    Level:Integer;
    StartTime:TDateTime;
    StopTime:TDateTime;
    InspectionCodeList:string;
    AlarmURL:string;
    SplitIntervalMinute: Integer;
    MonitorEnable: Boolean;
    MonitorCodes: string;
    MonitorInterval:Integer;
    MonitorTimeRange01: TTimeRange;
    MonitorTimeRange02: TTimeRange;
  end;

  TSmtpConfig = record
    Host:string;
    Port:integer;
    User:string;
    Pass:string;
  end;

  TSuningTxtConfig = record
    TodayPath:string;
    ArchivePath:string;
    ArchiveTime: TDateTime;
    APIHost:string;
    APIPort:Integer;
    APIUserName:string;
    APIPassword:string;
  end;

  TMonitorConfig = record
    CustomURL:string;
    WeChatToken:string;
    DingdingToken:string;
    CustomMessag:string;
  end;

  TKafkaConfig = record
    Brokers:string;
    Topic:string;
    ScanInterval:Integer;
  end;

  TQuoteScanConfig = class
  strict private
    FConnectString:string;
    FBinarySave:boolean;
    FBroadcastEnable:boolean;
    FBroadcastPort:integer;
    FQuoteFiles: TList<TQuoteFileConfig>;
    FSMTP:TSmtpConfig;
    FSuningTxt: TSuningTxtConfig;
    FDBLink:TDBLink;
    FAutoRemoveDays:Integer;
    FMonitorConfig: TMonitorConfig;
    FKafkaConfig: TKafkaConfig;
    FCustomSQL:string;
    FWindowCaption:string;
    FPlugins:TDictionary<String, Boolean>;
  public
    constructor Create;
    destructor Destroy; override;
    property AutoRemoveDays:Integer read FAutoRemoveDays write FAutoRemoveDays;
    property BinarySave:boolean read FBinarySave write FBinarySave;
    property ConnectString:string read FConnectString write FConnectString;
    property BroadcastEnable:boolean read FBroadcastEnable write FBroadcastEnable;
    property BroadcastPort:Integer read FBroadcastPort write FBroadcastPort;
    property QuoteFiles: TList<TQuoteFileConfig> read FQuoteFiles;
    property SMTP:TSmtpConfig read FSMTP;
    property SuningTxt: TSuningTxtConfig read FSuningTxt;
    property Kafka: TKafkaConfig read FKafkaConfig;
    procedure Load;
    procedure Save;
    property DBLink:TDBLink read FDBLink write FDBLink;
    property CustomSQL:string read FcustomSQL write FCustomSQL;
    property Plugins:TDictionary<String, Boolean> read FPlugins;
    property Monitor:TMonitorConfig read FMonitorConfig;
    property WindowsCaption:string read FWindowCaption;
  end;

  TQuoteScannerClass = class of TQuoteScanner;
  TQuoteScanner = class
  strict private
    FActive:boolean;
    FSourceFile: string;
    FChangeTime: TDateTime;
    FReader: TQuoteBase;
    FRecBuffer: PQuoteRecordAry;
    FRecCount:Integer;
    FAutoStartTime:TDatetime;
    FAutoStopTime:TDateTime;
    FReaderLock:TCriticalSection;
    FScanThread, FWriteThread, FFileChangeMonitor :TThread;
    FScanConfig:TQuoteScanConfig;
    FFileConfig:TQuoteFileConfig;
    FScanInterval:Integer;
    procedure Push(Source:PQuoteRecord);
    procedure WriteJob;
    procedure ScanJob;
    procedure _ScanFile(AJob: PQJob);
    procedure FileMonitorJob;
    function GetQueueCount: Integer;
    function GetRecCount: Integer;
    function GetRecByIndex(AIndex:Integer):PQuoteRecord;
    procedure ResetReader;
  protected
    FChangeList:TSafeQueue;
    FChangeCount:Integer;
    FUpdateCount:Integer;
    function GetToolName:string; virtual;
    procedure Init; virtual;abstract;
    procedure Uninit; virtual;abstract;
    procedure doStart; virtual; abstract;
    procedure doStop; virtual; abstract;
    procedure doWork; virtual; abstract;
  public
    constructor Create(AScanConfig:TQuoteScanConfig; AFileConfig: TQuoteFileConfig); virtual;
    destructor Destroy; override;
    //------------------------------
    procedure StartScan;
    procedure StopScan;
    procedure AutoAction(const ACurrTime:TDateTime);
    property AutoStartTime:TDatetime read FAutoStartTime;
    property AutoStopTime:TDateTime  read FAutoStopTime;
    function State:string;
    //------------------------------
    property SourceFile:string read FSourceFile;
    property ChangeTime:TDateTime read FChangeTime;
    property Active:boolean read FActive;
    property ChangeCount:Integer read FChangeCount;
    property UpdateCount:Integer read FUpdateCount;
    property QueueCount:Integer read GetQueueCount;
    property RecCount:Integer read GetRecCount;
    property Rec[AIndex:Integer]:PQuoteRecord read GetRecByIndex; default;
    property ToolName:string read GetToolName;
    property ScanConfig:TQuoteScanConfig read FScanConfig;
    property FileConfig:TQuoteFileConfig read FFileConfig;
    property Reader: TQuoteBase read FReader;
    property ScanInterval:Integer read FScanInterval write FScanInterval;  //扫描间隔，单位秒;
  end;


  TWriteDBTool = class(TQuoteScanner)
  strict private
    FConnectionString:string;
    FTblName:string;
    FConnection:TADOConnection;
    FUpdater:TADOQuery;
    FLevel:Integer;
    procedure AppendRecord(R:PQuoteRecord);
    procedure CommitToDB;
  protected
    procedure Init; override;
    procedure Uninit; override;
    procedure doWork; override;
    procedure doStart; override;
    procedure doStop; override;
    function GetToolName: string; override;
  public
    procedure Setup(AConnectionString:string; ATblName:string; const ALevel:Integer);
  end;

  TWriteCSVTool = class(TQuoteScanner)
  strict private
    FCSVWriter:TStreamWriter;
    FTblName:string;
    procedure WriteRecord(R:PQuoteRecord);
    procedure WriteFundEValuetionRecord(R:PQuoteRecord);
  protected
    procedure Init; override;
    procedure Uninit; override;
    procedure doWork; override;
    procedure doStart; override;
    procedure doStop; override;
    function GetToolName:string; override;
  public
    constructor Create(AScanConfig:TQuoteScanConfig; AFileConfig: TQuoteFileConfig); override;
  end;

  TSuningTxtInfo = record
    FileName: string;
    FileCreateDate: TDateTime;
    function ToString:string;
    function SetValue(AValue:String):boolean;
  end;

  TSuningTxtTool = class(TQuoteScanner)
  private
    FLastFileName    : string;
    FCurrFileStream  : TFileStream;
    FFileInfoFN      : string;
    FFileInfos       : TDictionary<string, TSuningTxtInfo>;
    FTodayPath       : string;
    FCurrentID       : Int64;
    procedure AddFileInfo(AFileName:string);
    procedure WriteRecord(const R:PQuoteRecord);
    function GetCurrentID:string;
  protected
    procedure Init; override;
    procedure Uninit; override;
    procedure doWork; override;
    procedure doStart; override;
    procedure doStop; override;
    function GetToolName:string; override;
  public

  end;

  TStockState = class
    MarketActive:boolean;   //市场是否处于交易时间
    LastModify:TDateTime;   //最近更新时间
    Alarmed: boolean;
    Code:string;
  end;

  TMonitorTool = class(TQuoteScanner)
  strict private
    FCodeList: TObjectDictionary<string, TStockState>; //被监测的代码列表
    FCheckTimerHandle: Integer;
    FHttp:TclHttp;
    procedure CheckTimer(AJob: PQJob);
    procedure PostAlarm(AState: TStockState; bError:Boolean=True);
  protected
    procedure Init; override;
    procedure Uninit; override;
    procedure doWork; override;
    procedure doStart; override;
    procedure doStop; override;
    function GetToolName:string; override;
  public
    constructor Create(AScanConfig:TQuoteScanConfig; AFileConfig: TQuoteFileConfig); override;
  end;


  //实时切片记录
  PSlice = ^TSlice;
  TSlice = packed record
    Empty:boolean;
    StockCode:array[0..31] of AnsiChar;
    SliceTime:TDateTime;
    Time: TDateTime;
    Prev:double;
    Open:double;
    High:double;
    Low:double;
    Close:double;
    Volume:Integer;
    Value:double;
    DealCnt:Integer;
  end;

  TStockTicks = class
  strict private
    FTickList: TList<TQuoteRecord>;
    FFlag:Boolean;
    FLastRec: TQuoteRecord;
  private
    function GetEndRec: TQuoteRecord;
  public
    constructor Create;
    destructor Destroy; override;
    function IsEmpty:Boolean;
    function Pack:TSlice;
    procedure AddTick(ATick: PQuoteRecord);
    property LastRec: TQuoteRecord read FLastRec;
    property EndRec:  TQuoteRecord read GetEndRec;
  end;

  //实时切片工具
  TRealSliceTool = class(TQuoteScanner)
  strict private
    FConnection       : TADOConnection;
    FConnectionString : string;
    FSliceList        : TSafeQueue;
    FStockList        : TDictionary<string, TStockTicks>;
    FUpdater          : TADOQuery;
    FWriteDBJob       : TThread;
    FCodePreFix       : string;
    procedure PushSlice(ARec:TSlice);
    procedure doSlice(ptrTick:PQuoteRecord);
    procedure CommitToDB;
  protected
    procedure Init; override;
    procedure Uninit; override;
    procedure doWork; override;
    procedure doStart; override;
    procedure doStop; override;
  public
    procedure Setup(AConnectionString:string);
  end;

  TStringsHelper = class helper for TStrings
    function Join(const Splitter: string): string;
  end;

  function InTime(const n, s, e:TDateTime):boolean;

  const C_Broadcast_Port:Integer = 9955;

implementation
const INIT_TBL_SQL : string =
    'IF OBJECT_ID(''_TBLNAME_'') IS NULL '+
    'begin '+
    '	SELECT TOP 0 * INTO _TBLNAME_ FROM TBL_EMPTY;'+
    '	ALTER TABLE _TBLNAME_ DROP COLUMN ID;'+
    '	ALTER TABLE _TBLNAME_ ADD ID BIGINT IDENTITY(1,1);'+
    //'   IF CHARINDEX(''2016'', @@VERSION) > 0 CREATE CLUSTERED COLUMNSTORE INDEX [IDX_COL__TBLNAME_] ON [_TBLNAME_];'+
    ' CREATE INDEX [IDX__TBLNAME_] ON _TBLNAME_([MarketTime],[Code],[Volume],[ID]) INCLUDE ([Last],[Value],[BuyPrice1],[BuyVolume1],[SellPrice1],[SellVolume1]);'+
    'end ';

const INIT_SLICE_TBL_SQL : string =
    'IF OBJECT_ID(''SLICE_EMPTY'') IS NULL '+
    'begin '+
    'CREATE TABLE SLICE_EMPTY '+
    '( '+
    '	ID BIGINT NOT NULL, '+
    ' StockCode CHAR(8) NOT null, '+
    '	SliceTime DATETIME NOT NULL, '+
    '	SliceMinute CHAR(8) NOT NULL, '+
    '	PrevPirce MONEY, '+
    '	OpenPrice MONEY, '+
    '	LowPrice MONEY, '+
    '	HighPrice MONEY, '+
    '	ClosePrice MONEY, '+
    '	Volume BIGINT, '+
    '	Value MONEY '+
    ') '+
    'end  '+
    'IF OBJECT_ID(''_TBLNAME_'') IS NULL '+
    'begin '+
    '	SELECT TOP 0 * INTO _TBLNAME_ FROM SLICE_EMPTY;'+
    '	ALTER TABLE _TBLNAME_ DROP COLUMN ID;'+
    '	ALTER TABLE _TBLNAME_ ADD ID BIGINT IDENTITY(1,1);'+
    //'   IF CHARINDEX(''2016'', @@VERSION) > 0 CREATE CLUSTERED COLUMNSTORE INDEX [IDX_COL__TBLNAME_] ON [_TBLNAME_];'+
    ' CREATE INDEX [IDX__TBLNAME_] ON _TBLNAME_(StockCode,SliceMinute,[ID]) INCLUDE (ClosePrice, Volume, Value);'+
    'end ';

function InTime(const n, s, e:TDateTime):boolean;
var
  rs,re:TDateTime;
begin
  rs := Frac(s);
  re := Frac(e);

  //跨天时间区间（适用于境外交易所）
  if rs > re then
  begin
    result := not Math.InRange(frac(n), re, rs);
  end else
  //日内时间区间（适用于境内交易所）
  begin
    result := Math.InRange(frac(n), rs, re);
  end;
end;

{ TQuote2DB }

procedure TQuoteScanner.AutoAction(const ACurrTime: TDateTime);
begin
  if InTime(ACurrTime, FAutoStartTime, FAutoStopTime) then
    StartScan
  else
    StopScan;
end;

constructor TQuoteScanner.Create(AScanConfig:TQuoteScanConfig; AFileConfig: TQuoteFileConfig);
begin
  FScanConfig := AScanConfig;
  FFileConfig := AFileConfig;

  FActive := False;

  FReader := nil;
  FRecBuffer := nil;
  FChangeCount := 0;
  FUpdateCount := 0;
  FRecCount := 0;
  FSourceFile := TPath.GetFullPath(AFileConfig.Path);
  FChangeList := TSafeQueue.Create;

  FAutoStartTime := AFileConfig.StartTime;
  FAutoStopTime := AFileConfig.StopTime;

  FReaderLock := TCriticalSection.Create;
  FScanInterval := 0;

  Init;
end;

destructor TQuoteScanner.Destroy;
begin
  StopScan;
  Sleep(1000);
  FChangeList.Free;
  if Assigned(FReader) then   FReader.Free;
  if Assigned(FRecBuffer) then FreeMem(FRecBuffer);
  Uninit;

  FReaderLock.Free;
  inherited;
end;

procedure TQuoteScanner.FileMonitorJob;
var
  _fsize:DWORD;
begin
  //侦测行情记录是否有变化
  while FActive do
  begin
    sleep(100);
    if not Assigned(FReader) then continue;

    _fsize := GetFileSize(FReader.FileHandle, nil);
    if _fsize <> FReader.FileSize then
    begin
      PostLog(llHint, '文件[%s]长度发生变化[%d-->%d]，重启扫描线程', [FReader.FileName,FReader.FileSize,_fsize]);
      ResetReader;
    end;
  end;
end;

function TQuoteScanner.GetQueueCount: Integer;
begin
  result := FChangeList.Size;
end;

function TQuoteScanner.GetRecByIndex(AIndex: Integer): PQuoteRecord;
begin
  if not FActive then exit(nil);
  if (AIndex<0) or (AIndex>=GetRecCount) then exit(nil);

  result := @FRecBuffer[AIndex]
end;

function TQuoteScanner.GetRecCount: Integer;
begin
  if FActive then
    result := FReader.RecCount
  else
    result := 0;
end;

function TQuoteScanner.GetToolName: string;
begin
  result := '';
end;

procedure TQuoteScanner.Push(Source: PQuoteRecord);
var
  pData: PQuoteRecord;
begin
  GetMem(pData, SizeOf(TQuoteRecord));
  Move(Source^, pData^, SizeOf(TQuoteRecord));
  FChangeList.EnQueue(pData);
end;

procedure TQuoteScanner.ResetReader;
var
  tmpClass : TQuoteBaseClass;
  tmpReader:TQuoteBase;
  i: integer;
begin

  //加载扫描文件
  tmpClass := uQuoteFile.GetQuoteReader(FSourceFile);
  if Assigned(tmpClass) then
  begin
    tmpReader := tmpClass.Create;
    tmpReader.BindFile(FSourceFile);
    tmpReader.ScanQuote;
  end
  else begin
    PostLog(llError, '程序不能识别此文件:[%s]',[FSourceFile]);
    Exit;
  end;

  FReaderLock.Enter;

    FRecCount := tmpReader.RecCount;
    GetMem(FRecBuffer, SizeOf(TQuoteRecord)*tmpReader.RecCount);
    Move(tmpReader.RecBuffer^, FRecBuffer[0], SizeOf(TQuoteRecord)*tmpReader.RecCount);

    if Assigned(FReader) then FreeAndNil(FReader);
    FReader := tmpReader;

  FReaderLock.Leave;


  //首次扫描，先将记录存入队列中
  for I := 0 to FRecCount - 1 do
  begin
    if not FRecBuffer[i].Valid then continue;
    Push(@FRecBuffer[i]);
    BroadCaster.Send(@FRecBuffer[i]);
  end;

  PostLog(llMessage, '初始化文件[%s]完毕,文件大小%dByte,共加载[%d]条记录', [FSourceFile, Reader.FileSize, self.FRecCount]);
end;

procedure TQuoteScanner.StartScan;
begin
  if FActive then Exit;

  PostLog(llMessage, '插件[%s]触发启动[%s]扫描', [self.ToolName, TPath.GetFileNameWithoutExtension(FSourceFile) ]);

  FChangeCount := 0;
  FUpdateCount := 0;
  FRecCount    := 0;

  doStart;

  //初始化文件读取
  ResetReader;

  //写数据库线程
  FWriteThread := TThread.CreateAnonymousThread(WriteJob);
  FWriteThread.FreeOnTerminate := False;
  FWriteThread.Start;

  //启动文件大小变化监测线程
  FFileChangeMonitor := TThread.CreateAnonymousThread(FileMonitorJob);
  FFileChangeMonitor.FreeOnTerminate := False;
  FFileChangeMonitor.Start;


  //启动扫描文件线程
  FScanThread := TThread.CreateAnonymousThread(ScanJob);
  FScanThread.FreeOnTerminate := False;
  FScanThread.Start;


  //置启动标记
  FActive := True;
end;

function TQuoteScanner.State: string;
const
  tmp:array[False..True] of string = ('停止','运行');
begin
  result := Format('%s[%s/%s]',[
    tmp[FActive],
    FormatDateTime('hh:nn:ss', FAutoStartTime),
    FormatDateTime('hh:nn:ss', FAutoStopTime)
  ]);
end;

procedure TQuoteScanner.ScanJob;
var
  jobHandle:IntPtr;
begin
  jobHandle := 0;

  if FScanInterval>0 then
  begin
    jobHandle := workers.At(
      _ScanFile,
      1000,
      FScanInterval*10000,
      nil);
  end;

  while FActive do
  begin
    sleep(5);
    if not FActive then break;
    if not Assigned(FReader) then continue;
    if jobHandle=0 then
      _ScanFile(nil);
  end;

  if jobHandle > 0 then
    Workers.ClearSingleJob(jobHandle);

end;

procedure TQuoteScanner._ScanFile(AJob: PQJob);
var i:integer;
begin
  if not FReaderLock.TryEnter then Exit;
  if FReader.ScanQuote then
  begin
    for i := 0 to FRecCount - 1 do
    begin
      if not FRecBuffer[i].Compare(FReader.Quote[i]) then
      begin
        BroadCaster.Send(FReader.Quote[i]);
        Push(FReader.Quote[i]); //写入队列
        Move(FReader.Quote[i]^, FRecBuffer[i], SizeOf(TQuoteRecord)); //写入缓存
        inc(FChangeCount);
        FChangeTime := now;
     end;
    end;
  end;
  FReaderLock.Leave;
end;

procedure TQuoteScanner.StopScan;
begin
  if not FActive then Exit;

  FActive := False;

  doStop;

  PostLog(llMessage, '尝试停止扫描行情文件[%s]！', [FSourceFile]);

  if Assigned(FFileChangeMonitor) then
  begin
    FFileChangeMonitor.Terminate;
    FFileChangeMonitor.WaitFor;
    FreeAndNil(FFileChangeMonitor);
  end;

  if Assigned(FScanThread) then
  begin
    FScanThread.Terminate;
    FScanThread.WaitFor;
    FreeAndNil(FScanThread);
  end;

  if Assigned(FWriteThread) then
  begin
    FWriteThread.Terminate;
    FWriteThread.WaitFor;
    FreeAndNil(FWriteThread);
  end;

  if Assigned(FReader) then FreeAndNil(FReader);

  PostLog(llMessage, '已停止扫描文件[%s]！', [FSourceFile]);
end;


procedure TQuoteScanner.WriteJob;
begin
  CoInitialize(nil);
  doWork;
end;

{ TQuoteScanConfig }

constructor TQuoteScanConfig.Create;
begin
  FQuoteFiles := TList<TQuoteFileConfig>.Create;
  FPlugins := TDictionary<String, Boolean>.Create;
  FBroadcastEnable :=  False;
  FBroadcastPort := C_Broadcast_Port;
  FDBLink := TDBLink.Create;
  FDBLink.DBType := stMySQL;
  //...Plugin...
  FPlugins.Add('Database',False);
  FPlugins.Add('CSV',False);
  FPlugins.Add('Binary',False);
  FPlugins.Add('SuningTxt',False);
  FPlugins.Add('Monitor',False);
  Fplugins.Add('Kafka', False);
end;

destructor TQuoteScanConfig.Destroy;
begin
  FPlugins.Free;
  FQuoteFiles.Free;
  inherited;
end;

procedure TQuoteScanConfig.Load;
var
  config_fn:string;
  json, fs, tmp:TQJson;
  i:integer;
  f:TQuoteFileConfig;
begin
  config_fn := TPath.GetFullPath('.\Config.JSON');

  //PostLog(llMessage, '准备加载配置文件');
  if TFile.Exists(config_fn) then
  begin
    json := TQJson.Create;
    json.LoadFromFile(config_fn);

    FWindowCaption := json.ValueByName('WindowCaption', '行情扫描工具【控制面板】');
    //数据库链接字符串
    FConnectString := json.ValueByName('ConnectString','');
    FCustomSQL := json.ValueByName('CustomSQL', '');

    //自动清除N天前数据
    FAutoRemoveDays := json.IntByName('AutoRemoveDays',0);

    //二进制数据流保存
    FBinarySave := json.BoolByPath('BinarySave\Enable', False);

    //行情广播配置
    FBroadcastEnable := json.BoolByPath('Broadcast\Enable', False);
    FBroadcastPort := json.IntByPath('Broadcast\Port', C_Broadcast_Port);
    //文件列表
    fs := json.ItemByName('Files');
    for i := 0 to fs.Count - 1 do
    begin
      f.Path := fs[i].ValueByName('Path','');
      f.StartTime := StrToTime( fs[i].ValueByName('StartTime', '09:00:00') );
      f.StopTime  := StrToTime( fs[i].ValueByName('StopTime' , '16:00:00') );
      f.Level     := fs[i].IntByName('Level',5);
      f.InspectionCodeList := fs[i].ValueByName('Inspection','');
      f.SplitIntervalMinute := fs[i].IntByName('SplitMinute',0);
      //文件监控配置
      f.MonitorInterval := fs[i].IntByName('MonitorInterval',15);
      f.MonitorEnable := fs[i].BoolByName('MonitorEnable', False);
      f.MonitorCodes := fs[i].ValueByName('MonitorCodes','');
      f.AlarmURL := fs[i].ValueByName('AlarmURL','');
      f.MonitorTimeRange01.StartTime := StrToTime( fs[i].ValueByName('MonitorTimeRange01Start', '09:30:00') );
      f.MonitorTimeRange01.EndTime := StrToTime( fs[i].ValueByName('MonitorTimeRange01End', '11:30:00') );
      f.MonitorTimeRange02.StartTime := StrToTime( fs[i].ValueByName('MonitorTimeRange02Start', '13:00:00') );
      f.MonitorTimeRange02.EndTime := StrToTime( fs[i].ValueByName('MonitorTimeRange02End', '15:00:00') );
      //if f.AlarmURL = '' then
      //  PostLog(llWarning, '未配置[AlarmUrl]，行情更新检测报警功能将被禁用！');
      FQuoteFiles.Add(f);

      //...
      if f.InspectionCodeList <> '' then
        PostLog(llHint, '%s开启证码为"%s"的更新监测，更新间隔%d秒', [TPath.GetFileName(f.Path), f.InspectionCodeList, f.MonitorInterval]);
    end;
    //Plugins
    FPlugins['Database'] :=  json.BoolByPath('Plugins\Database', False);
    FPlugins['CSV'] :=  json.BoolByPath('Plugins\CSV', False);
    FPlugins['Binary'] :=  json.BoolByPath('Plugins\Binary', False);
    FPlugins['SuningTxt'] :=  json.BoolByPath('Plugins\SuningTxt', False);
    FPlugins['Monitor'] :=  json.BoolByPath('Plugins\Monitor', False);
    FPlugins['Kafka'] :=  json.BoolByPath('Plugins\Kafka', False);
    //SMTP
    tmp := json.ItemByName('SMTP');
    if Assigned(tmp) then
    begin
      FSMTP.Host := tmp.ValueByName('Host','');
      FSMTP.Port := tmp.IntByName('Port', 25);
      FSMTP.User := tmp.ValueByName('User','');
      FSMTP.Pass := tmp.ValueByName('Pass','');
    end;
    //监控配置
    FMonitorConfig.CustomURL := json.ValueByPath('Monitor\CustomURL', '');
    FMonitorConfig.WeChatToken := json.ValueByPath('Monitor\WeChatToken', '');
    FMonitorConfig.DingdingToken := json.ValueByPath('Monitor\DingdingToken', '');
    FMonitorConfig.CustomMessag := json.ValueByPath('Monitor\CustomMessag', '');

    //苏宁专用工具配置项
    FSuningTxt.TodayPath := json.ValueByPath('SuningTxt\TodayPath', '.\Suning\Today');
    FSuningTxt.ArchivePath := json.ValueByPath('SuningTxt\ArchivePath', '.\Suning\Archive');
    FSuningTxt.ArchiveTime := StrToTime(json.ValueByPath('SuningTxt\ArchiveTime', '17:00:00'));
    FSuningTxt.APIHost := json.ValueByPath('SuningTxt\APIHost', '');
    FSuningTxt.APIPort := json.IntByPath('SuningTxt\APIPort', 9983);
    FSuningTxt.APIUserName := DecryStrHex(json.ValueByPath('SuningTxt\APIUserName', ''),'123');
    FSuningTxt.APIPassword := DecryStrHex(json.ValueByPath('SuningTxt\APIPassword', ''),'123');

    //Kafka配置
    FkafkaConfig.Brokers := json.ValueByPath('Kafka\Brokers', '');
    FKafkaConfig.Topic:= json.ValueByPath('Kafka\Topic', 'FundData');
    FKafkaConfig.ScanInterval := json.IntByPath('Kafka\ScanInterval', 0);

    //DBLINK
    tmp := json.ItemByName('DB');
    if Assigned(tmp) then
    begin
      FDBLink.DBType := TSyncType(tmp.IntByName('DBType', 1));
      FDBLink.Host := tmp.ValueByName('Host', '127.0.0.1');
      FDBLink.Port := tmp.IntByName('Port', 3306);
      FDBLink.Username := tmp.ValueByName('UserName', '');
      if FDBLink.Username<>'' then FDBLink.Username := DecryStrHex(FDBLink.Username, '123');
      FDBLink.Password := tmp.ValueByName('Password', '');
      if FDBLink.Password<>'' then FDBLink.Password := DecryStrHex(FDBLink.Password, '123');
      FDBLink.Database := tmp.ValueByName('Database', '');
      FDBLink.MySQLEncoding := TMySQLEncoding(tmp.IntByName('Encoding',0));
    end;

    //-----Release Object------
    json.Free;
    PostLog(llMessage, '加载Config.JSON配置文件完毕');
  end else
    PostLog(llError, '程序目录下未找到Config.JSON配置文件！');
end;

procedure TQuoteScanConfig.Save;
var
  json,fs, perFile,Broadcast, binary, db, plugins, monitor,sntxt, kafka:TQJson;
  fconfig: TQuoteFileConfig;
begin
  json := TQJson.Create;

  json.Add('ConnectString', FConnectString);
  json.Add('AutoRemoveDays', FAutoRemoveDays);
  json.Add('CustomSQL', FCustomSQL);

  //save files config
  fs := json.AddArray('Files');
  for fconfig in FQuoteFiles do
  begin
    perFile := TQJson.Create;
    perFile.Add('Path', fconfig.Path);
    perFile.Add('Level', fconfig.Level);
    perFile.Add('StartTime', FormatDateTime('hh:nn:ss', fconfig.StartTime));
    perFile.Add('StopTime', FormatDateTime('hh:nn:ss', fconfig.StopTime));
    perFile.Add('SplitMinute', fconfig.SplitIntervalMinute);
    perFile.Add('MonitorEnable', fconfig.MonitorEnable);
    perFile.Add('MonitorInterval', fconfig.MonitorInterval);
    perFile.Add('MonitorCodes', fconfig.MonitorCodes, jdtString);
    perFile.Add('MonitorTimeRange01Start', FormatDateTime('hh:nn:ss', fconfig.MonitorTimeRange01.StartTime));
    perFile.Add('MonitorTimeRange01End', FormatDateTime('hh:nn:ss', fconfig.MonitorTimeRange01.EndTime));
    perFile.Add('MonitorTimeRange02Start', FormatDateTime('hh:nn:ss', fconfig.MonitorTimeRange02.StartTime));
    perFile.Add('MonitorTimeRange02End', FormatDateTime('hh:nn:ss', fconfig.MonitorTimeRange02.EndTime));
    fs.Add(perFile);
  end;
  //Plugins
  plugins := json.Add('Plugins', jdtObject);
  plugins.Add('Database', FPlugins['Database']);
  plugins.Add('CSV', FPlugins['CSV']);
  plugins.Add('Binary', FPlugins['Binary']);
  plugins.Add('SuningTxt', FPlugins['SuningTxt']);
  plugins.Add('Monitor', FPlugins['Monitor']);
  plugins.Add('Kafka', FPlugins['Kafka']);

  //Binary File Save
  binary := json.Add('BinarySave', jdtObject);
  binary.Add('Enable', FBinarySave);

  //Monitor Config
  monitor := json.Add('Monitor', jdtObject);
  monitor.Add('CustomURL', FMonitorConfig.CustomURL);
  monitor.Add('CustomMessag', FMonitorConfig.CustomMessag);
  monitor.Add('DingdingToken', FMonitorConfig.DingdingToken);
  monitor.Add('WeChatToken', FMonitorConfig.WeChatToken);

  //Kafka Config;
  kafka := json.Add('Kafka', jdtObject);
  kafka.Add('Brokers', FKafkaConfig.Brokers);
  kafka.Add('Topic', FKafkaConfig.Topic);
  kafka.Add('ScanInterval', FKafkaConfig.ScanInterval);


  //Save Broadcast Config
  Broadcast := json.Add('Broadcast', jdtObject);
  Broadcast.Add('Enable', FBroadcastEnable);
  Broadcast.Add('Port', FBroadcastPort);

  //save DBConfig
  db := json.Add('DB');
  DB.Add('DBType', Integer(FDBLink.DBType));
  DB.Add('Host', FDBLink.Host);
  DB.Add('Port', FDBLink.Port);
  DB.Add('UserName', EncryStrHex(FDBLink.Username,'123'));
  DB.Add('Password', EncryStrHex(FDBLink.Password, '123'));
  DB.Add('Database', FDBLink.Database);
  DB.Add('Encoding', Integer(FDBLink.MySQLEncoding));
  //苏宁专用工具配置项
  sntxt := json.Add('SuningTxt');
  sntxt.Add('TodayPath', FSuningTxt.TodayPath);
  sntxt.Add('ArchivePath', FSuningTxt.ArchivePath);
  sntxt.Add('ArchiveTime', FormatDateTime('hh:nn:ss',FSuningTxt.ArchiveTime));
  sntxt.Add('APIHost', FSuningTxt.APIHost);
  sntxt.Add('APIPort', FSuningTxt.APIPort);
  sntxt.Add('APIUserName', EncryStrHex(FSuningTxt.APIUserName,'123'));
  sntxt.Add('APIPassword', EncryStrHex(FSuningTxt.APIPassword,'123'));

  //Write To File
  json.SaveToFile('.\Config.JSON');

  //-----Release Object------
  if Assigned(json) then FreeAndNil(json);
  //json.Free;fs.Free; Broadcast.Free; binary.Free; db.Free; plugins.Free; kafka.free;
end;

{ TWriteDBTool }

procedure TWriteDBTool.AppendRecord(R: PQuoteRecord);
begin
  FUpdater.Append;
  with FUpdater, R^ do
  begin
    FieldByName('Auction').AsString := Market.Auction;
    FieldByName('MarketTime').AsDateTime := Market.Time;
    FieldByName('Time').AsDateTime := Time;
    FieldByName('Code').AsString := GetCode;
    FieldByName('Abbr').AsString := GetAbbr;
    FieldByName('Prev').AsCurrency := Prev;
    FieldByName('Open').AsCurrency := Open;
    FieldByName('High').AsCurrency := High;
    FieldByName('Low').AsCurrency := Low;
    FieldByName('Last').AsCurrency := Last;
    FieldByName('Close').AsCurrency := Close;
    FieldByName('Volume').AsLargeInt := Volume;
    FieldByName('Value').AsCurrency := Value;
    FieldByName('DealCnt').AsInteger := DealCnt;
    FieldByName('PE1').AsFloat := PE1;
    FieldByName('PE2').AsFloat := PE2;
    FieldByName('BuyPrice1').AsCurrency := Buy[1].Price;
    FieldByName('BuyPrice2').AsCurrency := Buy[2].Price;
    FieldByName('BuyPrice3').AsCurrency := Buy[3].Price;
    FieldByName('BuyPrice4').AsCurrency := Buy[4].Price;
    FieldByName('BuyPrice5').AsCurrency := Buy[5].Price;
    FieldByName('BuyVolume1').AsLargeInt := Buy[1].Volume;
    FieldByName('BuyVolume2').AsLargeInt := Buy[2].Volume;
    FieldByName('BuyVolume3').AsLargeInt := Buy[3].Volume;
    FieldByName('BuyVolume4').AsLargeInt := Buy[4].Volume;
    FieldByName('BuyVolume5').AsLargeInt := Buy[5].Volume;
    FieldByName('SellPrice1').AsCurrency := Sell[1].Price;
    FieldByName('SellPrice2').AsCurrency := Sell[2].Price;
    FieldByName('SellPrice3').AsCurrency := Sell[3].Price;
    FieldByName('SellPrice4').AsCurrency := Sell[4].Price;
    FieldByName('SellPrice5').AsCurrency := Sell[5].Price;
    FieldByName('SellVolume1').AsLargeInt := Sell[1].Volume;
    FieldByName('SellVolume2').AsLargeInt := Sell[2].Volume;
    FieldByName('SellVolume3').AsLargeInt := Sell[3].Volume;
    FieldByName('SellVolume4').AsLargeInt := Sell[4].Volume;
    FieldByName('SellVolume5').AsLargeInt := Sell[5].Volume;
    if r.LevelType = LevelTen then
    begin
      FieldByName('BuyPrice6').AsCurrency := Buy[6].Price;
      FieldByName('BuyPrice7').AsCurrency := Buy[7].Price;
      FieldByName('BuyPrice8').AsCurrency := Buy[8].Price;
      FieldByName('BuyPrice9').AsCurrency := Buy[9].Price;
      FieldByName('BuyPrice10').AsCurrency := Buy[10].Price;
      FieldByName('BuyVolume6').AsLargeInt := Buy[6].Volume;
      FieldByName('BuyVolume7').AsLargeInt := Buy[7].Volume;
      FieldByName('BuyVolume8').AsLargeInt := Buy[8].Volume;
      FieldByName('BuyVolume9').AsLargeInt := Buy[9].Volume;
      FieldByName('BuyVolume10').AsLargeInt := Buy[10].Volume;
      FieldByName('SellPrice6').AsCurrency := Sell[6].Price;
      FieldByName('SellPrice7').AsCurrency := Sell[7].Price;
      FieldByName('SellPrice8').AsCurrency := Sell[8].Price;
      FieldByName('SellPrice9').AsCurrency := Sell[9].Price;
      FieldByName('SellPrice10').AsCurrency := Sell[10].Price;
      FieldByName('SellVolume1').AsLargeInt := Sell[6].Volume;
      FieldByName('SellVolume2').AsLargeInt := Sell[7].Volume;
      FieldByName('SellVolume3').AsLargeInt := Sell[8].Volume;
      FieldByName('SellVolume4').AsLargeInt := Sell[9].Volume;
      FieldByName('SellVolume5').AsLargeInt := Sell[10].Volume;
    end;
  end;
  FUpdater.Post;
end;

procedure TWriteDBTool.CommitToDB;
begin
  if FUpdater.RecordCount > 0 then
  begin
    try
      FUpdater.UpdateBatch;
      inc(FUpdateCount, FUpdater.RecordCount);
    except
    end;
    FUpdater.Requery();
  end;
end;

procedure TWriteDBTool.doStart;
var
  tname:string;

  function BuildInitSQLScript:string;
  begin
    result := ReplaceStr(INIT_TBL_SQL, '_TBLNAME_', tname);
    if FLevel = 10 then
      result := ReplaceStr(result, 'TBL_EMPTY', 'TBL10_EMPTY');
  end;
begin

  tname := FTblName + '_'+FormatDateTime('yyyymmdd', now);

  if FConnection.Connected then FConnection.Close;

  FConnection.ConnectionString := FConnectionString;
  FConnection.LoginPrompt := False;

  try
    FConnection.Open;
    FUpdater.Connection := FConnection;
    FUpdater.SQL.Text := BuildInitSQLScript;
    FUpdater.ExecSQL;
    FUpdater.Close;
    FUpdater.LockType := ltBatchOptimistic;
    FUpdater.CursorType := ctStatic;
    FUpdater.Prepared := True;
    FUpdater.EnableBCD := True;
    FUpdater.CacheSize := 500;
    FUpdater.SQL.Text := 'select top 0 * from ' +tname;
    FUpdater.Open;
  except
    on e:Exception do
    begin
      PostLog(llError, '执行SQL语句出现错误，[%s]', [e.Message]);
    end;
  end;

end;

procedure TWriteDBTool.doStop;
begin

end;

procedure TWriteDBTool.doWork;
var
  k:Integer;
  p:pointer;
begin
  //扫描行情入库队列
  while Active or (FChangeList.Size>0) do
  begin
    //从队列中取出记录，每次取200条
    k := 0;
    while FChangeList.DeQueue(p) do
    begin
      AppendRecord(p);
      FreeMem(p);
      inc(k);
      if k >= 500 then break; //批量写入500条记录
    end;

    //写入数据库
    CommitToDB;

    sleep(10);
  end;

  //提交剩余记录集
  CommitToDB;
end;

function TWriteDBTool.GetToolName: string;
begin
  result := 'DB写入'
end;

procedure TWriteDBTool.Init;
begin
  FConnection := TADOConnection.Create(nil);
  FUpdater := TADOQuery.Create(nil);
end;

procedure TWriteDBTool.Setup(AConnectionString, ATblName: string; const ALevel: Integer);
begin
  FConnectionString := AConnectionString;
  FTblName := ATblName;
  FLevel := ALevel;
end;

procedure TWriteDBTool.Uninit;
begin
  FUpdater.Free;
  FConnection.Free;
end;

{ TWriteCSVTool }

constructor TWriteCSVTool.Create(AScanConfig: TQuoteScanConfig; AFileConfig: TQuoteFileConfig);
begin
  inherited;
  FTblName := Uppercase(TPath.GetFileNameWithoutExtension(AFileConfig.Path));
  if UpperCase(FTblName)='FUND_HQ' then
    FTblName := 'FUND_B'
end;

procedure TWriteCSVTool.doStart;
var
  fn:string;
begin
  fn := FTblName+'_'+FormatDateTime('yyyymmdd', now)+'.CSV';
  if TFile.Exists(fn) then
  begin
    FCSVWriter := TStreamWriter.Create( TFileStream.Create(fn, fmOpenReadWrite or fmShareDenyWrite ), TEncoding.UTF8);
    FCSVWriter.BaseStream.Seek(0, soFromEnd);
  end else
  begin
    FCSVWriter := TStreamWriter.Create( TFileStream.Create(fn, fmCreate or fmShareDenyWrite) , TEncoding.UTF8);
    if SameText( FTblName, 'Fund') then
      FCSVWriter.WriteLine('DealTime,Code,Last,Change')
    else
      FCSVWriter.WriteLine('MTime,DealTime,Code,Abbr,Prev,Open,High,Low,Close,Volume,Value,B1P,B1V,S1P,S1V');
  end;

  FCSVWriter.OwnStream;
end;

procedure TWriteCSVTool.doStop;
begin
  FCSVWriter.Free;
end;

procedure TWriteCSVTool.doWork;
var
  p:pointer;
  k:integer;
begin
  //扫描行情入库队列
  while Active or (FChangeList.Size>0) do
  begin
    //从队列中取出记录，每次取500条
    k := 0;
    while FChangeList.DeQueue(p) do
    begin
      WriteRecord(p);
      FreeMem(p);
      inc(k);
      if k >= 500 then break; //批量写入500条记录
    end;

    sleep(10);
  end;
end;

function TWriteCSVTool.GetToolName: string;
begin
  result := 'CSV工具';
end;

procedure TWriteCSVTool.Init;
begin
end;

procedure TWriteCSVTool.Uninit;
begin

end;

procedure TWriteCSVTool.WriteFundEValuetionRecord(R: PQuoteRecord);
begin
  FCSVWriter.WriteLine(Format(
    '%s,%s,%s,%.3f,%.6f',
    [
    FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', r.Time),
    r.GetCode, r.GetAbbr, r.Last, r.PE1
  ]));
end;

procedure TWriteCSVTool.WriteRecord(R: PQuoteRecord);
begin
  if Pos('fund', lowercase(FTblName))>0 then
    WriteFundEValuetionRecord(r)
  else
  FCSVWriter.WriteLine(Format(
    '%s,%s,%s,%s,%.3f,%.3f,%.3f,%.3f,%.3f,%d,%.3f,%.3f,%d,%.3f,%d',
    [FormatDateTime('yyyy-mm-dd hh:nn:ss', r.Market.Time),
    FormatDateTime('yyyy-mm-dd hh:nn:ss', r.Time),
    r.GetCode, r.GetAbbr,
    r.Prev, r.Open, r.High, r.Low, r.Close,
    r.Volume, r.Value,
    r.Buy[1].Price, r.Buy[1].Volume,
    r.Sell[1].Price, r.Sell[1].Volume
  ]));
end;

{ TMonitorTool }

procedure TMonitorTool.CheckTimer(AJob: PQJob);
var
  perItem:TStockState;
begin
  if not FileConfig.MonitorEnable then Exit;

  if TimeInRange(Now, FileConfig.MonitorTimeRange01.StartTime, FileConfig.MonitorTimeRange01.EndTime)
    or TimeInRange(Now, FileConfig.MonitorTimeRange02.StartTime, FileConfig.MonitorTimeRange02.EndTime) then
  begin
    for perItem in FCodeList.Values do
    begin
      //非交易时间不做任何处理
      //if not perItem.MarketActive then continue;
      //检测行情更新间隔是否超过指定的秒数
      if (DateUtils.SecondsBetween(now, perItem.LastModify) > FileConfig.MonitorInterval) and (not perItem.Alarmed) then
      begin
        PostAlarm(perItem);
        perItem.Alarmed := True;
      end;
    end;
  end;
end;

constructor TMonitorTool.Create(AScanConfig: TQuoteScanConfig; AFileConfig: TQuoteFileConfig);
var
  perCode:string;
  defvalue:TStockState;
begin
  inherited;
  for perCode in SplitString(AFileConfig.MonitorCodes,',') do
  begin
    defvalue := TStockState.Create;
    defvalue.MarketActive := False;
    defvalue.LastModify := now;
    defvalue.Alarmed := False;
    defvalue.Code := Trim(perCode);
    FCodeList.AddOrSetValue(Trim(perCode), defvalue);
  end;
end;

procedure TMonitorTool.doStart;
begin
  //加载需要监控的代码列表
  FCheckTimerHandle := Workers.Post(CheckTimer, 3*10000, nil);
end;

procedure TMonitorTool.doStop;
begin
  Workers.ClearSingleJob(FCheckTimerHandle);
end;

procedure TMonitorTool.doWork;
var
  p:pointer;
  q:PQuoteRecord absolute p;
  stock:TStockState;
begin
  while Active or (FChangeList.Size>0) do
  begin
    while FChangeList.DeQueue(p) do
    begin
      if FCodeList.TryGetValue(q.GetCode, stock) then
      begin
        if stock.Alarmed then PostAlarm(stock, False); //TODO:发送行情恢复正常通知
        stock.MarketActive := q.Market.Status = 'T';
        stock.LastModify := now;
        stock.Alarmed := False;
      end;
      FreeMem(p);
    end;

    sleep(20);
  end;

end;

function TMonitorTool.GetToolName: string;
begin
  result := '行情监测';
end;

procedure TMonitorTool.Init;
begin
  FCodeList := TObjectDictionary<string, TStockState>.Create(100);
  FHttp := TclHttp.Create(nil);
end;

procedure TMonitorTool.PostAlarm(AState: TStockState; bError:Boolean=True);
var
  alarm: TAlarm;
  msg:string;
begin
  CoInitialize(nil);

  if bError then
    msg := Format('行情源[%s]中代码[%s]已超过%d秒未更新,CheckTime:%s', [TPAth.GetFileName(FileConfig.Path), AState.Code, FileConfig.MonitorInterval, FormatDateTime('hh:nn:ss',now)])
  else
    msg := Format('行情源[%s]中代码[%s]已于间隔%d秒后恢复更新！CheckTime:%s',[TPAth.GetFileName(FileConfig.Path), AState.Code, SecondsBetween(now, AState.LastModify), FormatDateTime('hh:nn:ss',now)]);

  PostLog(llWarning, msg);

  alarm.Title := '行情异常';
  alarm.Msg := Msg;
  //TODO:CustomURL报警

  //Dingding机器人报警
  if Trim(ScanConfig.Monitor.DingdingToken) <> '' then
    alarm.SendByDingText(Trim(ScanConfig.Monitor.DingdingToken));

  //WeChat报警
  if Trim(ScanConfig.Monitor.WeChatToken) <> '' then
    alarm.SendByWeChat(Trim(ScanConfig.Monitor.WeChatToken));

  //TODO:SMTP报警
end;

procedure TMonitorTool.Uninit;
begin
  FCodeList.Free;
  FHttp.Free;
end;

{ TRealSliceTool }

procedure TRealSliceTool.CommitToDB;
var
  p:pointer;
  rec:PSlice;
begin
  CoInitialize(nil);
  while Active or (FSliceList.Size>0) do
  begin
    while FSliceList.DeQueue(p) do
    begin
      rec := p;
      FUpdater.Append;
      with FUpdater do
      begin
        FieldByName('StockCode').AsString := FCodePreFix + Trim(rec.StockCode);
        FieldByName('SliceTime').AsDateTime := rec.SliceTime;
        FieldByName('SliceMinute').AsString := FormatDateTime('hh:nn:ss', rec.Time);
        FieldByName('PrevPirce').AsCurrency := rec.Prev;
        FieldByName('OpenPrice').AsCurrency := rec.Open;
        FieldByName('LowPrice').AsCurrency := rec.Low;
        FieldByName('HighPrice').AsCurrency := rec.High;
        FieldByName('ClosePrice').AsCurrency := rec.Close;
        FieldByName('Volume').AsLargeInt := rec.Volume;
        FieldByName('Value').AsCurrency := rec.Value;
      end;
      FUpdater.Post;
      FreeMem(rec);
    end;

    if FUpdater.RecordCount > 0 then
    begin
      try
        FUpdater.UpdateBatch;
        inc(FUpdateCount, FUpdater.RecordCount);
      except
      end;
      FUpdater.Requery();
    end;
    sleep(200);
  end;
end;

procedure TRealSliceTool.doSlice(ptrTick: PQuoteRecord);
var
  tmpList:TStockTicks;
  tick: TQuoteRecord;
  code:string;
  function compareTick(t1,t2:TDateTime):boolean;
  var h1,h2,m1,m2,s1,s2,ms1,ms2:word;
  begin
    DecodeTime(t1,h1,m1,s1,ms1);
    DecodeTime(t2,h2,m2,s1,ms2);
    result := (h1 = h2) and (m1 = m2);
  end;
begin
  //取出对应的股票TICK列表
  code := trim(ptrTick.Code);
  if not FStockList.TryGetValue(code, tmpList) then
  begin
    tmpList := TStockTicks.Create;
    FStockList.Add(code, tmpList);
  end;

  //队列为空，则加入队列后退出
  if not tmpList.IsEmpty then
  begin
    if not compareTick(ptrTick.Time, tmpList.EndRec.Time) then
      PushSlice(tmpList.Pack);
  end;
  tmpList.AddTick(ptrTick);
end;

procedure TRealSliceTool.doStart;
var
  tbname, buildtblSQL:string;
begin
  FCodePreFix := '';
  if UpperCase(TPath.GetFileNameWithoutExtension(SourceFile)) = 'SJSHQ' then FCodePreFix := 'SZ';
  if UpperCase(TPath.GetFileNameWithoutExtension(SourceFile)) = 'MKTDT00' then FCodePreFix := 'SH';


  FStockList.Clear;
  tbname := 'Slice_'+FormatDateTime('yyyymmdd', now);
  buildtblSQL := ReplaceStr(INIT_SLICE_TBL_SQL, '_TBLNAME_', tbname);
  if FConnection.Connected then FConnection.Close;

  FConnection.ConnectionString := FConnectionString;
  FConnection.LoginPrompt := False;

  try
    FConnection.Open;
    FUpdater.Connection := FConnection;
    FUpdater.SQL.Text := buildtblSQL;
    FUpdater.ExecSQL;
    FUpdater.Close;
    FUpdater.LockType := ltBatchOptimistic;
    FUpdater.CursorType := ctStatic;
    FUpdater.Prepared := True;
    FUpdater.EnableBCD := True;
    FUpdater.CacheSize := 500;
    FUpdater.SQL.Text := 'select top 0 * from ' +tbname;
    FUpdater.Open;
  except
    on e:Exception do
    begin
      PostLog(llError, '执行SQL语句出现错误，[%s]', [e.Message]);
    end;
  end;
end;

procedure TRealSliceTool.doStop;
var
  perCode:string;
  slice:TSlice;
begin
  while FChangeList.Size>0 do sleep(100);

  for perCode in FStockList.Keys do
  begin
    slice := FStockList[perCode].Pack;
    if not slice.Empty then
      PushSlice(slice);
  end;

  FStockList.Clear;
end;

procedure TRealSliceTool.doWork;
var
  p:pointer;
  q:PQuoteRecord absolute p;
  stock:TStockState;
begin
  FWriteDBJob := TThread.CreateAnonymousThread(CommitToDB);
  FWriteDBJob.FreeOnTerminate := True;
  FWriteDBJob.Start;

  while Active or (FChangeList.Size>0) do
  begin
    while FChangeList.DeQueue(p) do
    begin
      doSlice(p);
      FreeMem(p);
    end;
    sleep(10);
  end;
end;

procedure TRealSliceTool.Init;
begin
  FStockList := TDictionary<string, TStockTicks>.Create(2000);
  FSliceList := TSafeQueue.Create;
  FConnection := TADOConnection.Create(nil);
  FUpdater := TADOQuery.Create(nil);
end;

procedure TRealSliceTool.PushSlice(ARec: TSlice);
var
  tmp:PSlice;
begin
  New(tmp);
  move(ARec, tmp^, SizeOf(TSlice));
  FSliceList.EnQueue(tmp);
end;

procedure TRealSliceTool.Setup(AConnectionString: string);
begin
  FConnectionString := AConnectionString;
end;

procedure TRealSliceTool.Uninit;
begin
  FStockList.Free;
  FSliceList.Free;
  FUpdater.Free;
  FConnection.Free;
end;

{ TStockTicks }

procedure TStockTicks.AddTick(ATick: PQuoteRecord);
begin
  if not FFlag and (FTickList.Count=0) then
  begin
    FLastRec := ATick^;
    FFlag := True;
  end;

  FTickList.Add(ATick^);
end;

function TStockTicks.Pack: TSlice;
var
  h,m,s,ms:word;
  perTick:TQuoteRecord;
  code:AnsiString;
begin
  FillChar(result, SizeOf(TSlice), 0);

  result.Empty := True;
  if IsEmpty then Exit(Result);

  result.Empty := False;
  code := trim(FTickList.Last.Code);
  Move(Code[1], result.StockCode[0], Length(Code));
  result.SliceTime := Now;

  //最后一笔记录的时间
  DecodeTime(FTickList.Last.Time, h, m, s, ms);
  Result.Time := EncodeTime(h,m,0,0);


  //确认开盘价与收盘价
  result.Prev := FTickList.First.Prev;
  Result.Open := FTickList.First.Close;
  Result.Close := FTickList.Last.Close;

  //确认最高价与最低价
  Result.High := FTickList.First.Close;
  Result.Low  := FTickList.First.Close;
  for perTick in FTickList do
  begin
    if perTick.Close>Result.High then Result.High := perTick.Close;
    if perTick.Close<Result.Low  then Result.Low  := perTick.Close;
  end;

  //确认成交量与成交金额
  result.Volume := FTickList.Last.Volume - FLastRec.Volume;
  result.Value  := FTickList.Last.Value  - FLastRec.Value;

  //更新最后一笔记录
  FLastRec := FTickList.Last;

  //清空
  FTickList.Clear;
end;

constructor TStockTicks.Create;
begin
  FTickList := TList<TQuoteRecord>.Create;
  FFlag := False;
end;

destructor TStockTicks.Destroy;
begin
  FTickList.Free;
  inherited;
end;

function TStockTicks.GetEndRec: TQuoteRecord;
begin
  result := FTickList.Last;
end;

function TStockTicks.IsEmpty: Boolean;
begin
  result := Self.FTickList.Count = 0;
end;

{ TSuningTxtTool }
function FileListSort(List: TStringList; Index1, Index2: Integer): Integer;
begin
  result := CompareStr(List[Index1], List[Index2]);
  result := result * -1;
end;

procedure TSuningTxtTool.AddFileInfo(AFileName: string);
var
  tmp  : string;
  info : TSuningTxtInfo;
  slist: TStringList;
begin
  if Trim(AFileName)='' then Exit;
  tmp := TPath.GetFileName(AFileName);
  //若已存在则退出
  if FFileInfos.TryGetValue(tmp, info) then Exit;
  //新增文件名信息
  info.FileName := tmp;
  info.FileCreateDate := Now;
  FFileInfos.Add(tmp, Info);

  //写入文件名列表信息至文件
  slist := TStringList.Create;
  for info in FFileInfos.Values do
    slist.Add(info.ToString);
  slist.CustomSort(FileListSort);
  if slist.Count>0 then
  begin
    slist.SaveToFile(FFileInfoFN, TEncoding.UTF8);
  end;
  slist.Free;
end;

procedure TSuningTxtTool.doStart;
var
  path,perInfo : string;
  perLine      : string;
  tmp          : TStringList;
  tmpInfo      : TSuningTxtInfo;
  k :double;
  j :tdatetime;
begin
  FLastFileName := '';
  FCurrFileStream := nil;
  //当日目录创建
  path := TPath.GetFileNameWithoutExtension(FileConfig.Path);
  if UpperCase(path) =  'FUND_HQ' then path := 'FUND_B';
  
  FTodayPath := TPath.GetFullPath(TPath.Combine(ScanConfig.SuningTxt.TodayPath, path));
  TDirectory.CreateDirectory(FTodayPath);

  //文件名列表信息
  if UpperCase(path)='FUND_HQ' then path := 'FUND_B';
  FFileInfoFN := TPath.Combine(FTodayPath, Format('%s_filenames.txt', [path]));

  //读取文件列表
  FFileInfos.Clear;
  if TFile.Exists(FFileInfoFN) then
  begin
    tmp := TStringList.Create;
    tmp.LoadFromFile(FFileInfoFN, TEncoding.UTF8);
    for perLine in tmp do
    begin
      if perLine <> '' then
      begin
        tmpInfo.SetValue(perLine);
        FFileInfos.Add(tmpInfo.FileName, tmpInfo);
      end;
    end;
    tmp.Free;
  end;
  FCurrentID := DateUtils.SecondsBetween(Now, 36526)*1000; //距2000-1-1以来的毫秒数
end;

procedure TSuningTxtTool.doStop;
begin
  FLastFileName := '';
  if Assigned(FCurrFileStream) then
    FreeAndNil(FCurrFileStream);
end;

procedure TSuningTxtTool.doWork;
var
  p:pointer;
  k:integer;
begin
  //扫描行情入库队列
  while Active or (FChangeList.Size>0) do
  begin
    //从队列中取出记录，每次取500条
    k := 0;
    while FChangeList.DeQueue(p) do
    begin
      //非当日数据过滤
      if DateOf( PQuoteRecord(p).Time ) = today then
        WriteRecord(p);
      FreeMem(p);
      inc(k);
      if k >= 500 then break; //批量写入500条记录
    end;

    sleep(10);
  end;
end;

function TSuningTxtTool.GetCurrentID: string;
begin
  result := IntToStr(FCurrentID);
  inc(FCurrentID);
end;

function TSuningTxtTool.GetToolName: string;
begin
  result := 'SuNing-CSV专版工具'
end;

procedure TSuningTxtTool.Init;
begin
  FFileInfos := TDictionary<string, TSuningTxtInfo>.Create;
end;

procedure TSuningTxtTool.Uninit;
begin
  FFileInfos.Free;
end;

procedure TSuningTxtTool.WriteRecord(const R: PQuoteRecord);
var
  st,mktime:TDateTime;
  k,j:integer;
  fn:string;
  y,m,d:word;
  tmp:TStringList;
  str:AnsiString;
  u8:UTF8String;
begin
  st := TimeOf(FileConfig.StartTime);
  mktime := TimeOf(r.Market.Time);
  k := Max(MinutesBetween(mktime, st),0);
  j := k div  FIleConfig.SplitIntervalMinute;
  st := IncMinute(st, j*FIleConfig.SplitIntervalMinute);
  DecodeDate(now, y,m,d);
  st := RecodeDate(st,y,m,d);
  fn := TPath.GetFileNameWithoutExtension(FileConfig.Path);
  if UpperCase(fn)='FUND_HQ' then fn := 'FUND_B';
  fn := TPath.Combine(FTodayPath, fn+'_'+FormatDateTime('yyyymmddhhnn', st)+'.txt');
  if fn<>FLastFileName then
  begin
    FLastFileName := fn;
    if Assigned(FCurrFileStream) then
      FCurrFileStream.Free;
    if not TFile.Exists(FLastFileName) then
    begin
      FCurrFileStream := TFile.Create(FLastFileName);
      FCurrFileStream.Free;
    end;
    FCurrFileStream := TFileStream.Create(FLastFileName, fmOpenWrite or fmShareDenyNone);
    AddFileInfo(FLastFileName);
  end;
  tmp := TStringList.Create;
  tmp.Add(GetCurrentID);
  tmp.Add(r.Market.Auction);
  tmp.Add(FormatDatetime('yyyy-mm-dd hh:nn:ss', r.Market.Time));
  tmp.Add(FormatDatetime('yyyy-mm-dd hh:nn:ss', r.Time));
  tmp.Add(r.GetCode);
  tmp.Add(r.GetAbbr);
  tmp.Add(FloatToStr(r.Prev));
  tmp.Add(FloatToStr(r.Open));
  tmp.Add(FloatToStr(r.High));
  tmp.Add(FloatToStr(r.Low));
  tmp.Add(FloatToStr(r.Last));
  tmp.Add(FloatToStr(r.Close));
  tmp.Add(IntToStr(r.Volume));
  tmp.Add(FloatToStr(r.Value));
  tmp.Add(IntToStr(r.DealCnt));
  tmp.Add(FloatToStr(r.PE1));
  tmp.Add(FloatToStr(r.PE2));
  tmp.Add(FloatToStr(r.Buy[1].Price));
  tmp.Add(FloatToStr(r.Buy[2].Price));
  tmp.Add(FloatToStr(r.Buy[3].Price));
  tmp.Add(FloatToStr(r.Buy[4].Price));
  tmp.Add(FloatToStr(r.Buy[5].Price));
  tmp.Add(IntToStr(r.Buy[1].Volume));
  tmp.Add(IntToStr(r.Buy[2].Volume));
  tmp.Add(IntToStr(r.Buy[3].Volume));
  tmp.Add(IntToStr(r.Buy[4].Volume));
  tmp.Add(IntToStr(r.Buy[5].Volume));
  tmp.Add(FloatToStr(r.Sell[1].Price));
  tmp.Add(FloatToStr(r.Sell[2].Price));
  tmp.Add(FloatToStr(r.Sell[3].Price));
  tmp.Add(FloatToStr(r.Sell[4].Price));
  tmp.Add(FloatToStr(r.Sell[5].Price));
  tmp.Add(IntToStr(r.Sell[1].Volume));
  tmp.Add(IntToStr(r.Sell[2].Volume));
  tmp.Add(IntToStr(r.Sell[3].Volume));
  tmp.Add(IntToStr(r.Sell[4].Volume));
  tmp.Add(IntToStr(r.Sell[5].Volume));
  //-----------
  str := tmp.Join('|');
  tmp.Free;
  FCurrFileStream.Seek(0, soEnd);
  u8 := str; //转码为utf8编码并写入
  FCurrFileStream.Write(u8[1], Length(u8));
  str := #13#10;
  u8 := str;//转码为utf8编码并写入
  FCurrFileStream.Write(u8[1], Length(u8));
  inc(FUpdateCount);
end;

{ TSuningTxtInfo }

function TSuningTxtInfo.SetValue(AValue: String):boolean;
var
  Str:TStringDynArray;
  FSetting:TFormatSettings;
begin
  result := False;

  Str := SplitString(AValue, '|');
  if Length(Str) > 1 then
  begin
    FileName := Str[0];
    FSetting := TFormatSettings.Create(LOCALE_USER_DEFAULT);
    FSetting.LongDateFormat:='yyyy-MM-dd';
    FSetting.LongTimeFormat:='hh:mm:ss';
    FSetting.ShortDateFormat:='yyyy-MM-dd';
    FSetting.ShortTimeFormat := 'hh:mm:ss';
    FSetting.DateSeparator:='-';
    FSetting.TimeSeparator:=':';
    FileCreateDate := StrToDateTime(str[1], FSetting);
  end;
end;

function TSuningTxtInfo.ToString: string;
begin
  result := FileName+'|'+FormatDateTime('yyyy-mm-dd hh:NN:ss',self.FileCreateDate);
end;

{ TStringsHelper }

function TStringsHelper.Join(const Splitter: string): string;
var
  i:Integer;
  sb:TStringBuilder;
begin
  sb := TStringBuilder.Create;
  for i := 0 to Self.Count - 1 do
  begin
   sb.Append(self[i]);
   if i < Self.Count - 1 then
     sb.Append(Splitter);
  end;
  result := sb.ToString;
  sb.Free;
end;

end.
