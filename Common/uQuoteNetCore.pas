unit uQuoteNetCore;

interface

uses

  Windows, Messages, SysUtils, Classes, IOUtils, Generics.Collections, Math, SyncObjs,
  Generics.Defaults,

  diocp.coder.baseObject, diocp.coder.tcpServer, diocp.coder.tcpClient,
  diocp.tcp.server, diocp.sockets,
  diocp.tcp.client, utils.buffer,

  QXml, QWorker, uLog,
  uQuoteTypes;

const
  WM_RECV_INFO = WM_USER+123;

type

  TQuoteServer = class;
  TQuoteClient = class;

  PNetSpeedMonitor = ^TNetSpeedMonitor;
  TNetSpeedMonitor = packed record
  private
    FLastSent, FLastRecv:Int64;
    FJobHandle: IntPtr;
    FSource: diocp.tcp.server.TIocpDataMonitor;
    procedure doSpeedDetect(AJob: PQJob);
  public
    SentSpeed:Int64;
    RecvSpeed:Int64;
    constructor Create(ASource: diocp.tcp.server.TIocpDataMonitor);
    procedure  Stop;
  end;

  //行情文件信息
  TQuoteFileContext = class
  strict private
    FFileName:string;
    FKeyName:string;
    FFileSize:Integer;
    FFileStream:TFileStream;
    FTotalWriteSize:Int64;
    FUpdateCount:Integer;
    FUpdateTime:TDateTime;
    FUpdateSize:Integer;
  public
    constructor Create(AFileName:string; AKeyName:string);
    destructor Destroy; override;
    //文件操作方法
    function WriteBinaryBlocks(APack:TQuoteMsgPack):boolean;
    procedure WriteFile(APack:TQuoteMsgPack);
    function GetFilePack:TQuoteMsgPack;
    //属性定义
    property FileName:string read FFileName;
    property FileSize:Integer read FFileSize;
    property KeyName:string read FKeyName;
    property TotalWriteSize:Int64 read FTotalWriteSize;
    property UpdateCount:Integer read FUpdateCount;
    property UpdateSize:Integer read FUpdateSize;
    property UpdateTime:TDateTime read FUpdateTime;
  end;

  //用户信息
  TQuoteUserInfo = class
  strict private
    FFileList:TStringList;
    FUserName:string;
    FPassword:string;
    FExpireDate:TDateTime;
    FConnectCount:Integer;
    FConnectTime: TDateTime;
    FOnline: boolean;
    FIPAddr:string;
    FSentSize:Int64;
  public
    constructor Create;
    destructor Destroy; override;
    property UserName:string read FUserName write FUserName;
    property Password:string read FPassword write FPassWord;
    property ExpireDate:TDateTime read FExpireDate write FExpireDate;
    property FileList:TStringList read FFileList;
    property ConnectCount:Integer read FConnectCount write FConnectCount;
    property ConnectTime:TDateTime read FConnectTime write FConnectTime;
    property Online:boolean read FOnline write FOnline;
    property IPAddr:string read FIPAddr write FIPAddr;
    property SentSize:Int64 read FSentSize write FSentSize;
  end;

  //行情分发服务端配置
  TQuoteServerConfig = class
  strict private
    FUsers:TObjectList<TQuoteUserInfo>;
    FQuoteFilePath:TDictionary<string, string>;
    FPort: Integer;
    procedure LoadFromFile(AFileName:string);
    procedure Save;
    procedure ResetDefault;
    function GetUsers:TArray<TQuoteUserInfo>;
  public
    constructor Create;
    destructor Destroy; override;
    property Port:Integer read FPort write FPort;
    function FindUser(AUserName:string; var UserInfo:TQuoteUserInfo):boolean;
    procedure Reload;
    function AllFiles:TArray<string>;
    property Users:TArray<TQuoteUserInfo> read GetUsers;
  end;

  //行情接收配置
  TQuoteClientConfig = class
  strict private
    FPort: Integer;
    FPassword: string;
    FHost: string;
    FUserName: string;
    FLocalPath:string;
    FXML:TQXMLNode;
    FXMLNodeList:TQXMLNodeList;
    FQuoteFiles:TStringList;
    procedure SetHost(const Value: string);
    procedure SetPassword(const Value: string);
    procedure SetPort(const Value: Integer);
    procedure SetUserName(const Value: string);
    function GetRemoteHost(AIndex: Integer): string;
    procedure ResetDefault;
    function LoadFromLocalFile:boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Reload;
    property Host:string read FHost write SetHost;
    property Port:Integer read FPort write SetPort;
    property UserName:string read FUserName write SetUserName;
    property Password:string read FPassword write SetPassword;
    property LocalPath:string read FLocalPath write FLocalPath;
    //暂未实现，后续需要实现多主机自动切换
    property RemoteHost[AIndex:Integer]:string read GetRemoteHost;
    property Files:TStringList read FQuoteFiles;
  end;

  //文件扫描线程类
  TQBinaryFileScan = class(TThread)
  strict private
    FFileName     : string;
    FFileSize     : DWORD;
    FOwner        : TQuoteServer;
  protected
    FChangeBlocks : TQFileBlocks;
    FScanLocker   : TCriticalSection;
    pBuffer,pLastSnap: PByte;
    procedure Execute; override;
  public
    constructor Create(AOwner:TQuoteServer; AFilename:string);
    destructor Destroy; override;
    function FilePack: TQuoteMsgPack;
    property FileSize:DWORD read FFileSize;
    property FileName:string read FFileName;
    procedure Lock;
    procedure UnLock;
  end;

  //行情服务端
  TQuoteServer = class
  strict private
    FConfig        : TQuoteServerConfig;
    FOnlineClients : TObjectDictionary<TIOCPCoderClientContext, TQuoteUserInfo>;
    FSpeedMonitor  : PNetSpeedMonitor;
    FTCPServer     : TDiocpCoderTcpServer;
    FScanThreads   : TObjectList<TQBinaryFileScan>;
    function GetClients: TArray<TQuoteUserInfo>;
    function GetPort:Integer;
    function GetConnectCount:Integer;
    function GetSentSize:Int64;
  protected
    function CheckUser(AContext: TIOCPCoderClientContext; APack:TQuoteMsgPack; var iRetCode:Integer; var sRetMsg:string):boolean;
    procedure FileChanged(const pBlocks:PQFileBlocks);
    procedure OnClientDisconnect(pvClientContext: TIocpClientContext);
    procedure OnClientRequest(pvClient:TIOCPCoderClientContext; pvObject:TObject);
    procedure SendInitFile(AClient: TIOCPCoderClientContext; AUser:TQuoteUserInfo);
  public
    constructor Create;
    destructor Destroy; override;
    function Start:boolean;
    procedure ReloadAccount;
    property Clients:TArray<TQuoteUserInfo> read GetClients;
    property ConnectCount:Integer read GetConnectCount;
    property Port:Integer read GetPort;
    property Config: TQuoteServerConfig read FConfig;
    property Speed:PNetSpeedMonitor read FSpeedMonitor;
    property Server:TDiocpCoderTcpServer read FTCPServer;
  end;

  //行情客户端
  TQuoteClient = class
  private
    FConfig:TQuoteClientConfig;
    FTCPClient:TDiocpCoderTcpClient;
    FRemote:TIocpCoderRemoteContext;
    FSendLocker: TCriticalSection;
    FFileContexts: TObjectDictionary<string, TQuoteFileContext>;
    FNetDelay:Cardinal;
    FTargetWinHandle: HWND;
    FHBSendHandle: IntPtr;
    procedure OnResponse(pvTcpClient: TDiocpCoderTcpClient; pvContext:TIocpCoderRemoteContext; pvActionObject: TObject);
    procedure OnConnect(pvContext: TDiocpCustomContext);
    procedure OnDisconnect(pvContext: TDiocpCustomContext);
    procedure OnContextError(pvContext: TDiocpCustomContext; pvErrorCode: Integer);
    function GetRecvSize: Int64;
    function GetSentSize: Int64;
    function GetActive:boolean;
    function GetRemoteHost:string;
  protected
    procedure RecvFilePack(APack:TQuoteMsgPack);
    procedure RecvBinaryBlocks(APack:TQuoteMsgPack);
    procedure SendMessagePack(APack:TQuoteMsgPack; bAutoFree:boolean=True);
    procedure Login;
    procedure SendHeartbeat(AJob: PQJob);
    procedure Restart;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    property SentSize:Int64 read GetSentSize;
    property RecvSize:Int64 read GetRecvSize;
    property TargetWinHandle: HWND read FTargetWinHandle write FTargetWinHandle;
    property NetDelay:Cardinal read FNetDelay;
    property Active:boolean read GetActive;
    property RemoteHost:string read GetRemoteHost;
  end;

  //字节数转可读字符串
  function Capacity2Str(ABytes:Int64):string;

  const C_CLIENT_CONFIG_FILENAME = '.\QuoteClient.XML';
  const C_SERVER_CONFIG_FILENAME = '.\QuoteServer.XML';
  const C_DEFAULT_TCP_PORT = 9150;

implementation

function Capacity2Str(ABytes:Int64):string;
var
  f : double;
  k : integer;
const CapacityStr: array[0..4] of string = ('Byte','KB','MB','GB', 'TB');
begin
  if ABytes <= 1024 then Exit(Format('%dB',[ABytes]));

  f := ABytes*1.0;
  k := low(CapacityStr);
  while k <= High(CapacityStr) do
  begin
    if (f/1024)<1.0 then break;
    f := f / 1024;
    inc(k);
  end;
  result := Format('%f%s', [f, CapacityStr[k]]);
end;

type
  TQuoteMsgEncoder = class(TIOCPEncoder)
  public
    procedure Encode(pvDataObject: TObject; const ouBuf: TBufferLink); override;
  end;

  TQuoteMsgDeCoder = class(TIOCPDecoder)
  public
    function Decode(const inBuf: TBufferLink; pvContext: TObject): TObject; override;
  end;

{ TQuoteMsgEncoder }

procedure TQuoteMsgEncoder.Encode(pvDataObject: TObject; const ouBuf: TBufferLink);
var
  tmp:TQuoteMsgPack absolute pvDataObject;
begin
  tmp.Compress;
  ouBuf.AddBuffer(PAnsiChar(tmp.Buffer), tmp.PackageLen);
end;

{ TQuoteMsgDeCoder }
//pvContext=TIOCPCoderClientContext
function TQuoteMsgDeCoder.Decode(const inBuf: TBufferLink; pvContext: TObject): TObject;
var
  head:TQuoteMsgPackHead;
  pBuf:TBytes;
  k:Integer;
begin
  result := nil;
  k := inBuf.validCount;

  //超过5M,需要返回未知数据包，客户端需重连
  if k >= 5 * 1024 * 1024 then
  begin
    inBuf.clearBuffer;
    result := TQuoteMsgPack.BuildUnknow;
    Exit;
  end;

  //不及一个最小的包
  if k < PACKAGE_HEAD_SIZE then Exit;

  //读取包头
  inBuf.markReaderIndex;
  inBuf.readBuffer(@head, PACKAGE_HEAD_SIZE);

  //判断是否为完整的包;
  if k >= head.PackageLen then
  begin
    //TODO:不正确的数据包
    if head.PackageLen <= head.BodyLen then
    begin
      inBuf.clearBuffer;
      Exit(TQuoteMsgPack.BuildUnknow);
    end;
    //正确的数据包
    SetLength(pBuf, head.BodyLen);
    inBuf.readBuffer(@pBuf[0], head.BodyLen);
    result := TQuoteMsgPack.Create(head, pBuf[0], head.BodyLen);
    TQuoteMsgPack(result).Decompress;
  end
  else
    inBuf.restoreReaderIndex;

  SetLength(pBuf,0);
end;

{ TQuoteUserInfo }

constructor TQuoteUserInfo.Create;
begin
  FFileList := TStringList.Create;
  FFileList.Delimiter := '|';
  FConnectCount := 0;
  FConnectTime := Now;
  FOnline := False;
  FSentSize := 0;
  FIPAddr := '';
end;

destructor TQuoteUserInfo.Destroy;
begin
  FFileList.Free;
  inherited;
end;

{ TQuoteServerConfig }

function TQuoteServerConfig.AllFiles: TArray<string>;
begin
  result := FQuoteFilePath.Values.ToArray;
end;

constructor TQuoteServerConfig.Create;
begin
  FUsers := TObjectList<TQuoteUserInfo>.Create(True);
  FQuoteFilePath := TDictionary<string, string>.Create();
end;

destructor TQuoteServerConfig.Destroy;
begin
  FQuoteFilePath.Free;
  FUsers.Free;
  inherited;
end;

function TQuoteServerConfig.FindUser(AUserName: string; var UserInfo: TQuoteUserInfo): boolean;
var
  perU: TQuoteUserInfo;
begin
  result := False;
  for perU in FUsers do
  begin
    if perU.UserName = AUserName then
    begin
      UserInfo := perU;
      result := True;
    end;
  end;
end;

function TQuoteServerConfig.GetUsers: TArray<TQuoteUserInfo>;
begin
  result := FUsers.ToArray;
end;

procedure TQuoteServerConfig.LoadFromFile(AFileName: string);
var
  perNode, xml:TQXMLNode;
  ulist:TQXMLNodeList;
  uInfo:TQuoteUserInfo;
begin
  xml := TQXMLNode.Create;
  XMLCaseSensitive := False;

  xml.LoadFromFile(AFileName);
  FPort := StrToInt( xml.TextByPath('Port', '9150') );

  ulist := TQXMLNodeList.Create;
  xml.ItemByName('User', ulist, True);

  //Load Users Info
  FUsers.Clear;
  for perNode in ulist do
  begin
    uInfo := TQuoteUserInfo.Create;
    uInfo.UserName := perNode.TextByPath('UserName', 'ErrUserName');
    uInfo.Password := perNode.TextByPath('PassWord', 'ErrUserName');
    uInfo.ExpireDate := StrToDate(perNode.TextByPath('ExpireDate', DateToStr(Now+7)));
    uInfo.FileList.Text := perNode.TextByPath('Files', 'SJSHQ.DBF');
    FUsers.Add(uInfo);
  end;

  //Load QuoteFilePath
  FQuoteFilePath.Clear;
  ulist.Clear;
  xml.ItemByName('QuoteFile', ulist, True);
  for perNode in ulist do
  begin
     FQuoteFilePath.AddOrSetValue(
      UpperCase(perNode.Attrs.ValueByName('Name')),
      perNode.Attrs.ValueByName('Path'));
  end;


  ulist.Free;
  xml.Free;
end;

procedure TQuoteServerConfig.ReLoad;
begin
  if TFile.Exists(C_SERVER_CONFIG_FILENAME) then
    LoadFromFile(C_SERVER_CONFIG_FILENAME)
  else
    ResetDefault;

  if not TFile.Exists(C_SERVER_CONFIG_FILENAME) then Save;
end;

procedure TQuoteServerConfig.ResetDefault;
begin
  FPort := C_DEFAULT_TCP_PORT;

  FQuoteFilePath.Clear;
  FQuoteFilePath.Add('SHOW2003.DBF', '.\show2003.dbf');
  FQuoteFilePath.Add('SJSHQ.DBF', '.\sjshq.dbf');
  FQuoteFilePath.Add('SJSZS.DBF', '.\sjszs.dbf');
  FQuoteFilePath.Add('MKTDT00.TXT', '.\mktdt00.txt');

  FUsers.Clear;
  FUsers.Add(TQuoteUserInfo.Create);
  FUsers.First.UserName := 'guest';
  FUsers.First.Password := 'guest';
  FUsers.First.ExpireDate := now + 7;
  FUsers.First.FileList.Text := 'SJSHQ.DBF,MKTDT00.TXT';
end;

procedure TQuoteServerConfig.Save;
var
  xml,unode,usnode,qfsnode,qfnode:TQXMLNode;
  perU:TQuoteUserInfo;
  qf:string;
begin
  xml := TQXMLNode.Create;
  xml.Name := 'QuoteServer';

  //Port
  xml.AddNode('Port').Text := IntToStr(FPort);

  //Quote File Path
  qfsnode := xml.Add('QuoteFiles');
  for qf in FQuoteFilePath.Keys do
  begin
    qfnode := qfsnode.Add('QuoteFile');
    qfnode.Attrs.Add('Name').Value := qf;
    qfnode.Attrs.Add('Path').Value := FQuoteFilePath[qf];
  end;

  //Users Info
  usnode := xml.AddNode('Users');
  for perU in FUsers do
  begin
    unode := usnode.AddNode('User');
    unode.AddNode('UserName').Text := perU.UserName;
    unode.AddNode('PassWord').Text := perU.Password;
    unode.AddNode('ExpireDate').Text := DateToStr(perU.ExpireDate);
    unode.AddNode('FILES').Text := perU.FileList.Text;
  end;
  xml.SaveToFile(C_SERVER_CONFIG_FILENAME);
  xml.Free;
end;

{ TQuoteServer }

constructor TQuoteServer.Create;
var
  perLocalFile:string;
begin
  FConfig := TQuoteServerConfig.Create;
  FConfig.ReLoad;

  FOnlineClients := TObjectDictionary<TIOCPCoderClientContext, TQuoteUserInfo>.Create([]);


  FTCPServer := TDiocpCoderTcpServer.Create(nil);
  FTCPServer.OnContextDisconnected := OnClientDisconnect;

  //注册编码&解码对象
  FTCPServer.RegisterCoderClass(TQuoteMsgDeCoder,TQuoteMsgEncoder);

  //注册收到客户端请求时处理过程
  FTCPServer.OnContextAction := OnClientRequest;

  //速度监测
  FTCPServer.CreateDataMonitor;
  FSpeedMonitor := GetMemory(SizeOf(TNetSpeedMonitor));
  FSpeedMonitor.Create(FTCPServer.DataMoniter);

  //初始化文件变化扫描线程池
  FScanThreads := TObjectList<TQBinaryFileScan>.Create(False);
  for perLocalFile in FConfig.AllFiles do
    FScanThreads.Add( TQBinaryFileScan.Create(Self, perLocalFile) );
end;

destructor TQuoteServer.Destroy;
begin
  FScanThreads.Clear;

  FSpeedMonitor.Stop;
  FreeMem(FSpeedMonitor);

  FTCPServer.Close;
  FTCPServer.Free;
  FOnlineClients.Free;
  FConfig.Free;
  inherited;
end;

procedure TQuoteServer.OnClientDisconnect(pvClientContext: TIocpClientContext);
var
  tmp:TIOCPCoderClientContext;
  uinfo, user:TQuoteUserInfo;
begin
  tmp := pvClientContext as TIOCPCoderClientContext;
  if Assigned(tmp) then
  begin
    if FOnlineClients.TryGetValue(tmp, uinfo) then
    begin
      PostLog(llMessage, '用户[%s]已退出', [uinfo.UserName]);
      //变更用户状态
      if FConfig.FindUser(uinfo.UserName, user) then
      begin
        user.Online := False;
        user.SentSize := 0;
      end;

      FOnlineClients.Remove(tmp);
    end;
  end;
end;

procedure TQuoteServer.OnClientRequest(pvClient: TIOCPCoderClientContext; pvObject: TObject);
var
  request:TQuoteMsgPack absolute pvObject;
  response: TQuoteMsgPack;
  iRetCode: Integer;
  tmp:string;
begin
  if pvObject = nil then exit;

  response := nil;
  case request.HeadInfo.PackageType of
    //忽略客户端发送的心跳包，不做回应
    qmtHeart:;
    //客户测试延时包
    qmtNetTest: pvClient.WriteObject(pvObject);
    //登录处理
    qmtLogin:
    begin
      if CheckUser(pvClient, request, iRetCode, tmp) then
        response := TQuoteMsgPack.Build(1,iRetCode,tmp)
      else
        response := TQuoteMsgPack.Build(0,iRetCode,tmp);
    end;
  end;

  if Assigned(response) then
  begin
    pvClient.WriteObject(response);
    FreeAndNil(response);
  end;
end;

procedure TQuoteServer.SendInitFile(AClient: TIOCPCoderClientContext; AUser: TQuoteUserInfo);
var
  pack: TQuoteMsgPack;
  perThread:TQBinaryFileScan;
begin
  for perThread in FScanThreads do
  begin
    perThread.Lock;
    pack := nil;
    try
      pack := perThread.FilePack;
      AClient.WriteObject(pack);
      AUser.SentSize := AUser.SentSize + pack.PackageLen;
    finally
      perThread.UnLock;
      if Assigned(pack) then FreeAndNil(pack);
    end;
  end;
end;

function TQuoteServer.GetClients: TArray<TQuoteUserInfo>;
begin
  result := FOnlineClients.Values.ToArray();
end;

function TQuoteServer.GetConnectCount: Integer;
begin
  result := FTCPServer.ClientCount;
end;

function TQuoteServer.GetPort: Integer;
begin
  result := FTCPServer.Port;
end;

function TQuoteServer.GetSentSize: Int64;
begin
  result := FTCPServer.DataMoniter.SentSize;
end;

procedure TQuoteServer.ReloadAccount;
begin

end;

procedure TQuoteServer.FileChanged(const pBlocks:PQFileBlocks);
var
  lvList:TList;
  perClient:TIOCPCoderClientContext;
  msgPack:TQuoteMsgPack;
  uinfo:TQuoteUserInfo;
  i:integer;
begin
  msgPack := TQuoteMsgPack.Create(qmtBinaryBlocks, pBlocks^, pBlocks.RecordSize);
  msgPack.Compress;

  lvList := tList.Create;
  FTCPServer.GetOnlineContextList(lvList);

  for i := 0 to lvList.Count - 1 do
  begin
    perClient := TIOCPCoderClientContext(lvList[i]);
    perClient.LockContext('推送文件块', nil);
    try
      perClient.WriteObject(msgPack);
      if FOnlineClients.TryGetValue(perClient, uinfo) then
        uinfo.SentSize := uinfo.SentSize + msgPack.PackageLen;
    finally
      perClient.UnLockContext('推送文件块结束', nil);
    end;
  end;

  msgPack.Free;
  lvList.Free;
end;

function TQuoteServer.Start:boolean;
begin
  PostLog(llMessage, '开启行情文件传输服务，绑定端口%d',[FConfig.Port]);
  FTCPServer.Port := FConfig.Port;
  FTCPServer.Open;
  result := True;
end;

function TQuoteServer.CheckUser(AContext: TIOCPCoderClientContext; APack:TQuoteMsgPack; var iRetCode:Integer; var sRetMsg:string):boolean;
var
  uinfo:TQuoteUserInfo;
const
  errmsg:array[0..3] of string = ('登陆成功','未找到该用户', '密码不匹配', '账户已过期');
begin
  result := False;
  iRetCode := 0;

  PostLog(llMessage, '用户[%s]发送登录请求', [APack.UserName]);

  if FConfig.FindUser(APack.UserName,uinfo) then
  begin
    if uinfo.Password = APack.PassWord then
    begin
      if now > uinfo.ExpireDate then
        iRetCode := 3 //过期账户
      else
        result := True;
    end else
      iRetCode := 2; //密码不对
  end else
    iRetCode := 1; //未找到该用户

  sRetMsg := errmsg[iRetCode];

  if Result then
  begin
    PostLog(llMessage, '用户[%s]请求登录成功', [APack.UserName]);
    uinfo.Online := True;
    uinfo.ConnectTime := now;
    uinfo.ConnectCount := uinfo.ConnectCount + 1;
    uinfo.IPAddr := Format('%s:%d', [AContext.RemoteAddr, AContext.RemotePort]);
    FOnlineClients.AddOrSetValue(AContext, uinfo);
    SendInitFile(AContext, uinfo);
  end else
    PostLog(llMessage, '用户[%s]请求登录失败,错误信息：%s',[APack.UserName, sRetMsg]);
end;


{ TQuoteRecvConfig }

constructor TQuoteClientConfig.Create;
begin
  FQuoteFiles := TStringList.Create;
  FXMLNodeList := TQXMLNodeList.Create;
  FXML := TQXMLNode.Create;
  Reload;
end;

destructor TQuoteClientConfig.Destroy;
begin
  FQuoteFiles.Free;
  FXMLNodeList.Free;
  FXML.Free;
  inherited;
end;

function TQuoteClientConfig.GetRemoteHost(AIndex: Integer): string;
begin

end;

function TQuoteClientConfig.LoadFromLocalFile: boolean;
var
  cname:string;
  perNode:TQXMLNode;
begin
  FQuoteFiles.Clear;
  FXMLNodeList.Clear;

  cname := TPath.GetFullPath(C_CLIENT_CONFIG_FILENAME);
  if not TFile.Exists(cname) then
  begin
    PostLog(llWarning, '未找到客户端配置文件:'+cname);
    Exit(False);
  end;

  result := False;
  try
    FXML.LoadFromFile(cname);
    //FHost := FXML.TextByPath('Host', '127.0.0.1');
    FHost := FXML.TextByPath('Host', '139.196.111.19');
    FPort := StrToInt( FXML.TextByPath('Port', '9150') );
    FUserName := FXML.TextByPath('UserName', 'guest');
    FPassword := FXML.TextByPath('Password', 'guest');
    FLocalPath := FXML.TextByPath('LocalPath', '.\Files');
    //加载需要传输的行情文件列表
    FXML.ItemByName('File', FXMLNodeList, True);
    for perNode in FXMLNodeList do
      FQuoteFiles.Add( perNode.Text );
    result := True;
  except
    on E:Exception do
    begin
      PostLog(llWarning, '加载配置文件出现错误，详细信息：',[e.Message]);
    end;
  end;
end;

procedure TQuoteClientConfig.Reload;
begin
  if not LoadFromLocalFile then
  begin
    ResetDefault;
    FXML.SaveToFile(C_CLIENT_CONFIG_FILENAME);
    LoadFromLocalFile;
  end;
end;

procedure TQuoteClientConfig.ResetDefault;
var
  tmpNode:TQXMLNode;
  perFile:string;
begin
  FHost := '139.196.111.19';
  FHost := '127.0.0.1';
  FPort := C_DEFAULT_TCP_PORT;
  FUserName := 'guest';
  FPassword := 'guest';
  FLocalPath := '.\DataFiles';
  FQuoteFiles.Clear;
  //FQuoteFiles.Add('SHOW2003.DBF');
  FQuoteFiles.Add('SJSHQ.DBF');
  FQuoteFiles.Add('SJSZS.DBF');
  FQuoteFiles.Add('mktdt00.txt');

  FXML.Clear;
  FXML.Name := 'QuoteRecvConfig';
  FXML.AddNode('Host').Text := FHost;
  FXML.AddNode('Port').Text := IntToStr(FPort);
  FXML.AddNode('UserName').Text := FUserName;
  FXML.AddNode('Password').Text := FPassword;
  FXML.AddNode('LocalPath').Text := FLocalPath;
  tmpNode := FXML.AddNode('Files');
  for perFile in FQuoteFiles do
    tmpNode.AddNode('File').Text := perFile;
end;

procedure TQuoteClientConfig.SetHost(const Value: string);
begin
  FHost := Value;
end;

procedure TQuoteClientConfig.SetPassword(const Value: string);
begin
  FPassword := Value;
end;

procedure TQuoteClientConfig.SetPort(const Value: Integer);
begin
  FPort := Value;
end;

procedure TQuoteClientConfig.SetUserName(const Value: string);
begin
  FUserName := Value;
end;

{ TQuoteClient }
type
  TMyClientContext = class(TIocpCoderRemoteContext)
  public
    constructor Create; override;
  end;
  constructor TMyClientContext.Create;
  begin
    inherited;
    self.RegisterCoderClass(TQuoteMsgDeCoder,TQuoteMsgEncoder);
  end;

constructor TQuoteClient.Create;
begin
  FNetDelay := 5;
  FRemote := nil;

  FSendLocker := TCriticalSection.Create;
  FConfig := TQuoteClientConfig.Create;

  FFileContexts := TObjectDictionary<string, TQuoteFileContext>.Create([doOwnsValues]);

  FTCPClient := TDiocpCoderTcpClient.Create(nil);
  FTCPClient.CreateDataMonitor;
  FTCPClient.RegisterContextClass(TMyClientContext);
  FTCPClient.OnChildContextAction := OnResponse;
  FTCPClient.OnContextConnected := OnConnect;
  FTCPClient.OnContextDisconnected := OnDisconnect;
  FTCPClient.OnContextError := OnContextError;
  FTCPClient.Active := True;

  FHBSendHandle := Workers.Post(SendHeartbeat,30000, nil);
end;

destructor TQuoteClient.Destroy;
begin
  if FHBSendHandle > 0 then
    workers.ClearSingleJob(FHBSendHandle,True);

  FSendLocker.Enter;
  FRemote := nil;
  FSendLocker.Leave;

  FTCPClient.Active := False;
  FTCPClient.Free;

  FFileContexts.Free;

  FSendLocker.Free;
  inherited;
end;

procedure TQuoteClient.OnResponse(pvTcpClient: TDiocpCoderTcpClient; pvContext: TIocpCoderRemoteContext; pvActionObject: TObject);
var
  aPack:TQuoteMsgPack;
begin
  aPack := pvActionObject as TQuoteMsgPack;
  if not Assigned(aPack) then
  begin
    Postlog(llWarning, '未识别的数据包，解码失败');
    Exit;
  end;

  case aPack.HeadInfo.PackageType of
    qmtUnknow: Restart;
    qmtOperResponse:
    begin
      with PQuoteOperResponse( aPack.BodyBuffer )^ do
        PostLog(llMessage, '服务端响应: 代码:[%d], 消息:[%s]',[ReturnCode, GetMessage]);
    end;
    qmtFile:
    begin
      with PQuoteFilePack(aPack.BodyBuffer)^ do
        postLog(llMessage, '收到[%s]文件, 文件长度:%d字节', [GetFileName, FileLength]);
      RecvFilePack(aPack);
    end;
    qmtBinaryBlocks: RecvBinaryBlocks(aPack);
    qmtNetTest: FNetDelay := GetTickCount - PCardinal(aPack.BodyBuffer)^;
    qmtCustom: ;
  end;
end;

function TQuoteClient.GetActive: boolean;
begin
  result := Assigned(FRemote) and FRemote.Active;
end;

function TQuoteClient.GetRecvSize: Int64;
begin
  result := FTCPClient.DataMoniter.RecvSize
end;

function TQuoteClient.GetRemoteHost: string;
begin
  result := '[未连接]';
  if Self.Active then
  begin
    result := Format('%s:%d', [FRemote.Host, FRemote.Port]);
  end;
end;

function TQuoteClient.GetSentSize: Int64;
begin
  result := FTCPClient.DataMoniter.SentSize;
end;

procedure TQuoteClient.SendHeartbeat;
begin
  //判断是否已连接服务器
  if not Assigned(FRemote) then Exit;
  if not FRemote.Active then Exit;

  //发送心跳包
  SendMessagePack(TQuoteMsgPack.BuildHeartbeat);

//  //发送网络延时测试包
//  t := GetTickCount;
//  tmp := TQuoteMsgPack.Create(qmtNetTest, t, sizeof(Cardinal));
//  SendMessagePack(tmp);
end;

procedure TQuoteClient.Login;
begin
  SendMessagePack(TQuoteMsgPack.Build(FConfig.UserName, FConfig.Password));
end;

procedure TQuoteClient.OnConnect(pvContext: TDiocpCustomContext);
begin
  PostLog(llMessage, '已成功连接服务器');
  FRemote := pvContext as TIocpCoderRemoteContext;
  Login;
end;

procedure TQuoteClient.OnContextError(pvContext: TDiocpCustomContext; pvErrorCode: Integer);
begin
  PostLog(llError, '通讯错误，错误代码:%d', [pverrorCode]);
end;

procedure TQuoteClient.OnDisconnect(pvContext: TDiocpCustomContext);
begin
  FRemote := nil;
  FTCPClient.DataMoniter.clear;
  PostLog(llMessage, '断开与服务端的链接');
end;

procedure TQuoteClient.RecvBinaryBlocks(APack: TQuoteMsgPack);
var
  pFB: PQFileBlocks;
  pQFC: TQuoteFileContext;
begin
  pFB := APack.BodyBuffer;

  if FFileContexts.TryGetValue(pFB.GetFileName, pQFC) then
  begin
    pQFC.WriteBinaryBlocks(APack);
    SendMessage(TargetWinHandle, WM_RECV_INFO, Integer(Pointer(pQFC)),0);
  end else
  begin
    PostLog(llWarning, '未找到%s文件控制块，忽略此数据', [pFB.GetFileName]);
  end;

end;

procedure TQuoteClient.RecvFilePack(APack: TQuoteMsgPack);
var
  localFileName:string;
  pFilePack:PQuoteFilePack;
  pQFC: TQuoteFileContext;
begin
  pFilePack := APack.BodyBuffer;

  //建立文件写入对象
  if not FFileContexts.TryGetValue(pFilePack.GetFileName, pQFC) then
  begin
    localFileName := TPath.Combine( FConfig.LocalPath , pFilePack.GetFileName );
    localFileName := TPath.GetFullPath(localFileName);
    pQFC := TQuoteFileContext.Create(localFileName, pFilePack.GetFileName);
    FFileContexts.Add(UpperCase(pFilePack.GetFileName), pQFC);
  end;

  pQFC.WriteFile(APack);
  PostMessage(TargetWinHandle, WM_RECV_INFO, Integer(Pointer(pQFC)),0);
end;

procedure TQuoteClient.Restart;
begin
  Stop;
  Start;
end;

procedure TQuoteClient.SendMessagePack(APack:TQuoteMsgPack; bAutoFree:boolean=True);
begin
  FSendLocker.Enter;
  if Assigned(FRemote) and FRemote.Active then
  begin
    try
      FRemote.WriteObject(APack);
    except

    end;
    if bAutoFree then APack.Free;
  end;
  FSendLocker.Leave;
end;

procedure TQuoteClient.Start;
var
  context: TIocpRemoteContext;
begin
  //只允许有一个连接
  if Assigned(FRemote) then Exit;

  //断开所有连接
  FTCPClient.DisconnectAll;

  if not FTCPClient.Active then
    FTCPClient.Active := True;

  //异步连接服务端
  PostLog(llMessage, '准备连接%s:%d', [FConfig.Host, FConfig.Port]);
  context := FTCPClient.Add;
  context.Host := FConfig.Host;
  context.Port := FConfig.Port;
  context.AutoReConnect := True;
  context.ConnectASync;

end;

procedure TQuoteClient.Stop;
begin
  if Assigned(FRemote) then
  begin
    FRemote.AutoReConnect := False;
    FRemote.Close;
    FRemote := nil;
    sleep(150);
  end;

  FTCPClient.DisconnectAll;
  FFileContexts.Clear;
  FTCPClient.Active := False;
end;

{ TQuoteFileScan }

constructor TQBinaryFileScan.Create(AOwner: TQuoteServer; AFilename: string);
begin
  inherited Create(False);
  FScanLocker := TCriticalSection.Create;
  FreeOnTerminate := True;
  FFileName := TPath.GetFullPath( AFilename );
  FFileSize := 0;
  pBuffer := nil;
  pLastSnap := nil;
  //初始化差异文件块信息
  FillChar(FChangeBlocks, 0, SizeOf(TQFileBlocks));
  FChangeBlocks.SetFileName(TPath.GetFileName(FFileName));
  FChangeBlocks.BlockCount := 0;

  FOwner := AOwner;
end;

destructor TQBinaryFileScan.Destroy;
begin
  FScanLocker.Free;
  inherited;
end;

procedure TQBinaryFileScan.Execute;
var
  fHandle, mHandle :THandle;


  procedure _compare;
  var i,k,n:integer; ptr1, ptr2:PByte;
  begin
    ptr1 := pBuffer; ptr2 := pLastSnap;
    n := 0;
    for i := 0 to Ceil(FFileSize / Q_BINARY_BLOCK_SIZE) - 1 do
    begin
      k := Min(FFileSize-i*Q_BINARY_BLOCK_SIZE,Q_BINARY_BLOCK_SIZE);
      if not CompareMem(ptr1, ptr2, k) then
      begin
        FChangeBlocks.Context[n].Order := i;
        FChangeBlocks.Context[n].Len := k;
        Move(ptr1^, FChangeBlocks.Context[n].Bytes[1], k);
        inc(n);
      end;
      Inc(ptr1, Q_BINARY_BLOCK_SIZE);
      Inc(ptr2, Q_BINARY_BLOCK_SIZE);
    end;
    FChangeBlocks.BlockCount := n;
  end;
begin

  if not TFile.Exists(FFileName) then
  begin
    PostLog(llError, '扫描文件失败，%s文件不存在！',[FFileName]);
    Exit;
  end;

  //共享打开文件
  fHandle := FileOpen(FFileName, fmOpenRead or fmShareDenyNone);
  if fHandle = INVALID_HANDLE_VALUE then
  begin
    PostLog(llError, '快照扫描[%s],打开文件失败',[FFileName]);
    Exit;
  end;

  FFileSize := GetFileSize(fHandle, nil);

  //内存映射文件
  mHandle := CreateFileMapping(fHandle,nil,PAGE_READONLY or SEC_COMMIT, 0, FFileSize,nil);
  if mHandle = 0 then
  begin
    CloseHandle(fHandle);
    PostLog(llError, '快照扫描[%s],建立内存映射失败',[FFileName]);
    Exit;
  end;
  pBuffer := MapViewOfFile(mHandle, FILE_MAP_READ, 0, 0, 0);

  PostLog(llMessage, '开启%s文件扫描成功，字节数:%d',[FFileName,FFileSize]);
  //申请快照内存
  GetMem(pLastSnap,FFileSize);

  //循环比较文件内容
  Move(pBuffer^, pLastSnap^, FFileSize); //保存初始快照
  while not Terminated do
  begin
    FScanLocker.Enter;
    _compare;
    if FChangeBlocks.BlockCount>0 then
    begin
      Move(pBuffer^, pLastSnap^, FFileSize); //如果有变化，保存最后一次内容
      FOwner.FileChanged(@FChangeBlocks);
    end;
    FScanLocker.Leave;
    self.Sleep(10);
  end;

  //释放资源
  FreeMem(pLastSnap);
  UnmapViewOfFile(pBuffer);
  CloseHandle(mHandle);
  CloseHandle(fHandle);
end;

function TQBinaryFileScan.FilePack: TQuoteMsgPack;
var
  fp: TQuoteFilePack;
begin
  fp.SetFileName(UpperCase(TPath.GetFileName(filename)));
  fp.FileLength := FFileSize;
  result := TQuoteMsgPack.Create(qmtFile, fp.FileName[1], SizeOf(TQuoteFilePack));
  result.Append(pBuffer^, FFileSize);
end;

procedure TQBinaryFileScan.Lock;
begin
  FScanLocker.Enter;
end;

procedure TQBinaryFileScan.UnLock;
begin
  FScanLocker.Leave;
end;

{ TQuoteFileContext }

constructor TQuoteFileContext.Create(AFileName, AKeyName: string);
begin
  //如果文件不存在先创建
  if not TFile.Exists(AFileName) then
  begin
    //目录不存在，先创建
    if not TDirectory.Exists(TPath.GetDirectoryName(AFileName)) then
      TDirectory.CreateDirectory(TPath.GetDirectoryName(AFileName));
    FFileStream := TFileStream.Create(AFileName, fmCreate);
    FFileStream.Free;
  end;

  FFileName := AFileName;
  FKeyName := AKeyName;
  FFileStream := TFileStream.Create(FFileName, fmOpenWrite or fmShareDenyWrite);
  FFileSize := FFileStream.Size;
  FUpdateSize := 0;
  FTotalWriteSize := 0;
  FUpdateCount := 0;
end;

destructor TQuoteFileContext.Destroy;
begin
  if Assigned(FFileStream) then
    FreeAndNil(FFileStream);
  inherited;
end;

function TQuoteFileContext.GetFilePack: TQuoteMsgPack;
begin
  result := nil;
end;

function TQuoteFileContext.WriteBinaryBlocks(APack: TQuoteMsgPack): boolean;
var
  pBlk:PQBinaryBlock;
  tmp:PQFileBlocks;
  i:integer;
  ptrSrc:pByte;
begin
  FUpdateTime := now;
  FUpdateSize := 0;
  tmp := PQFileBlocks(APack.BodyBuffer);

  for i := 0 to tmp.BlockCount-1 do
  begin
    pBlk := @(tmp.Context[i]);

    Assert(pBlk.Len<=32);

    FFileStream.Seek(pBlk.Order*Q_BINARY_BLOCK_SIZE, soFromBeginning);
    ptrSrc := @(pBlk.Bytes[1]);
    FFileStream.Write(ptrSrc^, pBlk.Len);

    inc(FUpdateSize, pBlk.Len);
  end;

  inc(FTotalWriteSize, FUpdateSize);
  inc(FUpdateCount,1);
  result := True;
end;

procedure TQuoteFileContext.WriteFile(APack: TQuoteMsgPack);
var
  pFilePack:PQuoteFilePack;
begin
  pFilePack := APack.BodyBuffer;
  FFileStream.Size := pFilePack.FileLength;
  FFileStream.Seek(0, soFromBeginning);
  FFileStream.Write(pFilePack.GetContextPtr^, pFilepack.FileLength);

  FFileSize := pFilepack.FileLength;
  FUpdateSize := pFilepack.FileLength;

  Inc(FUpdateCount);
  inc(FTotalWriteSize, FFileSize);
  FUpdateTime := now;
end;

{ TNetMonitor }

constructor TNetSpeedMonitor.Create;
begin
  FLastSent := 0;
  FLastRecv := 0;
  FJobHandle := 0;
  FSource := ASource;
  //每秒检测一次
  FJobHandle := Workers.post(doSpeedDetect,10000, nil);
end;

procedure TNetSpeedMonitor.doSpeedDetect(AJob: PQJob);
var
  s,r:Int64;
begin
  s := FSource.SentSize;
  r := FSource.RecvSize;
  SentSpeed := s - FLastSent;
  RecvSpeed := r - FLastRecv;
  FLastSent := s;
  FLastRecv := r;
end;

procedure TNetSpeedMonitor.Stop;
begin
  if FJobHandle > 0 then
    workers.ClearSingleJob(FJobHandle);
end;

end.
