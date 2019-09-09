unit uFrmFileInfo;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, RzPanel, RzDlgBtn,
  uQuote2DB, StdCtrls, Spin, ComCtrls, RzButton, RzRadChk;

type
  TfrmFileInfo = class(TForm)
    RzDialogButtons1: TRzDialogButtons;
    FileOpenDialog1: TFileOpenDialog;
    edFileInfo: TLabeledEdit;
    dtStart: TDateTimePicker;
    Label1: TLabel;
    dtEnd: TDateTimePicker;
    Label2: TLabel;
    edSplitMintue: TSpinEdit;
    Label3: TLabel;
    btnPickFile: TButton;
    RzGroupBox1: TRzGroupBox;
    RzGroupBox2: TRzGroupBox;
    cbkMonitorEnable: TRzCheckBox;
    edMonitorCodes: TLabeledEdit;
    edMonitorInterval: TSpinEdit;
    Label4: TLabel;
    Label5: TLabel;
    dtMTRange1Start: TDateTimePicker;
    dtMTRange1End: TDateTimePicker;
    Label6: TLabel;
    dtMTRange2Start: TDateTimePicker;
    dtMTRange2End: TDateTimePicker;
    procedure btnPickFileClick(Sender: TObject);
    procedure cbkMonitorEnableClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure RzDialogButtons1ClickOk(Sender: TObject);
    procedure RzDialogButtons1ClickCancel(Sender: TObject);
  private
    { Private declarations }
    FSource:TQuoteFileConfig;
    FConfirmOK: boolean;
    procedure Sync;
  public
    { Public declarations }
    class function Init(AFileInfo: TQuoteFileConfig; var bOK:boolean): TQuoteFileConfig;
  end;



implementation

var
  frmFileInfo: TfrmFileInfo;

{$R *.dfm}

procedure TfrmFileInfo.btnPickFileClick(Sender: TObject);
begin
  if self.FileOpenDialog1.Execute then
  begin
    edFileInfo.Text := FileOpenDialog1.FileName;
  end;
end;

procedure TfrmFileInfo.cbkMonitorEnableClick(Sender: TObject);
begin
  edMonitorInterval.Enabled := cbkMonitorEnable.Checked;
  edMonitorCodes.Enabled := cbkMonitorEnable.Checked;
  dtMTRange1Start.Enabled := cbkMonitorEnable.Checked;
  dtMTRange1End.Enabled := cbkMonitorEnable.Checked;
  dtMTRange2Start.Enabled := cbkMonitorEnable.Checked;
  dtMTRange2End.Enabled := cbkMonitorEnable.Checked;
end;

procedure TfrmFileInfo.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var   errMsg:string;
label checkError;
begin
  errMsg := '';
  if not FConfirmOK then goto checkError;
  if dtStart.Time>=dtEnd.Time then errMsg := '文件扫描时段，起始时间不可大于结束时间！';
  if cbkMonitorEnable.Checked and (Trim(edMonitorCodes.Text) = '') then errMsg := '开启监控，监控代码不可为空！';
  if cbkMonitorEnable.Checked and (dtMTRange1Start.Time>=dtMTRange1End.Time) then errMsg := '监控时段起始时间不可大于结束时间';
  if cbkMonitorEnable.Checked and (dtMTRange2Start.Time>=dtMTRange2End.Time) then errMsg := '监控时段起始时间不可大于结束时间';
checkError:
  if errMsg<>'' then
  begin
    MessageDlg(errMsg, mtWarning, [mbOK], 0);
    CanClose := False;
  end;

end;

class function TfrmFileInfo.Init(AFileInfo: TQuoteFileConfig; var bOK:boolean): TQuoteFileConfig;
begin
  frmFileInfo := TfrmFileInfo.Create(nil);
  frmFileInfo.FSource := AFileInfo;
  frmFileInfo.Sync;
  bOK := frmFileInfo.ShowModal = mrOK;
  if bOK then
  with frmFileInfo do
  begin
    FSource.Path := Trim(frmFileInfo.edFileInfo.Text);
    FSource.StartTime := dtStart.Time;
    FSource.StopTime := dtEnd.Time;
    FSource.SplitIntervalMinute := edSplitMintue.Value;
    //----------------
    FSource.MonitorEnable := cbkMonitorEnable.Checked;
    FSource.MonitorInterval := edMonitorInterval.Value;
    FSource.MonitorCodes := Trim(edMonitorCodes.Text);
    FSource.MonitorTimeRange01.StartTime := dtMTRange1Start.Time;
    FSource.MonitorTimeRange01.EndTime := dtMTRange1End.Time;
    FSource.MonitorTimeRange02.StartTime := dtMTRange2Start.Time;
    FSource.MonitorTimeRange02.EndTime := dtMTRange2End.Time;
    result := FSource;
  end;
end;

procedure TfrmFileInfo.RzDialogButtons1ClickCancel(Sender: TObject);
begin
  FConfirmOK := False;
end;

procedure TfrmFileInfo.RzDialogButtons1ClickOk(Sender: TObject);
begin
  FConfirmOK := True;
end;

procedure TfrmFileInfo.Sync;
begin
  edFileInfo.Text := FSource.Path;
  dtStart.Time := FSource.StartTime;
  dtEnd.Time := FSource.StopTime;
  edSplitMintue.Value := FSource.SplitIntervalMinute;
  //----------------
  cbkMonitorEnable.Checked := FSource.MonitorEnable;
  edMonitorInterval.Value := FSource.MonitorInterval;
  edMonitorCodes.Text := FSource.MonitorCodes;
  dtMTRange1Start.Time := FSource.MonitorTimeRange01.StartTime;
  dtMTRange1End.Time := FSource.MonitorTimeRange01.EndTime;
  dtMTRange2Start.Time := FSource.MonitorTimeRange02.StartTime;
  dtMTRange2End.Time := FSource.MonitorTimeRange02.EndTime;
  //-------------------
  cbkMonitorEnableClick(Self);
  FConfirmOK := False;
end;

end.
