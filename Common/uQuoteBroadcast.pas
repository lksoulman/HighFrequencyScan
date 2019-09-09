unit uQuoteBroadcast;

interface

uses

  Classes, types, SysUtils, StrUtils, DateUtils, IOUtils, Windows, Math,
  ADODB,  ActiveX, Generics.Collections, SyncObjs,
  uQuoteFile,
  uLog,
  utils.queues,
  //BTMemoryModule,
  zmq,
  QJson;

  {$DEFINE DISABLE_ZERO}

type

  TQuoteBroadCast = class
  private
    FEnable: boolean;
    FPort: Integer;
    FZMQCTX:Pointer;
    FPub: Pointer;
    FLock:TCriticalSection;
    procedure Check(AValue:Integer);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start(APort:Integer);
    procedure Send(const Rec:PQuoteRecord);
    property Port:Integer read FPort;
  end;

  procedure MsgRecvDemo();

  procedure QuoteBroadCast(const Rec:PQuoteRecord);
  function  BroadCaster:TQuoteBroadCast;

implementation

var
  _BroadCaster: TQuoteBroadCast;

function  BroadCaster:TQuoteBroadCast;
begin
  result := _BroadCaster;
end;

procedure QuoteBroadCast(const Rec:PQuoteRecord);
begin
  _BroadCaster.Send(Rec);
end;

{ TQuoteBroadCast }

procedure TQuoteBroadCast.Check(AValue: Integer);
begin
  if AValue <> 0 then PostLog(llWarning, 'ZERO-MQ Call Error!!!');
end;

constructor TQuoteBroadCast.Create;
begin
  FEnable := False;
  FLock := TCriticalSection.Create;
  FPub := nil;
  FZMQCTX := nil;
  {$IFNDEF DISABLE_ZERO}
  FZMQCTX := zmq_ctx_new;
  {$ENDIF}


end;

destructor TQuoteBroadCast.Destroy;
begin
  {$IFNDEF DISABLE_ZERO}
  zmq_close(FPub);
  zmq_ctx_destroy(FZMQCTX);
  FLock.Free;
  {$ENDIF}
  inherited;
end;

procedure TQuoteBroadCast.Send(const Rec: PQuoteRecord);
var
  t1,t2:TDateTime;
  u1,u2:Int64;
  const date19700101 = 25569;
begin
  if not FEnable then exit;

  FLock.Enter;
  try
    t1 := Rec.Market.Time;
    t2 := Rec.Time;
    //转换时间至Unix
    PInt64(@Rec.Market.Time)^ := SecondsBetween(t1, date19700101);
    PInt64(@Rec.Time)^ := SecondsBetween(t2, date19700101);
    //发送
    {$IFNDEF DISABLE_ZERO}
    zmq_send(FPub, rec^, SizeOf(TQuoteRecord), 0);
    {$ENDIF}
    //恢复原值
    Rec.Market.Time := t1;
    Rec.Time := t2;
  finally
    flock.Leave;
  end;

end;

procedure TQuoteBroadCast.Start(APort: Integer);
var
  addr:AnsiString;
begin
  FPort := APort;
  {$IFNDEF DISABLE_ZERO}
  FPub := zmq_socket(FZMQCTX, ZMQ_PUB);
  addr := Format('tcp://*:%d',[FPort]);
  check( zmq_bind(FPub, @Addr[1]) );
  {$ENDIF}
  FEnable := True;
end;


procedure MsgRecvDemo();
begin
  TThread.CreateAnonymousThread(
  procedure
    var
    zContext:pointer;
    zIPC:pointer;
    pRec:TQuoteRecord;
    procedure Check(AValue: Integer);
    begin
      if AValue <> 0 then PostLog(llWarning, 'ZERO-MQ Call Error!!!');
    end;
  begin
    zContext := zmq_ctx_new;
    zIPC := zmq_socket(zContext, ZMQ_SUB);
    check( zmq_connect(zIPC, 'tcp://127.0.0.1:9905') );
    check( zmq_setsockopt(zIPC, ZMQ_SUBSCRIBE, nil, 0) );
    while True do
    begin
      zmq_recv(zIPC, pRec, SizeOf(TQuoteRecord), 1) ;
      sleep(1);
    end;
  end
  ).start;
end;

initialization
  _BroadCaster := TQuoteBroadCast.Create;

finalization

  _BroadCaster.Free;
end.
