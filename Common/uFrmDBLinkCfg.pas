unit uFrmDBLinkCfg;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, uDBSync, uSyncDefine,
  RzSpnEdt, Mask, RzEdit, RzCmboBx, RzButton, RzRadChk, StdCtrls;

type
  TfrmDBLinkCfg = class(TForm)
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label1: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    btnConfirm: TLabel;
    edDBType: TRzComboBox;
    edHost: TRzEdit;
    edPort: TRzSpinEdit;
    edDatabase: TRzEdit;
    edRole: TRzComboBox;
    edEncoding: TRzComboBox;
    edSID: TRzEdit;
    edUsername: TRzEdit;
    edPassword: TRzMaskEdit;
    edShowPass: TRzCheckBox;
    edWindowAuth: TRzCheckBox;
    btnTest: TRzBitBtn;
    RzBitBtn2: TRzBitBtn;
    btnCancel: TRzBitBtn;
    RzBitBtn1: TRzBitBtn;
    procedure btnCancelClick(Sender: TObject);
    procedure btnConfirmClick(Sender: TObject);
    procedure edWindowAuthClick(Sender: TObject);
    procedure edDBTypePropertiesChange(Sender: TObject);
    procedure edShowPassClick(Sender: TObject);
    procedure btnTestClick(Sender: TObject);
    procedure cxButton1Click(Sender: TObject);
  private
    { Private declarations }
    procedure ChangeGUI_By_DBType;
    procedure SetGUI(AOption: TDBLink);
    procedure GetOption(AOption: TDBLink);
  public
    { Public declarations }
  end;

  function DatabaseSetup(AOption:TDBLink; aTitle:string='数据库配置'; bModifyLinkName:boolean = False):boolean;

implementation
{$R *.dfm}
uses DBAccess;
function DatabaseSetup(AOption:TDBLink; aTitle:string='数据库配置'; bModifyLinkName:boolean = False):boolean;
var
  frm: TfrmDBLinkCfg;
begin
  frm := TfrmDBLinkCfg.Create(application);
  frm.Caption := aTitle;
  frm.SetGUI(AOption);
  result := frm.ShowModal = mrOK;
  if result then
    frm.GetOption(AOption);
  frm.Free;
end;


procedure TfrmDBLinkCfg.btnCancelClick(Sender: TObject);
begin
  self.ModalResult := mrCancel;
end;

procedure TfrmDBLinkCfg.btnConfirmClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TfrmDBLinkCfg.btnTestClick(Sender: TObject);
var
  aLink:TDBLink;
  errmsg:string;
  tmp: WideString;
begin
  alink := TDBLink.Create;
  GetOption(alink);
  if alink.Test(errmsg) then
  begin
    tmp := '连结成功！'#13#10'==========服务器版本信息=========='#13#10+errmsg;
    MessageBoxW(0, pWideChar(tmp), '消息', MB_ICONINFORMATION or MB_OK)
  end else
  begin
    errmsg := '连结失败！'+#13+#10+'错误：'+ errmsg;
    tmp := errmsg;
    MessageBox(0, pWideChar(tmp),  '消息', MB_ICONSTOP or MB_OK);
  end;
  aLink.Free;
end;

procedure TfrmDBLinkCfg.ChangeGUI_By_DBType;
begin
  edSID.Enabled := edDBtype.ItemIndex = 2; //Enabled If DBType is Oracle
  edRole.Enabled := edDBtype.ItemIndex = 2; //Enabled If DBType is Oracle
  edWindowAuth.Enabled := edDBtype.ItemIndex = 0;
  edEncoding.Enabled := edDBType.ItemIndex = 1;
end;

procedure TfrmDBLinkCfg.cxButton1Click(Sender: TObject);
var
  dblink:TDBLink;
  errmsg,dbname:string;
begin
  dbLink := tdbLink.create;
  GetOption(dblink);

  if not (dblink.DBType in [stLocalDB, stMySQL]) then
    raise Exception.Create('只有LocalDB类型支持创建库');
  if InputQuery('询问', '请输入数据库名称', dbname ) then
  begin
    if dblink.ExecSQL(format('create database %s',[dbname])) then
      MessageDlg('数据库【'+dbname+'】创建成功！', mtInformation, [mbOK], 0)
    else
      MessageDlg('数据库【'+dbname+'】创建失败', mtError, [mbOK], 0);
  end;
end;

procedure TfrmDBLinkCfg.edDBTypePropertiesChange(Sender: TObject);
begin
  ChangeGUI_By_DBType;
end;

procedure TfrmDBLinkCfg.edShowPassClick(Sender: TObject);
begin
  if edShowPass.Checked then
    edPassword.PasswordChar := '*'
  else
    edPassword.PasswordChar := #0;
end;

procedure TfrmDBLinkCfg.edWindowAuthClick(Sender: TObject);
begin
  self.edUsername.Enabled := not edWindowAuth.Checked;
  self.edPassword.Enabled := not edWindowAuth.Checked;
end;

procedure TfrmDBLinkCfg.SetGUI(AOption: TDBLink);
begin
  case AOption.DBType of
    stMSSQL: edDBtype.ItemIndex := 0;
    stMySQL: edDBType.ItemIndex := 1;
    stOracle: edDBType.ItemIndex := 2;
    stLocalDB: edDBType.ItemIndex := 3;
  end;
  edhost.Text          := AOption.Host;
  edport.Value         := AOption.Port;
  eddatabase.Text      := AOption.Database;
  edSID.Text           := AOption.OraServiceName;
  edRole.ItemIndex     := Integer(AOption.OraConnectionMode);
  edUserName.Text      := AOption.Username;
  edPassword.Text      := AOption.Password;
  edWindowAuth.Checked := AOption.WinAuth;
  //edLinkName.Text      := AOption.LinkName;
  edEncoding.ItemIndex := Integer(AOption.MySQLEncoding);
  ChangeGUI_By_DBType;
end;

procedure TfrmDBLinkCfg.GetOption(AOption: TDBLink);
begin
  case edDBType.ItemIndex of
    0: AOption.DBType := stMSSQL;
    1: AOption.DBType := stMySQL;
    2: AOption.DBType := stOracle;
    3: AOption.DBType := stLocalDB;
  end;
  AOption.Host := edHost.Text;
  AOption.Port := edPort.IntValue;
  AOption.Database := edDatabase.Text;
  AOption.OraServiceName := edSID.Text;
  AOption.OraConnectionMode := TOraConnMode(edRole.ItemIndex);
  AOption.Username := edUsername.Text;
  AOption.Password := edPassword.Text;
  AOption.WinAuth := edWindowAuth.Checked;
  //AOption.LinkName := edLinkName.Text;
  AOption.MySQLEncoding := TMySQLEncoding(edEncoding.ItemIndex);
end;

end.
