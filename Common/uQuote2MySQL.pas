unit uQuote2MySQL;

interface

uses
  Classes, types, SysUtils, StrUtils, DateUtils, IOUtils, Windows, Math,
  ADODB,  ActiveX, Generics.Collections, SyncObjs,
  uQuote2DB, uQuoteFile, uQuoteBroadcast, memds, VirtualTable ,
  uLog, utils.queues, uDBSync, uSyncDefine,
  UniProvider, MySQLUniProvider, DB, DBAccess, Uni, DALoader, UniLoader;

type
  TQuote2MySQL = class(TQuoteScanner)
  strict private
    FDBLink:TDBLink;
    FConnectionString:string;
    FTblName:string;
    FConnection:TUniConnection;
    FBuffer:TUniQuery;
    FLoader:TUniLoader;
    FLevel:Integer;
    procedure AppendRecord(R:PQuoteRecord);
    procedure CommitToDB(AMinutes:Integer);
    function GetCreateTblSQL(ATblName: string): string;
    procedure DropHisTables;
    procedure AddTblLog(ATblName:string);
    procedure ExecCustomSQL(ATblName:string);
  protected
    procedure Init; override;
    procedure Uninit; override;
    procedure doWork; override;
    procedure doStart; override;
    procedure doStop; override;
  public
    constructor Create(AScanConfig:TQuoteScanConfig; AFileConfig: TQuoteFileConfig); override;
  end;

implementation
var
BUILD_TBL_SCRIPT : AnsiString;
BUILD_RQTableList: AnsiString;
DROP_HIS_TBL     : AnsiString;
GET_BUFFER_REC   : AnsiString;
INIT_TBL_EMPTY   : AnsiString;

{ TQuote2MySQL }

procedure TQuote2MySQL.AddTblLog(ATblName: string);
var
  tmp:TUniQuery;
  fn, tt:string;
begin
  fn := UpperCase(TPath.GetFileName(FileConfig.Path));
  if pos('MKTDT',fn)>0 then tt := 'ShangHai';
  if pos('SJSHQ',fn)>0 then tt := 'ShenZhen';
  if pos('FUND_B',fn)>0 then tt := 'FundEvaBond';
  if pos('FUND_NB',fn)>0 then tt := 'FundEvaNB';
  if pos('SWZS',fn)>0 then tt := 'SWZS';
  if pos('FUND_HQ',fn)>0 then tt := 'FundEvaBond';

  FConnection.ExecSQL(BUILD_RQTableList);
  tmp := TUniQuery.Create(nil);
  tmp.Connection := FConnection;
  //tmp.SQL.Text := 'select {if SQLServer}top 0{endif} * from RQTableList {if MySQL}limit 0{endif}';
  tmp.SQL.Text :=
    '{if MySQL}' +
    'insert ignore into RQTableList(TableName,CreateTime,TableType) values(:TableName,:CreateTime,:TableType);' +
    '{endif}'+
    '{if SQLServer}' +
    'insert into RQTableList(TableName,CreateTime,TableType) values(:TableName,:CreateTime,:TableType);' +
    '{endif}';
  tmp.Params[0].AsString := ATblName;
  tmp.Params[1].AsDateTime := now;
  tmp.Params[2].AsString := tt;
  try
    tmp.Execute;
  except
  end;
  tmp.Free;
//  tmp.Open;
//  tmp.Append;
//  tmp.FieldByName('TableName').AsString := ATblName;
//  tmp.FieldByName('CreateTime').AsDateTime := now;
//  tmp.FieldByName('TableType').AsString := 'UNKNOW';
//  fn := UpperCase(TPath.GetFileName(FileConfig.Path));
//  if pos('MKTDT',fn)>0 then tmp.FieldByName('TableType').AsString := 'ShangHai';
//  if pos('SJSHQ',fn)>0 then tmp.FieldByName('TableType').AsString := 'ShenZhen';
//  if pos('FUND_B',fn)>0 then tmp.FieldByName('TableType').AsString := 'FundEvaBond';
//  if pos('FUND_NB',fn)>0 then tmp.FieldByName('TableType').AsString := 'FundEvaNB';
//  if pos('SWZS',fn)>0 then tmp.FieldByName('TableType').AsString := 'SWZS';
//  if pos('FUND_HQ',fn)>0 then tmp.FieldByName('TableType').AsString := 'FundEvaBond';
//  try
//    tmp.Post;
//  except
//  end;
//  tmp.Free;
end;

procedure TQuote2MySQL.AppendRecord(R: PQuoteRecord);
begin
  FBuffer.Append;
  with FBuffer, R^ do
  begin
    FieldByName('Auction').AsString := Market.Auction;
    FieldByName('MarketTime').AsDateTime := Market.Time;
    FieldByName('Time').AsDateTime := Time;
    FieldByName('Code').AsString := GetCode;
    FieldByName('Abbr').AsString := GetAbbr;
    FieldByName('Prev').AsCurrency := Prev;
    FieldByName('Open').AsCurrency := Open;
    FieldByName('High').AsCurrency := High;
    FieldByName('Low').AsCurrency := Low;
    FieldByName('Last').AsCurrency := Last;
    FieldByName('Close').AsCurrency := Close;
    FieldByName('Volume').AsLargeInt := Volume;
    FieldByName('Value').AsCurrency := Value;
    FieldByName('DealCnt').AsInteger := DealCnt;
    FieldByName('PE1').AsFloat := PE1;
    FieldByName('PE2').AsFloat := PE2;
    FieldByName('BuyPrice1').AsCurrency := Buy[1].Price;
    FieldByName('BuyPrice2').AsCurrency := Buy[2].Price;
    FieldByName('BuyPrice3').AsCurrency := Buy[3].Price;
    FieldByName('BuyPrice4').AsCurrency := Buy[4].Price;
    FieldByName('BuyPrice5').AsCurrency := Buy[5].Price;
    FieldByName('BuyVolume1').AsLargeInt := Buy[1].Volume;
    FieldByName('BuyVolume2').AsLargeInt := Buy[2].Volume;
    FieldByName('BuyVolume3').AsLargeInt := Buy[3].Volume;
    FieldByName('BuyVolume4').AsLargeInt := Buy[4].Volume;
    FieldByName('BuyVolume5').AsLargeInt := Buy[5].Volume;
    FieldByName('SellPrice1').AsCurrency := Sell[1].Price;
    FieldByName('SellPrice2').AsCurrency := Sell[2].Price;
    FieldByName('SellPrice3').AsCurrency := Sell[3].Price;
    FieldByName('SellPrice4').AsCurrency := Sell[4].Price;
    FieldByName('SellPrice5').AsCurrency := Sell[5].Price;
    FieldByName('SellVolume1').AsLargeInt := Sell[1].Volume;
    FieldByName('SellVolume2').AsLargeInt := Sell[2].Volume;
    FieldByName('SellVolume3').AsLargeInt := Sell[3].Volume;
    FieldByName('SellVolume4').AsLargeInt := Sell[4].Volume;
    FieldByName('SellVolume5').AsLargeInt := Sell[5].Volume;
    if r.LevelType = LevelTen then
    begin
      FieldByName('BuyPrice6').AsCurrency := Buy[6].Price;
      FieldByName('BuyPrice7').AsCurrency := Buy[7].Price;
      FieldByName('BuyPrice8').AsCurrency := Buy[8].Price;
      FieldByName('BuyPrice9').AsCurrency := Buy[9].Price;
      FieldByName('BuyPrice10').AsCurrency := Buy[10].Price;
      FieldByName('BuyVolume6').AsLargeInt := Buy[6].Volume;
      FieldByName('BuyVolume7').AsLargeInt := Buy[7].Volume;
      FieldByName('BuyVolume8').AsLargeInt := Buy[8].Volume;
      FieldByName('BuyVolume9').AsLargeInt := Buy[9].Volume;
      FieldByName('BuyVolume10').AsLargeInt := Buy[10].Volume;
      FieldByName('SellPrice6').AsCurrency := Sell[6].Price;
      FieldByName('SellPrice7').AsCurrency := Sell[7].Price;
      FieldByName('SellPrice8').AsCurrency := Sell[8].Price;
      FieldByName('SellPrice9').AsCurrency := Sell[9].Price;
      FieldByName('SellPrice10').AsCurrency := Sell[10].Price;
      FieldByName('SellVolume1').AsLargeInt := Sell[6].Volume;
      FieldByName('SellVolume2').AsLargeInt := Sell[7].Volume;
      FieldByName('SellVolume3').AsLargeInt := Sell[8].Volume;
      FieldByName('SellVolume4').AsLargeInt := Sell[9].Volume;
      FieldByName('SellVolume5').AsLargeInt := Sell[10].Volume;
    end;
  end;
  FBuffer.Post;
end;

procedure TQuote2MySQL.CommitToDB(AMinutes:Integer);
var
  tblname:string;
begin
  if FBuffer.RecordCount > 0 then
  begin
    if FileConfig.SplitIntervalMinute > 0 then
    begin
      tblname := FTblName+'_'+FormatDateTime('yyyymmddhhnn', IncMinute( today, 540+AMinutes) );
      FConnection.ExecSQL(GetCreateTblSQL(tblname));
      ExecCustomSQL(TblName);
      AddTblLog(tblname);
      FLoader.TableName := tblname;
    end else
    begin
      tblname := FTblName+'_'+FormatDateTime('yyyymmdd', today);
      FConnection.ExecSQL(GetCreateTblSQL(tblname));
      ExecCustomSQL(TblName);
      AddTblLog(tblname);
      FLoader.TableName := tblname;
    end;

    try
      //FLoader.Connection := FConnection;
      //FLoader.Options.QuoteNames := True;
      FLoader.Options.UseBlankValues := False;
      FLoader.LoadFromDataSet(FBuffer);
      FLoader.Load;
      inc(FUpdateCount, FBuffer.RecordCount);
    except on e:Exception do
      log.AddLogFormat('commit record error:%s', [e.Message]);
    end;
    //清空
    FBuffer.ExecSQL;
  end;
end;

constructor TQuote2MySQL.Create(AScanConfig:TQuoteScanConfig; AFileConfig: TQuoteFileConfig);
begin
  inherited;
  FDBLink := ScanConfig.DBLink;
  FTblName := Uppercase(TPath.GetFileNameWithoutExtension(FileConfig.Path));
  if UpperCase(FTblName)='FUND_HQ' then
    FTblName := 'FUND_B';
  FLevel := FileConfig.Level;
end;

procedure TQuote2MySQL.doStart;
var
  tname:string;
  tmp: TUniConnection;
begin
  tname := FTblName + '_'+FormatDateTime('yyyymmdd', now);

  //20190721变动，释放上一次建立的DB-Connection
  if Assigned(FBuffer.Connection) then
  begin
    tmp := FBuffer.Connection;
    FBuffer.Connection := nil;
    FreeAndNil(tmp);
  end;

  if Assigned(FConnection) then FreeAndNil(FConnection);
  FConnection := FDBLink.BuildConnection();
  log.AddLogFormat('建立数据库链接,Type:%s,Host:%s,Port:%d', [C_SyncNames[FDBLink.DBType],FDBLink.Host, FDBLink.Port]);
  if FDBLink.DBType = stMySQL then
    log.AddLogFormat('MySQL编码类型:%s', [MySQLEncodingText[FDBLink.MySQLEncoding]]);
  try
    FConnection.Open;
    FConnection.ExecSQL(INIT_TBL_EMPTY);
    if ScanConfig.AutoRemoveDays>0 then
      DropHisTables; //删除十天前的数据
    FBuffer.Connection := FConnection;
    FBuffer.LockMode := lmOptimistic;
    FBuffer.CachedUpdates :=True;
    FBuffer.LocalUpdate := True;
    FBuffer.Options.EnableBCD := True;
    FBuffer.SQL.Text := GET_BUFFER_REC;
    FBuffer.Execute;
    FLoader.Connection := FConnection;
    //FLoader.Options.
  except
    on e:Exception do
    begin
      PostLog(llError, '执行SQL语句出现错误，[%s]', [e.Message]);
    end;
  end;

end;

procedure TQuote2MySQL.doStop;
begin
  inherited;

end;

procedure TQuote2MySQL.doWork;
var
  p:pointer;
  t:TDateTime;
  k,j:integer;
  buckList:TDictionary<integer, TList>;
  procedure _add_rec(r:PQuoteRecord);
  begin
    if not r.Valid then Exit;
    if not SameDate(r.Time, now) then exit;

    if FileConfig.SplitIntervalMinute=0 then
      k := 0
    else
      k := (MinuteOfTheDay(r.Market.Time) -  MinuteOfTheDay(t)) div FileConfig.SplitIntervalMinute;
    k := abs(k);
    if not buckList.ContainsKey(k) then
      buckList.Add(k, TList.Create);
    buckList[k].Add(r);
  end;
begin
  CoInitialize(nil);
  t := IncMinute( today , 9*60); //AM09:00
  buckList := TDictionary<integer, TList>.Create;

  //扫描行情入库队列
  while Active or (FChangeList.Size>0) do
  begin
    //从队列中取出记录，每次取500条
    while FChangeList.DeQueue(p) do _add_rec(p);

    //写入数据库
    for k in buckList.Keys do
    begin
      for j := 0 to buckList[k].Count - 1 do
      begin
        p := buckList[k][j];
        AppendRecord(p);
        FreeMem(p);
      end;
      try
      CommitToDB(k*FileConfig.SplitIntervalMinute);
      except on e:Exception do
        PostLog(llError, e.Message);
      end;
      buckList[k].Clear;
    end;

    sleep(10);
  end;
end;

procedure TQuote2MySQL.DropHisTables;
var
  tmp:TCustomDADataset;
  script:string;
begin
  PostLog(llMessage, '正在清除[%s]的%d天前历史数据',[TPath.GetFileName(FileConfig.Path), ScanConfig.AutoRemoveDays]);
  script := replacestr(DROP_HIS_TBL, '_TBLPREFIX_', self.FTblName);
  script := replacestr(script, '_YMD_', FormatDateTime('yyyymmdd', IncDay(today,-ScanConfig.AutoRemoveDays)));
  tmp := FConnection.CreateDataSet;
  tmp.SQL.Text := script;
  tmp.Open;
  while not tmp.Eof do
  begin
    try
    FConnection.ExecSQL(tmp.Fields[0].asstring);
    except;
      PostLog(llError, '删除历史数据失败，脚本：%s', [script]);
    end;
    tmp.Next;
  end;
  tmp.Free;
end;

procedure TQuote2MySQL.ExecCustomSQL(ATblName: string);
var
  s:string;
begin
  if ScanConfig.CustomSQL <> '' then
  try
    s := StringReplace(ScanConfig.CustomSQL, '{TBLNAME}', aTblName, [rfReplaceAll,rfIgnoreCase]);
    FConnection.ExecSQL(s);
  except

  end;
end;

function TQuote2MySQL.GetCreateTblSQL(ATblName: string): string;
begin
  result := ReplaceStr(BUILD_TBL_SCRIPT, '_TBLNAME_', ATblName);
end;

procedure TQuote2MySQL.Init;
begin
  FBuffer := TUniQuery.Create(nil);
  FLoader := TUniLoader.Create(nil);
end;

{procedure TQuote2MySQL.Setup(const ALink: TDBLink; ATblName:string; const ALevel:Integer);
begin
  FDBLink := ALink;
  FTblName := ATblName;
  FLevel := ALevel;
end;}

procedure TQuote2MySQL.Uninit;
begin
  FLoader.Free;
  FBuffer.Free;
  if Assigned(FConnection) then FreeAndNil(Fconnection);
end;

var RS_Stream: TResourceStream;
initialization
  //BUILD_TBL_SCRIPT
  RS_Stream := TResourceStream.Create(HInstance, 'BUILD_TBL_SCRIPT', 'SQL');
  SetLength(BUILD_TBL_SCRIPT, RS_Stream.Size);
  RS_Stream.Read(BUILD_TBL_SCRIPT[1], RS_Stream.Size);
  RS_Stream.Free;
  //BUILD_RQTableList
  RS_Stream := TResourceStream.Create(HInstance, 'BUILD_RQTableList', 'SQL');
  SetLength(BUILD_RQTableList, RS_Stream.Size);
  RS_Stream.Read(BUILD_RQTableList[1], RS_Stream.Size);
  RS_Stream.Free;

  //drop his tbl
  RS_Stream := TResourceStream.Create(HInstance, 'DROP_HIS_TBL', 'SQL');
  SetLength(DROP_HIS_TBL, RS_Stream.Size);
  RS_Stream.Read(DROP_HIS_TBL[1], RS_Stream.Size);
  RS_Stream.Free;

  //GET_BUFFER_REC
  RS_Stream := TResourceStream.Create(HInstance, 'GET_BUFFER_REC', 'SQL');
  SetLength(GET_BUFFER_REC, RS_Stream.Size);
  RS_Stream.Read(GET_BUFFER_REC[1], RS_Stream.Size);
  RS_Stream.Free;

  //INIT_TBL_EMPTY
  RS_Stream := TResourceStream.Create(HInstance, 'INIT_TBL_EMPTY', 'SQL');
  SetLength(INIT_TBL_EMPTY, RS_Stream.Size);
  RS_Stream.Read(INIT_TBL_EMPTY[1], RS_Stream.Size);
  RS_Stream.Free;
end.

