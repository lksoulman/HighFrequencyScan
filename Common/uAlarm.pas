unit uAlarm;

interface

uses
  Classes, types, SysUtils, StrUtils, DateUtils, IOUtils, HttpApp,
  RestClient, RestUtils, httpconnection, uLog,
  clSmtp,clHttp, superObject;

type
  TAlarmSendType = (astCustomURL, astSMTP, astWeChat, astDingText, astDingMD);

  TAlarm = packed record
    Title : string;
    Msg   : string;
    function SendJson(AURL, AjsonStr: string): string;
    procedure SendByUrl(AUrl:string);
    procedure SendByMail(ATo:string; AServer, AUser, APassword:string; APort:Integer=25);
    procedure SendByWeChat(AToken:string);
    procedure SendByDingText(AToken:string);
    procedure SendByDingMarkdown(AToken:string);
  end;

implementation


{ TAlarm }

procedure TAlarm.SendByDingMarkdown(AToken: string);
begin

end;

procedure TAlarm.SendByDingText(AToken: string);
const
  Context = '{"msgtype":"text","text":{"content":"%s"},"at":{"atMobiles": [""],"isAtAll": true}}';
var
  str: string;
begin
  str := Format(context, [msg]);

  SendJSON(
    Format('https://oapi.dingtalk.com/robot/send?access_token=%s', [HttpEncode(AToken)]),
    str);
end;

procedure TAlarm.SendByMail(ATo, AServer, AUser, APassword: string;
  APort: Integer);
begin

end;

procedure TAlarm.SendByUrl(AUrl: string);
begin

end;

procedure TAlarm.SendByWeChat(AToken: string);
const serverJiang = 'https://pushbear.ftqq.com/sub';
//var
//  http:TclHttp;
//  url:string;
//  resp:TStringList;
//begin
//  url := Format('%s?sendkey=%s&text=%s&desp=%s', [serverJiang, AToken, HTTPEncode(Title), HTTPEncode(Msg)]);
//  resp := TStringList.Create;
//  http := tclhttp.Create(nil);
//  try
//    http.Post(url,resp);
//  except
//    http.Free;
//  end;
//  resp.Free;
var
  vResult: String;
  RestClient: TRestClient;
begin
  RestClient := TRestClient.Create(nil);
  RestClient.ConnectionType := hctWinInet;
  vResult := RestClient.Resource(serverJiang+Format('?sendkey=%s&text=%s&desp=%s', [ AToken, HTTPEncode(Title), HTTPEncode(Msg)]))
                       .Accept(RestUtils.MediaType_Json)
                       .ContentType(RestUtils.MediaType_Json)
                       .Get;
  RestClient.Free;
end;

function TAlarm.SendJson(AURL, AjsonStr: string): string;
var
  vResult: String;
  RestClient: TRestClient;
  stream:TStringStream;
begin
  stream := TStringStream.Create(AjsonStr, TEncoding.UTF8);
  stream.Position := 0;
  RestClient := TRestClient.Create(nil);
  RestClient.ConnectionType := hctWinInet;
  vResult := RestClient.Resource(AURL)
                       .Accept(RestUtils.MediaType_Json)
                       .ContentType(RestUtils.MediaType_Json)
                       .Post(stream);
  RestClient.Free;
  Stream.Free;
end;

end.


