program QuoteScanMonitor;


{$R *.dres}

uses
//  madExcept,
//  madLinkDisAsm,
//  madListHardware,
//  madListProcesses,
//  madListModules,
  Forms,
  Windows,
  QuoteScanGUI in 'QuoteScanGUI.pas' {frmMonitor},
  uQuote2DB in '..\Common\uQuote2DB.pas',
  uQuoteFile in '..\Common\uQuoteFile.pas',
  uQuoteBroadcast in '..\Common\uQuoteBroadcast.pas',
  uQuote2MySQL in '..\Common\uQuote2MySQL.pas',
  uFrmDBLinkCfg in '..\Common\uFrmDBLinkCfg.pas' {frmDBLinkCfg},
  uDBSync in '..\Common\uDBSync.pas',
  uSyncDefine in '..\Common\uSyncDefine.pas',
  uFrmConfig in 'uFrmConfig.pas' {frmConfig},
  uFrmFileInfo in 'uFrmFileInfo.pas' {frmFileInfo},
  uDES in '..\Common\uDES.pas',
  uQuoteScanPlugin in '..\Common\uQuoteScanPlugin.pas',
  uSaveBinary in '..\Common\uSaveBinary.pas',
  uAlarm in '..\Common\uAlarm.pas',
  uKafkaPlug in '..\Common\uKafkaPlug.pas';

{$R *.res}

const C_GILDATA_HDB_CLIENT_ID = 'GILDATA_QuoteScanMonitor_EXE';
function IsSingleton:boolean;
var
  mutex_handle:THandle;
begin
  result := False;
  mutex_handle := OpenMutex(MUTEX_ALL_ACCESS, False, C_GILDATA_HDB_CLIENT_ID);
  if mutex_handle = 0 then
  begin
    mutex_handle := CreateMutex(nil, False, C_GILDATA_HDB_CLIENT_ID);
    result := True;
  end;
end;

begin
  //if not IsSingleton then Exit; //单实例运行
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMonitor, frmMonitor);
  Application.Run;
end.
