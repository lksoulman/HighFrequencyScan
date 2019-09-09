unit uSyncDefine;

interface

uses
  Classes, DateUtils, SysUtils;

type

  //同步状态
  TSyncState = (ssWaitting, ssWorking, ssError);

  //同步类型
  TSyncType = (stMSSQL=0, stMySQL, stOracle, stSQLite, stLocalDB);

  //同步项
  ISyncItem = Interface
  ['{57AC2209-1C9E-47E7-97F3-F6617FFDEF6C}']
    //function GetOrder:Integer;
    function Sync: Integer;
    function ElapsedSecond: Integer;
    function ItemName: string;
    function LastTime:TDateTime;
    function SyncProgress: Integer;
    function SyncState: TSyncState;
  end;

  TSyncItemClass = class of TSyncItem;
  TSyncItem = class(TInterfacedObject, ISyncItem)
  private
    FItemName:string;
  protected
    FSyncProgress:Integer;
    FLastTime: TDatetime;
    FSyncState: TSyncState;
    function doSync: Integer; virtual; abstract;
  public
    constructor Create(AItemName:string);
    destructor Destroy; override;
    {ISyncItem}
    function Sync: Integer;
    function ElapsedSecond: Integer;
    function ItemName: string;
    function LastTime:TDateTime;
    function SyncProgress: Integer;
    function SyncState: TSyncState;
  end;

  //同步列表
  ISyncItemList = interface
  ['{F83736A7-05AD-4392-8DC9-7BEE35347E21}']
    function Count: Integer;
    function GetItem(AIndex:Integer):ISyncItem;
    procedure Reset;
  end;

  //同步接口定义
  ISync = Interface
  ['{26685704-31A6-4153-A817-6E96C9C8562C}']
    procedure Start;
    procedure Stop;
    function IsRunning:boolean;
    function SyncName:string;
    function SyncVersion:string;
    function LastBeginTime:TDatetime;
    function LastEndTime:TDateTime;
    function SyncType: TSyncType;
    function List: ISyncItemList;
  end;

  //数据库同步接口定义
  IDBSync = Interface(ISync)
  ['{B132390D-8996-4E40-AF73-10C74EEA6F60}']
    procedure CheckIntegrity; //检查本地数据库是否完整
    procedure CheckStruct;    //检查本地数据库的结构
  end;

  //文件同步接口定义
  IFileSync = Interface(ISync)
  ['{078C785F-FCAF-42C6-8741-A296BE579F77}']
  end;

  //同步列表实现类
  TSyncList = class(TInterfacedObject,ISyncItemList)
  protected
    FList:TInterfaceList;
  public
    constructor Create;
    destructor Destroy; override;
    property List: TInterfaceList read FList;
    {ISyncItemList}
    function Count: Integer;
    function GetItem(AIndex:Integer):ISyncItem;
    procedure Reset;
  end;

  //同步实现基类
  TSyncBase = class(TInterfacedObject, ISync)
  private
    function doGetSyncName:string;
  protected
    FSyncList: ISyncItemList;
    FIsRunning: Boolean;
    FLastBeginTime:TDateTime;
    FLastEndTime: TDateTime;
    function doGetSyncType: TSyncType;virtual; abstract;
    function doGetSyncVersion: string; virtual;
    procedure doStart(); virtual; abstract;
    procedure doStop(); virtual; abstract;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    function IsRunning:boolean;
    function SyncName:string;
    function SyncVersion:string;
    function SyncType: TSyncType;
    function List: ISyncItemList;
    function LastBeginTime:TDatetime;
    function LastEndTime:TDateTime;
  end;

  function Capacity2Str(ABytes:Cardinal):string;
  function SpanSecond2Str(ASecond:double):string;
const
    // (stMSSQL, stMySQL, stOracle, stSQLite, stFile);
    C_SyncNames : array[stMSSQL..stLocalDB] of string =('MSSQL','MySQL','Oracle','SQLite','LocalDB');
    
implementation

{ TSyncBase }

constructor TSyncBase.Create;
begin
  FSyncList := nil;
end;

destructor TSyncBase.Destroy;
begin
  FSyncList := nil;
  inherited;
end;

function TSyncBase.doGetSyncName: string;
begin
  result := C_SyncNames[Self.SyncType];
end;

function TSyncBase.doGetSyncVersion: string;
begin
  result := 'V.10';
end;

function TSyncBase.IsRunning: boolean;
begin
  result := FIsRunning;
end;

function TSyncBase.LastBeginTime: TDatetime;
begin
  result := FLastBeginTime;
end;

function TSyncBase.LastEndTime: TDateTime;
begin
  result := FLastEndTime;
end;

function TSyncBase.List: ISyncItemList;
begin
  result := FSyncList;
end;

procedure TSyncBase.Start;
begin
  if fIsRunning then exit;
  try
    fIsRunning := True;
    FLastBeginTime := Now;
    doStart;
  finally
    fIsRunning := False;
    FLastEndTime := now;
  end;
end;

procedure TSyncBase.Stop;
begin
  if not FisRunning then exit;
  try
    doStop();
  finally
    FLastEndTime := Now;
  end;
end;

function TSyncBase.SyncName: string;
begin
  result := self.doGetSyncName;
end;

function TSyncBase.SyncType: TSyncType;
begin
  result := self.doGetSyncType;
end;

function TSyncBase.SyncVersion: string;
begin
  result := doGetSyncVersion;
end;

{ TSyncList }

function TSyncList.Count: Integer;
begin
  result := 0;
end;

constructor TSyncList.Create;
begin
  FList := TInterfaceList.Create;
end;

destructor TSyncList.Destroy;
begin
  Flist.Clear;
  FList.Free;
  inherited;
end;

function TSyncList.GetItem(AIndex: Integer): ISyncItem;
begin
  result := FList[AIndex] as ISyncItem;
end;


procedure TSyncList.Reset;
begin
  FList.Clear;  
end;

{ TSyncItem }

constructor TSyncItem.Create(AItemname:string);
begin
  fItemname := AItemName;
end;

destructor TSyncItem.Destroy;
begin
  inherited;
end;

function TSyncItem.ElapsedSecond: Integer;
begin
  if FSyncState = ssWorking then
    result := DateUtils.SecondsBetween(Now, fLastTime)
  else
    result := 0;
end;

function TSyncItem.ItemName: string;
begin
  result := FItemName;
end;

function TSyncItem.LastTime: TDateTime;
begin
  result := FLasttime;
end;

function TSyncItem.Sync: Integer;
begin
  result := 0;
  FlastTime := now;
  self.FSyncState := ssWorking;
  try
    result := doSync();
  except
    fSyncState := ssError;
  end;
end;

function TSyncItem.SyncProgress: Integer;
begin
  result := Self.FSyncProgress;
end;

function TSyncItem.SyncState: TSyncState;
begin
  result := Self.FSyncState;
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

function SpanSecond2Str(ASecond:double):string;
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

end.
