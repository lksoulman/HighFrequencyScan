unit uMyDBF;

interface

uses

  Classes, SysUtils, Types, DB, Windows;

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
    function GetAsString: AnsiString;
    function GetAsStringX: AnsiString; // 包括尾部空格
    function GetAsPointer: PAnsiChar;
    function GetFieldType: AnsiChar;
    function GetWidth: Byte;
    function GetScale: Byte;
    //20040329 魏业 增加
    function GetFieldName: AnsiString;

    procedure SetAsBoolean(Value: Boolean);
    procedure SetAsChar(Value: AnsiChar);
    procedure SetAsDate(Value: TDateTime);
    procedure SetAsFloat(Value: Double);
    procedure SetAsInteger(Value: Integer);
    procedure SetAsString(const Value: AnsiString);
    procedure SetAsPointer(const Value: PAnsiChar);
  public
    constructor Create(Ptr: PDBFField);
    property AsBoolean: Boolean read GetAsBoolean write SetAsBoolean;
    property AsChar: AnsiChar read GetAsChar write SetAsChar;
    property AsDateTime: TDateTime read GetAsDate write SetAsDate;
    property AsFloat: Double read GetAsFloat write SetAsFloat;
    property AsInteger: Integer read GetAsInteger write SetAsInteger;
    property AsString: AnsiString read GetAsString write SetAsString;
    property AsStringX: AnsiString read GetAsStringX;
    property AsPointer: PAnsiChar read GetAsPointer write SetAsPointer;
    property FieldType: AnsiChar read GetFieldType;
    property Width: Byte read GetWidth;
    property Scale: Byte read GetScale;
    //20040329 魏业 增加
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

  TDataStatus = (dsBrowse, dsEdit, dsAppend);
  TLockMode = (lmFoxFile, lmFoxRecord, lmRawFile, lmNoLock);

  TMyDBF = class
  strict private
    FHead: TDBFHead;
    FDBFFields: array[0..253] of TDBFField;
    FFieldList: TFieldList;
    FFieldCount: Integer;
    FFileStream: TFileStream;
    FTableName: TFileName;
    FExclusive: Boolean;
    FReadOnly: Boolean;
    FActive: Boolean;
    FRecNo: Integer;
    FBof: Boolean;
    FEof: Boolean;
    FDataStatus: TDataStatus;
    FLockMode: TLockMode;
    FLockTime: DWORD;
    FRecBuf: PAnsiChar;
    FReadNoLock: Boolean;
    FErrorMsg:AnsiString;  // 20021128 何芝军增加配合GoX函数
    function GetRecordCount: Integer;
    function GetDeleted: Boolean;
    function GetField(Index: Integer): TField;
    procedure SetTablename(Value: TFileName);
    procedure SetExclusive(Value: Boolean);
    procedure SetReadOnly(Value: Boolean);
    procedure SetActive(Value: Boolean);
    procedure SetRecNo(Value: Integer);
    procedure SetDeleted(Value: Boolean);
    function Lock(RecordNo: Integer): Boolean;
    procedure Unlock(RecordNo: Integer);
    function ReadHead: Boolean;
    function ReadRecord(RecordNo: Integer): Boolean;
    procedure CheckActive(Flag: Boolean);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Open;
    procedure Close;
    procedure First;
    procedure Last;
    procedure Prior;
    procedure Next;
    function MoveBy(Distance: Integer): Integer;
    procedure Go(RecordNo: Integer);
    function GoX(RecordNo: Integer): boolean; // 20021128 何芝军加入 为False是有异常可以通过ErrorMsg取异常信息
    procedure Fresh;
    procedure Append;
    procedure Edit;
    procedure Post;
    procedure Zap;
    //20021023 王伟增加locktable，appendwithlock， unlocktable
    procedure LockTable;
    procedure AppendWithLock;
    procedure UnLockTable;
    function FieldByName(const FieldName: AnsiString): TField;
    property TableName: TFileName read FTableName write SetTableName;
    property Exclusive: Boolean read FExclusive write SetExclusive;
    property ReadOnly: Boolean read FReadOnly write SetReadOnly;
    property Active: Boolean read FActive write SetActive;
    property Bof: Boolean read FBof;
    property Deleted: Boolean read GetDeleted write SetDeleted;
    property Eof: Boolean read FEof;
    property FieldCount: Integer read FFieldCount;
    property Fields[Index: Integer]: TField read GetField;
    property LockMode: TLockMode read FLockMode write FLockMode;
    property LockTime: DWORD read FLockTime write FLockTime;
    property RecNo: Integer read FRecNo write SetRecNo;
    property RecordCount: Integer read GetRecordCount;
    property ReadNoLock: Boolean read FReadNoLock write FReadNoLock;
    property ErrorMsg:AnsiString read FErrorMsg;
  end;

implementation

{ TField }

constructor TField.Create(Ptr: PDBFField);
begin
  inherited Create;
  FPtr := Ptr;
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
  //GetAsPointer;
  try
    Result := StrToFloat(GetAsString); //FFieldBuf);
  except
    Result := 0;
  end;
end;

function TField.GetAsInteger: Integer;
begin
  //GetAsPointer;
  Result := StrToIntDef(GetAsString, 0); //FFieldBuf, 0);
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

{ THsDBF }

constructor TMyDBF.Create;
begin
  inherited Create;
  FFieldCount := 0;
  FFileStream := nil;
  FExclusive := False;
  FReadOnly := False;
  FActive := False;
  FRecNo := 0;
  FBof := True;
  FEof := True;
  FDataStatus := dsBrowse;
  FLockMode := lmFoxFile;
  FLockTime := 4000;
  FFieldList := TFieldList.Create;
  FRecBuf := nil;
{$IFDEF ReadNoLock}
  FReadNoLock := True;
{$ELSE}
  FReadNoLock := False;
{$ENDIF}
end;

destructor TMyDBF.Destroy;
begin
  Close;
  FFieldList.Free;
  inherited;
end;

function TMyDBF.GetRecordCount: Integer;
begin
  CheckActive(True);
  Result := FHead.RecCount;
end;

function TMyDBF.GetDeleted: Boolean;
begin
  CheckActive(True);
  Result := FRecBuf[0] = Chr($2A);
end;

function TMyDBF.GetField(Index: Integer): TField;
begin
  CheckActive(True);
  Result := FFieldList.Fields[Index];
end;

procedure TMyDBF.SetTablename(Value: TFileName);
begin
  CheckActive(False);
  FTableName := Value;
end;

procedure TMyDBF.SetExclusive(Value: Boolean);
begin
  CheckActive(False);
  FExclusive := Value;
end;

procedure TMyDBF.SetReadOnly(Value: Boolean);
begin
  CheckActive(False);
  FReadOnly := Value;
end;

procedure TMyDBF.SetActive(Value: Boolean);
begin
  if Value then
    Open
  else
    Close;
end;

procedure TMyDBF.SetRecNo(Value: Integer);
begin
  CheckActive(True);
  Go(Value);
end;

procedure TMyDBF.SetDeleted(Value: Boolean);
var
  cDeleted: AnsiChar;
begin
  CheckActive(True);
  if Value then
    cDeleted := Chr($2A)
  else
    cDeleted := Chr($20);
  if FRecBuf[0] = cDeleted then
    Exit;
  with FFileStream do
    if Lock(FRecNo) then
    try
      Seek(FHead.DataOffset + (FRecNo - 1) * FHead.RecSize, soFromBeginning);
      Write(cDeleted, 1);
    finally
      Unlock(0);
    end;
  FRecBuf[0] := cDeleted;
end;

function TMyDBF.Lock(RecordNo: Integer): Boolean;
var
  dwCount, dwCount2: DWORD;
begin
  dwCount := GetTickCount;
  dwCount2 := 0;
  repeat
    if (FLockMode = lmFoxFile) or ((FLockMode = lmFoxRecord) and (RecordNo < 1)) then
      Result := LockFile(FFileStream.Handle, $40000000, 0, $C0000000, 0)
    else if FLockMode = lmFoxRecord then
      Result := LockFile(FFileStream.Handle, $40000000 + FHead.DataOffset + (RecordNo - 1) * FHead.RecSize, 0, FHead.RecSize, 0)
    else if FLockMode = lmRawFile then
      Result := LockFile(FFileStream.Handle, $00000000, 0, $FFFFFFFF, 0)
    else
      Result := True;
    if Result then
      Break;
    dwCount2 := GetTickCount;
  until (dwCount2 >= dwCount) and (dwCount2 - dwCount >= FLockTime)
    or (dwCount2 < dwCount) and (MAXDWORD - dwCount + dwCount2 >= FLockTime);
  if not Result then
    raise Exception.Create(FTableName + '加锁失败');
end;

procedure TMyDBF.Unlock(RecordNo: Integer);
begin
  if (FLockMode = lmFoxFile) or ((FLockMode = lmFoxRecord) and (RecordNo < 1)) then
    UnlockFile(FFileStream.Handle, $40000000, 0, $C0000000, 0)
  else if FLockMode = lmFoxRecord then
    UnlockFile(FFileStream.Handle, $40000000 + FHead.DataOffset + (RecordNo - 1) * FHead.RecSize, 0, FHead.RecSize, 0)
  else if FLockMode = lmRawFile then
    UnlockFile(FFileStream.Handle, $00000000, 0, $FFFFFFFF, 0);
end;

function TMyDBF.ReadHead: Boolean;
begin
  Result := False;
  with FFileStream do
    if Lock(0) then
    try
      Seek(0, soFromBeginning);
      Result := Read(FHead, SizeOf(TDBFHead)) = SizeOf(TDBFHead);
    finally
      Unlock(0);
    end
end;

function TMyDBF.ReadRecord(RecordNo: Integer): Boolean;
var
  Index: Integer;
  iLen: Longint;
begin
  Result := False;
  with FFileStream do
  begin
    if Lock(RecordNo) then
    begin
      try
        Seek(FHead.DataOffset + FHead.RecSize * (RecordNo - 1), soFromBeginning);
        Move(FRecBuf^, (FRecBuf + FHead.RecSize)^, FHead.RecSize);
        iLen := Read(FRecBuf^, FHead.RecSize);
        if iLen <> FHead.RecSize then
        begin
          if iLen > 0 then
            Move((FRecBuf + FHead.RecSize)^, FRecBuf^, FHead.RecSize);
          raise Exception.Create(FTableName + '记录号超出范围(' + IntToStr(RecordNo) + ')');
        end;
        {for iLen := 0 to FHead.RecSize - 1 do
          if (FRecBuf + iLen)^ = #0 then
             (FRecBuf + iLen)^ := ' ';}
      finally
        Unlock(RecordNo);
      end;
      FRecNo := RecordNo;
      for Index := 0 to FFieldCount - 1 do
        FFieldList.Fields[Index].FDataBuf := FRecBuf;
      Result := True;
    end;
  end;
end;

procedure TMyDBF.CheckActive(Flag: Boolean);
begin
  if Flag and (not FActive) then
    raise Exception.Create('文件尚未打开');
  if (not Flag) and FActive then
    raise Exception.Create('文件已经打开');
end;

procedure TMyDBF.Open;
var
  Index: Integer;
  wMode: Word;
begin
  if FActive then
    Exit;

  if FExclusive then
    wMode := fmShareExclusive
  else
    wMode := fmShareDenyNone;
  if FReadOnly then
    wMode := wMode or fmOpenRead
  else
    wMode := wMode or fmOpenReadWrite;
  FFileStream := TFileStream.Create(FTableName, wMode);
  with FFileStream do
  try
    // 读入DBF头结构
    if not ReadHead then
      raise Exception.Create(FTableName + '不是有效的DBF文件');

    // 计算共有几个字段
    FFieldCount := (FHead.DataOffset - SizeOf(TDBFHead)) div SizeOf(TDBFField);
    if (FFieldCount < 1) or (FFieldCount > 254) then
      raise Exception.Create(FTableName + '的字段个数无效');

    if Read(FDBFFields, FFieldCount * SizeOf(TDBFField)) <> FFieldCount * SizeOf(TDBFField) then
      raise Exception.Create(FTableName + '的字段个数错误');

    // 因某些DBF可能不规范，重置偏移量
    FDBFFields[0].FieldOffset := 1;
    for Index := 1 to FFieldCount - 1 do
      FDBFFields[Index].FieldOffset := FDBFFields[Index - 1].FieldOffset + FDBFFields[Index - 1].Width;
    GetMem(FRecBuf, FHead.RecSize * 2);
    FillChar(FRecBuf^, FHead.RecSize * 2, $20);
    FFieldList.Clear;

    FHead.RecSize := 1;
    for Index := 0 to FFieldCount - 1 do
    begin
      FFieldList.Add(TField.Create(@FDBFFields[Index]));
      FFieldList.Fields[Index].FDataBuf := FRecBuf;
      FHead.RecSize :=  FHead.RecSize + FDBFFields[Index].Width; //重计算记录大小
    end;
    //重新计算记录数，防止有些DBFHEAD有误 Allen@20120803
    FHead.RecCount := (FFileStream.Size - SizeOf(TDBFHead) - SizeOf(TDBFField)*FFieldCount) div FHead.RecSize;
    //...
    FActive := True;
    if FHead.RecCount > 0 then
    try
      Go(1);
    except
    end;
  except
    FFileStream.Free;
    FreeMem(FRecBuf);
    raise;
  end;
end;

procedure TMyDBF.Close;
begin
  if Active then
  begin
    FFieldCount := 0;
    FFileStream.Free;
    FFileStream := nil;
    //FExclusive := False;
    //FReadOnly := False;
    FActive := False;
    FRecNo := 0;
    FBof := True;
    FEof := True;
    FDataStatus := dsBrowse;
    FreeMem(FRecBuf);
  end;
end;

procedure TMyDBF.First;
begin
  CheckActive(True);
  Go(1);
  FBof := True;
end;

procedure TMyDBF.Last;
begin
  CheckActive(True);
  ReadHead;
  Go(FHead.RecCount);
  FEof := True;
end;

procedure TMyDBF.Prior;
begin
  CheckActive(True);
  Go(FRecNo - 1);
end;

procedure TMyDBF.Next;
begin
  CheckActive(True);
  Go(FRecNo + 1);
end;

function TMyDBF.MoveBy(Distance: Integer): Integer;
var
  iPreRecNo: Integer;
begin
  CheckActive(True);
  iPreRecNo := FRecNo;
  Go(FRecNo + Distance);
  Result := FRecNo - iPreRecNo;
end;

procedure TMyDBF.Go(RecordNo: Integer);
var
  lmSave: TLockMode;
begin
  if FReadNoLock then
  begin
    lmSave := FLockMode;
    FLockMode := lmNoLock;
  end
  else
    lmSave := FLockMode; //20020822 孔洪飚为了去掉一个警告冗余一句
  try
    CheckActive(True);
    if (FHead.RecCount < 1) or FEof then
    try
      ReadHead;
    except
    end;
    if (RecordNo < 1) then
    begin
      FBof := True;
      if FHead.RecCount >= 1 then
      begin
        ReadRecord(1);
        FEof := False;
      end
      else
      begin
        FEof := True;
      end;
    end
    else if RecordNo > FHead.RecCount then
    begin
      try
        ReadHead;
      except
      end;
      if RecordNo > FHead.RecCount then
      begin
        FEof := True;
        FBof := FHead.RecCount < 1;
        FillChar(FRecBuf^, FHead.RecSize * 2, $20);
        FRecNo := RecordNo;
      end
      else
      begin
        FEof := False;
        FBof := False;
        ReadRecord(RecordNo);
      end;
    end
    else
    begin
      FBof := False;
      FEof := False;
      ReadRecord(RecordNo);
    end;
  finally
    if FReadNoLock then
      FLockMode := lmSave;
  end;
end;
// 20021128 何芝军加入主要用于对错误的屏蔽

function TMyDBF.GoX(RecordNo: Integer): boolean;
var
  lmSave: TLockMode;
begin
  result := True; FErrorMsg := '';
  if FReadNoLock then
  begin
    lmSave := FLockMode;
    FLockMode := lmNoLock;
  end
  else
    lmSave := FLockMode; //20020822 孔洪飚为了去掉一个警告冗余一句
  try
    try
      CheckActive(True);
      if (FHead.RecCount < 1) or FEof then
      try
        ReadHead;
      except
      end;
      if (RecordNo < 1) then
      begin
        FBof := True;
        if FHead.RecCount >= 1 then
        begin
          ReadRecord(1);
          FEof := False;
        end
        else
        begin
          FEof := True;
        end;
      end
      else if RecordNo > FHead.RecCount then
      begin
        try
          ReadHead;
        except
        end;
        if RecordNo > FHead.RecCount then
        begin
          FEof := True;
          FBof := FHead.RecCount < 1;
          FillChar(FRecBuf^, FHead.RecSize * 2, $20);
          FRecNo := RecordNo;
        end
        else
        begin
          FEof := False;
          FBof := False;
          ReadRecord(RecordNo);
        end;
      end
      else
      begin
        FBof := False;
        FEof := False;
        ReadRecord(RecordNo);
      end;
    except
      on E: Exception do
      begin
        result := False;
        FErrorMsg := E.Message; //记录错误信息
      end
    end;
  finally
    if FReadNoLock then
      FLockMode := lmSave;
  end;
end;


procedure TMyDBF.Fresh;
begin
  CheckActive(True);
  ReadHead;
  ReadRecord(FRecNo);
end;

procedure TMyDBF.Append;
begin
  CheckActive(True);
  FDataStatus := dsAppend;
  FillChar(FRecBuf^, FHead.RecSize * 2, $20);
end;

procedure TMyDBF.Edit;
begin
  CheckActive(True);
  FDataStatus := dsEdit;
end;

procedure TMyDBF.LockTable;
begin
// 20030610 俞俊涛修改
{
  if FDataStatus = dsAppend then
  begin
    with FFileStream do
    begin
      Lock(0);
    end;
  end;
}
  with FFileStream do
  begin
    Lock(0);
    Seek(0, soFromBeginning);
    Read(FHead, SizeOf(TDBFHead));
  end;
end;

procedure TMyDBF.UnLockTable;
begin
  try
    with FFileStream do
    begin
      UnLock(0);
    end;
  except
  end;
end;

procedure TMyDBF.AppendWithLock;
begin
  if FDataStatus = dsAppend then
  begin
    FDataStatus := dsBrowse;
    with FFileStream do
    begin
      try
        Seek(0, soFromBeginning);
        Read(FHead, SizeOf(TDBFHead));
        Seek(FHead.DataOffset + FHead.RecCount * FHead.RecSize, soFromBeginning);
        (FRecBuf + FHead.RecSize)^ := Chr($1A);
        Write(FRecBuf^, FHead.RecSize + 1);
        Inc(FHead.RecCount);
        Seek(0, soFromBeginning);
        Write(FHead, SizeOf(TDBFHead));
        FRecNo := FHead.RecCount;
      finally
        Unlock(0);
      end;
    end;
  end;
end;

procedure TMyDBF.Post;
begin
  CheckActive(True);
  if FDataStatus = dsEdit then
  begin
    FDataStatus := dsBrowse;
    with FFileStream do
      if Lock(FRecNo) then
      try
        Seek(FHead.DataOffset + (FRecNo - 1) * FHead.RecSize, soFromBeginning);
        Write(FRecBuf^, FHead.RecSize);
      finally
        Unlock(FRecNo);
      end;
  end
  else if FDataStatus = dsAppend then
  begin
    FDataStatus := dsBrowse;
    with FFileStream do
      if Lock(0) then
      try
        Seek(0, soFromBeginning);
        Read(FHead, SizeOf(TDBFHead));
        Seek(FHead.DataOffset + FHead.RecCount * FHead.RecSize, soFromBeginning);
        (FRecBuf + FHead.RecSize)^ := Chr($1A);
        Write(FRecBuf^, FHead.RecSize + 1);
        Inc(FHead.RecCount);
        Seek(0, soFromBeginning);
        Write(FHead, SizeOf(TDBFHead));
        FRecNo := FHead.RecCount;
      finally
        Unlock(0);
      end;
  end;
end;

procedure TMyDBF.Zap;
var
  wYear, wMonth, wDay: WORD;
begin
  CheckActive(True);
  with FFileStream do
    if Lock(0) then
    try
      Seek(0, soFromBeginning);
      Read(FHead, SizeOf(TDBFHead));
      DecodeDate(Date, wYear, wMonth, wDay);
      FHead.Year := wYear - (wYear div 100) * 100;
      FHead.Month := Byte(wMonth);
      FHead.Day := Byte(wDay);
      FHead.RecCount := 0;
      Seek(0, soFromBeginning);
      Write(FHead, SizeOf(TDBFHead));
      FRecNo := FHead.RecCount;
      FEof := True;
      FBof := True;
      FillChar(FRecBuf^, FHead.RecSize * 2, $20);
      FFileStream.Size := FHead.DataOffset;
    finally
      Unlock(0);
    end;
end;

function TMyDBF.FieldByName(const FieldName: AnsiString): TField;
var
  Index: Integer;
begin
  Result := nil;
  CheckActive(True);
  for Index := 0 to FFieldCount - 1 do
    if StrIComp(FDBFFields[Index].FieldName, PAnsiChar(FieldName)) = 0 then
    begin
      Result := FFieldList.Fields[Index];
      Break;
    end;
  if Result = nil then
    raise Exception.Create(FTableName + '找不到字段' + FieldName);
end;

end.