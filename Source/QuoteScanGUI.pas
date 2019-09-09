unit QuoteScanGUI;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, RzButton, ImgList, RzPanel, RzSplit, ExtCtrls, ComCtrls, RzListVw,
  StdCtrls,RzStatus, DB, ADODB, Generics.Collections, Math, DateUtils, IOUtils,
  StrUtils, Types, uFrmDBLinkCfg,

  uQuoteFile, uQuote2DB, uQuote2MySQL, uQuoteBroadcast, uSaveBinary, uKafkaPlug,
  uMemoryDBF, uDBSync, uPerformance,
  uFrmConfig, uAlarm, QWorker,
  uLog, RzTabs, Grids, RzGrids, RzLabel, Mask, RzEdit;

type
  TfrmMonitor = class(TForm)
    RzStatusBar1: TRzStatusBar;
    RzSplitter1: TRzSplitter;
    RzToolbar1: TRzToolbar;
    ImageList1: TImageList;
    btnStart: TRzToolButton;
    btnConfig: TRzToolButton;
    btnExit: TRzToolButton;
    mmLog: TMemo;
    lvScanFileList: TRzListView;
    RzClockStatus1: TRzClockStatus;
    spTimeInfo: TRzStatusPane;
    ADOConnection1: TADOConnection;
    _guiTimer: TTimer;
    RzSpacer1: TRzSpacer;
    _checkTimer: TTimer;
    spBroadcast: TRzStatusPane;
    RzPageControl1: TRzPageControl;
    TabSheet1: TRzTabSheet;
    TabSheet2: TRzTabSheet;
    gdQuotePreview: TRzStringGrid;
    RzToolbar2: TRzToolbar;
    btnFindCode: TRzToolButton;
    btnExportCSV: TRzToolButton;
    btnCopyRecord: TRzToolButton;
    edCode: TRzEdit;
    RzLabel1: TRzLabel;
    RzSpacer2: TRzSpacer;
    btnRefresh: TRzToolButton;
    RzSpacer3: TRzSpacer;
    SaveDialog1: TSaveDialog;
    spVerInfo: TRzStatusPane;
    Btn: TRzToolButton;
    RzStatusPane1: TRzStatusPane;
    procedure FormCreate(Sender: TObject);
    procedure btnConfigClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure _checkTimerTimer(Sender: TObject);
    procedure btnExitClick(Sender: TObject);
    procedure btnStartClick(Sender: TObject);
    procedure _guiTimerTimer(Sender: TObject);
    procedure lvScanFileListDblClick(Sender: TObject);
    procedure btnFindCodeClick(Sender: TObject);
    procedure btnExportCSVClick(Sender: TObject);
    procedure BtnClick(Sender: TObject);
  private
    { Private declarations }
    FConfig:TQuoteScanConfig;
    procedure SyncGUI;
    procedure Preview(Q:TQuoteScanner);
    function GetSelectedPlugin:TQuoteScanner;
    procedure DoSuningTxtBackup;
    procedure SuningArchiveJob(AJob: PQJob);
    procedure StopAll;
  public
    { Public declarations }
  end;

var
  frmMonitor: TfrmMonitor;

implementation

{$R *.dfm}
procedure GetBuildInfo(var V1, V2, V3, V4: word); overload;
var
  VerInfoSize, VerValueSize, Dummy: DWORD;
  VerInfo: Pointer;
  VerValue: PVSFixedFileInfo;
begin
  VerInfoSize := GetFileVersionInfoSize(PChar(ParamStr(0)), Dummy);
  if VerInfoSize > 0 then
  begin
      GetMem(VerInfo, VerInfoSize);
      try
        if GetFileVersionInfo(PChar(ParamStr(0)), 0, VerInfoSize, VerInfo) then
        begin
          VerQueryValue(VerInfo, '\', Pointer(VerValue), VerValueSize);
          with VerValue^ do
          begin
            V1 := dwFileVersionMS shr 16;
            V2 := dwFileVersionMS and $FFFF;
            V3 := dwFileVersionLS shr 16;
            V4 := dwFileVersionLS and $FFFF;
          end;
        end;
      finally
        FreeMem(VerInfo, VerInfoSize);
      end;
  end;
end;

function GetBuildInfo:string; overload;
var V1, V2, V3, V4: word;
begin
  GetBuildInfo(V1, V2, V3, V4);
  result := Format('%d.%d.%d.%d',[v1,v2,v3,v4]);
end;

procedure TfrmMonitor.BtnClick(Sender: TObject);
var
  m:TAlarm;
  f:TFileStream;
  head:TDBFHead;
  rec:ansistring;
begin
  caption := FormatDateTime('yyyymmdd-hns', now);
//3137-245e70ccc4f680f04eeadba2f23fdef5
//  m.Title := 'Allen';
//  m.Msg := '#RestClient Test';
//  m.SendByDingText('6d23878f7a057c2c99e4939f5a38447706a0d32f9102c57b3d684c87d4a35284');

//测试 DBF 文件大小变更
//.\\Files\\FUND_NB.DBF
//  f := TFileStream.Create('.\Files\Fund_NB.DBF', fmOpenReadWrite or fmShareDenyNone);
//  f.Read(head, sizeof(TDBFHead));
//
//  head.RecCount := head.RecCount+1;
//  f.Seek(0, soBeginning);
//  f.Write(head, sizeof(TDBFHead));
//
//  rec := '9991232018-04-09 15:10:59.9421.1695   0.012     ';
//  f.Seek(0, soEnd);
//  f.Write(rec[1], length(rec));
//  f.Free;

end;

procedure TfrmMonitor.btnConfigClick(Sender: TObject);
begin
  TfrmConfig.Init(FConfig)
end;

procedure TfrmMonitor.btnExitClick(Sender: TObject);
begin
  if MessageBox(0, '是否关闭高频扫描程序？', '警告', MB_ICONWARNING or MB_YESNO or MB_DEFBUTTON2) = mrYes then
  begin
    StopAll;
    sleep(1000);
    Close;
  end;
end;

procedure TfrmMonitor.btnExportCSVClick(Sender: TObject);
var
  w:TStreamWriter;
  ls:TStringList;
  i,k:integer;
begin
  if gdQuotePreview.RowCount<10 then exit;

  if not SaveDialog1.Execute(0) then exit;

  ls := TStringList.Create;

  w := TStreamWriter.Create(SaveDialog1.FileName);
  for i := 1 to gdQuotePreview.RowCount - 1 do
  begin
    ls.Clear;
    for k := 0 to gdQuotePreview.ColCount - 1 do
    begin
      ls.Add(gdQuotePreview.Cells[k,i]);
    end;
    w.WriteLine(ls.DelimitedText);
  end;
  ls.Free;
  w.Free
end;

procedure TfrmMonitor.btnFindCodeClick(Sender: TObject);
var
  code:string;
  i:integer;
begin
  code := Trim(edCode.Text);
  if code = '' then Exit;
  if gdQuotePreview.RowCount = 1 then exit;

  gdQuotePreview.SetFocus;

  for i := 1 to gdQuotePreview.RowCount-1 do
  begin
    if SameText( gdQuotePreview.Cells[0,i], code) then
    begin
      gdQuotePreview.Col := 0;
      gdQuotePreview.Row := i;
      break;
    end;
  end;

end;

procedure TfrmMonitor.btnStartClick(Sender: TObject);
begin
  if not Assigned(lvScanFileList.Selected) then exit;
  TQuoteScanner(lvScanFileList.Selected.Data).StartScan;
end;

procedure TfrmMonitor.DoSuningTxtBackup;
var
  h,m,s,ms:word;
  cron:string;
begin
  if FConfig.Plugins['SuningTxt'] then
  begin
    DecodeTime(FConfig.SuningTxt.ArchiveTime,h,m,s,ms);
    cron := Format('%d %d %d * * * ', [s,m,h]);
    workers.Plan(SuningArchiveJob, cron, nil);
  end;
end;

procedure TfrmMonitor.FormCreate(Sender: TObject);
var
  fc:TQuoteFileConfig;
  f, str:string;
  tmpObj: TQuoteScanner;
  scanner:TQuoteScannerClass;
  plugins:TObjectList<TQuoteScanner>;
  //tmpRow:INxCellsRow;
  function GetPlugin(APluginName:string): TQuoteScannerClass;
  begin
    result := nil;
    if not FConfig.Plugins[APluginName] then exit(nil);
    if UpperCase(APluginName) = 'DATABASE' then result := TQuote2MySQL else
    if UpperCase(APluginName) = 'CSV' then result := TWriteCSVTool else
    if UpperCase(APluginName) = 'BINARY' then result := TSaveBinary else
    if UpperCase(APluginName) = 'SUNINGTXT' then result := TSuningTxtTool else
    if UpperCase(APluginName) = 'MONITOR' then result := TMonitorTool;
    if UpperCase(APluginName) = 'KAFKA' then result := TKafkaPlug;
  end;
begin
  EnableMenuItem(GetSystemMenu(Handle,FALSE),SC_CLOSE,MF_BYCOMMAND or MF_GRAYED);
  spTimeInfo.Caption := Format('启动时间：%s', [FormatDateTime('yyyy-mm-dd hh:nn:ss', now)]);
  Log.SetDispLogTarget(mmLog.Lines);

  //加载配置
  FConfig := TQuoteScanConfig.Create;
  FConfig.Load;

  self.Caption := fconfig.WindowsCaption;

  //行情广播
  if FConfig.BroadcastEnable then
    BroadCaster.Start(FConfig.BroadcastPort);

  //初始化界面
  RzPageControl1.ActivePageIndex := 0;
  lvScanFileList.Clear;
  //self.gridMain.ClearRows;
  for fc in FConfig.QuoteFiles do
  begin
    f := fc.Path;
    if not TFile.Exists(f) then
    begin
      PostLog(llError, '%s不存在', [f]);
      Continue;
    end;
    plugins := TObjectList<TQuoteScanner>.Create(True);
    for str in FConfig.Plugins.Keys do
    begin
      scanner := GetPlugin(str);
      if Assigned(scanner) then
      begin
        tmpObj := scanner.Create(FConfig, fc);
        plugins.Add(tmpObj);
      end;
    end;
    //write sqlserver
    //tmpObj := TWriteDBTool.Create(TPath.GetFullPath(f), fc.StartTime, fc.StopTime);
    //TWriteDBTool(tmpObj).Setup(FConfig.ConnectString, Uppercase(TPath.GetFileNameWithoutExtension(f)), fc.Level);

    //tmpObj := TRealSliceTool.Create(TPath.GetFullPath(f), fc.StartTime, fc.StopTime);
    //TRealSliceTool(tmpObj).Setup(FConfig.ConnectString);
    lvScanFileList.AddItem(UpperCase(TPath.GetFileNameWithoutExtension(f)), plugins);
    //tmpRow := gridMain.AddRow();
    //tmpRow.Data := plugins;
    //tmpRow.Cells[0].Text := UpperCase(TPath.GetFileNameWithoutExtension(f));
  end;

  //状态栏
  if FConfig.BroadcastEnable then
    spBroadcast.Caption := Format('行情广播服务:%d', [fconfig.BroadcastPort])
  else
    spBroadcast.Caption := '行情广播服务:关闭';

  //版本信息
  spVerInfo.Caption := '版本号：'+GetBuildInfo;

  //设置定时器
  _checkTimer.Enabled := True;
  _guiTimer.Enabled := True;

  //苏宁定时归档过程
  DoSuningTxtBackup;
end;

procedure TfrmMonitor.FormDestroy(Sender: TObject);
var
  i:Integer;
begin
  log.AddLog('正在准备退出程序');
  log.SetDispLogTarget(nil);
  _checkTimer.Enabled := False;
  _guiTimer.Enabled := False;
  Workers.Clear;
  StopAll;
  log.AddLog('清除工作状态完成,程序退出！');
end;

function TfrmMonitor.GetSelectedPlugin: TQuoteScanner;
begin
  result := nil;
  if Assigned(lvScanFileList.Selected) and Assigned(lvScanFileList.Selected.Data) then
  begin
    result := TObjectList<TQuoteScanner>(lvScanFileList.Selected.Data).First;
  end;
end;

procedure TfrmMonitor.lvScanFileListDblClick(Sender: TObject);
var
  tmp:TQuoteScanner;
begin
  if not Assigned(lvScanFileList.Selected) then exit;
  tmp := GetSelectedPlugin;
  if Assigned(tmp) then
  begin
    if not tmp.Active then
    begin
      MessageBox(0, '扫描器未启动，无法预览数据！', '警告', MB_ICONWARNING or MB_OK);
      Exit;
    end;
    Preview(tmp);
    RzPageControl1.ActivePageIndex := 1;
  end;
end;

procedure TfrmMonitor.Preview(Q: TQuoteScanner);
var
  i,k:Integer;
  r:PQuoteRecord;
begin
  if not Assigned(Q) then Exit;

  gdQuotePreview.DefaultColWidth := 80;

  gdQuotePreview.RowCount := 10;
  gdQuotePreview.ColCount := 10;
  gdQuotePreview.FixedRows := 1;

  gdQuotePreview.Cells[00,0] := '代码';
  gdQuotePreview.Cells[01,0] := '简称';
  gdQuotePreview.Cells[02,0] := '时间';
  gdQuotePreview.Cells[03,0] := '昨收';
  gdQuotePreview.Cells[04,0] := '今开';
  gdQuotePreview.Cells[05,0] := '最高';
  gdQuotePreview.Cells[06,0] := '最低';
  gdQuotePreview.Cells[07,0] := '最新';
  gdQuotePreview.Cells[08,0] := '成交量';
  gdQuotePreview.Cells[09,0] := '成交额';

  gdQuotePreview.RowCount := q.RecCount+1;
  gdQuotePreview.ColWidths[2] := 70;

  for i := 0 to Q.RecCount - 1 do
  with gdQuotePreview do
  begin
    r := Q[i];
    if not Assigned(r) then continue;

    k := i+1;
    Cells[00,k] := r.GetCode;
    Cells[01,k] := r.GetAbbr;
    Cells[02,k] := FormatDateTime('hh:nn:ss',r.Market.Time);
    Cells[03,k] := FloatToStrF(r.Prev,ffNumber, 19,3);
    Cells[04,k] := FloatToStrF(r.Open,ffNumber, 19,3);
    Cells[05,k] := FloatToStrF(r.High,ffNumber, 19,3);
    Cells[06,k] := FloatToStrF(r.Low,ffNumber, 19,3);
    Cells[07,k] := FloatToStrF(r.Last,ffNumber, 19,3);
    Cells[08,k] := InttoStr(r.Volume);
    Cells[09,k] := FloatToStrF(r.Value,ffNumber, 19,3);
  end;

end;

procedure TfrmMonitor.StopAll;
var
  i:integer;
  plugins:TObjectList<TQuoteScanner>;
  scanner:TQuoteScanner;
begin
  try
    for i := 0 to lvScanFileList.Items.Count - 1 do
    begin
      plugins := TObjectList<TQuoteScanner>(lvScanFileList.Items[i].Data);
      for scanner in plugins do
        if scanner.Active then scanner.StopScan;
    end;
  except on e:Exception do
    begin
      PostLog(llError, '停止扫描任务失败，详细信息：'+e.Message);
    end;
  end;
end;

procedure TfrmMonitor.SuningArchiveJob(AJob: PQJob);
var
  spath, dpath, perFile, destFile, currFile: string;
  sfiles:TStringDynArray;
  tmp : TQuoteFileConfig;
  k:integer;
begin
  log.AddLog('===启动归档文件操作===');
  for tmp in FConfig.QuoteFiles do
  begin
    currFile := TPath.GetFileNameWithoutExtension(tmp.Path);
    if UpperCase(currFile)='FUND_HQ' then currFile := 'FUND_B';

    spath := TPath.Combine(FConfig.SuningTxt.TodayPath, currFile);
    dpath := TPath.Combine(FConfig.SuningTxt.ArchivePath, currFile);
    dpath := TPath.Combine(dpath, FormatDateTime('yyyy\MM\dd', today));
    sfiles := TDirectory.GetFiles(spath);
    k := 0;
    for perFile in sfiles do
    begin
      destFile := TPath.Combine(dpath, TPath.GetFileName(perFile));
      TDirectory.CreateDirectory(TPath.GetDirectoryName(destFile));
      try
        TFile.Move(perFile, destFile);
        inc(k);
      except
        log.AddLogFormat('归档[%文件]出现错误！',[currFile]);
      end;
    end;
    log.AddLogFormat('[%s]归档完成，共移动%d个文件', [currFile, k]);
  end;
  log.AddLog('===归档文件操作结束===');
end;

procedure TfrmMonitor.SyncGUI;
var
  plugins:TObjectList<TQuoteScanner>;
  p:TQuoteScanner;
  i:integer;
begin
  if csDestroying in Self.ComponentState then exit;

  lvScanFileList.Items.BeginUpdate;
  for i := 0 to lvScanFileList.Items.Count - 1 do
  begin
    plugins := TObjectList<TQuoteScanner>(lvScanFileList.Items[i].Data);
    if plugins.Count=0 then continue;
    p := plugins.First;
    if Assigned(p) then
    begin
      lvScanFileList.Items[i].SubItems.Clear;
      lvScanFileList.Items[i].SubItems.Add(FormatDateTime('hh:nn:ss.zzz', p.ChangeTime));
      lvScanFileList.Items[i].SubItems.Add(IntToStr( p.ChangeCount ));
      lvScanFileList.Items[i].SubItems.Add(IntToStr( p.UpdateCount ));
      lvScanFileList.Items[i].SubItems.Add(IntToStr( p.QueueCount ));
      lvScanFileList.Items[i].SubItems.Add(p.State);
      lvScanFileList.Items[i].SubItems.Add(Format('%d',[p.RecCount]));
      lvScanFileList.Items[i].SubItems.Add(TPath.GetDirectoryName(p.SourceFile));
    end;
  end;
  lvScanFileList.Items.EndUpdate;
  RzStatusPane1.Caption := Format('CPU:%f%,Mem:%s', [uPerformance.GetProcessCpuUsagePct,Capacity2Str(GetProcessMemUse)]);

  //New Update
//  gridMain.BeginUpdate();
//  for i := 0 to gridMain.RowCount - 1 do
//  begin
//    plugins := TObjectList<TQuoteScanner>(gridMain.Row[i].Data);
//    p := plugins.First;
//    if not assigned(p) then continue;
//    gridMain.Cell[1,i].AsString := FormatDateTime('hh:nn:ss.zzz', p.ChangeTime);
//    gridMain.Cell[2,i].AsInteger := p.ChangeCount;
//    gridMain.Cell[3,i].AsInteger := p.UpdateCount;
//    gridMain.Cell[4,i].AsInteger := p.QueueCount;
//    gridMain.Cell[5,i].AsString := p.State;
//    gridMain.Cell[6,i].AsInteger := p.RecCount;
//    gridMain.Cell[7,i].AsString := TPath.GetDirectoryName(p.SourceFile);
//  end;
//  gridMain.EndUpdate();
end;

procedure TfrmMonitor._checkTimerTimer(Sender: TObject);
var
  n:double;
  i:integer;
  plugins:TObjectList<TQuoteScanner>;
  scanner:TQuoteScanner;
begin
  if csDestroying in Self.ComponentState then exit;

  try
    n := now;
    for i := 0 to lvScanFileList.Items.Count - 1 do
    begin
      plugins := TObjectList<TQuoteScanner>(lvScanFileList.Items[i].Data);
      for scanner in plugins do
        scanner.AutoAction(n);
    end;
  except on e:Exception do
    begin
      PostLog(llError, '启动扫描任务失败，详细信息：'+e.Message);
    end;
  end;
end;

procedure TfrmMonitor._guiTimerTimer(Sender: TObject);
begin
  SyncGUI;
end;

end.
