unit uDBSync;

interface

uses
  OracleUniProvider, SQLServerUniProvider, MySQLUniProvider,SQLiteUniProvider,
  uni, uniLoader, DbAccess, OLEDBAccessUni, OraDataTypeMapUni,
  {$IFDEF FPC}
  paswstring,fgl,
  {$ELSE}
  Generics.Collections, SysUtils, DateUtils, StrUtils, RegularExpressions, SyncObjs,
  {$ENDIF}
  uSyncDefine, uLog,
  Classes, DB;

type

  TDBLink = class;
  TOraConnMode = (ocmNormal=0,ocmSysOper=1,ocmSysDBA=2,ocmSysASM=3);
  TMySQLEncoding = (myGKB=0, myUTF8=1);
  TDBObjType = (dotTable=1, dotView=2, dotUnknow=99);


  TFieldInfo = class(TObject)
  strict private
    FLength: integer;
    FFieldName: string;
    FFieldType: string;
    FPrecesion: Integer;
    FScale: Integer;
    FNullable: boolean;
    procedure SetFieldType(const Value: string);
  public
    property FieldName:string read FFieldName write FFieldName;
    property FieldType:string read FFieldType write SetFieldType;
    property Length:integer read FLength write FLength;
    property Precesion:Integer read FPrecesion write FPrecesion;
    property Scale:Integer read FScale write FScale;
    property Nullable:boolean read FNullable write FNullable;
    function ToSQLScript(ATargetDBType:TSyncType):string;
    function ToString: string; override;
  end;

  //索引字段
  TIndexField = class(TObject)
  public
    FieldName:string;
    ASC: boolean;
    function ToString:string; override;
  end;

  {$IFDEF FPC}
  TIndexFields= specialize TFPGList<TIndexField>;
  {$ELSE}
  TIndexFields= TObjectList<TIndexField>;
  {$ENDIF}

  //表索引
  TIndexInfo = class
  strict private
    FIndexName:string;
    FUnique: Boolean;
    FIndexFields: TIndexFields;
  public
    constructor Create;
    destructor Destroy; override;
    property IndexName:string read FIndexName write FIndexName;
    property Unique:boolean read FUnique write FUnique;
    property IndexFields: TIndexFields read FIndexFields;
  end;

  //表空间使用情况
  TTableSpaceInfo = packed record
    Valid: Boolean;
    TotalRow:Integer;
    SpaceUsedKB: Integer;
  end;

  {$IFDEF FPC}
  TFieldList = specialize TFPGList<TFieldInfo>;
  TIndexList = specialize TFPGList<TIndexInfo>;
  {$ELSE}
  TFieldList= TObjectList<TFieldInfo>;
  TIndexList = TObjectList<TIndexInfo>;
  {$ENDIF}
  TTableInfo = class(TObject)
  strict private
    FTableName: string;
    FFieldList: TFieldList;
    FHasSlave:boolean;
    FHasImageField:boolean;
    FIndexList: TIndexList;
    FSpaceInfo: TTableSpaceInfo;
    FOwner:TDBLink;
    FIsView: boolean;
    procedure CreateIndex(Target:TDBLink; ATblName, AIndexName:string; bUNIQUE:boolean; AFields:array of string);
    procedure BuildTable(Target:TDBLink; ATableName:string);
    function FieldExist(AFieldName:string):boolean;
  public
    class function TblIsExist(Target: TDBLink; const ATblName:string):boolean;
    constructor Create(AOwner:TDBLink);
    destructor Destroy; override;
    function GetDLL(ATarget:TDBLink):string;
    procedure CreateTbl(Target: TDBLink; ANewTableName:string='');
    property Fields:TFieldList read FFieldList;
    property HasImageField:boolean read FHasImageField write FHasImageField;
    property HasSlave:boolean read FHasSlave write FHasSlave;
    property IndexList: TIndexList read FIndexList;
    property SpaceInfo: TTableSpaceInfo read FSpaceInfo write FSpaceInfo;
    property TableName: string read FTableName write FTableName;
    property IsView:boolean read FIsView write FIsView;
  end;

  TFieldMapHelper = class
  strict private
    FMapList: TDictionary<string, string>;
    procedure AddMap(AType:TSyncType; ASrc, ATarget:string);
  public
    constructor Create;
    destructor Destroy; override;
    function Convert(AFieldInfo:TFieldInfo; ATargetDBType:TSyncType):string;
  end;

  {$IFDEF FPC}
  TTables= specialize TFPGMap<string,TTableInfo>;
  {$ELSE}
  TTables = TDictionary<string,TTableInfo>;
  {$ENDIF}

  ISyncTable = Interface(ISyncItem)
    function ServerGetDataSQL:string;
    function ExpireDate:TDateTime;
  end;

  TSyncTable=class(TSyncItem, ISyncTable)
  protected
    FServerGetDataSQL:string;
    FExpireDate:TDateTime;
    function MergeData(ASource:TDataset):boolean; virtual; abstract;
    function DoSync: Integer; override;
    //ISyncTable
    function ServerGetDataSQL:string;
    function ExpireDate:TDateTime;
  end;

  //数据库同步参数
  TDBSyncOption = class
  private
    FSyncThreadCount: Integer;
    FProductNo: Integer;
    FSyncInterval: Integer;
    FProductName: string;
  public
    property ProductNo:Integer read FProductNo write FProductNo;
    property ProductName: string read FProductName write FProductName;
    property SyncThreadCount: Integer read FSyncThreadCount write FSyncThreadCount;
    property SyncInterval: Integer read FSyncInterval write FSyncInterval;
  end;

  TDBLink = class
  strict private
    FHost, FUserName, FPassword, FOraServiceName, FSQLiteDBPath:string;
    FPort:Integer;
    FWinAuth, FUtf8:Boolean;
    FDBType: TSyncType;
    FDatabase: string;
    FMaxPoolSize:Integer;
    FOraConnectionMode: TOraConnMode;
    FLinkName:string;
    FMySQLEncoding:TMySQLEncoding;
    FTblList:TStrings;
    FCS: TCriticalSection;
    procedure OnAfterConn(Sender:TObject);
  public
    constructor Create;
    destructor Destroy; override;
    function BuildConnection(const bUsePool:Boolean=False):TUniConnection;
    function Equ(ALink:TDBLink):Boolean;
    function ExecSQL(ASQLScript:string; bThrowException:boolean=False):boolean;
    function ExecScalar(ASQLCmd: string): Variant;
    function GetMSSQLTablInfo(ATblName:string):TTableInfo;
    function OpenData(ASQL:string;var bSuccess:boolean; var aError:string): TDataSet;
    function Test(var aMessage:string): boolean;
    function ToString:string; override;
    procedure Assign(AOther:TDBLink);
    procedure InitTblList(const bForceRefresh:boolean=False);
    function FullTblName(AValue:string; const bLookinDB:Boolean=False):string;
    function GetDBObjType(ADBObjName:string):TDBObjType;
  published
    function GetTblInfo(ATblName:string):TTableInfo;
    function LoadTblList(AList:TStrings; bAppend:Boolean=False):boolean;
    function LoadViewList(AList:TStrings;bAppend:Boolean=False): boolean;
    function TableIsExist(ATblName:string):boolean;
    property Database:string read FDatabase write FDatabase;
    property DBType: TSyncType read FDBType write FDBType;
    property Host: string read Fhost write FHost;
    property LinkName:string read FLinkname write FLinkName;
    property MaxPoolSize:Integer read FMaxPoolSize write FMaxPoolSize;
    property MySQLEncoding: TMySQLEncoding read FMySQLEncoding write FMySQLEncoding;
    property OraConnectionMode: TOraConnMode read FOraConnectionMode write FOraConnectionMode;
    property OraServiceName:string read FOraServiceName write FOraServiceName;
    property Password: string read FPassword write FPassword;
    property Port: Integer read FPort write FPort;
    property SQLiteDBPath: string read FSQLiteDBPath write FSQLiteDBPath;
    property Username: string read FUsername write FUserName;
    property WinAuth:boolean read FWinAuth write FWinAuth;
  end;

  TDBSync=class(TSyncBase, IDBSync)
  private
    FLocalDBConn: TUniConnection;
    FDBSyncOption: TDBSyncOption;
    function GetSysUpdateTblName:string;
    function GetDeleteRecTblName:string;
  protected
    procedure doCheckStruct;
    procedure doCheckIntegrity; virtual; abstract;
    procedure doBeforeLogin; virtual;
    procedure doAfterLogin; virtual;
    procedure doDeleteRec;
    procedure doExecUpdateScript;
    function GetSyncTableClass:TSyncItemClass; virtual; abstract;
    {本地数据库数据访问方法}
    procedure ConnToLocalDB;
    function LocalExecCommand(ASQLCmd:string):Boolean;
    function LocalExecScalar(ASQLCmd:string):variant;
    function LocalGetDataset(ASQLCmd:string):TDataset;
    function LocalTableIsExist(ATableName:string):boolean; virtual; abstract;
    function LocalCreateTable(ATblInfo:TTableInfo):boolean; virtual; abstract;
    {服务端通讯接口}
    function Login(AParameters:string):boolean;
    function GetSyncList(AItemClass: TSyncItemClass): ISyncItemList;
    function GetDataSet(ASQLCommand:string):TDataset;
    function GetRemoteTblStu(ATblName:string): TTableInfo;
    procedure Logout;
    {ISync}
    procedure doStart(); override;
    procedure doStop(); override;
    {IDBSync}
    procedure CheckIntegrity; //检查本地数据库是否完整
    procedure CheckStruct;    //检查本地数据库的结构
  public
    constructor Create; override;
    destructor Destroy; override;
    property Option: TDBSyncOption read FDBSyncOption;
    property LocalConnection: TUniConnection read FLocalDBConn;
    property TblName_SysUpdate:string read GetSysUpdateTblName;
    property TblName_DeleteRec:string read GetDeleteRecTblName;
  end;

  Function IIF( lExp:boolean; vExp1,vExp2 : variant) : variant;

  const MySQLEncodingText:array[TMySQLEncoding] of string = ('GBK','UTF8');

implementation
var __FieldMaper : TFieldMapHelper;

function FieldMaper: TFieldMapHelper;
begin
  if not Assigned(__FieldMaper) then
    __FieldMaper := TFieldMapHelper.Create;
  result := __FieldMaper;
end;

Function IIF( lExp:boolean; vExp1,vExp2 : variant) : variant;
begin
  if lExp
  then Result := vExp1
  else Result := vExp2 ;
end;

function ExistString(AValue: string; keywords: array of string):boolean;
var
  i:integer;
begin
  result := false;
  for i := low(keywords) to high(keywords) do
    if UpperCase(AValue)=UpperCase(keywords[i]) then
    Exit(True);
end;

function JoinStrings(AList:TStrings; bBreak:boolean=False):string; overload;
var
  k:Integer;
begin
  result :='';
  k := 0;
  while k < Alist.Count do
  begin
    result := result + AList[k];
    if k < (AList.Count -1) then
    begin
      result := result + ',';
      if bBreak then
        result := result + #13#10;
    end;
    inc(k);
  end;
end;

function JoinStrings(AList:array of string):string; overload;
var
  k:Integer;
begin
  result :='';
  k := 0;
  while k <= High(Alist) do
  begin
    result := result + AList[k];
    if k < High(AList)  then
    begin
      result := result + ',';
    end;
    inc(k);
  end;
end;

{ TDBSync }

procedure TDBSync.CheckIntegrity;
begin

end;

procedure TDBSync.CheckStruct;
begin
  doCheckStruct;
end;

procedure TDBSync.ConnToLocalDB;
begin
  if not FLocalDBConn.Connected then
    FLocalDBConn.Open;
end;

constructor TDBSync.Create;
begin
  inherited;
  //TOODO:加载本地数据库链接参数
  FDBSyncOption := TDBSyncOption.Create;
  FLocalDBConn := tUniConnection.Create(nil);
end;

destructor TDBSync.Destroy;
begin
  FLocalDBConn.Free;
  FDBSyncOption.Free;
  inherited;
end;

procedure TDBSync.doAfterLogin;
begin

end;

procedure TDBSync.doBeforeLogin;
var
  tinfo:TTableInfo;
begin
  if LocalTableIsExist(TblName_SysUpdate) then
  begin
    tinfo := GetRemoteTblStu(TblName_SysUpdate);
    LocalCreateTable(tinfo);
    tinfo.Free;
  end;

  if LocalTableIsExist(self.TblName_DeleteRec) then
  begin
    tinfo := GetRemoteTblStu(TblName_DeleteRec);
    LocalCreateTable(tinfo);
    tinfo.Free;
  end;
end;

procedure TDBSync.doCheckStruct;
begin
  //TODO:检查本地表结构与服务端表结构是否一致
end;

procedure TDBSync.doDeleteRec;
begin
   //接收删除记录至临时表
   //分批处理：select distinct TABLENAME from [临时表]
   // --> delete a from [业务表] a, [临时表] b where a.ID = b.RECID and b.TABLENAME  = 业务表名
   //     IF Exist(业务表名_SL) then
   //        delete a from [业务表_SL] a, [临时表] b where a.ID = b.RECID and b.TABLENAME  = 业务表名
   //     delete from [临时表] where ID in (select ID from [删除表：XXXX_DeleteRec])
end;

procedure TDBSync.doExecUpdateScript;
begin

end;

procedure TDBSync.doStart;
var
  i:Integer;
begin
  doBeforeLogin;
  //TODO:客户端登陆
  Login('');
  self.doAfterLogin;
  doExecUpdateScript;
  doDeleteRec;
  FSyncList := GetSyncList(TSyncTable);

  //TODO: 同步数据表，需要实现优先级与多线程策略
  for i := 0 to fSyncList.Count - 1 do
    fSyncList.GetItem(i).Sync;
end;

procedure TDBSync.doStop;
begin
  Logout();
  self.FSyncList.Count
end;

function TDBSync.GetDataSet(ASQLCommand: string): TDataset;
begin

end;

function TDBSync.GetDeleteRecTblName: string;
begin
  result := FDBSyncOption.ProductName+'_DeleteRec';
end;

const
C_SQL_GETTBLSTRUC =
  'SELECT '+
  'ColumnID=B.column_id, ColumnName=B.name, ColumnType=C.name, Nullable=B.is_nullable,'+
  'ColumnLength=B.max_length, [Precision]= B.precision, Scale=B.scale '+
  'FROM sys.objects A JOIN sys.columns B ON A.object_id = B.object_id ' +
  'LEFT JOIN sys.types C ON B.system_type_id = C.system_type_id '+
  'WHERE A.[name] = ''%s''';

function TDBSync.GetRemoteTblStu(ATblName: string): TTableInfo;
var
  ds:TDataset;
  fdinfo:TFieldInfo;
begin
  //TODO: GetRemoteTblStu
  result := TTableInfo.Create(nil);
  ds := GetDataSet(Format(C_SQL_GETTBLSTRUC, [ATblName]));
  result.TableName := ATblName;
  ds.First;
  while not ds.Eof do
  begin
    fdinfo := TFieldInfo.Create;
    fdinfo.FieldName := ds.FieldByName('ColumnName').AsWideString;
    fdinfo.FieldType := ds.FieldByName('ColumnType').AsWideString;
    fdinfo.Nullable := ds.FieldByName('Nullable').AsInteger = 1;
    fdinfo.Length := ds.FieldByName('ColumnLength').AsInteger;
    fdinfo.Precesion := ds.FieldByName('Precision').AsInteger;
    fdinfo.Scale := ds.FieldByName('Scale').AsInteger;
    result.Fields.Add(fdinfo);
    ds.Next;
  end;
end;

function TDBSync.GetSyncList(AItemClass: TSyncItemClass): ISyncItemList;
var
  rList:TSyncList;
begin
  rList := TSyncList.Create;
  //TODO:获取本次所需的同步项目列表
  result := rList;
end;

function TDBSync.GetSysUpdateTblName: string;
begin
  result := FDBSyncOption.ProductName+'_SysUpdate';
end;

function TDBSync.LocalExecCommand(ASQLCmd: string): Boolean;
var
  AQuery: TUniQuery;
begin
  result := True;
  try
    ConnToLocalDB;
    AQuery := TUniQuery.Create(FLocalDBConn);
    AQuery.SQL.Add(ASQLCmd);
    AQuery.Execute;
  except
    result := False;
  end;
end;

function TDBSync.LocalExecScalar(ASQLCmd: string): variant;
var
  AQuery: TUniQuery;
begin
  result := varNull;
  try
    ConnToLocalDB;
    AQuery := TUniQuery.Create(FLocalDBConn);
    AQuery.SQL.Add(ASQLCmd);
    AQuery.Open;
    if AQuery.RecordCount > 0 then
      result := AQuery.Fields[0].AsVariant;
  except
  end;
end;

function TDBSync.LocalGetDataset(ASQLCmd: string): TDataset;
var
  AQuery: TUniQuery;
begin
  result := nil;
  try
    ConnToLocalDB;
    AQuery := TUniQuery.Create(FLocalDBConn);
    AQuery.SQL.Add(ASQLCmd);
    AQuery.Open;
    result := AQuery;
  except
  end;
end;

function TDBSync.Login(AParameters: string): boolean;
begin
  result := False;
end;

procedure TDBSync.Logout;
begin

end;

{ TSyncTable }

function TSyncTable.DoSync: Integer;
begin
  result := 0;
end;

function TSyncTable.ExpireDate: TDateTime;
begin
  result := FExpireDate;
end;

function TSyncTable.ServerGetDataSQL: string;
begin
  result := Self.FServerGetDataSQL;
end;

{ TTableInfo }

constructor TTableInfo.Create;
begin
  FOwner := AOwner;
  FFieldList := TFieldList.Create;
  FIndexList := TIndexList.Create;
  FSpaceInfo.Valid := False;
end;

procedure TTableInfo.CreateIndex(Target: TDBLink; ATblName, AIndexName: string; bUNIQUE:boolean; AFields: array of string);
var
  sql:string;
  flist:string;
begin
  sql := '';
  flist := JoinStrings(AFields);
  case Target.DBType of
    stMSSQL: sql := Format('create %s index %s on %s (%s);' ,[IIF(bUnique, 'unique',''), AIndexName, ATblName, flist]);
    stMySQL: sql := Format('alter table %s add %s index %s(%s);', [aTblName, IIF(bUnique, 'unique',''),AIndexName, flist]);
    stOracle: sql := Format('create %s index %s.%s on %s(%s)', [IIF(bUnique, 'unique',''),  Target.Database, AIndexName, aTblName, flist]);
    stSQLite: ;
    stLocalDB: sql := Format('alter table %s add %s index %s(%s);', [aTblName, IIF(bUnique, 'unique',''),AIndexName, flist]);
  end;
  target.ExecSQL(sql);
end;

procedure TTableInfo.BuildTable(Target: TDBLink; ATableName: string);
var
  sql, fd:TStrings;
  perField:TFieldInfo;
  perIndex:TIndexInfo;
  perIndexField:TIndexField;
  ddl:string;
  function AdjustIndexName(AIndexName:string):string;
  begin
    result := AIndexName;
    if (Length(AIndexName)>30) and (Target.DBType=stOracle) then
    begin
      result := 'IDX_'+FormatDateTime('yyyymmdd_HHMMSSZZZ',now);
      Log.AddLogFormat('索引''%s''超长,已自动更名为:%s',[AIndexName, Result]);
    end;
  end;

  function IndexFieldDLL(const ifobj:TIndexField):string;
  begin
    case target.DBType of
      stMSSQL: result := Format('[%s] %s',[ifobj.FieldName , IIF(ifobj.ASC, 'asc','desc')]);
      stMySQL: result := Format('`%s` %s',[ifobj.FieldName , IIF(ifobj.ASC, 'asc','desc')]);
      stOracle: result := Format('"%s" %s',[ifobj.FieldName , IIF(ifobj.ASC, 'asc','desc')]);
      stSQLite: result := Format('%s %s',[ifobj.FieldName , IIF(ifobj.ASC, 'asc','desc')]);
      stLocalDB: result := Format('`%s` %s',[ifobj.FieldName , IIF(ifobj.ASC, 'asc','desc')]);
    end;
  end;
begin
  sql := TStringList.Create;
  fd  := TStringList.Create;
  for perField in FFieldList do
    fd.Add( perField.ToSQLScript(Target.DBType) );
  sql.Clear;
  sql.Add('create table ');
  sql.Add(Target.FullTblName(ATableName));
  sql.Add('(');
  sql.Add(JoinStrings(fd,true));
  sql.Add(')');
  if not Target.ExecSQL(sql.Text) then
  begin
  end;
  fd.Free;
  sql.Free;

  //构建索引
  if FIndexList.Count = 0  then
  begin
    //如果源表不存在索引，则自动创建索引
    //建ID索引
    if FieldExist('ID') AND FieldExist('TypeCode') and (UpperCase(RightStr(ATableName,3))='_SE')  then
      CreateIndex(Target,Target.FullTblName(ATableName), Format('IDX_%S',[ATableName]), True, ['ID','TypeCode','Code']);
    if FieldExist('ID') and (UpperCase(RightStr(ATableName,3))<>'_SE') then
      CreateIndex(Target,Target.FullTblName(ATableName), Format('IDX_%S',[ATableName]), True, ['ID']);
    //建JSID索引
    if FieldExist('TMSTAMP') then CreateIndex(
      Target, Target.FullTblName(ATableName),
      Format('IDX_%s_%s',[ATableName, 'TMSTAMP']),
      False, ['TMSTAMP']);
  end else
  begin
    //复制源表的索引结构
    sql := TStringList.Create;
    for perIndex in FIndexList do
    begin
      for perIndexField in perIndex.IndexFields do sql.Add(IndexFieldDLL(perIndexField));
      case Target.DBType of
        stMSSQL: ddl := Format('create %s index %s on %s (%s);' ,[IIF(perIndex.Unique, 'unique',''), perIndex.IndexName, ATableName, JoinStrings(sql)]);
        stMySQL: ddl := Format('alter table %s add %s index %s(%s);', [ATableName, IIF(perIndex.Unique, 'unique',''),perIndex.IndexName, JoinStrings(sql)]);
        stOracle: ddl := Format('create %s index %s.%s on %s(%s)', [IIF(perIndex.Unique, 'unique',''),  Target.Database, AdjustIndexName(perIndex.IndexName), Target.Database+'.'+ATableName, JoinStrings(sql)]);
        stSQLite: ;
        stLocalDB: ddl := Format('alter table %s add %s index %s(%s);', [ATableName, IIF(perIndex.Unique, 'unique',''),perIndex.IndexName, JoinStrings(sql)]);
      end;
      target.ExecSQL(ddl)
    end;
    sql.Free;
  end;

end;

procedure TTableInfo.CreateTbl(Target: TDBLink; ANewTableName: string);
begin
  if not TblIsExist(Target, IIF(ANewTableName='', FTableName, ANewTableName)) then
    BuildTable(Target, IIF(ANewTableName='', FTableName, ANewTableName));
end;

destructor TTableInfo.Destroy;
begin
  FFieldList.Free;
  FIndexList.Free;
  inherited;
end;

function TTableInfo.FieldExist(AFieldName: string): boolean;
var
  f:TFieldInfo;
begin
  result := False;
  for f in self.FFieldList do
    if UpperCase( f.FieldName )= UpperCase (AFieldName) then Exit(True);
end;

function TTableInfo.GetDLL(ATarget: TDBLink): string;
begin

end;

class function TTableInfo.TblIsExist(Target: TDBLink; const ATblName: string): boolean;
begin
  Result := Target.TableIsExist(ATblName);
end;

{ TDBLink }

procedure TDBLink.Assign(AOther: TDBLink);
var
  perTbl:string;
begin
  FDBType := AOther.DBType;
  FHost := AOther.Host;
  FPort := AOther.Port;
  FDatabase := AOther.Database;
  FUserName := AOther.Username;
  FPassword := AOther.Password;
  FOraServiceName := AOther.OraServiceName;
  FOraConnectionMode := AOther.OraConnectionMode;
  FSQLiteDBPath := AOther.SQLiteDBPath;
  FWinAuth := AOther.WinAuth;
  FTblList.Clear;
end;

function TDBLink.BuildConnection(const bUsePool:Boolean=False):TUniConnection;
begin
  result := TUniConnection.Create(nil);
  result.Server := Host;
  result.Database := Database;
  result.Username := UserName;
  result.Password := Password;
  if bUsePool then
  begin
    result.Pooling := True;
    result.PoolingOptions.MaxPoolSize := FMaxPoolSize;
  end;
  case FDBType of
    stMSSQL:
    begin
      result.ProviderName := 'SQL Server';
      result.Port := IIF(Port=0, 1433, Port);
      if WinAuth then
        result.SpecificOptions.Values['Authentication'] := 'auWindows'
      else
        result.SpecificOptions.Values['Authentication'] := 'auServer';
    end;
    stMySQL:
    begin
      result.ProviderName := 'MySQL';
      if Port>0 then
        result.Port := Port;
      result.SpecificOptions.Values['UseUnicode'] := 'FALSE';
      //result.SpecificOptions.Values['Direct'] := 'True';
      case FMySQLEncoding of
        myGKB: result.SpecificOptions.Values['CharSet'] := 'GBK';
        myUTF8:
        begin
          result.SpecificOptions.Values['CharSet'] := 'UTF8';
          result.SpecificOptions.Values['UseUnicode'] := 'TRUE';
        end;
      end;
    end;
    stOracle:
    begin
      result.ProviderName := 'Oracle';
      result.Port := IIF(Port=0, 1521, Port);
      result.Server := Format('%s:%d:%s', [Host,result.Port,OraServiceName]);
      result.SpecificOptions.Values['Direct'] := 'True';
      {$IFDEF fpc}
      //Lazarus下不支持Oracle直连模式
      result.SpecificOptions.Values['Direct'] := 'False';
      {$ENDIF}
      case FOraConnectionMode of
        ocmNormal: ;
        ocmSysOper: result.SpecificOptions.Values['ConnectMode'] := 'cmSysOper';
        ocmSysDBA: result.SpecificOptions.Values['ConnectMode'] := 'cmSysDBA';
        ocmSysASM: result.SpecificOptions.Values['ConnectMode'] := 'cmSysASM';
      end;
    end;
    stSQLite: ;
    stLocalDB:
    begin
      result.ProviderName := 'MySQL';
      result.SpecificOptions.Values['Embedded'] := 'True';
      result.SpecificOptions.Values['EmbeddedParams'] := '--basedir=.'#13#10'--datadir=data';
    end;
  end;
  result.AfterConnect := self.OnAfterConn;
  result.AfterDisconnect := self.OnAfterConn;
end;

constructor TDBLink.Create;
begin
  FMaxPoolSize := 50;
  FTblList := TStringList.Create;
  FCS := TCriticalSection.Create;
end;

destructor TDBLink.Destroy;
begin
  FTblList.Free;
  FCS.Free;
  inherited;
end;

function TDBLink.Equ(ALink: TDBLink): Boolean;
begin
  result :=
    (FDBType = ALink.DBType) and (FHost=ALink.Host) and
    (FPort = ALink.Port) and (FDatabase = ALink.Database);
end;

function TDBLink.ExecScalar(ASQLCmd: string): Variant;
var
  conn:TUniConnection;
  ds:TCustomDADataSet;
begin
  result := varNull;
  conn := BuildConnection(True);
  try
    ds := conn.CreateDataSet(nil);
    ds.SQL.Text := ASQLCmd;
    ds.Open;
    if (ds.RecordCount>0) then
      result := ds.Fields[0].AsVariant;
  finally
    ds.Free;
    conn.Free;
  end;

end;

function TDBLink.ExecSQL(ASQLScript: string; bThrowException:boolean=False):boolean;
var
  conn:TUniConnection;
  dasql: TCustomDASQL;
begin
  result := True;
  conn := BuildConnection(True);
  try
    try
      conn.ExecSQL(ASQLScript);
    except
      on e:exception do
      begin
        Log.AddLogFormat('Exception:%s', [e.Message]);
        result := False;
      end;
    end;
  finally
    conn.Free;
  end;
end;

function TDBLink.FullTblName(AValue: string; const bLookinDB:Boolean=False): string;
begin
  result := '';

  if bLookinDB and TableIsExist(AValue) then
    AValue := FTblList[FTblList.IndexOf(AValue)];

  case Self.DBType of
    stMSSQL: result := '['+AValue+']';
    stMySQL: result := Format('%s.`%s`', [Database, AValue]);
    stOracle: result := Username+'.'+AValue;
    stSQLite: ;
    stLocalDB: result := format('`%s`', [AValue]);
  end;
end;

function TDBLink.GetDBObjType(ADBObjName: string): TDBObjType;
var
  r:variant;
begin
  result := dotUnknow;
  case FDBType of
    stMSSQL:
    begin
      r := self.ExecScalar('select CASE [type] WHEN ''U'' THEN 1 WHEN ''V'' THEN 2  ELSE 99 END from sysobject where [name]='''+ADBObjName+''';');
      result := TDBObjType(r);
    end;
    stMySQL: ;
    stOracle: ;
    stSQLite: ;
    stLocalDB: ;
  end;
end;

function TDBLink.GetMSSQLTablInfo(ATblName:string): TTableInfo;
var
  conn:TUniConnection;
  rds :TCustomDADataSet;
  fieldInfo: TFieldInfo;
begin
  result := TTableInfo.Create(self);
  result.TableName := ATblName;
  result.HasSlave := TableIsExist(ATblName+'_SE');
  result.HasImageField := False;
  conn := BuildConnection;
  rds := conn.CreateDataSet();
  try
    //TODO: GetMSSQLTablInfo
    //Get Fields Info
    rds.SQL.Text := 'select B.[name], C.[name], B.[max_length], B.[precision], B.[scale], B.[isnullable] from sys.objects A join sys.columns B on A.object_id=B.object_id join sys.types C on B.system_type_id=C.system_type_id   where A.name = ''QT_DailyQuote'' and A.type = ''U''';
    rds.Open;
    while not rds.Eof do
    begin
      fieldInfo := TFieldInfo.Create;
      fieldInfo.FieldName := rds.Fields[0].AsString;
      fieldInfo.FieldType := rds.Fields[1].AsString;
      fieldInfo.Length := rds.Fields[2].AsInteger;
      fieldInfo.Precesion := rds.Fields[3].AsInteger;
      fieldInfo.Scale := rds.Fields[4].AsInteger;
      fieldInfo.Nullable := rds.Fields[5].AsInteger = 1;
      result.Fields.Add(fieldInfo);
      rds.Next;
    end;
    rds.Close;
    //Get Indexs Information
    rds.SQL.Text := '';
    rds.Open;
    while not rds.Eof do
    begin

    end;
  finally
    rds.Free;
    conn.Free;
  end;
end;

function TDBLink.GetTblInfo(ATblName:string): TTableInfo;
var
  conn : TUniConnection;
  meta : TDAMetaData;
  data : TCustomDADataSet;
  fieldInfo : TFieldInfo;
  perIndex:TIndexInfo;
  tmpSI: TTableSpaceInfo;
  function ConvertMSSpace(AValue:string):Integer;
  var
    m:TMatch;
  begin
    result := 0;
    m := TRegEx.Match(AValue, '\d+');
    if m.Success then
      TryStrToInt(m.Value, result);
  end;
begin
  result := TTableInfo.Create(self);
  result.TableName := ATblName;
  result.HasSlave := TableIsExist(ATblName+'_SE');
  result.HasImageField := False;
  result.IsView := False;

  //获取字段信息
  conn := BuildConnection(True);
  meta := conn.CreateMetaData;
  meta.MetaDataKind := 'Columns';
  case self.FDBType of
    stMSSQL: ;
    stMySQL: ;
    stOracle: meta.Restrictions.Values['TABLE_SCHEMA'] := UpperCase(Username);
    stSQLite: ;
    stLocalDB: ;
  end;
  meta.Restrictions.Values['TABLE_NAME'] := ATblName;
  data := conn.CreateDataSet(nil);
  data.SQL.Text := Format(
  'SELECT A.name AS COLUMN_NAME, C.name AS DATA_TYPE, A.precision AS DATA_PRECISION, A.scale AS DATA_SCALE, A.max_length AS DATA_LENGTH, cast(A.is_nullable as INT) AS NULLABLE '+
  'FROM sys.columns A JOIN sys.objects B ON A.object_id=B.object_id '+
  'JOIN sys.types C ON A.system_type_id=C.system_type_id '+
  'WHERE b.name = ''%s'' AND b.type=''U'' '+
  'ORDER BY A.column_id', [ATblName]);
  try
    data.Open;
    data.First;
    while not data.Eof do
    begin
      fieldInfo := TFieldInfo.Create;
      fieldInfo.FieldName := data.FieldByName('COLUMN_NAME').AsString;
      fieldInfo.Length := data.FieldByName('DATA_LENGTH').AsInteger;
      fieldInfo.FieldType := data.FieldByName('DATA_TYPE').AsString;
      fieldInfo.Precesion := data.FieldByName('DATA_PRECISION').AsInteger;
      fieldInfo.Scale := data.FieldByName('DATA_SCALE').AsInteger;
      fieldInfo.Nullable := data.FieldByName('NULLABLE').AsInteger = 1;
      result.Fields.Add(fieldInfo);
      result.HasImageField := result.HasImageField or ExistString(fieldInfo.FieldType,
        ['Blob','LongBlob','Image','CLOB','Text','LongText']);
      data.Next;
    end;
  finally
    data.Free;
    conn.Free;
  end;

  //获取索引信息
  conn := BuildConnection(True);
  meta := conn.CreateMetaData;
  meta.MetaDataKind := 'Indexes';
  meta.Restrictions.Values['Table_Name'] := ATblName;
  try
    meta.Open;
    while not meta.Eof do
    begin
      result.IndexList.Add(TIndexInfo.Create);
      result.IndexList.Last.IndexName := meta.FieldByName('INDEX_NAME').AsString;
      result.IndexList.Last.Unique := meta.FieldByName('UNIQUE').AsInteger = 1;
      meta.Next;
    end;
  finally
    meta.Free;
    conn.Free;
  end;

  if result.IndexList.Count=0 then Exit;

  //获取索引字段信息
  conn := BuildConnection(True);
  meta := conn.CreateMetaData;
  meta.MetaDataKind := 'IndexColumns';
  meta.Restrictions.Values['Table_Name'] := ATblName;
  try
    meta.Open;

    for perIndex in result.IndexList do
    begin
      meta.Filtered := False;
      meta.Filter := Format('INDEX_NAME = ''%s''', [perIndex.IndexName]);
      meta.Filtered := True;
      meta.First;
      while not meta.Eof do
      begin
        perIndex.IndexFields.Add(TIndexField.Create);
        perIndex.IndexFields.Last.FieldName := meta.FieldByName('COLUMN_NAME').AsString;
        perIndex.IndexFields.Last.ASC := meta.FieldByName('SORT_ORDER').AsString = 'ASC';
        meta.Next;
      end;
    end;
  finally
    meta.Free;
    conn.Free;
  end;

  //获取表存储信息
  conn := BuildConnection(True);
  data := conn.CreateDataSet(nil);
  tmpSI.Valid := False;
  try
    case FDBType of
      stMSSQL:
      begin
        data.SQL.Text := Format('sp_spaceused [%s]',[atblName]);
        data.Open;
        if not data.IsEmpty then
        begin
          tmpSI.Valid := True;
          if Assigned(data.FieldByName('rows')) then tmpSI.TotalRow := data.FieldByName('rows').AsInteger;
          if Assigned(data.FieldByName('data')) then tmpSI.SpaceUsedKB := ConvertMSSpace( data.FieldByName('data').AsString ) ;
        end;
      end;
      stMySQL:
      begin
        data.SQL.Text := Format('show table status like ''%s''',[atblName]);
        data.Open;
        if not data.IsEmpty then
        begin
          tmpSI.Valid := True;
          if Assigned(data.FieldByName('rows')) then tmpSI.TotalRow := data.FieldByName('rows').AsInteger;
          if Assigned(data.FieldByName('data_length')) then tmpSI.SpaceUsedKB := data.FieldByName('data_length').AsInteger div 1024 ;
        end;
      end;
      stOracle: ;
      stSQLite: ;
      stLocalDB: ;
    end;
  finally
    data.Free;
    conn.Free;
  end;
  result.SpaceInfo := tmpSI;
end;

procedure TDBLink.InitTblList(const bForceRefresh:boolean=False);
begin
  FCS.Enter;
  try
    if (FTblList.Count=0) or bForceRefresh then
      LoadTblList(FTblList);
  finally
    FCS.Leave;
  end;
end;

function TDBLink.LoadTblList(AList: TStrings; bAppend:Boolean=False): boolean;
var
  conn:TUniConnection;
  meta:TDAMetaData;
begin
  conn := BuildConnection;
  meta := conn.CreateMetaData;
  AList.BeginUpdate;
  if not bAppend then
    AList.Clear;
  try
    meta.MetaDataKind := 'Tables';
    meta.Restrictions.Values['TABLE_TYPE'] := 'TABLE';
    case self.DBType of
      stMSSQL: ;
      stMySQL: meta.Restrictions.Values['TABLE_SCHEMA'] := DataBase;
      stOracle: meta.Restrictions.Values['TABLE_SCHEMA'] := UpperCase(Username);
      stSQLite: ;
      stLocalDB: meta.Restrictions.Values['TABLE_SCHEMA'] := DataBase;
    end;
    meta.Open;
    meta.First;
    while not meta.Eof do
    begin
      AList.Add(meta.FieldByName('TABLE_NAME').Value);
      meta.Next;
    end;
  finally
    AList.EndUpdate;
    meta.Free;
    conn.Free;
  end;
end;

function TDBLink.LoadViewList(AList: TStrings; bAppend:Boolean=False): boolean;
var
  conn:TUniConnection;
  meta:TDAMetaData;
begin
  conn := BuildConnection;
  meta := conn.CreateMetaData;
  AList.BeginUpdate;
  if not bAppend then
    AList.Clear;
  try
    meta.MetaDataKind := 'Tables';
    meta.Restrictions.Values['TABLE_TYPE'] := 'View';
    case self.DBType of
      stMSSQL: ;
      stMySQL: meta.Restrictions.Values['TABLE_SCHEMA'] := DataBase;
      stOracle: meta.Restrictions.Values['TABLE_SCHEMA'] := UpperCase(Username);
      stSQLite: ;
      stLocalDB: meta.Restrictions.Values['TABLE_SCHEMA'] := DataBase;
    end;
    meta.Open;
    meta.First;
    while not meta.Eof do
    begin
      AList.Add(meta.FieldByName('TABLE_NAME').Value);
      meta.Next;
    end;
  finally
    AList.EndUpdate;
    meta.Free;
    conn.Free;
  end;
end;

procedure TDBLink.OnAfterConn(Sender: TObject);
var
  c:TUniConnection;
begin
  c := Sender as TUniConnection;
  if Assigned(c) then
  begin
    //myloger.Debug('%s:%s', [c.Server, IIF(c.Connected, 'Connect', 'Disconnect')]);
  end;
end;

function TDBLink.OpenData(ASQL: string; var bSuccess:boolean; var aError:string): TDataSet;
var
  conn:TUniConnection;
begin
  conn := BuildConnection;
  result := conn.CreateDataSet();
  bSuccess := False;
  aError := '';
  try
    TCustomDADataSet(result).SQL.Text := ASQL;
    try
      Result.Open;
      bSuccess := True;
    except on E:exception do
      aError := e.Message;
    end;
  finally
//    if conn.Pooling then
//      conn.RemoveFromPool
//    else
//      FreeAndNil(conn);
  end;
end;

function TDBLink.TableIsExist(ATblName: string): boolean;
begin
  InitTblList;
  result := FTblList.IndexOf(ATblName) >= 0;
end;

function TDBLink.Test(var aMessage:string): boolean;
var
  conn:TUniConnection;
begin
  result := True;
  conn := BuildConnection;
  try
    conn.Open;
    aMessage := conn.ServerVersionFull;
  except on e:Exception do
    begin
      aMessage := e.Message;
      result := False;
    end;
  end;
  Conn.Free;
end;

function TDBLink.ToString: string;
begin
  result := Format('%s/%s/%s', [C_SyncNames[self.FDBType], Self.Host, self.Database]);
end;

{ TFieldInfo }

procedure TFieldInfo.SetFieldType(const Value: string);
var
  fid:integer;
begin
  //MSSQL-SERVER，返回数值型的字段类型描述须转换
  //OLEDB DATA_type映射关系参考：http://www.cnblogs.com/zany-hui/articles/3111856.html
{/*
System.Data.OleDb.OleDbType.Empty	0
System.Data.OleDb.OleDbType.SmallInt	2
System.Data.OleDb.OleDbType.Integer	3
System.Data.OleDb.OleDbType.Single	4
System.Data.OleDb.OleDbType.Double	5
System.Data.OleDb.OleDbType.Currency	6
System.Data.OleDb.OleDbType.Date	7
System.Data.OleDb.OleDbType.BSTR	8
System.Data.OleDb.OleDbType.IDispatch	9
System.Data.OleDb.OleDbType.Error	10
System.Data.OleDb.OleDbType.Boolean	11
System.Data.OleDb.OleDbType.Variant	12
System.Data.OleDb.OleDbType.IUnknown	13
System.Data.OleDb.OleDbType.Decimal	14
System.Data.OleDb.OleDbType.TinyInt	16
System.Data.OleDb.OleDbType.UnsignedTinyInt	17
System.Data.OleDb.OleDbType.UnsignedSmallInt	18
System.Data.OleDb.OleDbType.UnsignedInt	19
System.Data.OleDb.OleDbType.BigInt	20
System.Data.OleDb.OleDbType.UnsignedBigInt	21
System.Data.OleDb.OleDbType.Filetime	64
System.Data.OleDb.OleDbType.Guid	72
System.Data.OleDb.OleDbType.Binary	128
System.Data.OleDb.OleDbType.Char	129
System.Data.OleDb.OleDbType.WChar	130
System.Data.OleDb.OleDbType.Numeric	131
System.Data.OleDb.OleDbType.DBDate	133
System.Data.OleDb.OleDbType.DBTime	134
System.Data.OleDb.OleDbType.DBTimeStamp	135
System.Data.OleDb.OleDbType.PropVariant	138
System.Data.OleDb.OleDbType.VarNumeric	139
System.Data.OleDb.OleDbType.VarChar	200
System.Data.OleDb.OleDbType.LongVarChar	201
System.Data.OleDb.OleDbType.VarWChar	202
System.Data.OleDb.OleDbType.LongVarWChar	203
System.Data.OleDb.OleDbType.VarBinary	204
System.Data.OleDb.OleDbType.LongVarBinary	205
*/}
  if TryStrToInt(Value, fid) then
  begin
    case fid of
      2,3,11,16,17,18,19: FFieldType := 'int';
      14: FFieldType := 'decimal';
      4,5,131: FFieldType := 'float';
      6: FFieldType := 'money';
      7,133,134,135: FFieldType := 'datetime';
      20,21: FFieldType := 'bigint';
      128,204,205: FFieldType := 'image';
      129,130: FFieldType := IIF(Flength<10000, 'varchar','text');
      200,202: FFieldType := 'varchar';
      201,203: FFieldType := 'text';
      else
        raise Exception.Create('Field Type ERROR!');
    end;
  end else
    FFieldType := Value;
end;

function TFieldInfo.ToSQLScript(ATargetDBType: TSyncType): string;
var
  fname2:string;
begin
  fname2 := FFieldName;
  case ATargetDBType of
    stMSSQL: fname2 := Format('[%s]', [FFieldName]);
    stMySQL: fname2 := Format('`%s`', [FFieldName]);
    stOracle: fname2 := Format('"%s"', [FFieldName]);
    stSQLite: ;
    stLocalDB: fname2 := Format('`%s`', [FFieldName]);
  end;
  result := Format('%s %s %s',[
    fname2, //字段名
    FieldMaper.Convert(self, ATargetDBType), //字段类型
    IIF(self.Nullable, '', 'not null')
  ]);
end;

function TFieldInfo.ToString: string;
begin
  result := Format('%s,%s(%d,%d)',[FFieldName, FFieldType, FPrecesion, FScale])
end;

{ TFieldMapHelper }

procedure TFieldMapHelper.AddMap(AType:TSyncType; ASrc, ATarget:string);
var
  key:string;
begin
  key := C_SyncNames[AType]+'/'+ASrc;
  key := UpperCase(key);
  FMapList.AddOrSetValue(key, ATarget);
end;

function TFieldMapHelper.Convert(AFieldInfo: TFieldInfo; ATargetDBType: TSyncType): string;
var
  key, tmp:string;
begin
  key := UpperCase(C_SyncNames[ATargetDBType]+'/'+AFieldInfo.FieldType);
  if not FMapList.TryGetValue(key, tmp) then
    raise Exception.Create('FieldMapHelper.Convert错误，不支持的字段类型');
  //--Length
  tmp := ReplaceStr(tmp, '#L', IntToStr(AFieldInfo.Length));
  tmp := ReplaceStr(tmp, '#P', IntToStr(AFieldInfo.Precesion));
  tmp := ReplaceStr(tmp, '#S', IntToStr(AFieldInfo.Scale));
  result := tmp;
end;

constructor TFieldMapHelper.Create;
begin
  FMapList := TDictionary<string, string>.Create;
  //----MSSQL --> MSSQL----
  AddMap(stMSSQL, 'BigInt', 'BigInt');
  AddMap(stMSSQL, 'Bit', 'Bit');
  AddMap(stMSSQL, 'char', 'char(#L)');
  AddMap(stMSSQL, 'Datetime', 'Datetime');
  AddMap(stMSSQL, 'Decimal', 'Decimal(#P,#S)');
  AddMap(stMSSQL, 'Float', 'Float');
  AddMap(stMSSQL, 'Image', 'Image');
  AddMap(stMSSQL, 'Int', 'Int');
  AddMap(stMSSQL, 'Money', 'Money');
  AddMap(stMSSQL, 'nchar', 'nchar(#L)');
  AddMap(stMSSQL, 'Numeric', 'Numeric(#P,#S)');
  AddMap(stMSSQL, 'nvarchar', 'nvarchar(#L)');
  AddMap(stMSSQL, 'Real', 'Real');
  AddMap(stMSSQL, 'Smalldatetime', 'Smalldatetime');
  AddMap(stMSSQL, 'Smallint', 'Smallint');
  AddMap(stMSSQL, 'Smallmoney', 'Smallmoney');
  AddMap(stMSSQL, 'Text', 'Text');
  AddMap(stMSSQL, 'Tinyint', 'Tinyint');
  AddMap(stMSSQL, 'Timestamp', 'Timestamp');
  AddMap(stMSSQL, 'varchar', 'varchar(#L)');
  AddMap(stMSSQL, 'binary', 'binary(#L)');
  //--Oracle --> MSSQL
  AddMap(stMSSQL, 'BLOB', 'Image');
  AddMap(stMSSQL, 'CHAR', 'CHAR(#L)');
  AddMap(stMSSQL, 'CLOB', 'Text');
  AddMap(stMSSQL, 'DATE', 'Datetime');
  AddMap(stMSSQL, 'FLOAT', 'float');
  AddMap(stMSSQL, 'NUMBER', 'decimal(#P,#S)');
  AddMap(stMSSQL, 'NVARCHAR2', 'nvarchar(#L)');
  AddMap(stMSSQL, 'VARCHAR2', 'varchar(#L)');
  //--MySQL --> MSSQL
  AddMap(stMSSQL, 'bigint', 'bigint');
  AddMap(stMSSQL, 'datetime', 'datetime');
  AddMap(stMSSQL, 'decimal', 'decimal(#P,#S)');
  AddMap(stMSSQL, 'int', 'int');
  AddMap(stMSSQL, 'longtext', 'text');
  AddMap(stMSSQL, 'varchar', 'varchar(#L)');
  AddMap(stMSSQL, 'longblob', 'image');

  //MSSQL --> MySQL
  AddMap(stMySQL, 'BigInt', 'bigInt');
  AddMap(stMySQL, 'Bit', 'int');
  AddMap(stMySQL, 'char', 'varchar(#L)');
  AddMap(stMySQL, 'Datetime', 'Datetime');
  AddMap(stMySQL, 'Decimal', 'decimal(#P,#S)');
  AddMap(stMySQL, 'Float', 'double');
  AddMap(stMySQL, 'Image', 'longblob');
  AddMap(stMySQL, 'Int', 'int');
  AddMap(stMySQL, 'Money', 'decimal(19,4)');
  AddMap(stMySQL, 'nchar', 'varchar(#L)');
  AddMap(stMySQL, 'Numeric', 'decimal(#P,#S)');
  AddMap(stMySQL, 'nvarchar', 'varchar(#L)');
  AddMap(stMySQL, 'Real', 'Float');
  AddMap(stMySQL, 'Smalldatetime', 'Datetime');
  AddMap(stMySQL, 'Smallint', 'int');
  AddMap(stMySQL, 'Smallmoney', 'decimal(10,4)');
  AddMap(stMySQL, 'Text', 'longtext');
  AddMap(stMySQL, 'Tinyint', 'int');
  AddMap(stMySQL, 'varchar', 'varchar(#L)');

  //MSSQL --> Oracle
  AddMap(stOracle, 'BigInt', 'number(19,0)');
  AddMap(stOracle, 'Bit', 'number(1,0)');
  AddMap(stOracle, 'char', 'varchar2(#L)');
  AddMap(stOracle, 'Datetime', 'date');
  AddMap(stOracle, 'Decimal', 'number(#P,#S)');
  AddMap(stOracle, 'Float', 'number');
  AddMap(stOracle, 'Image', 'blob');
  AddMap(stOracle, 'Int', 'number(10,0)');
  AddMap(stOracle, 'Money', 'number(19,4)');
  AddMap(stOracle, 'nchar', 'varchar2(#L)');
  AddMap(stOracle, 'Numeric', 'number(#P,#S)');
  AddMap(stOracle, 'nvarchar', 'varchar2(#L)');
  AddMap(stOracle, 'Real', 'number');
  AddMap(stOracle, 'Smalldatetime', 'date');
  AddMap(stOracle, 'Smallint', 'number(5,0)');
  AddMap(stOracle, 'Smallmoney', 'decimal(10,4)');
  AddMap(stOracle, 'Text', 'clob');
  AddMap(stOracle, 'Tinyint', 'number(5,0)');
  AddMap(stOracle, 'varchar', 'varchar2(#L)');
end;

destructor TFieldMapHelper.Destroy;
begin
  FMapList.Free;
  inherited;
end;

{ TIndexInfo }

constructor TIndexInfo.Create;
begin
  FIndexFields := TIndexFields.Create(True);
end;

destructor TIndexInfo.Destroy;
begin
  FIndexFields.Free;
  inherited;
end;

{ TIndexField }

function TIndexField.ToString: string;
begin
  result := Format('%s %s',[FieldName , IIF(ASC, 'asc','desc')]);
end;

end.



