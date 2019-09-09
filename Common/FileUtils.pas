unit FileUtils;

interface

uses

  Classes,SysUtils, Windows, IOUtils, Math;

type

  //每块大小固定32个字节
  PFileBlock = ^TFileBlock;
  TFileBlock = record
    Order: DWORD;
    Len: Byte;
    Bytes: array[1..32] of Byte;
  end;

  TFileBlocks = class
  private
    FList: TList;
    function GetCount: Integer;
    procedure Clear;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Push(ptr:PByte; iOrder:DWORD; iLen:Byte);
    property Count: Integer read GetCount;
  end;

  TQuotaFile = class
  private
    FFileName: string;
    FFileHandle : THandle;
    FMapHandle: THandle;
    FDataPtr:PByte;
    FSnapPtr: PByte;
    FFileSize:DWORD;
    FBlocks: TFileBlocks;
    procedure SaveSnap;
  public
    constructor Create(ASource:string);
    destructor Destroy; override;
    property FileName:string read FFileName;
    procedure Compare;
    procedure WriteBlocks(ABlocks: TFileBlocks);
  end;

  function Compress(ASource:Pointer; ALen:Integer):TMemoryStream;
  function DeCompress(ASource:Pointer; ALen:Integer):TMemoryStream;

implementation

uses SynLZ;
{ TQuotaFile }

constructor TQuotaFile.Create(ASource: string);
var
  tmp:AnsiString;
begin
  FFileHandle := 0;
  FMapHandle := 0;
  FDataPtr := nil;
  FSnapPtr := nil;
  FBlocks := TFileBlocks.Create();

  FFileName := TPath.GetFullPath(ASource);

  FFileHandle := CreateFile(PWideChar(FFilename), GENERIC_READ,FILE_SHARE_READ,nil,OPEN_EXISTING,0,0);
  tmp := FFileName;
  if FFileHandle = INVALID_HANDLE_VALUE then
    raise Exception.Create('创建文件失败！');

  FFileSize := GetFileSize(FFileHandle, nil);
  GetMem(FSnapPtr, FFileSize);

  FMapHandle := CreateFileMapping(FFileHandle,nil,PAGE_READONLY,0,FFileSize,nil);

  if FMapHandle=0 then
    raise Exception.Create('建立文件映射失败');

  FDataPtr := MapViewOfFile(FMapHandle,FILE_MAP_READ,0,0,FFileSize);
  SaveSnap;
end;


destructor TQuotaFile.Destroy;
begin
  CloseHandle(FMapHandle);
  CloseHandle(FFileHandle);
  FreeMem(FSnapPtr);

  FBlocks.Free;
  inherited;
end;

procedure TQuotaFile.SaveSnap;
begin
  CopyMemory(FSnapPtr, FDataPtr, FFileSize);
end;

procedure TQuotaFile.WriteBlocks(ABlocks: TFileBlocks);
begin

end;

procedure TQuotaFile.Compare;
var
  i,k:DWORD;
  ptr1, ptr2:PByte;
begin
  FBlocks.Clear;

  ptr1 := FSnapPtr;
  ptr2 := FDataPtr;

  for i := 0 to Ceil(FFileSize / 32) - 1 do
  begin
    k := Min(FFileSize-i*32,32);
    if not CompareMem(ptr1, ptr2, k) then
      FBlocks.Push(ptr2, i, k);
    inc(ptr1, 32);
    inc(ptr2, 32);
  end;


  SaveSnap;
end;

{ TFileBlocks }

procedure TFileBlocks.Push(ptr:PByte; iOrder:DWORD; iLen:Byte);
var
  pBlock:PFileBlock;
begin
  GetMem(pBlock, SizeOf(TFileBlocks));
  pBlock.Order := iOrder;
  pBlock.Len := iLen;
  Move(ptr^, pBlock.Bytes[1], iLen);
  FList.Add(pBlock);
end;

procedure TFileBlocks.Clear;
var
  perBlock:PFileBlock;
begin
  for perBlock in FList do
    FreeMem(perBlock);
  FList.Clear;
end;

constructor TFileBlocks.Create;
begin
  FList := TList.Create;

end;

destructor TFileBlocks.Destroy;
begin
  Clear;
  FList.Free;
  inherited;
end;

function TFileBlocks.GetCount: Integer;
begin
  result := FList.Count;
end;

function Compress(ASource:Pointer; ALen:Integer):TMemoryStream;
var
  len:Integer;
begin
  result := TMemoryStream.Create;
  if ALen=0 then Exit;

  result.SetSize(SynLZcompressdestlen(ALen));

  len := SynLZcompress1pas(ASource, ALen, result.Memory);
  result.SetSize(len);
end;

function DeCompress(ASource:Pointer; ALen:Integer):TMemoryStream;
begin
  result := TMemoryStream.Create;
  if ALen=0 then Exit;
  result.SetSize(SynLZdecompressdestlen(ASource));
  SynLZdecompress1pas(ASource, ALen, result.Memory);
end;

end.
