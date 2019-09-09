unit uSaveBinary;

interface

uses
  Classes, types, SysUtils, StrUtils, DateUtils, IOUtils, Windows, Math,
  ActiveX, Generics.Collections, SyncObjs,
  uQuote2DB, uQuoteFile, uQuoteBroadcast, memds, VirtualTable ,
  uLog, utils.queues, uCRCTools;

type

  TSaveBinary = class(TQuoteScanner)
  strict private
    FSimpleFN:string;
    FConfig: TQuoteScanConfig;
    FFileConfig: TQuoteFileConfig;
    FWriteThread: TThread;
    FFileStream:TFileStream;
    FTrace:boolean;
  protected
    procedure Init; override;
    procedure Uninit; override;
    procedure doStart; override;
    procedure doStop; override;
    procedure doWork; override;
    function GetToolName:string; override;
  public
    constructor Create(AScanConfig:TQuoteScanConfig; AFileConfig: TQuoteFileConfig); override;
    property Trace:boolean read FTrace write FTrace;
  end;

  TBin_RecordHead = packed record
    FIX_INFO: WORD;     //�̶�ֵ��$D8EA
    RecSize : DWORD;    //�����ֽڳ���
    CRC     : Cardinal; //�㷨�ο�����Ԫ��VerifyData������
  end;

  TBin_PriceInfo = packed record
    Price : Integer;  //10000
    Volume: integer;
  end;

  TBin_Quote = packed record
    Market    : TMarket;
    Time      : TDateTime; //����ʱ��
    LevelType : TLevelType;
    Currency  : array[1..3] of AnsiChar;
    Code      : array[1..10] of AnsiChar;
    Abbr      : array[1..32] of AnsiChar;
    //Price&Volume...
    Prev, Open, High, Low, Last, Close: Integer; //10000
    Volume    : Int64;
    Value     : Int64;   //10000
    DealCnt   : Integer;
    PE1, PE2  : Int64;   //10000
    Buy       : array[1..10] of TBin_PriceInfo;
    Sell      : array[1..10] of TBin_PriceInfo;
    procedure Build(const ASource:PQuoteRecord);
  end;

  TBin_Quote_Array = array[0..1023] of TBin_Quote;
  PBin_Quote_Array = ^TBin_Quote_Array;

implementation

function VerifyData(const buf; len: Cardinal): Cardinal;
var
  i:Cardinal;
  p:PByte;
begin
  i := 0;
  Result := 0;
  p := PByte(@buf);
  while i < len do
  begin
    Result := Result + p^;
    Inc(p);
    Inc(i);
  end;
end;

constructor TSaveBinary.Create(AScanConfig: TQuoteScanConfig; AFileConfig: TQuoteFileConfig);
begin
  inherited;
  FTrace := False;
  FConfig := AScanConfig;
  FFileConfig := AFileConfig;
  FSimpleFN := Uppercase(TPath.GetFileNameWithoutExtension(FFileConfig.Path));
end;

procedure TSaveBinary.doStart;
begin
  inherited;

end;

procedure TSaveBinary.doStop;
begin
  inherited;

end;

procedure TSaveBinary.doWork;
var
  p:pointer;
  k:integer;
  fn,str_code:string;
  buf:PBin_Quote_Array;
  head:TBin_RecordHead;
const
  batch_size:Integer = 500;
begin
  if FTrace then Self.Reader.TraceFileChange := True;

  TDirectory.CreateDirectory('.\Binary');
  fn := Format('.\Binary\%s_%s.bin', [FSimpleFN, FormatDateTime('yyyymmdd', today)]);
  if TFile.Exists(fn) then
    FFileStream := TFileStream.Create(fn, fmOpenReadWrite or fmShareDenyNone)
  else
    FFileStream := TFileStream.Create(fn, fmCreate or fmOpenReadWrite or fmShareDenyNone);
  FFileStream.Seek(0, soEnd);

  buf := GetMemory(SizeOf(TBin_Quote)*batch_size);

  while Active or (FChangeList.Size>0) do
  begin
    try
      //�Ӷ�����ȡ����¼��ÿ��ȡ500��
      k := 0;
      while FChangeList.DeQueue(p) do
      begin
        if PQuoteRecord(p).IsValid then //20180109, У�������Ƿ���Ч��Allen
          buf[k].Build(p)
        else
        begin
          str_code := PQuoteRecord(p).Code;
          log.AddLogFormat('������Ч����,����:%s,�ɽ���:%f', [str_code, PQuoteRecord(p).Value]);
        end;

        FreeMem(p);
        inc(k);
        if k >= batch_size then break; //����д��500����¼
      end;

      if k>0 then
      begin
        //write record head
        head.FIX_INFO := $D8EA;
        head.RecSize := SizeOf(TBin_Quote)*k;
        head.CRC := VerifyData(buf[0], head.RecSize);
        FFileStream.Write(head, SizeOf(TBin_RecordHead));
        //write record data
        FFileStream.Write(buf^, head.RecSize);
      end;
    except
      on e:exception do
      begin
        //��¼������־ ,����ͣ5��
        Log.AddLogFormat('StackTrace:%s', [e.StackTrace]);
        Log.AddLogFormat('Error Message:%s', [e.Message]);
        sleep(5000);
        continue;
      end;
    end;
    sleep(10);
  end;

  //---Freememory----
  FreeMem(buf);
  FFileStream.Free;
end;

function TSaveBinary.GetToolName: string;
begin
  result := '�����ļ�������ɨ�蹤�߲��';
end;

procedure TSaveBinary.Init;
begin
  inherited;

end;

procedure TSaveBinary.Uninit;
begin
  inherited;

end;

{ TBin_Quote }

procedure TBin_Quote.Build(const ASource: PQuoteRecord);
var
  i:integer;
begin
  FillChar(self, SizeOf(TBin_Quote), 0);
  Market := ASource.Market;
  Time   := ASource.Time;
  LevelType := ASource.LevelType;
  Move(ASource.Currency[1], Currency[1], 3);
  Move(ASource.Code[1], Code[1], 10);
  Move(ASource.Abbr[1], Abbr[1], 10);
  Prev := Trunc(ASource.Prev *10000);
  Open := Trunc(ASource.Open *10000);
  High := Trunc(ASource.High *10000);
  Low := Trunc(ASource.Low *10000);
  Last := Trunc(ASource.Last *10000);
  Close := Trunc(ASource.Close *10000);
  Volume := ASource.Volume;
  Value := Trunc(ASource.Value*10000);
  DealCnt := ASource.DealCnt;
  PE1 := Trunc(ASource.PE1 * 10000);
  PE2 := Trunc(ASource.PE2 * 10000);
  for i := 1 to 10 do
  begin
    Self.Buy[i].Price := Trunc(ASource.Buy[i].Price * 10000);
    Self.Buy[i].Volume := ASource.Buy[i].Volume;
    Self.Sell[i].Price := Trunc(ASource.Sell[i].Price * 10000);
    Self.Sell[i].Volume := ASource.Sell[i].Volume;
  end;
end;

end.
