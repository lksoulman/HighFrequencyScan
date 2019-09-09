unit uQuoteFile;

interface
uses
  Classes, types, SysUtils, StrUtils, DateUtils, IOUtils, Windows, Math,
  Generics.Collections, uLog,
  RegularExpressions,
  SynLZ, uCRCTools, uMemoryDBF;

type

  TMarket = packed record
    Code    : AnsiChar; //S:上海 ，Z:深圳 ，H：香港 ，U：美国， N：新三板
    Status  : AnsiChar; //S:开市 ，T：交易  E:闭市  P:盘前交易（美） A:盘后交易（美）
    Auction : AnsiChar; //Y:集合竞价 N:非集合竞价
    Time    : TDateTime; //市场时间 (本地时间)
  end;

  TPrice = packed record
    Price : double;
    Volume: integer;
  end;

  TLevelType = (
    LevelZero  = 00, //无买卖档
    LevelOne   = 01, //一档买卖
    LevelFive  = 05, //五档买卖
    LevelTen   = 10  //十档买卖
  );

  //行情记录结构定义
  PQuoteRecord = ^TQuoteRecord;
  TQuoteRecord = packed record
    Valid     : boolean;
    //basic info
    Market    : TMarket;
    Time      : TDateTime; //行情时间
    LevelType : TLevelType;
    Currency  : array[1..3] of AnsiChar;
    Code      : array[1..10] of AnsiChar;
    Abbr      : array[1..32] of AnsiChar;
    //Price&Volume...
    Prev, Open, High, Low, Last, Close: double;
    Volume    : Int64;
    Value     : double;
    DealCnt   : Integer;
    PE1, PE2  : double;
    Buy       : array[1..10] of TPrice;
    Sell      : array[1..10] of TPrice;
    procedure SetCode(ASource:AnsiString);
    procedure SetAbbr(ASource:AnsiString);
    procedure SetCurrency(AValue:AnsiString);
    function GetCode:string;
    function GetAbbr:string;
    function ToString:string;
    function Compare(const AValue: PQuoteRecord):boolean;
    function IsValid:boolean;
  end;
  TQuoteRecordAry = array[0..MaxInt div 1024-1] of TQuoteRecord;
  PQuoteRecordAry = ^TQuoteRecordAry;

  TQuoteBlock = class
  strict private
    FCount:Integer;
    FCapacity: Integer;
    FBuffer: PQuoteRecordAry;
  public
    constructor Create(ACapacity:Integer);
    destructor Destroy; override;
    procedure Append(const ASrc:PQuoteRecord);
    procedure Clear;
    property Count:Integer read FCount;
    property Capacity:Integer read FCapacity;
    property Buffer: PQuoteRecordAry read FBuffer;
  end;

  //行情文件基类
  TQuoteBaseClass = class of TQuoteBase;
  TQuoteBase = class
  strict private
    FUseMemoryMap:boolean;
    FFileName:string;
    FFileSize:DWORD;
    FFileHandle:THandle;
    FMapHandle:THandle;
    FLastCRC:Cardinal;
    FTraceFileChange: Boolean;
    function GetFilename:string;
    function GetPath:string;
    function GetFullName:string;
    function GetRecBuffer:Pointer;
  protected
    FptrBuffer: Pointer;
    FQuoteRecs: PQuoteRecordAry;
    function GetQuoteRecordByCode(ACode:string): PQuoteRecord;
    function GetQuoteRecordByIndex(AIndex:Integer): PQuoteRecord;
    function GetRecCound:Integer; virtual; abstract;
    procedure doScanQuote; virtual;
    procedure InitFile; virtual;
    procedure ClearResource; virtual;
    procedure doFileBufferChanged; virtual;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    function Compress(const ATarget:TMemoryStream):Boolean;
    procedure BindFile(ALocalFile:string);
    function ScanQuote:boolean;
    property Buffer:Pointer read FptrBuffer;
    property FileName:string read GetFileName;
    property FileSize:DWORD read FFileSize;
    property FullName:string read GetFullName;
    property Path:string read GetPath;
    property Quote[AIndex:Integer]:PQuoteRecord read GetQuoteRecordByIndex; default;
    property RecCount:Integer read GetRecCound;
    property RecBuffer:Pointer read GetRecBuffer;
    property FileHandle: THandle read FFileHandle;
    property TraceFileChange: boolean read FTraceFileChange write FTraceFileChange;
    class function FileKey:string; virtual;
    class function FileIsMatch(AFileName:string):boolean; virtual;
  end;

  TDBFQuote = class(TQuoteBase)
  protected
    FDBF:TMemoryDBF;
    procedure InitFile; override;
    procedure ClearResource; override;
    procedure doScanQuote; override;
    function GetRecCound:Integer; override;
  public
    constructor Create; override;
    destructor Destroy; override;
  end;

  TSHOW2003 = class(TDBFQuote)
  protected
    procedure doScanQuote; override;
    class function FileKey:string; override;
  end;

  TSJSHQ = class(TDBFQuote)
  protected
    procedure doScanQuote; override;
    class function FileKey:string; override;
  end;

  TSJSZS = class(TDBFQuote)
  protected
    procedure doScanQuote; override;
    class function FileKey:string; override;
  end;

  TNQHQ = class(TSJSHQ)
  protected
    procedure doScanQuote; override;
    class function FileKey:string; override;
  end;

  TLineFileQuote = class(TQuoteBase)
  protected
    FLines:TStringList;
    procedure InitFile; override;
    procedure ClearResource; override;
  public
    constructor Create; override;
  end;

  TMKTDT00 = class(TLineFileQuote)
  strict private
    function ConvertTime(BaseDay:TDateTime; ASource:string):TDateTime;
  protected
    function GetRecCound:Integer; override;
    procedure doScanQuote; override;
    procedure _scanIndexQuote(const k:Integer; Source: TStringDynArray);
    procedure _scanStockQuote(const k:Integer; Source: TStringDynArray);
    procedure _scanFundQuote(const k:Integer; Source: TStringDynArray);
    class function FileKey:string; override;
  end;

  TUSStockDBF = class(TDBFQuote)
  protected
    function GetRecCound:Integer; override;
    procedure doScanQuote; override;
    class function FileKey:string; override;
  end;

  THKExDBF = class(TDBFQuote)
  protected
    procedure doScanQuote; override;
    class function FileKey:string; override;
  end;

  THKIndexDBF = class(TDBFQuote)
  protected
    procedure doScanQuote; override;
    class function FileKey:string; override;
  end;

  TFundEValueDBF = class(TDBFQuote)
  private
    FSetting : TFormatSettings;
  protected
    procedure doScanQuote; override;
    class function FileKey:string; override;
  public
    constructor Create; override;
  end;

  TFundEValueDBF2 = class(TFundEValueDBF)
  protected
    class function FileKey:string; override;
  end;

  TFundHQDBF = class(TDBFQuote)
  protected
    FSetting : TFormatSettings;
    function GetRecCound:Integer; override;
    procedure doScanQuote; override;
    class function FileKey:string; override;
  public
    constructor Create; override;
  end;

  TFundNVDBF = class(TDBFQuote)
  protected
    function GetRecCound:Integer; override;
    procedure doScanQuote; override;
    class function FileKey:string; override;
  end;

  TFundBasicDBF = class(TDBFQuote)
  protected
    function GetRecCound:Integer; override;
    procedure doScanQuote; override;
    class function FileKey:string; override;
  end;

  TSWZSDBF = class(TDBFQuote)
  protected
    procedure doScanQuote; override;
    class function FileKey:string; override;
    function GetRecCound:Integer; override;
  end;

  //中证指数文件结构声明
  PCSI_IndexRecord = ^TCSI_IndexRecord;
  TCSI_IndexRecord = packed record
    {记录类型 01: 指数行情信息 02: 指数权重信息 03: ETF 的 IOPV（参考净值}
    JLLX    : array[0..1] of AnsiChar;
    SPLIT01 : AnsiChar;
    {备用字段始终为空格}
    BYZD    : array[0..3] of AnsiChar;
    SPLIT02 : AnsiChar;
    {指数代码}
    ZSDM    : array[0..5] of AnsiChar;
    SPLIT03 : AnsiChar;
    {指数简称}
    JC      : array[0..19] of AnsiChar;
    SPLIT04 : AnsiChar;
    {市场代码 1：上证所；2：深交所；3：沪深；4：香港；5: 亚太； 0: 全球（附加说明见注）}
    SCDM    : AnsiChar;
    SPLIT05 : AnsiChar;
    {实时指数，当前指数值}
    SSZS    : array[0..10] of AnsiChar;
    SPLIT06 : AnsiChar;
    {当日开盘值，当前交易日开盘指数值。初始值为 0.0000。当值为 0.0000 时，说明指数未开盘}
    DRKP    : array[0..10] of AnsiChar;
    SPLIT07 : AnsiChar;
    {当日最大值，当前交易日最大指数值}
    DRZD    : array[0..10] of AnsiChar;
    SPLIT08 : AnsiChar;
    {当日最小值，当前交易日最小指数值}
    DRZX    : array[0..10] of AnsiChar;
    SPLIT09 : AnsiChar;
    {当日收盘值，当前交易日收盘值。初始值为 0.0000。当值不为 0.0000 时，说明指数已收盘。}
    DRSP    : array[0..10] of AnsiChar;
    SPLIT10 : AnsiChar;
    {昨日收盘值，上一交易日收盘值}
    ZRSP    : array[0..10] of AnsiChar;
    SPLIT11 : AnsiChar;
    {涨跌}
    ZD      : array[0..10] of AnsiChar;
    SPLIT12 : AnsiChar;
    {涨跌幅}
    ZDF     : array[0..10] of AnsiChar;
    SPLIT13 : AnsiChar;
    {成交量单位为股，如该指数为债券指数，则成交量的单位为张。}
    CJL     : array[0..13] of AnsiChar;
    SPLIT14 : AnsiChar;
    {成交金额（万元）}
    CJJE    : array[0..15] of AnsiChar;
    SPLIT15 : AnsiChar;
    {汇率，该汇率在盘中时为0.00000000，收盘后，该汇率值为该指数收盘时计算指数
    所使用的汇率。例：若该指数为日经 225 指数以人民币计价的指数，则汇率为人民
    币对日元的汇率。若该指数为沪深 300 指数以美元计价的指数，则汇率为美元对人
    民币的汇率。其他若该指数不涉及汇率的情况下，则始终为 1.00000000}
    HL      : array[0..11] of AnsiChar;
    SPLIT16 : AnsiChar;
    {币种标志,使用货币。0：人民币；1：港币；2：美元；3：台币； 4：日元}
    BZBZ    : AnsiChar;
    SPLIT17 : AnsiChar;
    {指数展示序号}
    ZSXH    : array[0..3] of AnsiChar;
    SPLIT18 : AnsiChar;
    {当日收盘值2, 若该指数为全球指数，该收盘值为当日亚太 区 收 盘 值 。 初 始 值 为
    0.0000。当值不为 0.0000 时，说明指数亚太区已收盘。}
    DRSP2   : array[0..10] of AnsiChar;
    SPLIT19 : AnsiChar;
    {当日收盘值 3，若该指数为全球指数，该收盘值为当日欧洲 区 收 盘 值 。 初 始 值 为
    0.0000。当值不为 0.0000 时，说明指数欧洲区已收盘}
    DRSP3   : array[0..10] of AnsiChar;
    //$0D0A换行符
    SPLIT20 : array[0..1] of Byte;
  end;

  {CSI文件头}
  PCSI_FILE_HEAD = ^TCSI_FILE_HEAD;
  TCSI_FILE_HEAD = packed record
    //每日传递的版本号，目前固定为“02”。
    BBH    : array[0..1] of AnsiChar;
    SPLIT01: Byte;
    {行情文件所代表交易日期，内容为被用于计算的那天的交易日 期 。 日 期 的 格 式 为
    “YYYYMMDD”。其中，YYYY：年，MM：月，DD：日。}
    JYRQ   : array[0..7] of AnsiChar;
    SPLIT02: Byte;
    {行情文件所代表的自然日期(北京时间),内容为被用于计算的那天的自然日期（北京时
    间 ） . 日 期 的 格 式 为“YYYYMMDD”。如交易日为 2012年 1 月 19 日的全球指数收盘
    时北京时间已经是 2012 年 1月 20 日。}
    JSRQ   : array[0..7] of AnsiChar;
    SPLIT03: Byte;
    {行情文件的更新时间戳（北京时间），格式为“HHMMSS”。HH：小时，MM：分钟，SS：秒}
    GXSJ   : array[0..5] of AnsiChar;
    SPLIT04: Byte;
    {表示本文件拥有的记录条数，条数，}
    JLS    : array[0..9] of AnsiChar;
    //$0D0A换行符
    SPLIT05: array[0..1] of Byte;
  end;

  {ETF 参考净值 ETF 参考净值 （ （IOPV） ） 信息定义：}
  PCSI_ETFIOPV = ^TCSI_ETFIOPV;
  TCSI_ETFIOPV = packed record
    {记录类型 01: 指数行情信息 02: 指数权重信息 03: ETF 的 IOPV（参考净值}
    JLLX    : array[0..1] of AnsiChar;
    SPLIT01 : AnsiChar;
    {备用字段始终为空格}
    BYZD    : array[0..3] of AnsiChar;
    SPLIT02 : AnsiChar;
    {ETF 的证券代码}
    ZQDM    : array[0..5] of AnsiChar;
    SPLIT03 : AnsiChar;
    {ETF 的证券名称}
    ZQMC    : array[0..19] of AnsiChar;
    SPLIT04 : AnsiChar;
    {市场代码 1：上证所；2：深交所；3：沪深；4：香港；5: 亚太； 0: 全球（附加说明见注）}
    SCDM    : AnsiChar;
    SPLIT05 : AnsiChar;
    {基金参考净值（IOPV）}
    IPOV    : array[0..10] of AnsiChar;
    //$0D0A换行符
    SPLIT06: array[0..1] of Byte;
  end;

  PCSI_RecHead = ^TCSI_RecHead;
  TCSI_RecHead = packed record
    JLLX    : array[0..1] of AnsiChar;
    SPLIT01 : AnsiChar;
  end;

  TCSI_RecordType = (csiFileHad=0, csiIndexQuota=1, csiMemberWeight, csiIPOV=3);
  TCSI_RecordBody = packed record
    case Integer of
      -2: (Data : PByte);
      -1: (Test : PCSI_RecHead);
      00: (Head : PCSI_FILE_HEAD);
      01: (Quota: PCSI_IndexRecord);
      02: (IOPV : PCSI_ETFIOPV)
  end;

  TCSI_Record = packed record
    RecordType: TCSI_RecordType;
    Body      : TCSI_RecordBody;
  end;

  TCSIFile = class(TQuoteBase)
  private
    FHead: PCSI_FILE_HEAD;
    FList: TList<TCSI_Record>;
    function Str2Date(AValue:string):TDate; inline;
    function Str2Time(AValue:string):TTime; inline;
  protected
    function GetRecCound:Integer; override;
    procedure doScanQuote; override;
    procedure InitFile; override;
    procedure ClearResource; override;
  protected
    class function FileKey:string; override;
    class function FileIsMatch(AFileName: string): boolean; override;
  end;

  function GetQuoteReader(AFile:string): TQuoteBaseClass;

implementation
{$WARNINGS OFF}

function IIF(express:boolean; t,f:AnsiChar):AnsiChar;
begin
  if express then
    result := t
  else
    result := f;
end;

const
  __QUOTE_READER_CLASSES:array[0..14] of TQuoteBaseClass =
  (
    TSHOW2003,
    TSJSHQ,
    TMKTDT00,
    TSJSZS,
    TNQHQ,
    TUSStockDBF,
    THKExDBF,
    THKIndexDBF,
    TFundEValueDBF,    //FUND_B.DBF
    TFundEValueDBF2,   //FUND_NB.DBF
    TFundHQDBF,        //FUND_HQ.DBF
    TFundNVDBF,        //FUND_NV.DBF
    TFundBasicDBF,     //FUND_BASIC.DBF
    TSWZSDBF,
    TCSIFile
  );

function GetQuoteReader(AFile:string): TQuoteBaseClass;
var
  fn: string;
  c : TQuoteBaseClass;
begin
  fn := UpperCase(TPath.GetFileName(AFile));
  result := nil;
  for c in __QUOTE_READER_CLASSES do
    if c.FileKey = fn then Exit(c);

  for c in __QUOTE_READER_CLASSES do
    if c.FileIsMatch(fn) then Exit(c);
end;
{ TQuoteBase }

procedure TQuoteBase.ClearResource;
begin
  if FUseMemoryMap then
  begin
    if Assigned(FptrBuffer) then UnmapViewOfFile(fptrBuffer);
  end else
    FreeMem(fPtrBuffer);

  if FMapHandle > 0 then
    CloseHandle(FMapHandle);

  if FFileHandle > 0 then
    CloseHandle(FFileHandle);

  if Assigned(FQuoteRecs) then
    FreeMem(FQuoteRecs);
end;

function TQuoteBase.Compress(const ATarget: TMemoryStream): boolean;
var
  len:Integer;
begin
  if self.FFileSize = 0 then exit(False);

  ATarget.Size := SynLZcompressdestlen(FFileSize);
  ATarget.Seek(0, soBeginning);
  len := SynLZcompress1pas(FptrBuffer, FFileSize, ATarget.Memory);
  ATarget.Seek(0, soBeginning);
  ATarget.Size := len;
  result := True;
end;

constructor TQuoteBase.Create;
begin
  FFileHandle := 0;
  FMapHandle := 0;
  FptrBuffer := nil;
  FQuoteRecs := nil;
  FLastCRC := 0;
  FTraceFileChange := False;
end;

destructor TQuoteBase.Destroy;
begin
  ClearResource;
  inherited;
end;

procedure TQuoteBase.doFileBufferChanged;
var
  fn:string;
  tmp:TStreamWriter;
begin
  if not FTraceFileChange then exit;
  TDirectory.CreateDirectory('.\Trace');
  fn := TPath.Combine( '.\Trace\', TPath.GetFileName(self.FFileName)+'_'+FormatDateTime('yyyymmdd', now));
  tmp := TFile.AppendText(fn);
  try
    tmp.WriteLine('--Trace %s--',[FormatDateTime('hh:nn:ss.zzz', now)]);
    tmp.BaseStream.Write(self.FptrBuffer^, self.FFileSize);
  finally
    tmp.Free;
  end;
end;

procedure TQuoteBase.doScanQuote;
var
  i:Integer;
begin
  if not Assigned(FQuoteRecs) then
  begin
    GetMem(FQuoteRecs, SizeOf(TQuoteRecord)*RecCount);
    FillChar(FQuoteRecs[0], SizeOf(TQuoteRecord)*RecCount, 0);
    for i := 0 to RecCount-1 do FQuoteRecs[i].Valid := True;
  end;
end;

class function TQuoteBase.FileIsMatch(AFileName: string): boolean;
begin
  result := False;
end;

class function TQuoteBase.FileKey: string;
begin
end;

function TQuoteBase.GetFilename: string;
begin
  result := TPath.GetFileName(Self.FFilename)
end;

function TQuoteBase.GetFullName: string;
begin
  result := TPath.GetFullPath(Self.FFilename);
end;

function TQuoteBase.GetPath: string;
begin
  result := TPath.GetDirectoryName(Self.FFilename);
end;

function TQuoteBase.GetQuoteRecordByCode(ACode:string): PQuoteRecord;
begin
  result := nil;
end;

function TQuoteBase.GetQuoteRecordByIndex(AIndex:Integer): PQuoteRecord;
begin
  result := @FQuoteRecs[AIndex]
end;

function TQuoteBase.GetRecBuffer: Pointer;
begin
  result := @FQuoteRecs[0];
end;

procedure TQuoteBase.BindFile(ALocalFile: string);
begin
  ClearResource;
  FFilename := ALocalFile;
  InitFile;
end;

procedure TQuoteBase.InitFile;
var
  hsize:Cardinal;
begin
  if not TFile.Exists(FFilename) then
    raise Exception.Create('文件不存在');

  //共享打开文件
  FFileHandle := FileOpen(FFilename, fmOpenRead or fmShareDenyNone);
//  FFileHandle := CreateFile(PWideChar(FFilename),
//    GENERIC_READ,
//    FILE_SHARE_READ or FILE_SHARE_WRITE,
//    nil,
//    OPEN_EXISTING,
//    FILE_FLAG_SEQUENTIAL_SCAN,
//    0);
  if FFileHandle = INVALID_HANDLE_VALUE then
      raise Exception.Create('无法打开文件');

  FFileSize := GetFileSize(FFileHandle, @hsize);

  //如果源文件为网络路径，则使用读文件流的方式
  if not StartsText('\\', FFileName) then
  begin
    //如果使用内存映射失败，需要读取文件流的方式，并做标记；
    FMapHandle := CreateFileMapping(FFileHandle,nil,PAGE_READONLY, hsize,FFileSize,nil);
    FUseMemoryMap := FMapHandle <> INVALID_HANDLE_VALUE;
  end else
    FUseMemoryMap := False;

  if FUseMemoryMap then
    FptrBuffer := MapViewOfFile(FMapHandle, FILE_MAP_READ, 0, 0, 0)
  else
  begin
    GetMem(FptrBuffer, FFileSize);
    FileRead(FFileHandle, fPtrBuffer^, FFileSize);
  end;
end;

function TQuoteBase.ScanQuote:boolean;
var
  crc:Cardinal;
begin
  if not FUseMemoryMap then
  begin
    FileSeek(FFileHandle, 0, 0);
    FileRead(FFileHandle, fPtrBuffer^, FFileSize);
  end;
  crc := TCRCTools.crc32Buf(fPtrBuffer^, FFileSize);

  if (crc <> FLastCRC) then
  begin
    //try
      doFileBufferChanged;
      doScanQuote;
    //except on e:Exception do
    //  PostLog(llError, e.Message);
    //end;
    FLastCRC := crc;
    result := True;
  end else
    result := False;
end;

{ TDBFQuoteDBF }

procedure TDBFQuote.ClearResource;
begin
  inherited;
end;

constructor TDBFQuote.Create;
begin
  inherited;
  FDBF := nil;
end;

destructor TDBFQuote.Destroy;
begin
  if Assigned(FDBF) then
    FDBF.Free;
  inherited;
end;

procedure TDBFQuote.doScanQuote;
begin
  if not Assigned(FDBF) then Exit;

  if not Assigned(FQuoteRecs) then
  begin
    GetMem(FQuoteRecs, SizeOf(TQuoteRecord)*RecCount);
    FillChar(FQuoteRecs[0], SizeOf(TQuoteRecord)*RecCount, 0);
  end;
end;

function TDBFQuote.GetRecCound: Integer;
begin
  if Assigned(FDBF) then
    result := FDBF.RecCount
  else
    result := 0;
end;

procedure TDBFQuote.InitFile;
begin
  inherited;
  FDBF := TMemoryDBF.Create;
  FDBF.Link(FptrBuffer);
end;

{ TShow2003 }

procedure TShow2003.doScanQuote;
var
  i:integer;
  t:TDateTime;
  s1,s6,s11,s17:string;
begin
  inherited;
  t := now;
  //根据SHOW2003的规则，生成行情时间：S6 为当前日期，S1为当前时间
  //S11为闭市标志，交易期间该字段为0，闭市后该字段为 “1111111111”，表示市场闭市，所有行情结束
  //S15为上海行情结束标志，“0”表示行情未结束，“1”表示行情结束
  //S17为上海行情集合竞价结束标志，“0”表示集合竞价未结束，“1”表示集合竞价结束。
  S6  := FDBF.Field['S6',0].AsString;
  S1  := FDBF.Field['S2',0].AsString;
  S11 := FDBF.Field['S11',0].AsString;
  S17 := FDBF.Field['S17',0].AsString;
  t := EncodeDateTime(
    StrToInt(Copy(S6,1,4)),
    StrToInt(Copy(S6,5,2)),
    StrToInt(Copy(S6,7,2)),
    StrToInt(Copy(S1,1,2)),
    StrToInt(Copy(S1,3,2)),
    StrToInt(Copy(S1,5,2)),
    MilliSecondOf(t) );
  //逐条转换DBF中的记录至行情数组
  for i := 0 to RecCount - 1 do
  begin
    with FQuoteRecs[i], FDBF do
    begin
      Market.Code    := 'S';
      Market.Status  := IIF(LeftStr(s11,1)='0', 'T', 'E');
      Market.Auction := IIF(LeftStr(s17,1)='0', 'Y', 'N');
      Market.Time    := t;
      LevelType      := LevelFive;
      Time           := t;
      SetCode(Field['S1',i].AsString);
      SetAbbr(Field['S2',i].AsString);
      Prev           := Field['S3',i].AsFloat;
      Open           := Field['S4',i].AsFloat;
      Value          := Field['S5',i].AsInteger;
      High           := Field['S6',i].AsFloat;
      Low            := Field['S7',i].AsFloat;
      Last           := Field['S8',i].AsFloat;
      Buy[1].Price   := Field['S9',i].AsFloat;
      Sell[1].Price  := Field['S10',i].AsFloat;
      Volume         := Field['S11',i].AsLargeInt;
      PE1            := Field['S13',i].AsFloat;
      Buy[1].Volume  := Field['S15',i].AsInteger;
      Buy[2].Price   := Field['S16',i].AsFloat;
      Buy[2].Volume  := Field['S17',i].AsInteger;
      Buy[3].Price   := Field['S18',i].AsFloat;
      Buy[3].Volume  := Field['S19',i].AsInteger;
      Sell[1].Volume := Field['S21',i].AsInteger;
      Sell[2].Price  := Field['S22',i].AsFloat;
      Sell[2].Volume := Field['S23',i].AsInteger;
      Sell[3].Price  := Field['S24',i].AsFloat;
      Sell[3].Volume := Field['S25',i].AsInteger;
      Buy[4].Price   := Field['S26',i].AsFloat;
      Buy[4].Volume  := Field['S27',i].AsInteger;
      Buy[5].Price   := Field['S28',i].AsFloat;
      Buy[5].Volume  := Field['S29',i].AsInteger;
      Sell[4].Price  := Field['S30',i].AsFloat;
      Sell[4].Volume := Field['S31',i].AsInteger;
      Sell[5].Price  := Field['S32',i].AsFloat;
      Sell[5].Volume := Field['S33',i].AsInteger;
      FQuoteRecs[i].Close := Last;
    end;
  end;
end;

class function TSHOW2003.FileKey: string;
begin
  result := 'SHOW2003.DBF';
end;

{ TQuoteRecord }

function TQuoteRecord.Compare(const AValue: PQuoteRecord): boolean;
begin
  //result := (Time = AValue.Time) and (Code = AValue.Code);
  result := CompareMem(@Code[1], @AValue.Code[1], SizeOf(TQuoteRecord)-SizeOf(TMarket)-SizeOf(TDateTime)-SizeOf(TLevelType));
end;

function TQuoteRecord.GetAbbr: string;
var
  p:PAnsiChar;
begin
  p := @Abbr[1];
  result := Trim(p);
//  if result<>'' then
//    OutputDebugString('AA');
end;

function TQuoteRecord.GetCode: string;
var
  p:PAnsiChar;
begin
  p := @Code[1];
  result := Trim(p);
end;

function TQuoteRecord.IsValid: boolean;
const
  MAX_VALID_VALUE:Int64 = 90000000000000; //9万亿
begin
  result := True;
  if Prev >= MAX_VALID_VALUE then Exit(False);
  if Open >= MAX_VALID_VALUE then Exit(False);
  if High >= MAX_VALID_VALUE then Exit(False);
  if Low >= MAX_VALID_VALUE then Exit(False);
  if Last >= MAX_VALID_VALUE then Exit(False);
  if Close >= MAX_VALID_VALUE then Exit(False);
  if Value >= MAX_VALID_VALUE then Exit(False);
  if Value >= MAX_VALID_VALUE then Exit(False);
  if PE1 >= MAX_VALID_VALUE then Exit(False);
  if PE2 >= MAX_VALID_VALUE then Exit(False);
end;

procedure TQuoteRecord.SetAbbr(ASource: AnsiString);
begin
  Move(ASource[1], Self.Abbr[1], Min(Length(ASource),32));
end;

procedure TQuoteRecord.SetCode(ASource: AnsiString);
begin
  Move(ASource[1], Self.Code[1], Min(Length(ASource),10));
end;

procedure TQuoteRecord.SetCurrency(AValue: AnsiString);
begin
  Move(AValue[1], Self.CURRENCY[1], Min(Length(AValue),3));
end;

function TQuoteRecord.ToString: string;
begin
  result := Format(
    '%s:[%8s/%16s] Price:%7.2f Volume:%15d Value:%15f',
    [FormatDateTime('yyyy/mm/dd hh:NN:ss.zzz', Time),
    GetCode, GetAbbr, Last, Volume, Value]);
end;

{ TSJSHQ }

procedure TSJSHQ.doScanQuote;
var
  i:integer;
  t:TDateTime;
  hqsj,hqrq,hqcjsl:string;
  initm:TMarket;
begin
  inherited;
  //根据SJSHQ的规则，生成行情时间：HQZQJC 为当前日期，HQCJBS为当前时间
  //HQCJSL个位数存放收市行情标志（ 0：非收市行情； 1：表示收市行情）
  hqrq := FDBF.Field['HQZQJC',0].AsString;
  hqsj := Trim(FDBF.Field['HQCJBS',0].AsString);
  if Length(hqsj)<6 then hqsj:='0'+hqsj;
  hqcjsl := Trim(FDBF.Field['HQCJSL',0].AsString);
  t := EncodeDateTime(
    StrToInt(Copy(hqrq,1,4)),
    StrToInt(Copy(hqrq,5,2)),
    StrToInt(Copy(hqrq,7,2)),
    StrToInt(Copy(hqsj,1,2)),
    StrToInt(Copy(hqsj,3,2)),
    StrToInt(Copy(hqsj,5,2)), 0);
  initm.Code    := 'Z';
  initm.Status  := IIF(RightStr(hqcjsl,1)='0', 'T', 'E');
  initm.Auction := IIF(hqsj >= '093000',   'N','Y');
  initm.Time    := t;
  //逐条转换DBF中的记录至行情数组
  for i := 0 to Self.RecCount - 1 do
  begin
    with FQuoteRecs[i], FDBF do
    begin
      Market := initm;
      LevelType      := LevelFive;
      Time := t;
      SetCode(Field['HQZQDM',i].AsString);
      SetAbbr(Field['HQZQJC',i].AsString);
      Prev           := Field['HQZRSP',i].AsFloat;
      Open           := Field['HQJRKP',i].AsFloat;
      Last           := Field['HQZJCJ',i].AsFloat;
      Volume         := Field['HQCJSL',i].AsLargeInt;
      Value          := Field['HQCJJE',i].AsFloat;
      DealCnt        := Field['HQCJBS',i].AsInteger;
      High           := Field['HQZGCJ',i].AsFloat;
      Low            := Field['HQZDCJ',i].AsFloat;
      PE1            := Field['HQSYL1',i].AsFloat;
      PE2            := Field['HQSYL2',i].AsFloat;
      Buy[1].Price   := Field['HQBJW1',i].AsFloat;
      Buy[1].Volume  := Field['HQBSL1',i].AsInteger;
      Buy[2].Price   := Field['HQBJW2',i].AsFloat;
      Buy[2].Volume  := Field['HQBSL2',i].AsInteger;
      Buy[3].Price   := Field['HQBJW3',i].AsFloat;
      Buy[3].Volume  := Field['HQBSL3',i].AsInteger;
      Buy[4].Price   := Field['HQBJW4',i].AsFloat;
      Buy[4].Volume  := Field['HQBSL4',i].AsInteger;
      Buy[5].Price   := Field['HQBJW5',i].AsFloat;
      Buy[5].Volume  := Field['HQBSL5',i].AsInteger;
      Sell[1].Price  := Field['HQSJW1',i].AsFloat;
      Sell[1].Volume := Field['HQSSL1',i].AsInteger;
      Sell[2].Price  := Field['HQSJW2',i].AsFloat;
      Sell[2].Volume := Field['HQSSL2',i].AsInteger;
      Sell[3].Price  := Field['HQSJW3',i].AsFloat;
      Sell[3].Volume := Field['HQSSL3',i].AsInteger;
      Sell[4].Price  := Field['HQSJW4',i].AsFloat;
      Sell[4].Volume := Field['HQSSL4',i].AsInteger;
      Sell[5].Price  := Field['HQSJW5',i].AsFloat;
      Sell[5].Volume := Field['HQSSL5',i].AsInteger;
      FQuoteRecs[i].Close := Last;
    end;
  end;

end;

class function TSJSHQ.FileKey: string;
begin
  result := 'SJSHQ.DBF';
end;

{ TLineFileQuote }

procedure TLineFileQuote.ClearResource;
begin
  inherited;
  if Assigned(FLines) then
    FreeAndNil(FLines);
end;

constructor TLineFileQuote.Create;
begin
  inherited;
  FLines := nil;
end;

procedure TLineFileQuote.InitFile;
var
  s:AnsiString;
begin
  inherited;
  FLines := TStringList.Create;
  SetLength(s, FileSize);
  Move(Self.FptrBuffer^, s[1], FileSize);
  FLines.Text := s;
  SetLength(s,0);
end;

{ TMKTDT00 }

function TMKTDT00.ConvertTime(BaseDay:TDateTime; ASource: string): TDateTime;
begin
  //HH:MM:SS.000
  result := EncodeTime(
    StrToInt(copy(ASource,01,2)),
    StrToInt(copy(ASource,04,2)),
    StrToInt(copy(ASource,07,2)),
    StrToInt(copy(ASource,10,3)));
  result := trunc(BaseDay) + result;
end;

procedure TMKTDT00.doScanQuote;
var
  i:integer;
  tmp:TStringDynArray;
  ts:string;
  s:AnsiString;
  t:TDateTime;
  initM:TMarket;
  ptrString:PAnsiChar;
begin
  inherited;

  SetLength(s, FileSize);
  Move(Self.FptrBuffer^, s[1], FileSize);
  FLines.Text := s;

  if not Assigned(FQuoteRecs) then
  begin
    GetMem(FQuoteRecs, SizeOf(TQuoteRecord)*FLines.Count-2);
    FillChar(FQuoteRecs[0], SizeOf(TQuoteRecord)*FLines.Count-2, 0);
  end;

  //文件首行处理
  tmp := SplitString( FLines[0], '|' );
  ts := tmp[6];
  t := EncodeDateTime(
      StrToInt(Copy(ts,1,4)),
      StrToInt(Copy(ts,5,2)),
      StrToInt(Copy(ts,7,2)),
      StrToInt(Copy(ts,10,2)),
      StrToInt(Copy(ts,13,2)),
      StrToInt(Copy(ts,16,2)),
      StrToInt(Copy(ts,19,3))
      );
  initM.Time := t;
  initM.Code := 'S';
  s := LeftStr(tmp[8],1);
  initM.Status := s[1];
  initM.Auction := IIF(Copy(tmp[8],2,1)='0', 'Y','N');
  for i := 1 to FLines.Count-2 do
  begin
    tmp := SplitString( FLines[i], '|' );
    FQuoteRecs[i-1].Market := initM;
    FQuoteRecs[i-1].LevelType := LevelFive;
    FQuoteRecs[i-1].Time := t;
    if tmp[0]='MD001' then _scanIndexQuote(i-1, tmp);
    if tmp[0]='MD002' then _scanStockQuote(i-1, tmp);
    if tmp[0]='MD003' then _scanStockQuote(i-1, tmp);
    if tmp[0]='MD004' then _scanFundQuote (i-1, tmp);
  end;
end;

class function TMKTDT00.FileKey: string;
begin
  result := 'MKTDT00.TXT';
end;

function TMKTDT00.GetRecCound: Integer;
begin
  if Assigned(FLines) then
    result := FLines.Count - 2
  else
    result := 0;
end;

procedure TMKTDT00._scanFundQuote(const k: Integer; Source: TStringDynArray);
begin
  with FQuoteRecs[k] do
  begin
    SetCode(source[1]);
    SetAbbr(source[2]);
    Volume := StrToIntDef(Source[3],0);
    Value  := StrToFloatDef(Source[4],0);
    Prev   := StrToFloatDef(Source[5],0);
    Open   := StrToFloatDef(Source[6],0);
    High   := StrToFloatDef(Source[7],0);
    Low    := StrToFloatDef(Source[8],0);
    Last   := StrToFloatDef(Source[9],0);
    Close  := StrToFloatDef(Source[9],0);

    Buy[1].Price   := StrToFloatDef(Source[11],0);
    Buy[1].Volume  := StrToInt64Def(Source[12],0);
    Sell[1].Price  := StrToFloatDef(Source[13],0);
    Sell[1].Volume := StrToInt64Def(Source[14],0);

    Buy[2].Price   := StrToFloatDef(Source[15],0);
    Buy[2].Volume  := StrToInt64Def(Source[16],0);
    Sell[2].Price  := StrToFloatDef(Source[17],0);
    Sell[2].Volume := StrToInt64Def(Source[18],0);

    Buy[3].Price   := StrToFloatDef(Source[19],0);
    Buy[3].Volume  := StrToInt64Def(Source[20],0);
    Sell[3].Price  := StrToFloatDef(Source[21],0);
    Sell[3].Volume := StrToInt64Def(Source[22],0);

    Buy[4].Price   := StrToFloatDef(Source[23],0);
    Buy[4].Volume  := StrToInt64Def(Source[24],0);
    Sell[4].Price  := StrToFloatDef(Source[25],0);
    Sell[4].Volume := StrToInt64Def(Source[26],0);

    Buy[5].Price   := StrToFloatDef(Source[27],0);
    Buy[5].Volume  := StrToInt64Def(Source[28],0);
    Sell[5].Price  := StrToFloatDef(Source[29],0);
    Sell[5].Volume := StrToInt64Def(Source[30],0);
    PE1            := StrToFloatDef(Source[31],0);
    PE2            := StrToFloatDef(Source[32],0);
    Time           := ConvertTime(Market.Time, Source[34]);//时间戳HH:MM:SS.000
  end;
end;

procedure TMKTDT00._scanIndexQuote(const k: Integer; Source: TStringDynArray);
begin
  with FQuoteRecs[k] do
  begin
    SetCode(source[1]);
    SetAbbr(source[2]);
    Volume := StrToIntDef(Source[3],0);
    Value  := StrToFloatDef(Source[4],0);
    Prev   := StrToFloatDef(Source[5],0);
    Open   := StrToFloatDef(Source[6],0);
    High   := StrToFloatDef(Source[7],0);
    Low    := StrToFloatDef(Source[8],0);
    Last   := StrToFloatDef(Source[9],0);
    Close  := StrToFloatDef(Source[9],0);
    Time   := ConvertTime(Market.Time, Source[12]); //时间戳HH:MM:SS.000
  end;
end;

procedure TMKTDT00._scanStockQuote(const k: Integer; Source: TStringDynArray);
begin
  with FQuoteRecs[k] do
  begin
    SetCode(source[1]);
    SetAbbr(source[2]);
    Volume := StrToIntDef(Source[3],0);
    Value  := StrToFloatDef(Source[4],0);
    Prev   := StrToFloatDef(Source[5],0);
    Open   := StrToFloatDef(Source[6],0);
    High   := StrToFloatDef(Source[7],0);
    Low    := StrToFloatDef(Source[8],0);
    Last   := StrToFloatDef(Source[9],0);
    Close  := StrToFloatDef(Source[10],0);

    Buy[1].Price   := StrToFloatDef(Source[11],0);
    Buy[1].Volume  := StrToInt64Def(Source[12],0);
    Sell[1].Price  := StrToFloatDef(Source[13],0);
    Sell[1].Volume := StrToInt64Def(Source[14],0);

    Buy[2].Price   := StrToFloatDef(Source[15],0);
    Buy[2].Volume  := StrToInt64Def(Source[16],0);
    Sell[2].Price  := StrToFloatDef(Source[17],0);
    Sell[2].Volume := StrToInt64Def(Source[18],0);

    Buy[3].Price   := StrToFloatDef(Source[19],0);
    Buy[3].Volume  := StrToInt64Def(Source[20],0);
    Sell[3].Price  := StrToFloatDef(Source[21],0);
    Sell[3].Volume := StrToInt64Def(Source[22],0);

    Buy[4].Price   := StrToFloatDef(Source[23],0);
    Buy[4].Volume  := StrToInt64Def(Source[24],0);
    Sell[4].Price  := StrToFloatDef(Source[25],0);
    Sell[4].Volume := StrToInt64Def(Source[26],0);

    Buy[5].Price   := StrToFloatDef(Source[27],0);
    Buy[5].Volume  := StrToInt64Def(Source[28],0);
    Sell[5].Price  := StrToFloatDef(Source[29],0);
    Sell[5].Volume := StrToInt64Def(Source[30],0);
    Time           := ConvertTime(Market.Time, Source[32]);//时间戳HH:MM:SS.000
  end;
end;


{ TNQHQ }

procedure TNQHQ.doScanQuote;
var
  i:Integer;
begin
  inherited;
  for i := 0 to Self.RecCount - 1 do
    FQuoteRecs[i].Market.Code := 'N';
end;

class function TNQHQ.FileKey: string;
begin
  result := 'NQHQ.DBF';
end;

{ TSJSZS }

procedure TSJSZS.doScanQuote;
begin
  inherited;

end;

class function TSJSZS.FileKey: string;
begin
  result := 'SJSZS.DBF';
end;

{ TUSStockDBF }

procedure TUSStockDBF.doScanQuote;
var
  i,k:integer;
  t:TDateTime;
  initm:TMarket;
begin
  inherited;
  initm.Code    := 'U';
  initm.Status  := '-';
  initm.Auction := 'N';
  initm.Time    := Now;

  //逐条转换DBF中的记录至行情数组
  for i := 0 to Self.RecCount - 1 do
  begin
    k := i + 1;  //跳过首行记录
    if Trim(FDBF.Field['DealTime',k].AsString)='' then
    begin
      FQuoteRecs[i].Market := initm;
      FQuoteRecs[i].SetCode(FDBF.Field['CODE',k].AsString);
      FQuoteRecs[i].SetAbbr('--INVALID--');
      continue;
    end;

    with FQuoteRecs[i], FDBF do
    begin
      Market := initm;
      LevelType      := LevelFive;
      Time :=  Trunc(initm.Time) + StrToTime(Field['DealTime',k].AsString);
      //校正Market.Time值
      if HourOf(Market.Time)<HourOf(Time) then
        Time := IncDay(Time,-1);
      SetCode(Field['CODE',k].AsString);
      Prev           := Field['prev',k].AsFloat;
      Open           := Field['open',k].AsFloat;
      Close          := Field['close',k].AsFloat;
      Last           := Field['price',k].AsFloat;
      Volume         := Field['volume',k].AsLargeInt;
      Value          := Field['value',k].AsFloat;
      DealCnt        := 0;
      High           := Field['high',k].AsFloat;
      Low            := Field['low',k].AsFloat;
      Buy[1].Price   := Field['bp1',k].AsFloat;
      Buy[1].Volume  := Field['bv1',k].AsInteger;
      Buy[2].Price   := Field['bp2',k].AsFloat;
      Buy[2].Volume  := Field['bv2',k].AsInteger;
      Buy[3].Price   := Field['bp3',k].AsFloat;
      Buy[3].Volume  := Field['bv3',k].AsInteger;
      Buy[4].Price   := Field['bp4',k].AsFloat;
      Buy[4].Volume  := Field['bv4',k].AsInteger;
      Buy[5].Price   := Field['bp5',k].AsFloat;
      Buy[5].Volume  := Field['bv5',k].AsInteger;
      Sell[1].Price  := Field['sp1',k].AsFloat;
      Sell[1].Volume := Field['sv1',k].AsInteger;
      Sell[2].Price  := Field['sp2',k].AsFloat;
      Sell[2].Volume := Field['sv2',k].AsInteger;
      Sell[3].Price  := Field['sp3',k].AsFloat;
      Sell[3].Volume := Field['sv3',k].AsInteger;
      Sell[4].Price  := Field['sp4',k].AsFloat;
      Sell[4].Volume := Field['sv4',k].AsInteger;
      Sell[5].Price  := Field['sp5',k].AsFloat;
      Sell[5].Volume := Field['sv5',k].AsInteger;
    end;
  end;
end;

class function TUSStockDBF.FileKey: string;
begin
  result := 'USSTOCK.DBF';
end;

function TUSStockDBF.GetRecCound: Integer;
begin
  result := FDBF.RecCount - 1;
end;

{ THKEX }

procedure THKExDBF.doScanQuote;
var
  i:integer;
  t:TDateTime;
  initm:TMarket;
begin
  inherited;
  initm.Code    := 'H';
  initm.Status  := '-';
  initm.Auction := 'N';
  initm.Time    := Now;

  //逐条转换DBF中的记录至行情数组
  for i := 0 to Self.RecCount - 1 do
  begin
    if Trim(FDBF.Field['DealTime',i].AsString)='' then
    begin
      FQuoteRecs[i].Market := initm;
      FQuoteRecs[i].SetCode(FDBF.Field['CODE',i].AsString);
      FQuoteRecs[i].SetAbbr('--INVALID--');
      continue;
    end;

    with FQuoteRecs[i], FDBF do
    begin
      Market := initm;
      LevelType      := LevelTen;
      Time :=  Trunc(initm.Time) + StrToTime(Field['DealTime',i].AsString);
      SetCode(Field['CODE',i].AsString);
      SetAbbr(Field['ABBR',i].AsString);
      Prev           := Field['prev',i].AsFloat;
      Open           := Field['open',i].AsFloat;
      Close          := Field['close',i].AsFloat;
      Last           := Field['price',i].AsFloat;
      Volume         := Field['volume',i].AsLargeInt;
      Value          := Field['value',i].AsFloat;
      DealCnt        := 0;
      High           := Field['high',i].AsFloat;
      Low            := Field['low',i].AsFloat;
      Buy[1].Price   := Field['bp1',i].AsFloat;
      Buy[1].Volume  := Field['bv1',i].AsInteger;
      Buy[2].Price   := Field['bp2',i].AsFloat;
      Buy[2].Volume  := Field['bv2',i].AsInteger;
      Buy[3].Price   := Field['bp3',i].AsFloat;
      Buy[3].Volume  := Field['bv3',i].AsInteger;
      Buy[4].Price   := Field['bp4',i].AsFloat;
      Buy[4].Volume  := Field['bv4',i].AsInteger;
      Buy[5].Price   := Field['bp5',i].AsFloat;
      Buy[5].Volume  := Field['bv5',i].AsInteger;
      Buy[6].Price   := Field['bp6',i].AsFloat;
      Buy[6].Volume  := Field['bv6',i].AsInteger;
      Buy[7].Price   := Field['bp7',i].AsFloat;
      Buy[7].Volume  := Field['bv7',i].AsInteger;
      Buy[8].Price   := Field['bp8',i].AsFloat;
      Buy[8].Volume  := Field['bv8',i].AsInteger;
      Buy[9].Price   := Field['bp9',i].AsFloat;
      Buy[9].Volume  := Field['bv9',i].AsInteger;
      Buy[10].Price   := Field['bp10',i].AsFloat;
      Buy[10].Volume  := Field['bv10',i].AsInteger;
      Sell[1].Price  := Field['sp1',i].AsFloat;
      Sell[1].Volume := Field['sv1',i].AsInteger;
      Sell[2].Price  := Field['sp2',i].AsFloat;
      Sell[2].Volume := Field['sv2',i].AsInteger;
      Sell[3].Price  := Field['sp3',i].AsFloat;
      Sell[3].Volume := Field['sv3',i].AsInteger;
      Sell[4].Price  := Field['sp4',i].AsFloat;
      Sell[4].Volume := Field['sv4',i].AsInteger;
      Sell[5].Price  := Field['sp5',i].AsFloat;
      Sell[5].Volume := Field['sv5',i].AsInteger;
      Sell[6].Price  := Field['sp6',i].AsFloat;
      Sell[6].Volume := Field['sv6',i].AsInteger;
      Sell[7].Price  := Field['sp7',i].AsFloat;
      Sell[7].Volume := Field['sv7',i].AsInteger;
      Sell[8].Price  := Field['sp8',i].AsFloat;
      Sell[8].Volume := Field['sv8',i].AsInteger;
      Sell[9].Price  := Field['sp9',i].AsFloat;
      Sell[9].Volume := Field['sv9',i].AsInteger;
      Sell[10].Price  := Field['sp10',i].AsFloat;
      Sell[10].Volume := Field['sv10',i].AsInteger;
    end;
  end;
end;

class function THKExDBF.FileKey: string;
begin
  result := 'HKEX.DBF';
end;

{ TQuoteBlock }

procedure TQuoteBlock.Append(const ASrc: PQuoteRecord);
begin
  Move(ASrc^, FBuffer[FCount], SizeOf(TQuoteRecord));
  inc(FCount);
end;

procedure TQuoteBlock.Clear;
begin
  FCount := 0;
end;

constructor TQuoteBlock.Create(ACapacity: Integer);
begin
  FCount := 0;
  FCapacity := ACapacity;
  GetMem(FBuffer, SizeOf(TQuoteRecord)*FCapacity);
end;

destructor TQuoteBlock.Destroy;
begin
  FreeMem(FBuffer);
  inherited;
end;

{ THKIndexDBF }

procedure THKIndexDBF.doScanQuote;
var
  i:integer;
  t:TDateTime;
  initm:TMarket;
begin
  inherited;
  initm.Code    := 'H';
  initm.Status  := '-';
  initm.Auction := 'N';
  initm.Time    := Now;

  //逐条转换DBF中的记录至行情数组
  for i := 0 to Self.RecCount - 1 do
  begin
    if Trim(FDBF.Field['DealTime',i].AsString)='' then
    begin
      FQuoteRecs[i].Market := initm;
      FQuoteRecs[i].SetCode(FDBF.Field['CODE',i].AsString);
      FQuoteRecs[i].SetAbbr('--INVALID--');
      continue;
    end;

    with FQuoteRecs[i], FDBF do
    begin
      Market := initm;
      LevelType      := LevelZero;
      Time :=  Trunc(initm.Time) + StrToTime(Field['DealTime',i].AsString);
      SetCode(Field['CODE',i].AsString);
      //SetAbbr(Field['ABBR',i].AsString);
      Prev           := Field['prev',i].AsFloat;
      Open           := Field['open',i].AsFloat;
      Close          := Field['close',i].AsFloat;
      Last           := Field['price',i].AsFloat;
      //Volume         := Field['volume',i].AsLargeInt;
      Value          := Field['TURNOVER',i].AsFloat;
      DealCnt        := 0;
      High           := Field['high',i].AsFloat;
      Low            := Field['low',i].AsFloat;
      Buy[1].Price   := 0;
      Buy[1].Volume  := 0;
      Buy[2].Price   := 0;
      Buy[2].Volume  := 0;
    end;
  end;
end;

class function THKIndexDBF.FileKey: string;
begin
  result := 'INDEX.DBF';
end;

{ TFundEValueDBF }

constructor TFundEValueDBF.Create;
begin
  inherited;
  FSetting := TFormatSettings.Create(LOCALE_USER_DEFAULT);
  FSetting.ShortDateFormat:='yyyy-MM-dd';
  FSetting.DateSeparator:='-';
  FSetting.LongTimeFormat:='hh:mm:ss.zzz';
end;

procedure TFundEValueDBF.doScanQuote;
var
  i:integer;
  t:TDateTime;
  initm:TMarket;
  t1s,t1e, t2s,t2e:TTime;
begin
  inherited;
  t1s := EncodeTime(9,30,0,0);
  t1e := EncodeTime(11,30,0,0);
  t2s := EncodeTime(13,00,0,0);
  t2e := EncodeTime(15,00,0,0);

  t := now;
  initm.Code    := 'F';
  initm.Status  := '-';
  initm.Auction := 'N'; ////S:开市 ，T：交易  E:闭市  P:盘前交易（美） A:盘后交易（美）
  initm.Time    := t;

  //逐条转换DBF中的记录至行情数组
  try
    for i := 0 to Self.RecCount - 1 do
    begin
      with FQuoteRecs[i], FDBF do
      begin
        if Trim(Field['Time',i].AsString) <> '' then t := StrToDateTime(Field['Time',i].AsString, FSetting);
        initm.Time := t;
        if TimeInRange(t,t1s, t1e,true) or TimeInRange(t,t2s,t2e,true) then
          initm.Status := 'T'
        else
          initm.Status := 'E';
        Market := initm;
        LevelType := LevelZero;
        Time := t;
        SetCode(Field['Code',i].AsString);
        Last := Field['Value',i].AsFloat;
        PE1 := Field['Change',i].AsFloat;
        DealCnt := 0;
        Market.Time := Time;
      end;
    end;
  except
    on e: exception do log.AddLog('内部异常[TFundEValueDBF.doScanQuote]:'+e.Message);
  end;
end;

class function TFundEValueDBF.FileKey: string;
begin
  result := 'FUND_B.DBF';
end;

{ TFundEValueDBF2 }

class function TFundEValueDBF2.FileKey: string;
begin
  result := 'FUND_NB.DBF';
end;

{ TFundHQDBF }

constructor TFundHQDBF.Create;
begin
  inherited;
end;

procedure TFundHQDBF.doScanQuote;
var
  i:integer;
  t:TDateTime;
  initm:TMarket;
  s:string;
begin
  inherited;
  initm.Code    := 'F';
  initm.Status  := '-';
  initm.Auction := 'N';
  initm.Time    := Now;

  //逐条转换DBF中的记录至行情数组
  for i := 0 to Self.RecCount - 1 do
  begin
    with FQuoteRecs[i], FDBF do
    begin
      Valid := True;
      Market := initm;
      LevelType := LevelZero;
      s := Field['Time',i+1].AsString;
      if Length(s) < 9 then
      begin
        //PostLog(llWarning, Format('文件[%s],代码[%s],行情时间为空',[self.FileKey, Field['Code',i+1].AsString]));
        Valid := False;
        time := now;
      end else
      begin
        Time := EncodeTime(StrToInt(copy(s,01,2)), StrToInt(copy(s,03,2)), StrToInt(copy(s,05,2)), StrToInt(copy(s,07,3)));
      end;
      s := Field['ABBR',0].AsString;
      Time := Time + EncodeDate(StrToInt(copy(s,1,4)), StrToInt(copy(s,5,2)), StrToInt(copy(s,7,2)));
      SetCode(Field['Code',i+1].AsString);
      SetAbbr(Field['Abbr',i+1].AsString);
      Last := Field['Value',i+1].AsFloat;
      PE1 := Field['Change',i+1].AsFloat;
      DealCnt := 0;
      Market.Time := Time;
    end;
  end;
end;

class function TFundHQDBF.FileKey: string;
begin
  result := 'FUND_HQ.DBF';
end;

function TFundHQDBF.GetRecCound: Integer;
begin
  if Assigned(FDBF) then
    result := FDBF.RecCount-1
  else
    result := 0;
end;

{ TSWZSDBF }

procedure TSWZSDBF.doScanQuote;
var
  i:integer;
  t:TDateTime;
  initm:TMarket;
  L5, L11: AnsiString;
begin
  inherited;

  L5 := FDBF.Field[ 'L5', 0].AsString;  //第1条记录的L5字段为时间 ：HHMMSS
  if Length(L5)=5 then L5 := '0' + L5;

  L11:= FDBF.Field['L11', 0].AsString;  //第1条记录的L11字段为日期:YYYYMMDD

  initm.Code    := 'W';
  initm.Status  := '-';
  initm.Auction := 'N';

  initm.Time    := EncodeDateTime(
    StrToInt(Copy(L11,1,4)),
    StrToInt(Copy(L11,5,2)),
    StrToInt(Copy(L11,7,2)),
    StrToInt(Copy( L5,1,2)),
    StrToInt(Copy( L5,3,2)),
    StrToInt(Copy( L5,5,2)),0);


  //逐条转换DBF中的记录至行情数组
  for i := 1 to Self.RecCount do
  begin
    with FQuoteRecs[i-1], FDBF do
    begin
      Market := initm;
      LevelType      := LevelOne;
      Time           := Now;
      SetCode(Field['L1',i].AsString);
      SetAbbr(Field['L2',i].AsString);
      Prev           := Field['L3',i].AsFloat;
      Open           := Field['L4',i].AsFloat;
      Close          := Field['L8',i].AsFloat;
      Last           := Field['L8',i].AsFloat;
      Volume         := Trunc(Field['L11',i].AsFloat);
      Value          := Field['L5',i].AsFloat;
      DealCnt        := 0;
      High           := Field['L6',i].AsFloat;
      Low            := Field['L7',i].AsFloat;
      Buy[1].Price   := 0;
      Buy[1].Volume  := 0;
      Buy[2].Price   := 0;
      Buy[2].Volume  := 0;
    end;
  end;
end;

class function TSWZSDBF.FileKey: string;
begin
  result := 'SWZS.DBF';
end;

function TSWZSDBF.GetRecCound: Integer;
begin
  if Assigned(FDBF) then
    result := FDBF.RecCount-1
  else
    result := 0;
end;

{ TCSIFile }

procedure TCSIFile.ClearResource;
begin
  inherited;

end;

procedure TCSIFile.doScanQuote;
var
  jysj:TDateTime; //交易时间
  i:integer;
  initm:TMarket;
begin
  inherited;

  initm.Code    := 'C';
  initm.Status  := '-';
  initm.Auction := 'N';
  initm.Time    := Now;

  //获取文件头的交易日期和时间
  jysj := Str2Date(Trim(Fhead.JYRQ)) + Str2Time(Trim(Fhead.GXSJ));

  //加载CSI行情至数组
  try
    for i := 0 to Self.RecCount - 1 do
    begin
      with FQuoteRecs[i] do
      begin
        Market := InitM;
        LevelType := LevelZero;
        Time := jysj;
        SetCode(FList[i].Body.Quota.ZSDM);
        SetAbbr(FList[i].Body.Quota.JC);
        Prev := StrToFloatDef(FList[i].Body.Quota.ZRSP,0);
        Open := StrToFloatDef(FList[i].Body.Quota.DRKP,0);
        High := StrToFloatDef(FList[i].Body.Quota.DRZD,0);
        Low  := StrToFloatDef(FList[i].Body.Quota.DRZX,0);
        Last := StrToFloatDef(FList[i].Body.Quota.SSZS,0);
        Close:= StrToFloatDef(FList[i].Body.Quota.DRSP,0);
        Volume := StrToInt64Def(FList[i].Body.Quota.CJL,0);
        Value  := StrToFloatDef(FList[i].Body.Quota.CJJE,0);
        PE1    := StrToFloatDef(FList[i].Body.Quota.DRSP2,0);
        PE2    := StrToFloatDef(FList[i].Body.Quota.DRSP3,0);
        DealCnt := 0;
      end;
    end;
  except
    on e:exception do
    begin
      log.AddLogFormat('TCSIFile.doScanQuote Error:%s', [e.Message]);
      Log.AddLogFormat('TCSIFile.doScanQuote StackTrace:%s', [e.Message]);
    end;
  end;
end;

class function TCSIFile.FileIsMatch(AFileName: string): boolean;
begin
  result := TRegEx.IsMatch(AFileName, '^csi\d+', [roIgnoreCase]);
end;

class function TCSIFile.FileKey: string;
begin
  result := 'ZZZS.TXT';
end;

function TCSIFile.GetRecCound: Integer;
begin
  result := FList.Count;
end;

procedure TCSIFile.InitFile;
var
  i,cnt,jllx:Integer;
  tmp:PByte;
  rec:TCSI_Record;
begin
  inherited;
  FHead := FptrBuffer;
  FList := TList<TCSI_Record>.Create;

  cnt := StrToIntDef(Trim(FHead.JLS), 0); //确定记录条数
  tmp := fPtrBuffer;

  for i := 0 to cnt - 1 do
  begin
    FillChar(rec, SizeOf(TCSI_Record), 0);
    rec.Body.Data := tmp;

    if i = 0 then
    begin
      rec.RecordType := csiFileHad;
      inc(tmp, SizeOf(TCSI_FILE_HEAD));
    end else
    begin
      rec.RecordType := TCSI_RecordType(StrToIntDef(Trim(PCSI_RecHead(tmp).JLLX),0));
      case rec.RecordType of
        csiFileHad: ;
        csiIndexQuota:
        begin
          inc(tmp, SizeOf(TCSI_IndexRecord));
          FList.Add(rec);
        end;
        csiMemberWeight: ;
        csiIPOV: inc(tmp, SizeOf(TCSI_ETFIOPV));
      end;
    end;
  end;

end;

function TCSIFile.Str2Date(AValue: string): TDate;
var
  y,m,d:word;
begin
  y := strtoint(LeftBStr(AValue,4));
  m := strtoint(MidBStr(AValue,5,2));
  d := strtoint(RightStr(AValue,2));
  result := EncodeDate(y,m,d);
end;

function TCSIFile.Str2Time(AValue: string): TTime;
var
  h,m,s:word;
begin
  h := strtoint(LeftBStr(AValue,2));
  m := strtoint(MidBStr(AValue,3,2));
  s := strtoint(RightStr(AValue,2));
  result := EncodeTime(h,m,s,0);
end;

{ TFundNVDBF }

procedure TFundNVDBF.doScanQuote;
var
  i:integer;
  t:TDateTime;
  initm:TMarket;
  s:string;
begin
  inherited;
  initm.Code    := 'F';
  initm.Status  := '-';
  initm.Auction := 'N';
  initm.Time    := Now;

  //逐条转换DBF中的记录至行情数组
  for i := 0 to Self.RecCount - 1 do
  begin
    with FQuoteRecs[i], FDBF do
    begin
      Valid := True;
      Market := initm;
      LevelType := LevelZero;
      s := Field['Time',i+1].AsString;
      if length(S)<8 then
      begin
        Valid := False;
        Continue;
      end;
      Market.Time := EncodeDate(StrToInt(copy(s,1,4)), StrToInt(copy(s,5,2)), StrToInt(copy(s,7,2)));
      FQuoteRecs[i].Time := Market.Time;
      SetCode(Field['Code',i+1].AsString);
      Last := Field['Value',i+1].AsFloat;
      PE1 := Field['Change',i+1].AsFloat;
      DealCnt := 0;
    end;
  end;
end;

class function TFundNVDBF.FileKey: string;
begin
  result := 'FUND_NV.DBF';
end;

function TFundNVDBF.GetRecCound: Integer;
begin
  if Assigned(FDBF) then
    result := FDBF.RecCount-1
  else
    result := 0;
  result := MAX(0,result); // 不可为负
end;

{ TFundBasicDBF }

procedure TFundBasicDBF.doScanQuote;
var
  i:integer;
  t:TDateTime;
  initm:TMarket;
  s:string;
begin
  inherited;
  initm.Code    := 'F';
  initm.Status  := '-';
  initm.Auction := 'N';
  initm.Time    := Now;

  //逐条转换DBF中的记录至行情数组
  for i := 0 to Self.RecCount - 1 do
  begin
    with FQuoteRecs[i], FDBF do
    begin
      Valid := True;
      Market := initm;
      LevelType := LevelZero;
      s := Field['ENDDATET_1',i+1].AsString;
      if length(S)<8 then
      begin
        Valid := False;
        Continue;
      end;
      Market.Time := EncodeDate(StrToInt(copy(s,1,4)), StrToInt(copy(s,5,2)), StrToInt(copy(s,7,2)));
      FQuoteRecs[i].Time := Market.Time;
      SetCode(Field['Code',i+1].AsString);
      SetAbbr(Field['ABBR',i+1].AsString);
      Last := Field['UNITNVT_1',i+1].AsFloat;
      PE1 := 0;
      DealCnt := 0;
    end;
  end;
end;

class function TFundBasicDBF.FileKey: string;
begin
  result := 'FUND_BASIC.DBF';
end;

function TFundBasicDBF.GetRecCound: Integer;
begin
  if Assigned(FDBF) then
    result := FDBF.RecCount-1
  else
    result := 0;
  result := MAX(0,result); // 不可为负
end;

initialization

finalization


end.
