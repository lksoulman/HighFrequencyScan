unit uQuoteScan;

interface
uses
  Classes, types, SysUtils, StrUtils, DateUtils, IOUtils, Windows, Math,
  SynLZ, uQuoteFile;

const

  Q_FILE_BLOCK_SIZE=32;

type

  //每块大小固定32个字节
  PFileBlock = ^TFileBlock;
  TFileBlock = record
    Order: DWORD;
    Len  : Byte;
    Bytes: array[1..Q_FILE_BLOCK_SIZE] of Byte;
  end;

  //以32个字节为扫描单位，对比行情文件前后差异
  TBinaryQuote = class(TQuoteBase)
  strict private
    FLastStream: TMemoryStream;
    FDiffStream: TMemoryStream;
  protected
    procedure InitFile; override;
  public
    constructor Create; override;
    destructor Destroy; override;
    function Shotsnap:boolean;
    property Difference:TMemoryStream read FDiffStream;
  end;

  IQRecordScaner = Interface
  ['{B760A9BD-B355-42DE-8D78-C44B8E873881}']
  end;

  TQuoteScanConfig = class

  end;

  TQuoteScan = class
  strict private

  public

  end;

implementation

{$WARNINGS OFF}

{ TBinaryQuote }

constructor TBinaryQuote.Create;
begin
  inherited;
  FLastStream := TMemoryStream.Create;
  FDiffStream := TMemoryStream.Create;
end;

destructor TBinaryQuote.Destroy;
begin
  FLastStream.Free;
  FDiffStream.Free;
  inherited;
end;

procedure TBinaryQuote.InitFile;
begin
  inherited;
  FLastStream.Seek(0, soBeginning);
  FLastStream.Write(Self.FptrBuffer^, FileSize);
end;

function TBinaryQuote.Shotsnap: boolean;
var
  i,k,iBlockCount:DWORD;
  ptr1, ptr2:PByte;
  tmp: TFileBlock;
begin

  iBlockCount := 0;
  FDiffStream.Size := 0;
  FDiffStream.Write(iBlockCount, SizeOf(DWORD));
  ScanQuote;

  FLastStream.Seek(0, soBeginning);

  ptr1 := FLastStream.Memory;
  ptr2 := self.FptrBuffer;

  for i := 0 to Ceil(FileSize / Q_FILE_BLOCK_SIZE) - 1 do
  begin
    k := Min(FileSize-i*Q_FILE_BLOCK_SIZE,Q_FILE_BLOCK_SIZE);
    if not CompareMem(ptr1, ptr2, k) then
    begin
      tmp.Order := 0;
      tmp.Len := k;
      Move(ptr2^, tmp.Bytes[1], k);
      FDiffStream.Write(tmp.Order, SizeOf(TFileBlock));
      inc(iBlockCount);
    end;
    Inc(ptr1, Q_FILE_BLOCK_SIZE);
    Inc(ptr2, Q_FILE_BLOCK_SIZE);
  end;
  FDiffStream.Seek(0, soBeginning);
  FDiffStream.Write(iBlockCount, SizeOf(DWORD));
  result := iBlockCount > 0;

  if result then
  begin
    FLastStream.Seek(0, soBeginning);
    FLastStream.Write(Self.FptrBuffer^, FileSize);
  end;
end;

end.
