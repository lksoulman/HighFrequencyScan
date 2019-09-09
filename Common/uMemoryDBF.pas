unit uMemoryDBF;

interface

uses

  Classes, SysUtils, Types, DB, Windows, IOUtils, Generics.Collections;

type
  // DBF文件头结构
  PDBFHead = ^TDBFHead;
  TDBFHead = packed record
    Mark: AnsiChar;
    Year: Byte;
    Month: Byte;
    Day: Byte; //4
    RecCount: Integer; //8
    DataOffset: Word; //10
    RecSize: Word; //12
    Reserved: array[0..19] of AnsiChar;
  end;

  // DBF文件每字段结构
  PDBFField = ^TDBFField;
  TDBFField = packed record
    FieldName: array[0..10] of AnsiChar;
    FieldType: AnsiChar;
    FieldOffset: Integer;
    Width: Byte;
    Scale: Byte;
    Reserved: array[0..13] of AnsiChar;
  end;
  TDBFFields = array[0..254] of TDBFField;
  PDBFFields = ^TDBFFields;

  TField = class
  private
    FDataBuf: PAnsiChar;
    FPtr: PDBFField;
    FFieldBuf: array[0..255] of AnsiChar;
  protected
    function GetAsBoolean: Boolean;
    function GetAsChar: AnsiChar;
    function GetAsDate: TDateTime;
    function GetAsFloat: Double;
    function GetAsInteger: Integer;
    function GetAsLargeInt: Int64;
    function GetAsString: AnsiString;
    function GetAsStringX: AnsiString; // 包括尾部空格
    function GetAsSingle: Single;
    function GetAsPointer: PAnsiChar;
    function GetFieldType: AnsiChar;
    function GetWidth: Byte;
    function GetScale: Byte;
    function GetFieldName: AnsiString;

    procedure SetAsBoolean(Value: Boolean);
    procedure SetAsChar(Value: AnsiChar);
    procedure SetAsDate(Value: TDateTime);
    procedure SetAsFloat(Value: Double);
    procedure SetAsInteger(Value: Integer);
    procedure SetAsString(const Value: AnsiString);
    procedure SetAsPointer(const Value: PAnsiChar);
  public
    constructor Create(pSrc: PDBFField);
    destructor Destroy; override;

    property AsBoolean: Boolean read GetAsBoolean write SetAsBoolean;
    property AsChar: AnsiChar read GetAsChar write SetAsChar;
    property AsDateTime: TDateTime read GetAsDate write SetAsDate;
    property AsSingle: Single read GetAsSingle;
    property AsFloat: Double read GetAsFloat write SetAsFloat;
    property AsInteger: Integer read GetAsInteger write SetAsInteger;
    property AsLargeInt:Int64 read GetAsLargeInt;
    property AsString: AnsiString read GetAsString write SetAsString;
    property AsStringX: AnsiString read GetAsStringX;
    property AsPointer: PAnsiChar read GetAsPointer write SetAsPointer;
    property FieldType: AnsiChar read GetFieldType;
    property Width: Byte read GetWidth;
    property Scale: Byte read GetScale;
    property FieldName: AnsiString read GetFieldName;
  end;

  TFieldList = class(TList)
  private
    function GetField(Index: Integer): TField;
  protected
    procedure Notify(Ptr: Pointer; Action: TListNotification); override;
  public
    function Add(Field: TField): Integer; overload;
    property Fields[Index: Integer]: TField read GetField;
  end;

  TMemoryDBF = class
  private
    FHead: PDBFHead;
    FDBFFields: PDBFFields;
    FFieldCount,FRecCount: Integer;
    FFieldList:TObjectDictionary<string,TField>;
    function GetFieldByName(AFieldName:string; ARecIndex:Integer):TField;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Link(const Address:Pointer);
    property FieldCount:Integer read FFieldCount;
    property RecCount:Integer read FRecCount;
    property Field[AFieldName:string; ARecIndex:Integer]: TField read GetFieldByName;
  end;

  //自定义压缩DBF数据流
  TColumnType = (ctInt, ctInt64, ctSinfle, ctDouble, ctChar);
  TPackedDBF = class
  private
    FHeadBuffer:TMemoryStream;
    FColumns: TObjectList<TMemoryStream>;
    function GetColumnType(AField:TField): TColumnType;
    procedure WriteInt32(AColIndex:Integer; AValue:Integer);
    procedure WriteInt64(AColIndex:Integer; AValue:Int64);
    procedure WriteSingle(AColIndex:Integer; AValue:Single);
    procedure WriteDouble(AColIndex:Integer; AValue:double);
    procedure WriteString(AColIndex:Integer; AValue:AnsiString);
    procedure WriteToFile(ATarget:string);
  public
    constructor Create;
    destructor Destroy; override;
    class function Compress(ASource:string): TPackedDBF;
    class function Decompresss(ABuf:PByte; iLen:Integer):TBytes;
  end;
  function SwapBytes(Value: Integer): Integer; register;
  function Swap64(Value: Int64): Int64;
implementation
{$WARNINGS OFF}
function SwapBytes(Value: Integer): Integer; register;
asm  BSWAP  EAX end;

function Swap64(Value: Int64): Int64;
begin
  Result:= SwapBytes(LongWord(Value));
  Result:= (Result shl 32) or SwapBytes(LongWord(Value shr 32));
end;
{ TField }

constructor TField.Create(pSrc: PDBFField);
begin
  inherited Create;
  GetMem(fPtr, SizeOf(TDBFField));
  Move(pSrc^, fPtr^, SizeOf(TDBFField));
  //FPtr := Ptr;
end;

destructor TField.Destroy;
begin
  FreeMem(FPtr);
  inherited;
end;

function TField.GetAsBoolean: Boolean;
begin
  Result := (FPtr^.FieldType = 'L') and ((FDataBuf + FPtr^.FieldOffset)^ = 'T');
end;

function TField.GetAsChar: AnsiChar;
begin
  Result := (FDataBuf + FPtr^.FieldOffset)^;
end;

function TField.GetAsDate: TDateTime;
begin
  GetAsPointer;
  try
    Result := EncodeDate(StrToIntDef(Copy(FFieldBuf, 1, 4), 0),
      StrToIntDef(Copy(FFieldBuf, 5, 2), 0),
      StrToIntDef(Copy(FFieldBuf, 7, 2), 0));
  except
    Result := EncodeDate(1980, 01, 01);
  end;
end;

function TField.GetAsFloat: Double;
begin
  if not TryStrToFloat(GetAsString,result) then exit(0);
end;

function TField.GetAsInteger: Integer;
begin
  //GetAsPointer;
  if not TryStrToInt(GetAsString, result) then result := 0;
  //Result := StrToIntDef(GetAsString, 0); //FFieldBuf, 0);
end;

function TField.GetAsLargeInt: Int64;
begin
  if not TryStrToInt64(GetAsString, result) then result := 0;
end;

function TField.GetAsSingle: Single;
begin
  if not TryStrToFloat(GetAsString,result) then exit(0);
end;

function TField.GetAsString: AnsiString;
var
  i: Integer;
begin
  GetAsPointer;
  for i := FPtr^.Width - 1 downto 0 do
    if FFieldBuf[i] <> ' ' then
      Break;
  FFieldBuf[i + 1] := #0;
  Result := FFieldBuf;

  if result = '' then
  case FPtr.FieldType of
    'I': result := '0';
    'N','F', 'Y', 'B': result := '0.0';
    'D', 'T': result := '1899-12-31';
    'L': result := 'False';
  end;
end;

function TField.GetAsStringX: AnsiString;
begin
  Result := GetAsPointer;
end;

function TField.GetAsPointer: PAnsiChar;
begin
  Move((FDataBuf + FPtr^.FieldOffset)^, FFieldBuf, FPtr^.Width);
  FFieldBuf[FPtr^.Width] := #0;
  Result := FFieldBuf;
end;

function TField.GetFieldType: AnsiChar;
begin
  Result := FPtr^.FieldType;
end;

function TField.GetWidth: Byte;
begin
  Result := FPtr^.Width;
end;

function TField.GetScale: Byte;
begin
  Result := FPtr^.Scale;
end;

//20040329 魏业 增加
function TField.GetFieldName: AnsiString;
begin
  Result := StrPas(FPtr^.FieldName);
end;

procedure TField.SetAsBoolean(Value: Boolean);
begin
  if FPtr^.Width > 1 then
    FillChar((FDataBuf + FPtr^.FieldOffset)^, FPtr^.Width, $20);
  if Value then
    (FDataBuf + FPtr^.FieldOffset)^ := 'T'
  else
    (FDataBuf + FPtr^.FieldOffset)^ := 'F';
end;

procedure TField.SetAsChar(Value: AnsiChar);
begin
  if FPtr^.Width > 1 then
    FillChar((FDataBuf + FPtr^.FieldOffset)^, FPtr^.Width, $20);
  (FDataBuf + FPtr^.FieldOffset)^ := Value;
end;

procedure TField.SetAsDate(Value: TDateTime);
begin
  SetAsString(FormatDateTime('yyyymmdd', Value));
end;

procedure TField.SetAsFloat(Value: Double);
begin
  SetAsString(Format('%*.*f', [FPtr^.Width, FPtr^.Scale, Value]));
end;

procedure TField.SetAsInteger(Value: Integer);
begin
  SetAsString(IntToStr(Value));
end;

procedure TField.SetAsString(const Value: AnsiString);
var
  iDataLen: Integer;
begin
  iDataLen := Length(Value);
  if iDataLen > FPtr^.Width then
    iDataLen := FPtr^.Width
  else if iDataLen < FPtr^.Width then
    FillChar((FDataBuf + FPtr^.FieldOffset)^, FPtr^.Width, $20);
  if (FPtr^.FieldType = 'N') or (FPtr^.FieldType = 'F') then
    Move(PAnsiChar(Value)^, (FDataBuf + FPtr^.FieldOffset + FPtr^.Width - iDataLen)^, iDataLen)
  else
    Move(PAnsiChar(Value)^, (FDataBuf + FPtr^.FieldOffset)^, iDataLen);
end;

procedure TField.SetAsPointer(const Value: PAnsiChar);
begin
  Move(Value^, (FDataBuf + FPtr^.FieldOffset)^, FPtr^.Width);
end;

{ TFieldList }

function TFieldList.GetField(Index: Integer): TField;
begin
  Result := Items[Index];
end;

procedure TFieldList.Notify(Ptr: Pointer; Action: TListNotification);
begin
  if Action = lnDeleted then
    TField(Ptr).Free;
end;

function TFieldList.Add(Field: TField): Integer;
begin
  Result := Add(Pointer(Field));
end;



{ TMemoryDBF }

constructor TMemoryDBF.Create;
begin
  FFieldCount := 0;
  FRecCount := 0;
  FHead := nil;
  FDBFFields := nil;

  FFieldList := TObjectDictionary<string,TField>.Create([doOwnsValues]);
end;

destructor TMemoryDBF.Destroy;
begin
  FFieldList.Free;
  inherited;
end;

function TMemoryDBF.GetFieldByName(AFieldName: string; ARecIndex: Integer): TField;
begin
  result := FFieldList[UpperCase(AFieldName)];
  result.FDataBuf := Pointer(Integer(FHead)+FHead.DataOffset + FHead.RecSize * ARecIndex);
end;

procedure TMemoryDBF.Link(const Address: Pointer);
var
  k:Integer;
  offset: integer;
begin
  FFieldList.Clear;

  FHead := Address;
  FFieldCount := (FHead.DataOffset - SizeOf(TDBFHead)) div SizeOf(TDBFField);
  if (FFieldCount < 1) or (FFieldCount > 254) then
      raise Exception.Create('DBF字段个数无效');

  offset := 0;

  FRecCount := FHead.RecCount;
  FDBFFields := Pointer(Integer(FHead)+SizeOf(TDBFField));
  for k := 0 to FFieldCount - 1 do
  begin

    FFieldList.Add(UpperCase(FDBFFields[k].FieldName), TField.Create(@FDBFFields[k]));

    //修正FieldOffset值
    if FDBFFields[k].FieldOffset=0 then
      FFieldList[UpperCase(FDBFFields[k].FieldName)].FPtr.FieldOffset := Offset+1;

    Inc(offset, FDBFFields[k].Width);
  end;
end;

{ TPackedDBF }

class function TPackedDBF.Compress(ASource: string): TPackedDBF;
var
  sm:TFileStream;
  pHead:PDBFHead;
  FieldObj:TField;
  buf:PByte;
  i,j,c:Integer;
  ct:TColumnType;
  pDelete:PByte;
begin
  result := TPackedDBF.Create;
  sm := TFileStream.Create(ASource, fmOpenRead or fmShareDenyNone);
  GetMem(buf, sm.Size);
  sm.Read(buf^, sm.Size);
  sm.Free;

  //load dbf head
  pHead := PDBFHead(buf);
  c := (pHead.DataOffset - 33) div SizeOf(TDBFField);
  result.FHeadBuffer.Write(buf[0], pHead.DataOffset);
  //逐字段写入数据
  for i := 0 to c - 1 do
  begin
    result.FColumns.Add(TMemoryStream.Create);
    FieldObj := TField.Create(Pointer(Integer(Buf)+SizeOf(TDBFHead)+i*SizeOf(TDBFField)));
    FieldObj.FDataBuf := Pointer(Integer(pHead)+pHead.DataOffset);
    ct := Result.GetColumnType(FieldObj);
    for j := 0 to pHead.RecCount - 1 do
    begin
      //写入数据
      case ct of
        ctInt: result.WriteInt32(i, FieldObj.GetAsInteger);
        ctInt64: result.WriteInt64(i, FieldObj.GetAsLargeInt);
        ctSinfle: result.WriteSingle(i, FieldObj.AsSingle);
        ctDouble: result.WriteDouble(i, FieldObj.GetAsFloat);
        ctChar: result.WriteString(i, FieldObj.GetAsString);
      end;
      inc(FieldObj.FDataBuf, pHead.RecSize);
    end;
    //----------------------------

    FieldObj.Free;
  end;

  //删除标记
  result.FColumns.Insert(0, TMemoryStream.Create);
  pDelete := Pointer(Integer(Buf)+pHead.DataOffset);
  for j := 0 to pHead.RecCount - 1 do
  begin
    result.FColumns[0].Write(pDelete^, 1);
    inc(pDelete, pHead.RecSize);
  end;

  //todo:debug
  result.WriteToFile('e:\temp\sjshq2.dbf');
  //release
  FreeMem(buf);;
end;

constructor TPackedDBF.Create;
begin
  FHeadBuffer :=TMemoryStream.Create;
  FColumns := TObjectList<TMemoryStream>.Create(True);
end;

class function TPackedDBF.Decompresss(ABuf: PByte; iLen: Integer): TBytes;
begin

end;

destructor TPackedDBF.Destroy;
begin
  FHeadBuffer.Free;
  FColumns.Free;
  inherited;
end;

function TPackedDBF.GetColumnType(AField: TField): TColumnType;
begin
  if AField.FPtr.FieldType = 'N' then
  begin
  if (AField.Width < 10) and (AField.Scale = 0) then result := ctInt else
  if (AField.Width > 10) and (AField.Scale = 0) then result := ctInt64 else
  if (AField.Width < 12) and (AField.Scale > 0) then result := ctSinfle else
  if (AField.Width > 12) and (AField.Scale > 0) then result := ctDouble else result := ctChar;
  end else
    result := ctChar;
end;

procedure TPackedDBF.WriteDouble(ACOlIndex: Integer; AValue: double);
begin
  FColumns[AColIndex].Write(AValue, SizeOf(double));
end;

procedure TPackedDBF.WriteInt32(AColIndex, AValue: Integer);
begin
  FColumns[AColIndex].Write(AValue, SizeOf(Integer));
end;

procedure TPackedDBF.WriteInt64(AColIndex: Integer; AValue: Int64);
begin
  FColumns[AColIndex].Write(AValue, SizeOf(Int64));
end;

procedure TPackedDBF.WriteSingle(AColIndex: Integer; AValue: Single);
begin
  FColumns[AColIndex].Write(AValue, SizeOf(single));
end;

procedure TPackedDBF.WriteString(AColIndex: Integer; AValue: AnsiString);
var l:byte;
begin
  l := Length(AValue);
  FColumns[AColIndex].Write(l, 1);
  FColumns[AColIndex].Write(AValue[1], l);
end;

procedure TPackedDBF.WriteToFile(ATarget: string);
var
  fm:TFileStream;
  i:integer;
begin
  fm := TFileStream.Create(ATarget, fmCreate);
  FHeadBuffer.Position := 0;
  fm.Write(self.FHeadBuffer.Memory^, FHeadBuffer.Size);

  for i := 0 to FColumns.Count - 1 do
  begin
    FColumns[i].Position := 0;
    fm.Write(FColumns[i].Memory^, FColumns[i].Size)
  end;

  fm.Free;
end;

end.
