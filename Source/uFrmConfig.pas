unit uFrmConfig;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, RzPanel, RzDlgBtn, StdCtrls, ComCtrls, RzListVw,
  uQuote2DB,
  uFrmFileInfo,
  uFrmDBLinkCfg,
  Mask, RzEdit, RzSpnEdt, RzButton, RzRadChk, Menus, RzTabs, Grids, ValEdit,
  RzLstBox, RzChkLst, RzTreeVw;

type
   TfrmConfig = class(TForm)
    RzDialogButtons1: TRzDialogButtons;
    btnDBSet: TButton;
    lbDBDescription: TLabel;
    chkBroadcast: TRzCheckBox;
    Label1: TLabel;
    edBroadcastPort: TRzSpinEdit;
    Label2: TLabel;
    lvFilelist: TRzListView;
    PopupMenu1: TPopupMenu;
    miAddFile: TMenuItem;
    miRemoveFile: TMenuItem;
    Label3: TLabel;
    edAutoRemoveDays: TRzSpinEdit;
    RzPageControl1: TRzPageControl;
    TabSheet2: TRzTabSheet;
    TabSheet3: TRzTabSheet;
    RzGroupBox1: TRzGroupBox;
    LabeledEdit1: TLabeledEdit;
    RzSpinEdit2: TRzSpinEdit;
    LabeledEdit2: TLabeledEdit;
    LabeledEdit3: TLabeledEdit;
    RzGroupBox2: TRzGroupBox;
    chkPlugins: TRzCheckList;
    RzGroupBox3: TRzGroupBox;
    LabeledEdit4: TLabeledEdit;
    LabeledEdit5: TLabeledEdit;
    Memo1: TMemo;
    Label4: TLabel;
    LabeledEdit6: TLabeledEdit;
    procedure btnDBSetClick(Sender: TObject);
    procedure miAddFileClick(Sender: TObject);
    procedure lvFilelistDblClick(Sender: TObject);
  private
    { Private declarations }
    FConfig: TQuoteScanConfig;
    procedure SyncGUI;
    procedure SaveConfig;
  public
    { Public declarations }
    class function Init(ASource:TQuoteScanConfig):boolean;
  end;

implementation
var
  frmConfig: TfrmConfig;

{$R *.dfm}

{ TfrmConfig }

procedure TfrmConfig.btnDBSetClick(Sender: TObject);
begin
  if DatabaseSetup(FConfig.DBLink) then
  begin
    self.lbDBDescription.Caption := fConfig.DBLink.ToString;
    FConfig.Save;
  end;
end;

class function TfrmConfig.Init(ASource:TQuoteScanConfig):boolean;
begin
  frmConfig := TfrmConfig.Create(nil);
  frmConfig.FConfig := ASource;
  frmConfig.SyncGUI;
  result := frmConfig.ShowModal = mrOK;
  if result then
    frmConfig.SaveConfig;
  frmConfig.Free;
  if result then ASource.Save;
end;

procedure TfrmConfig.lvFilelistDblClick(Sender: TObject);
var
  bOk : boolean;
  tmp : TQuoteFileConfig;
begin
  if lvFilelist.Items.Count = 0 then Exit;
  tmp := uFrmFileInfo.TfrmFileInfo.Init(FConfig.QuoteFiles[lvFilelist.Selected.Index], bOK);
  if bOK then
    FConfig.QuoteFiles[lvFilelist.Selected.Index] := tmp;
end;

procedure TfrmConfig.miAddFileClick(Sender: TObject);
begin
  self.lvFilelist.AddItem('XXX.DBF',nil);
end;

procedure TfrmConfig.SaveConfig;
begin
  FConfig.BroadcastEnable := chkBroadcast.Checked;
  FConfig.BroadcastPort := edBroadcastPort.IntValue;
  FConfig.BinarySave := False; //TODO:chkBinarySave.Enabled;
  FConfig.AutoRemoveDays := Trunc(edAutoRemoveDays.Value);
  FConfig.Plugins['Database'] := self.chkPlugins.ItemChecked[0];
  FConfig.Plugins['CSV'] := self.chkPlugins.ItemChecked[1];
  FConfig.Plugins['Binary'] := self.chkPlugins.ItemChecked[2];
  FConfig.Plugins['SuningTxt'] := self.chkPlugins.ItemChecked[3];
  FConfig.Plugins['Monitor'] := self.chkPlugins.ItemChecked[4];
  FConfig.Plugins['Kafka'] := self.chkPlugins.ItemChecked[5];
end;

procedure TfrmConfig.SyncGUI;
var
  perFile:TQuoteFileConfig;
begin
  lbDBDescription.Caption := FConfig.DBLink.ToString;
  chkBroadcast.Checked := FConfig.BroadcastEnable;
  edBroadcastPort.IntValue := FConfig.BroadcastPort;
  edAutoRemoveDays.Value := FConfig.AutoRemoveDays;
  lvFilelist.Clear;
  for perFile in FConfig.QuoteFiles do
  begin
    lvFilelist.AddItem(perFile.Path, nil);
    lvFilelist.Items[lvFileList.Items.Count-1].SubItems.Add( FormatDateTime('hh:nn', perFile.StartTime ) );
    lvFilelist.Items[lvFileList.Items.Count-1].SubItems.Add( FormatDateTime('hh:nn', perFile.StopTime ) );
    lvFilelist.Items[lvFileList.Items.Count-1].SubItems.Add( Format('%d∑÷÷”',[perFile.SplitIntervalMinute]) );
  end;
  chkPlugins.ItemChecked[0] := FConfig.Plugins['Database'];
  chkPlugins.ItemChecked[1] := FConfig.Plugins['CSV'];
  chkPlugins.ItemChecked[2] := FConfig.Plugins['Binary'];
  chkPlugins.ItemChecked[3] := FConfig.Plugins['SuningTxt'];
  chkPlugins.ItemChecked[4] := FConfig.Plugins['Monitor'];
  chkPlugins.ItemChecked[5] := FConfig.Plugins['Kafka'];
end;

end.
