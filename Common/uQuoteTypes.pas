unit uQuoteTypes;

interface

uses

  Types, DateUtils, SysUtils, Classes, IOUtils, Math,
  uZipTools, ulog;

type

  QString = AnsiString;

  TQuoteMsgType = (
    qmtUnknow        = 00,
    qmtHeart         = 01,
    qmtOperResponse  = 05,
    qmtFile          = 06,
    qmtFileBlocks    = 07,
    qmtLogin         = 10,
    qmtBinaryBlocks  = 20, //文件块集合
    qmtNetTest       = 90,
    qmtTimeTest      = 91,
    qmtCustom        = 99
  );

  TQuoteLoingState = (qlsOK=0, qlsInvalidUser=1,qlsInvalidIP=2, qlsExpire=3);



  //包头定义
  PQuoteMsgPackHead = ^TQuoteMsgPackHead;
  TQuoteMsgPackHead = packed record
    PackageLen  : Integer;
    PackageType : TQuoteMsgType;
    IsCompress  : Integer; //0:未压缩  1:已压缩
    BodyLen     : Integer; //数据包长度;
    function DataPtr:Pointer;
    function IsEmpty:boolean;
  end;

  PQuoteLoginInfo = ^TQuoteLoginInfo;
  TQuoteLoginInfo = packed record
    UserName: array[1..32] of AnsiChar;
    PassWord: array[1..32] of AnsiChar;
  end;

  PQuoteOperResponse = ^TQuoteOperResponse;
  TQuoteOperResponse = packed record
    OperCode: Integer;
    ReturnCode: Integer;
    Message:array[1..256] of AnsiChar;
    function GetMessage:string;
  end;

  TQuoteNetTest = packed record
    TICK: Cardinal;
  end;
  PQuoteFilePack = ^TQuoteFilePack;
  TQuoteFilePack = packed record
    FileName: array[1..32] of AnsiChar;
    FileLength: Integer;
    procedure SetFileName(fn:QString);
    function GetFileName:string;
    function GetContextPtr:Pointer;
  end;

  PQuoteTimeTest = ^TQuoteTimeTest;
  TQuoteTimeTest = packed record
    Tick:Cardinal;
    T1,T2,T3:TDateTime;
  end;
  //网络数据包对象定义
  TQuoteMsgPack = class
  strict private
    FBuffer: PByte;
    function GetHeadInfo:TQuoteMsgPackHead;
    function GetPackageLen: Integer;
    function GetIsEmpty: Boolean;
    function GetPassWord: string;
    function GetUserName: string;
    function GetBodyBuffer:Pointer;
  public
    constructor Create(AType: TQuoteMsgType; const ASrcData; iDataLen:Integer); overload;
    constructor Create(const Raw; iRawLen:Integer); overload;
    constructor Create(Head:TQuoteMsgPackHead; const ASrcData; iDataLen:Integer); overload;
    destructor Destroy; override;
    procedure Append(const ASrcData; iLen:Integer);
    //Compress&Decompress
    procedure Compress;
    procedure Decompress;
    //Properies...
    property Buffer:PByte read FBuffer;
    property BodyBuffer: Pointer read GetBodyBuffer;
    property IsEmpty:boolean read GetIsEmpty;
    property HeadInfo: TQuoteMsgPackHead read GetHeadInfo;
    property PackageLen: Integer read GetPackageLen;
    property UserName:string read GetUserName;
    property PassWord:string read GetPassWord;
    //Utility functions...
    class function Build(const AData; iDataLen:Integer): TQuoteMsgPack; overload;
    class function BuildHeartbeat:TQuoteMsgPack; overload;
    class function Build(AStream:TStream): TQuoteMsgPack; overload;
    class function Build(AUsername, APassword:QString): TQuoteMsgPack; overload;
    class function Build(iOperCode:Integer; iRetCode:Integer; AMessage:QString): TQuoteMsgPack; overload;
    class function BuildUnknow:TQuoteMsgPack;
    class function IsFullyPack(const APackageHead; iLen:Integer):boolean;
  end;

  const PACKAGE_HEAD_SIZE = SizeOf(TQuoteMsgPackHead); //通用封包的包头长度

  const Q_BINARY_BLOCK_SIZE = 32; //每块大小固定32个字节

type
  //二进制文件块信息
  PQBinaryBlock = ^TQBinaryBlock;
  TQBinaryBlock = packed record
    Order: DWORD;
    Len  : Byte;
    Bytes: array[1..Q_BINARY_BLOCK_SIZE] of Byte;
  end;

  PQFileBlocks = ^TQFileBlocks;
  TQFileBlocks = packed record
    FileName   :array[1..32] of AnsiChar;
    BlockCount :Integer;
    Context    :array[0..160000-1] of TQBinaryBlock; //可存储5M左右
    procedure SetFileName(AValue:QString);
    procedure Reset(Src:TQuoteMsgPack);
    function RecordSize:Integer;
    function GetFileName:string;
  end;

function ConvertAnsiStr(const AValue:PAnsiChar; bUpper:boolean=False):string;

implementation

function ConvertAnsiStr(const AValue:PAnsiChar; bUpper:boolean=False):string;
begin
  if bUpper then
    result := UpperCase(Trim(AValue))
  else
    result := Trim(AValue);
end;

function ReadFileAllBytes(ASource:string):TBytes;
var
  fm:TFileStream;
begin
  fm := TFileStream.Create(ASource, fmOpenRead or fmShareDenyNone);
  setLength(result, fm.Size);
  fm.Read(result[0], fm.Size);
  fm.Free;
end;

{ TQuoteMsgPack }

class function TQuoteMsgPack.Build(const AData; iDataLen: Integer): TQuoteMsgPack;
begin
  result := TQuoteMsgPack.Create(qmtCustom, AData, iDataLen);
end;

class function TQuoteMsgPack.Build(AStream: TStream): TQuoteMsgPack;
var
  clone:TMemoryStream;
begin
  clone := TMemoryStream.Create;
  clone.LoadFromStream(AStream);
  result := TQuoteMsgPack.Create(qmtCustom, Clone.Memory^, clone.Size);
  clone.Free;
end;

class function TQuoteMsgPack.BuildHeartbeat: TQuoteMsgPack;
var
  any:integer;
begin
  result := TQuoteMsgPack.Create(qmtHeart, any, 0);
end;

class function TQuoteMsgPack.BuildUnknow: TQuoteMsgPack;
var
  any:integer;
begin
  result := TQuoteMsgPack.Create(qmtUnknow,any,0);
end;

procedure TQuoteMsgPack.Compress;
var
  newl: Integer;
  cbuf: TBytes;
begin
  //小于4K不压缩
  if HeadInfo.PackageLen<2*1024 then Exit;
  if HeadInfo.IsCompress=1 then Exit;

  //压缩
  cbuf := TZipTools.compressBuf(FBuffer[PACKAGE_HEAD_SIZE], HeadInfo.BodyLen);
  newl := Length(cbuf);

  //替换包体
  ReallocMem(FBuffer, PACKAGE_HEAD_SIZE+newl);
  Move(cbuf[0], FBuffer[PACKAGE_HEAD_SIZE], newl);

  //重置包头信息
  PQuoteMsgPackHead(FBuffer).PackageLen := PACKAGE_HEAD_SIZE+newl;
  PQuoteMsgPackHead(FBuffer).IsCompress := 1;
  PQuoteMsgPackHead(FBuffer).BodyLen := newl;

  SetLength(cbuf,0);
end;

constructor TQuoteMsgPack.Create(Head: TQuoteMsgPackHead; const ASrcData; iDataLen: Integer);
begin
  GetMem(FBuffer, PACKAGE_HEAD_SIZE+iDataLen);
  //Set HeadInfo
  PQuoteMsgPackHead(FBuffer)^ := Head;
  //Copy Body Data
  Move(ASrcData, GetBodyBuffer^, iDataLen);
end;

constructor TQuoteMsgPack.Create(const Raw; iRawLen: Integer);
begin
  FBuffer := nil;
  GetMem(FBuffer, iRawLen);
  Move(Raw, FBuffer^, iRawLen);
end;

constructor TQuoteMsgPack.Create(AType: TQuoteMsgType; const ASrcData; iDataLen:Integer);
begin
  GetMem(FBuffer,PACKAGE_HEAD_SIZE+iDataLen);
  with PQuoteMsgPackHead(FBuffer)^ do
  begin
    PackageType := AType;
    PackageLen := PACKAGE_HEAD_SIZE+iDataLen;
    IsCompress := 0;
    BodyLen := iDataLen;
  end;
  //Copy Body Data
  Move(aSrcData, GetBodyBuffer^, iDataLen);
end;

procedure TQuoteMsgPack.Decompress;
var
  newl: Integer;
  cbuf: TBytes;
begin
  //未压缩，直接退出
  if HeadInfo.IsCompress = 0 then Exit;

  //解压
  cbuf := TZipTools.unCompressBuf(FBuffer[PACKAGE_HEAD_SIZE], HeadInfo.BodyLen);
  newl := Length(cbuf);

  //替换包体
  ReallocMem(FBuffer, PACKAGE_HEAD_SIZE+newl);
  Move(cbuf[0], FBuffer[PACKAGE_HEAD_SIZE], newl);

  //重置包头信息
  PQuoteMsgPackHead(FBuffer).PackageLen := PACKAGE_HEAD_SIZE+newl;
  PQuoteMsgPackHead(FBuffer).IsCompress := 0;
  PQuoteMsgPackHead(FBuffer).BodyLen := newl;

  SetLength(cbuf,0);
end;

destructor TQuoteMsgPack.Destroy;
begin
  if Assigned(FBuffer) then
    FreeMem(FBuffer);
  inherited;
end;

function TQuoteMsgPack.GetBodyBuffer: Pointer;
begin
  result := Pointer(Integer(Pointer(FBuffer))+PACKAGE_HEAD_SIZE);
end;

function TQuoteMsgPack.GetHeadInfo: TQuoteMsgPackHead;
begin
  result := PQuoteMsgPackHead(FBuffer)^;
end;

function TQuoteMsgPack.GetIsEmpty: Boolean;
begin
  result := HeadInfo.IsEmpty;
end;

function TQuoteMsgPack.GetPackageLen: Integer;
begin
  result := Self.HeadInfo.PackageLen;
end;

function TQuoteMsgPack.GetPassWord: string;
var
  p:PAnsiChar;
  li:pQuoteLoginInfo;
begin
  li := GetBodyBuffer;
  p := @li.PassWord[1];
  result := Trim(p);
end;

function TQuoteMsgPack.GetUserName: string;
var
  p:PAnsiChar;
  li:pQuoteLoginInfo;
begin
  li := GetBodyBuffer;
  p := @li.UserName[1];
  result := Trim(p);
end;

class function TQuoteMsgPack.IsFullyPack(const APackageHead; iLen: Integer): boolean;
var
  tmp: PQuoteMsgPackHead absolute APackageHead;
begin

  result := iLen >= PACKAGE_HEAD_SIZE;

  if result then
    result := iLen >= tmp.PackageLen;

end;

class function TQuoteMsgPack.Build(AUsername, APassword: QString): TQuoteMsgPack;
var
  login:TQuoteLoginInfo;
begin
  FillChar(login, sizeof(TQuoteLoginInfo), 0);
  Move(aUserName[1], login.UserName, Min(32, Length(AUserName)));
  Move(APassword[1], login.PassWord, Min(32, Length(APassword)));
  result := TQuoteMsgPack.Create(qmtLogin, login, SizeOf(TQuoteLoginInfo));
end;

procedure TQuoteMsgPack.Append(const ASrcData; iLen: Integer);
var
  oldHead:TQuoteMsgPackHead;
  tmp:PByte;
begin
  oldHead := HeadInfo;

  ReallocMem(FBuffer, oldhead.PackageLen+iLen);

  tmp := FBuffer;
  inc(tmp, oldHead.PackageLen);
  Move(aSrcData, tmp^, iLen);

  //Reassign head info
  oldHead.PackageLen := oldhead.PackageLen+iLen;
  oldHead.BodyLen := oldHead.BodyLen + iLen;
  PQuoteMsgPackHead(FBuffer)^ := oldHead;

end;

class function TQuoteMsgPack.Build(iOperCode, iRetCode: Integer; AMessage: QString): TQuoteMsgPack;
var
  tmp:TQuoteOperResponse;
begin
  FillChar(tmp, SizeOf(TQuoteOperResponse),0);
  tmp.OperCode := iOperCode;
  tmp.ReturnCode := iRetCode;
  Move(AMessage[1], tmp.Message[1], Min(Length(AMessage), SizeOf(tmp.Message)));
  result := Create(qmtOperResponse, tmp, SizeOf(TQuoteOperResponse));
end;

{ TQuoteMsgPackHead }

function TQuoteMsgPackHead.DataPtr: Pointer;
begin
  result := Pointer(Integer(@PackageLen)+PACKAGE_HEAD_SIZE);
end;

function TQuoteMsgPackHead.IsEmpty: boolean;
begin
  result := BodyLen = 0;
end;

{ TQuoteFilePack }

function TQuoteFilePack.GetContextPtr: Pointer;
var
  p:PByte;
begin
  p := @FileName[1];
  inc(p, SizeOf(TQuoteFilePack));
  result := p;
end;

function TQuoteFilePack.GetFileName: string;
var
  p:PAnsiChar;
begin
  p := @self.filename[1];
  result := Trim(p);
end;

procedure TQuoteFilePack.SetFileName(fn: QString);
begin
  FillChar(self.FileName[1], 32, 0);
  Move(fn[1], FileName[1], Min(32,Length(fn)));
end;

{ TFileBlocks }

function TQFileBlocks.GetFileName: string;
var
  p:PAnsiChar;
begin
  p := @self.filename[1];
  result := UpperCase(Trim(p));
end;

function TQFileBlocks.RecordSize: Integer;
begin
  result := Length(FileName)+SizeOf(BlockCount);
  result := result + SizeOf(TQBinaryBlock)*BlockCount;
end;

procedure TQFileBlocks.Reset(Src:TQuoteMsgPack);
var
  pQFB: PQFileBlocks;
begin
  pQFB := Src.BodyBuffer;
  BlockCount := pQFB.BlockCount;
  Move(pQFB.FileName[1], FileName[1], 32);
  Move(pQFB.Context[0], pQFB.Context[0], BlockCount*SizeOf(TQBinaryBlock));
end;

procedure TQFileBlocks.SetFileName(AValue: QString);
begin
  FillChar(self.FileName[1], 32, 0);
  Move(AValue[1], FileName[1], Min(32,Length(AValue)));
end;

{ TQuoteOperResponse }

function TQuoteOperResponse.GetMessage: string;
begin
  result := ConvertAnsiStr(@Message[1]);
end;

end.
