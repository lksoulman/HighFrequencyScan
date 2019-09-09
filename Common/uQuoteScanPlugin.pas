unit uQuoteScanPlugin;

interface

uses

  uQuoteFile, IOUtils, StrUtils, DateUtils, Classes, Generics.Collections;

type

  TScanPlugin_LogProc = procedure(ALevel:Integer; AMsg:PAnsiChar; ALen:Integer); stdcall;
  TScanPlugin_Init = procedure(ALogProcCallback:TScanPlugin_LogProc); stdcall;
  TScanPlugin_Final = procedure(); stdcall;
  TScanPlugin_RecvQuotation= procedure(const ARec:PQuoteRecord); stdcall;

  PScanPluginInfo = ^TScanPluginInfo;
  TScanPluginInfo = packed record
    PluginName:array[0..63] of AnsiChar;
    PluginVer :array[0..63] of AnsiChar;
    OnInit    :TScanPlugin_Init;
    OnFInal   :TScanPlugin_Final;
    OnRecv    :TScanPlugin_RecvQuotation;
  end;

  TPluginHelper = class
  strict private
    class var
    FPluginList:TList<TScanPluginInfo>;
  public
    class procedure LoadAllPlugin;
    class property PluginList: TList<TScanPluginInfo> read FPluginList;
  end;



implementation

{ TPluginHelper }

class procedure TPluginHelper.LoadAllPlugin;
begin

end;

end.
